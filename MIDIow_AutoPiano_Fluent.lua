--[[
    MIDIow Auto Piano - standalone custom GUI
    No Fluent/WindUI dependency.

    Executor requirements (for local files / MIDI keyboard injection):
      - VirtualInputManager:SendKeyEvent
      - isfolder, makefolder, readfile, writefile, listfiles (optional but recommended)
      - game:HttpGet (optional, for loading a MIDI URL)

    Folders:
      MIDI/           Put .mid/.midi files here
      MIDIow/Saves/   Saved piano-sheet text files

    Sheet notation:
      q w e r t       sequential keys
      [qet]           chord (keys pressed together)
      Q               uppercase = hold Shift while pressing that key
      - or .          rest for one beat
      Spaces/newlines are ignored.

    MIDI mapping below is a practical default keyboard layout. Some piano games
    use a different layout; edit MIDI_KEY_LAYOUT / MIDI_FIRST_NOTE if needed.
    This script deliberately contains no anti-cheat, anti-detection, or bypass code.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

local APP_NAME = "MIDIow Auto Piano"
local ROOT_FOLDER = "MIDIow"
local SAVE_FOLDER = ROOT_FOLDER .. "/Saves"
local MIDI_FOLDER = "MIDI"

local COLORS = {
    background = Color3.fromRGB(13, 15, 22),
    panel = Color3.fromRGB(21, 24, 34),
    panel2 = Color3.fromRGB(28, 32, 45),
    panel3 = Color3.fromRGB(36, 41, 57),
    accent = Color3.fromRGB(125, 98, 255),
    accent2 = Color3.fromRGB(84, 178, 255),
    text = Color3.fromRGB(240, 242, 250),
    muted = Color3.fromRGB(155, 162, 181),
    green = Color3.fromRGB(80, 210, 151),
    red = Color3.fromRGB(255, 102, 121),
    border = Color3.fromRGB(54, 60, 78),
}

local function safeCall(fn, ...)
    local args = table.pack(...)
    local ok, result = pcall(function()
        return fn(table.unpack(args, 1, args.n))
    end)
    return ok, result
end

local function ensureFolder(path)
    if type(isfolder) == "function" and type(makefolder) == "function" then
        local ok, exists = pcall(isfolder, path)
        if ok and not exists then
            pcall(makefolder, path)
        end
    end
end

ensureFolder(ROOT_FOLDER)
ensureFolder(SAVE_FOLDER)
ensureFolder(MIDI_FOLDER)

local function fileApiAvailable()
    return type(readfile) == "function" and type(writefile) == "function" and type(listfiles) == "function"
end

local function notify(title, message, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = duration or 3,
        })
    end)
end

-- Keyboard input -------------------------------------------------------------
local keyCodes = Enum.KeyCode
local function enumKey(name)
    local ok, value = pcall(function() return keyCodes[name] end)
    return ok and value or nil
end
local activeKeyboardKeys = {}
local shiftHeld = false

local function sendKey(keyCode, isDown)
    if not keyCode or not VirtualInputManager then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
    end)
end

local function setShift(isDown)
    if shiftHeld == isDown then return end
    shiftHeld = isDown
    sendKey(keyCodes.LeftShift, isDown)
end

local function pressKeyboardKey(keyCode, shifted, holdId)
    if not keyCode then return end
    -- Apply Shift only for the key-down event. This allows chords to mix
    -- shifted and unshifted notes without leaving the modifier held globally.
    if shifted then sendKey(keyCodes.LeftShift, true) end
    sendKey(keyCode, true)
    if shifted then sendKey(keyCodes.LeftShift, false) end
    if holdId then
        activeKeyboardKeys[holdId] = { key = keyCode, shifted = false }
    else
        task.delay(0.055, function() sendKey(keyCode, false) end)
    end
end

local function releaseKeyboardKey(holdId)
    local held = activeKeyboardKeys[holdId]
    if not held then return end
    sendKey(held.key, false)
    activeKeyboardKeys[holdId] = nil
    if held.shifted then
        local anyShifted = false
        for _, item in pairs(activeKeyboardKeys) do
            if item.shifted then anyShifted = true break end
        end
        if not anyShifted then setShift(false) end
    end
end

local function releaseAllKeys()
    for id, held in pairs(activeKeyboardKeys) do
        sendKey(held.key, false)
        activeKeyboardKeys[id] = nil
    end
    setShift(false)
end

-- Piano-sheet key names -------------------------------------------------------
local SHEET_KEYS = {}
for c = string.byte("a"), string.byte("z") do
    local name = string.char(c):upper()
    SHEET_KEYS[string.char(c)] = { key = enumKey(name), shifted = false }
    SHEET_KEYS[name] = { key = enumKey(name), shifted = true }
end

local digitNames = {
    ["1"] = "One", ["2"] = "Two", ["3"] = "Three", ["4"] = "Four", ["5"] = "Five",
    ["6"] = "Six", ["7"] = "Seven", ["8"] = "Eight", ["9"] = "Nine", ["0"] = "Zero",
}
for digit, enumName in pairs(digitNames) do
    SHEET_KEYS[digit] = { key = enumKey(enumName), shifted = false }
end

local punctuationNames = {
    ["["] = "LeftBracket", ["]"] = "RightBracket", [";"] = "Semicolon", ["'"] = "Quote",
    [","] = "Comma", ["."] = "Period", ["/"] = "Slash", ["-"] = "Minus", ["="] = "Equals",
    ["\\"] = "BackSlash", ["`"] = "Backquote",
}
for char, enumName in pairs(punctuationNames) do
    SHEET_KEYS[char] = { key = enumKey(enumName), shifted = false }
end

-- MIDI mapping: 3 keyboard rows, chromatic notes. This is a default mapping;
-- replace entries here to match the target piano game's physical key layout.
local MIDI_FIRST_NOTE = 21 -- A0; first 44-key bank, followed by a Shift bank
local MIDI_KEY_LAYOUT = {
    "Z", "S", "X", "D", "C", "V", "G", "B", "H", "N", "J", "M",
    "Q", "Two", "W", "Three", "E", "R", "Five", "T", "Six", "Y", "Seven", "U",
    "I", "Nine", "O", "Zero", "P", "LeftBracket", "Equals", "RightBracket", "BackSlash", "A", "Four", "F",
    "Eight", "K", "Comma", "L", "Period", "Semicolon", "Slash", "Quote",
}
local MIDI_KEY_MAP = {}
for bank = 0, 1 do
    for i, enumName in ipairs(MIDI_KEY_LAYOUT) do
        local note = MIDI_FIRST_NOTE + bank * #MIDI_KEY_LAYOUT + i - 1
        MIDI_KEY_MAP[note] = { key = enumKey(enumName), shifted = bank == 1 }
    end
end

-- MIDI parser -----------------------------------------------------------------
local function readU16(data, pos)
    local a, b = string.byte(data, pos, pos + 1)
    if not b then error("Unexpected end of MIDI header") end
    return a * 256 + b, pos + 2
end

local function readU32(data, pos)
    local a, b, c, d = string.byte(data, pos, pos + 3)
    if not d then error("Unexpected end of MIDI chunk") end
    return ((a * 256 + b) * 256 + c) * 256 + d, pos + 4
end

local function readVLQ(data, pos, limit)
    local value = 0
    local count = 0
    while pos <= limit do
        local byte = string.byte(data, pos)
        if not byte then error("Unexpected end while reading MIDI variable length quantity") end
        pos += 1
        value = value * 128 + bit32.band(byte, 0x7F)
        count += 1
        if bit32.band(byte, 0x80) == 0 then return value, pos end
        if count > 4 then error("Invalid MIDI variable length quantity") end
    end
    error("Malformed MIDI variable length quantity")
end

local function parseMidi(data)
    assert(type(data) == "string" and #data >= 14, "MIDI data is empty or too short")
    assert(string.sub(data, 1, 4) == "MThd", "Not a Standard MIDI file")

    local headerLength, p = readU32(data, 5)
    assert(headerLength >= 6, "Invalid MIDI header")
    local format, trackCount
    format, p = readU16(data, p)
    trackCount, p = readU16(data, p)
    local division
    division, p = readU16(data, p)
    assert(trackCount > 0, "MIDI contains no tracks")
    assert(bit32.band(division, 0x8000) == 0, "SMPTE-timed MIDI files are not supported")
    local ticksPerBeat = division
    assert(ticksPerBeat > 0, "Invalid MIDI ticks-per-beat value")
    p = 9 + headerLength

    local rawEvents = {}
    local tempos = { { tick = 0, tempo = 500000 } }
    local eventSerial = 0

    for track = 1, trackCount do
        if string.sub(data, p, p + 3) ~= "MTrk" then break end
        local trackLength
        trackLength, p = readU32(data, p + 4)
        local pos = p
        local trackEnd = math.min(#data + 1, pos + trackLength)
        p = trackEnd
        local absTick = 0
        local runningStatus = nil

        while pos < trackEnd do
            local delta
            delta, pos = readVLQ(data, pos, trackEnd - 1)
            absTick += delta
            local status = string.byte(data, pos)
            if not status then break end

            if status >= 0x80 then
                pos += 1
                if status < 0xF0 then runningStatus = status end
            else
                status = runningStatus
                if not status then error("MIDI running status without previous status") end
            end

            if status == 0xFF then
                local metaType = string.byte(data, pos)
                pos += 1
                local length
                length, pos = readVLQ(data, pos, trackEnd - 1)
                if metaType == 0x51 and length == 3 then
                    local a, b, c = string.byte(data, pos, pos + 2)
                    if c then tempos[#tempos + 1] = { tick = absTick, tempo = a * 65536 + b * 256 + c } end
                end
                pos += length
                if metaType == 0x2F then break end
            elseif status == 0xF0 or status == 0xF7 then
                local length
                length, pos = readVLQ(data, pos, trackEnd - 1)
                pos += length
                runningStatus = nil
            else
                local command = bit32.band(status, 0xF0)
                local data1 = string.byte(data, pos)
                if not data1 then break end
                pos += 1
                local data2
                if command ~= 0xC0 and command ~= 0xD0 then
                    data2 = string.byte(data, pos)
                    if not data2 then break end
                    pos += 1
                end

                if command == 0x90 and data2 and data2 > 0 then
                    eventSerial += 1
                    rawEvents[#rawEvents + 1] = { tick = absTick, kind = "on", note = data1, velocity = data2, channel = bit32.band(status, 0x0F), serial = eventSerial }
                elseif command == 0x80 or (command == 0x90 and data2 == 0) then
                    eventSerial += 1
                    rawEvents[#rawEvents + 1] = { tick = absTick, kind = "off", note = data1, channel = bit32.band(status, 0x0F), serial = eventSerial }
                end
            end
            if pos > trackEnd then error("MIDI track chunk is malformed") end
        end
    end

    table.sort(tempos, function(a, b) return a.tick < b.tick end)
    local compactTempos = {}
    for _, t in ipairs(tempos) do
        if #compactTempos > 0 and compactTempos[#compactTempos].tick == t.tick then
            compactTempos[#compactTempos].tempo = t.tempo
        else
            compactTempos[#compactTempos + 1] = t
        end
    end
    tempos = compactTempos

    table.sort(rawEvents, function(a, b)
        if a.tick == b.tick then
            if a.kind ~= b.kind then return a.kind == "off" end
            return a.serial < b.serial
        end
        return a.tick < b.tick
    end)

    -- Pair every Note On with its matching Note Off so held keys are released.
    local activeByPitch = {}
    for _, event in ipairs(rawEvents) do
        local pitchKey = tostring(event.channel or 0) .. ":" .. tostring(event.note)
        activeByPitch[pitchKey] = activeByPitch[pitchKey] or {}
        local queue = activeByPitch[pitchKey]
        if event.kind == "on" then
            event.pairId = event.serial
            queue[#queue + 1] = event.serial
        else
            event.pairId = table.remove(queue, 1) or event.serial
        end
    end

    local tempoIndex = 1
    local currentTick = 0
    local currentSeconds = 0
    local currentTempo = tempos[1].tempo
    local events = {}
    local maxTime = 0

    for _, event in ipairs(rawEvents) do
        while tempoIndex < #tempos and tempos[tempoIndex + 1].tick <= event.tick do
            local nextTempo = tempos[tempoIndex + 1]
            currentSeconds += ((nextTempo.tick - currentTick) / ticksPerBeat) * (currentTempo / 1000000)
            currentTick = nextTempo.tick
            currentTempo = nextTempo.tempo
            tempoIndex += 1
        end
        local eventTime = currentSeconds + ((event.tick - currentTick) / ticksPerBeat) * (currentTempo / 1000000)
        events[#events + 1] = { time = eventTime, kind = event.kind, note = event.note, velocity = event.velocity, pairId = event.pairId }
        if eventTime > maxTime then maxTime = eventTime end
    end

    assert(#events > 0, "No playable note events were found in this MIDI")
    return events, maxTime, format, trackCount
end

-- Playback state --------------------------------------------------------------
local state = {
    mode = "none", -- midi / sheet
    status = "Ready",
    events = {},
    index = 1,
    duration = 0,
    elapsed = 0,
    startedAt = 0,
    playing = false,
    paused = false,
    bpm = 120,
    speed = 1,
    transpose = 0,
    loop = false,
    songName = "No song loaded",
    currentSource = nil,
    generation = 0,
}

local function updateStatus(message)
    state.status = message
end

local function sortedEvents(events)
    table.sort(events, function(a, b)
        if a.time == b.time then
            if a.kind ~= b.kind then return a.kind == "off" end
            return (a.order or 0) < (b.order or 0)
        end
        return a.time < b.time
    end)
    return events
end

local function midiNoteOn(note, velocity, id)
    local mapped = MIDI_KEY_MAP[note + state.transpose]
    if not mapped or not mapped.key then return end
    pressKeyboardKey(mapped.key, mapped.shifted, "midi:" .. tostring(id))
end

local function midiNoteOff(note, id)
    releaseKeyboardKey("midi:" .. tostring(id))
end

local function stopPlayback(silent)
    state.generation += 1
    state.playing = false
    state.paused = false
    state.elapsed = 0
    state.index = 1
    releaseAllKeys()
    if not silent then updateStatus("Stopped") end
end

local function loadEventSong(events, duration, name, mode)
    stopPlayback(true)
    state.events = sortedEvents(events)
    state.duration = duration or 0
    state.index = 1
    state.elapsed = 0
    state.mode = mode
    state.songName = name or "Untitled"
    state.currentSource = nil
    updateStatus("Loaded: " .. state.songName)
end

local function playFromCurrentPosition()
    if #state.events == 0 then
        updateStatus("Load a MIDI or sheet first")
        return
    end
    if state.playing then return end
    if state.elapsed >= state.duration and state.duration > 0 then
        state.elapsed = 0
        state.index = 1
    end
    state.playing = true
    state.paused = false
    state.startedAt = os.clock() - (state.elapsed / state.speed)
    state.generation += 1
    local myGeneration = state.generation
    updateStatus("Playing")

    task.spawn(function()
        while state.playing and state.generation == myGeneration do
            local elapsed = (os.clock() - state.startedAt) * state.speed
            state.elapsed = elapsed

            while state.index <= #state.events do
                local ev = state.events[state.index]
                if ev.time > elapsed then break end
                local id = ev.id or tostring(state.index)
                if state.mode == "midi" then
                    if ev.kind == "on" then
                        midiNoteOn(ev.note, ev.velocity, ev.pairId or id)
                    elseif ev.kind == "off" then
                        midiNoteOff(ev.note, ev.pairId or id)
                    end
                elseif state.mode == "sheet" then
                    if ev.kind == "on" then
                        pressKeyboardKey(ev.key, ev.shifted, "sheet:" .. tostring(id))
                    elseif ev.kind == "off" then
                        releaseKeyboardKey("sheet:" .. tostring(id))
                    end
                end
                state.index += 1
            end

            if state.index > #state.events then
                if state.loop then
                    state.elapsed = 0
                    state.index = 1
                    state.startedAt = os.clock()
                    releaseAllKeys()
                else
                    state.playing = false
                    state.paused = false
                    state.elapsed = state.duration
                    releaseAllKeys()
                    updateStatus("Finished")
                    break
                end
            end
            task.wait(0.002)
        end
    end)
end

local function pausePlayback()
    if not state.playing then return end
    state.elapsed = (os.clock() - state.startedAt) * state.speed
    state.playing = false
    state.paused = true
    releaseAllKeys()
    updateStatus("Paused")
end

local function resumePlayback()
    if state.paused then
        state.startedAt = os.clock() - (state.elapsed / state.speed)
        state.playing = false
        playFromCurrentPosition()
    else
        playFromCurrentPosition()
    end
end

local function seekPlayback(fraction)
    fraction = math.clamp(fraction, 0, 1)
    local wasPlaying = state.playing
    state.generation += 1
    state.playing = false
    state.paused = true
    releaseAllKeys()
    local target = state.duration * fraction
    state.elapsed = target
    state.index = 1
    while state.index <= #state.events and state.events[state.index].time < target do
        state.index += 1
    end
    updateStatus("Seeked to " .. string.format("%.1f", target) .. "s")
    if wasPlaying then resumePlayback() end
end

-- Sheet notation parser --------------------------------------------------------
local function parseSheet(text, bpm)
    assert(type(text) == "string" and #text > 0, "Enter piano sheet notation first")
    local steps = {}
    local i = 1
    while i <= #text do
        local char = string.sub(text, i, i)
        if char:match("%s") or char == "," or char == "|" then
            i += 1
        elseif char == "[" then
            local closeAt = string.find(text, "]", i + 1, true)
            assert(closeAt, "Chord is missing a closing ]")
            local chordText = string.sub(text, i + 1, closeAt - 1)
            local chord = {}
            for ch in chordText:gmatch(".") do
                local mapped = SHEET_KEYS[ch]
                if mapped and mapped.key then chord[#chord + 1] = mapped end
            end
            assert(#chord > 0, "Empty or invalid chord in sheet")
            steps[#steps + 1] = { notes = chord }
            i = closeAt + 1
        elseif char == "-" then
            steps[#steps + 1] = { notes = {} }
            i += 1
        elseif char == "." then
            steps[#steps + 1] = { notes = {} }
            i += 1
        else
            local mapped = SHEET_KEYS[char]
            if mapped and mapped.key then
                steps[#steps + 1] = { notes = { mapped } }
            end
            i += 1
        end
    end
    assert(#steps > 0, "No valid piano keys were found in the sheet")

    local beat = 60 / math.clamp(tonumber(bpm) or 120, 30, 300)
    local events = {}
    local eventId = 0
    local noteLength = beat * 0.78
    for stepIndex, step in ipairs(steps) do
        local startTime = (stepIndex - 1) * beat
        for _, note in ipairs(step.notes) do
            eventId += 1
            local id = eventId
            events[#events + 1] = { time = startTime, kind = "on", key = note.key, shifted = note.shifted, id = id, order = 2 }
            events[#events + 1] = { time = startTime + noteLength, kind = "off", id = id, order = 1 }
        end
    end
    return sortedEvents(events), #steps * beat
end

-- Fluent-modded UI --------------------------------------------------------------
-- Fluent-modded 1.6.0 release bundle. The Example.lua asset is an example script;
-- this loader targets the bundled library asset, not the example itself.
local FLUENT_URL = "https://github.com/StyearX/Fluent-modded/releases/download/1.6.0/main.lua"

local function loadFluent()
    assert(type(game.HttpGet) == "function", "HTTP is unavailable in this executor")
    local source = game:HttpGet(FLUENT_URL)
    assert(type(source) == "string" and #source > 0, "Fluent library download was empty")
    local chunk, compileError = loadstring(source)
    assert(chunk, "Fluent compile failed: " .. tostring(compileError))
    local library = chunk()
    assert(type(library) == "table", "Fluent did not return a library table")
    return library
end

local Fluent = loadFluent()
local Window = Fluent:CreateWindow({
    Title = "MIDIow Auto Piano",
    SubTitle = "MIDI + Piano Sheet Player",
    TabWidth = 145,
    Size = UDim2.fromOffset(620, 520),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Floating open/close pill -----------------------------------------------------
-- Fluent-modded exposes Window:Show() and Window:Hide(). This small persistent
-- pill stays outside the window so it can reopen the UI after it is hidden.
local pillGui = Instance.new("ScreenGui")
pillGui.Name = "MIDIowFluentPill"
pillGui.ResetOnSpawn = false
pillGui.IgnoreGuiInset = true
pillGui.DisplayOrder = 100000
pillGui.Parent = PLAYER_GUI

local pill = Instance.new("TextButton")
pill.Name = "TogglePill"
pill.AnchorPoint = Vector2.new(1, 0.5)
pill.Position = UDim2.new(1, -18, 0.58, 0)
pill.Size = UDim2.fromOffset(112, 38)
pill.BackgroundColor3 = Color3.fromRGB(125, 98, 255)
pill.TextColor3 = Color3.fromRGB(255, 255, 255)
pill.Text = "MIDIow  •  OPEN"
pill.TextSize = 13
pill.Font = Enum.Font.GothamBold
pill.AutoButtonColor = true
pill.BorderSizePixel = 0
pill.ZIndex = 100001
pill.Parent = pillGui

local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(1, 0)
pillCorner.Parent = pill

local pillStroke = Instance.new("UIStroke")
pillStroke.Color = Color3.fromRGB(190, 175, 255)
pillStroke.Thickness = 1
pillStroke.Transparency = 0.15
pillStroke.Parent = pill

local windowVisible = true
pill.Activated:Connect(function()
    windowVisible = not windowVisible
    if windowVisible then
        pcall(function() Window:Show() end)
        pill.Text = "MIDIow  •  OPEN"
        pill.BackgroundColor3 = Color3.fromRGB(125, 98, 255)
    else
        pcall(function() Window:Hide() end)
        pill.Text = "MIDIow  •  SHOW"
        pill.BackgroundColor3 = Color3.fromRGB(65, 155, 125)
    end
end)

local Tabs = {
    Player = Window:AddTab({ Title = "Player", Icon = "music" }),
    Sheet = Window:AddTab({ Title = "Sheet", Icon = "keyboard" }),
    Library = Window:AddTab({ Title = "Library", Icon = "library" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local function notify(title, message, duration)
    Fluent:Notify({
        Title = title or APP_NAME,
        Content = tostring(message),
        Duration = duration or 4
    })
end

-- Player tab -------------------------------------------------------------------
local statusParagraph = Tabs.Player:AddParagraph({
    Title = "Now playing",
    Content = "Ready\nNo song loaded"
})

Tabs.Player:AddButton({
    Title = "Play / Resume",
    Description = "Start or resume the currently loaded song",
    Callback = resumePlayback
})

Tabs.Player:AddButton({
    Title = "Pause",
    Description = "Pause playback and release held piano keys",
    Callback = pausePlayback
})

Tabs.Player:AddButton({
    Title = "Stop",
    Description = "Stop playback and return to the beginning",
    Callback = stopPlayback
})

Tabs.Player:AddSlider("PlaybackSpeed", {
    Title = "Playback speed",
    Description = "Adjust playback speed",
    Default = 1,
    Min = 0.5,
    Max = 2,
    Rounding = 2,
    Callback = function(value)
        state.speed = math.clamp(tonumber(value) or 1, 0.5, 2)
    end
})

Tabs.Player:AddToggle("LoopSong", {
    Title = "Loop song",
    Default = false,
    Callback = function(value)
        state.loop = value == true
    end
})

Tabs.Player:AddInput("Transpose", {
    Title = "Transpose (semitones)",
    Description = "MIDI note shift from -24 to +24",
    Default = "0",
    Placeholder = "-12 to +12",
    Numeric = true,
    Finished = true,
    Callback = function(value)
        state.transpose = math.clamp(math.floor(tonumber(value) or 0), -24, 24)
        notify(APP_NAME, "Transpose: " .. state.transpose)
    end
})

local midiPath = ""
Tabs.Player:AddInput("MIDIPath", {
    Title = "MIDI filename or direct URL",
    Description = "Local files are read from MIDI/",
    Default = "",
    Placeholder = "song.mid or https://.../song.mid",
    Numeric = false,
    Finished = true,
    Callback = function(value)
        midiPath = tostring(value or "")
    end
})

Tabs.Player:AddButton({
    Title = "Load MIDI file",
    Description = "Load a .mid/.midi file from the MIDI folder",
    Callback = function()
        if not fileApiAvailable() then
            notify(APP_NAME, "Executor file APIs are unavailable")
            return
        end

        local filename = midiPath:gsub("^%s+", ""):gsub("%s+$", "")
        if filename == "" or filename:match("^https?://") then
            notify(APP_NAME, "Enter a local MIDI filename")
            return
        end

        local path = filename:find("/") and filename or (MIDI_FOLDER .. "/" .. filename)
        local ok, data = pcall(readfile, path)
        if not ok then ok, data = pcall(readfile, "./" .. path) end
        if not ok or type(data) ~= "string" then
            notify(APP_NAME, "Could not read: " .. path)
            return
        end

        local parseOk, events, duration = pcall(parseMidi, data)
        if not parseOk then
            notify(APP_NAME, tostring(events), 6)
            return
        end

        loadEventSong(events, duration, filename, "midi")
        state.currentSource = data
        notify(APP_NAME, "Loaded " .. filename)
    end
})

Tabs.Player:AddButton({
    Title = "Download and load MIDI URL",
    Description = "The URL must point directly to a MIDI file",
    Callback = function()
        local url = midiPath:gsub("^%s+", ""):gsub("%s+$", "")
        if not url:match("^https?://") then
            notify(APP_NAME, "Enter a direct MIDI URL")
            return
        end

        local ok, data = pcall(function() return game:HttpGet(url) end)
        if not ok or type(data) ~= "string" then
            notify(APP_NAME, "MIDI download failed")
            return
        end

        local parseOk, events, duration = pcall(parseMidi, data)
        if not parseOk then
            notify(APP_NAME, tostring(events), 6)
            return
        end

        local filename = url:match("([^/]+)$") or "Downloaded MIDI"
        loadEventSong(events, duration, filename, "midi")
        state.currentSource = data

        if fileApiAvailable() then
            local saveName = filename:gsub("[^%w%._%-]", "_")
            if not saveName:lower():match("%.midi?$") then saveName ..= ".mid" end
            pcall(writefile, MIDI_FOLDER .. "/" .. saveName, data)
        end
        notify(APP_NAME, "Downloaded and loaded " .. filename)
    end
})

-- Sheet tab --------------------------------------------------------------------
local sheetText = "q q [et] y y - [qet]"
local sheetBpm = 120
local sheetName = "My Sheet"

Tabs.Sheet:AddParagraph({
    Title = "Notation guide",
    Content = "Type keys in order: q w e r t\nUse [qet] for a chord, uppercase for Shift, and - or . for a rest. Separate notes with spaces."
})

local sheetNotationControl = Tabs.Sheet:AddInput("SheetNotation", {
    Title = "Piano sheet notation",
    Description = "Enter a sequence of piano keys and chords",
    Default = sheetText,
    Placeholder = "q q [et] y y - [qet]",
    Numeric = false,
    Finished = true,
    Callback = function(value)
        sheetText = tostring(value or "")
    end
})

Tabs.Sheet:AddInput("SheetBPM", {
    Title = "Sheet BPM",
    Default = "120",
    Placeholder = "30-300",
    Numeric = true,
    Finished = true,
    Callback = function(value)
        sheetBpm = math.clamp(tonumber(value) or 120, 30, 300)
    end
})

Tabs.Sheet:AddInput("SheetName", {
    Title = "Song name",
    Default = "My Sheet",
    Placeholder = "Song name",
    Numeric = false,
    Finished = true,
    Callback = function(value)
        sheetName = tostring(value or "My Sheet")
    end
})

Tabs.Sheet:AddButton({
    Title = "Load sheet for playback",
    Description = "Parse the notation and prepare it for playback",
    Callback = function()
        local ok, events, duration = pcall(parseSheet, sheetText, sheetBpm)
        if not ok then
            notify(APP_NAME, tostring(events), 6)
            return
        end
        loadEventSong(events, duration, sheetName ~= "" and sheetName or "My Sheet", "sheet")
        notify(APP_NAME, "Piano sheet loaded")
    end
})

Tabs.Sheet:AddButton({
    Title = "Save current sheet",
    Description = "Save the notation to MIDIow/Saves/",
    Callback = function()
        if type(writefile) ~= "function" then
            notify(APP_NAME, "writefile is unavailable")
            return
        end

        local safeName = sheetName:gsub("[^%w%-%_ ]", ""):gsub("%s+", "_")
        if safeName == "" then
            notify(APP_NAME, "Enter a valid song name")
            return
        end

        local path = SAVE_FOLDER .. "/" .. safeName .. ".txt"
        local ok, err = pcall(writefile, path, sheetText)
        if not ok then
            notify(APP_NAME, "Save failed: " .. tostring(err), 6)
            return
        end
        notify(APP_NAME, "Saved " .. safeName)
    end
})

-- Library tab ------------------------------------------------------------------
local savedFiles = {}
local selectedSavedPath = nil
local selectedSavedName = nil
local selectedDropdownValue = nil

local savedDropdown = Tabs.Library:AddDropdown("SavedSheets", {
    Title = "Saved piano sheets",
    Description = "Choose a saved sheet",
    Values = {},
    Multi = false,
    Default = nil,
    Callback = function(value)
        selectedDropdownValue = value
        for _, item in ipairs(savedFiles) do
            if item.display == value then
                selectedSavedPath = item.path
                selectedSavedName = item.name
                break
            end
        end
    end
})

local function getSavedFiles()
    if type(listfiles) ~= "function" then return {} end
    local ok, files = pcall(listfiles, SAVE_FOLDER)
    if not ok or type(files) ~= "table" then
        ok, files = pcall(listfiles, "./" .. SAVE_FOLDER)
    end
    if not ok or type(files) ~= "table" then return {} end

    local results = {}
    for _, path in ipairs(files) do
        local pathText = tostring(path)
        if pathText:lower():match("%.txt$") then
            local name = (pathText:match("([^/\\]+)$") or pathText):gsub("%.txt$", "")
            results[#results + 1] = {
                path = pathText,
                name = name,
                display = name
            }
        end
    end
    table.sort(results, function(a, b) return a.name:lower() < b.name:lower() end)
    return results
end

local function refreshSavedDropdown()
    savedFiles = getSavedFiles()
    local values = {}
    for _, item in ipairs(savedFiles) do
        values[#values + 1] = item.display
    end
    if savedDropdown and savedDropdown.SetValues then
        savedDropdown:SetValues(values)
    end
    selectedSavedPath, selectedSavedName, selectedDropdownValue = nil, nil, nil
    notify(APP_NAME, #values .. " saved sheet(s) found")
end

Tabs.Library:AddButton({
    Title = "Refresh saved sheets",
    Callback = refreshSavedDropdown
})

Tabs.Library:AddButton({
    Title = "Load selected sheet",
    Description = "Put the selected sheet into the editor",
    Callback = function()
        if not selectedSavedPath then
            notify(APP_NAME, "Choose a saved sheet first")
            return
        end
        local ok, data = pcall(readfile, selectedSavedPath)
        if not ok or type(data) ~= "string" then
            notify(APP_NAME, "Could not read selected sheet")
            return
        end
        sheetText = data
        sheetName = selectedSavedName or "Saved Sheet"
        pcall(function() sheetNotationControl:SetValue(data) end)
        notify(APP_NAME, "Loaded into the sheet editor")
        Window:SelectTab(2)
    end
})

Tabs.Library:AddInput("RenameSavedSheet", {
    Title = "Rename selected sheet",
    Default = "",
    Placeholder = "New filename",
    Numeric = false,
    Finished = true,
    Callback = function(value)
        local newName = tostring(value or ""):gsub("[^%w%-%_ ]", ""):gsub("%s+", "_")
        if not selectedSavedPath then
            notify(APP_NAME, "Select a saved sheet first")
            return
        end
        if newName == "" then
            notify(APP_NAME, "Enter a valid new name")
            return
        end
        local readOk, data = pcall(readfile, selectedSavedPath)
        if not readOk then
            notify(APP_NAME, "Could not read selected sheet")
            return
        end
        local newPath = SAVE_FOLDER .. "/" .. newName .. ".txt"
        local writeOk = pcall(writefile, newPath, data)
        if not writeOk then
            notify(APP_NAME, "Rename failed")
            return
        end
        if type(delfile) == "function" then pcall(delfile, selectedSavedPath) end
        refreshSavedDropdown()
        notify(APP_NAME, "Renamed to " .. newName)
    end
})

Tabs.Library:AddButton({
    Title = "Delete selected sheet",
    Description = "Requires executor delfile support",
    Callback = function()
        if not selectedSavedPath then
            notify(APP_NAME, "Select a saved sheet first")
            return
        end
        if type(delfile) ~= "function" then
            notify(APP_NAME, "delfile is unavailable")
            return
        end
        local ok = pcall(delfile, selectedSavedPath)
        if not ok then
            notify(APP_NAME, "Delete failed")
            return
        end
        refreshSavedDropdown()
        notify(APP_NAME, "Deleted saved sheet")
    end
})

Tabs.Library:AddParagraph({
    Title = "MIDI folder",
    Content = "Put .mid or .midi files in MIDI/. Use the Player tab to load them by filename."
})

Tabs.Library:AddButton({
    Title = "List MIDI files",
    Callback = function()
        if type(listfiles) ~= "function" then
            notify(APP_NAME, "listfiles is unavailable")
            return
        end
        local ok, files = pcall(listfiles, MIDI_FOLDER)
        if not ok or type(files) ~= "table" then
            ok, files = pcall(listfiles, "./" .. MIDI_FOLDER)
        end
        local names = {}
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local value = tostring(path)
                if value:lower():match("%.mid$") or value:lower():match("%.midi$") then
                    names[#names + 1] = value:match("([^/\\]+)$") or value
                end
            end
        end
        notify(APP_NAME, #names > 0 and table.concat(names, ", ") or "No MIDI files found", 6)
    end
})

-- Settings tab -----------------------------------------------------------------
Tabs.Settings:AddParagraph({
    Title = "Controls and requirements",
    Content = "RightCtrl minimizes Fluent. Local song files use executor file APIs. MIDI playback uses VirtualInputManager keyboard events. Piano key mapping may need adjustment for the specific piano game."
})

Tabs.Settings:AddButton({
    Title = "Stop and release all keys",
    Callback = function()
        stopPlayback(true)
        releaseAllKeys()
        notify(APP_NAME, "Playback stopped; all injected keys released")
    end
})

Window:SelectTab(1)
refreshSavedDropdown()

Fluent:Notify({
    Title = APP_NAME,
    Content = "Loaded successfully. RightCtrl minimizes the window.",
    Duration = 5
})

-- Keep status text fresh without depending on a custom ScreenGui.
task.spawn(function()
    while not Fluent.Unloaded do
        local elapsed = math.max(0, state.elapsed or 0)
        local duration = math.max(0, state.duration or 0)
        local function clock(value)
            value = math.floor(value)
            return string.format("%02d:%02d", math.floor(value / 60), value % 60)
        end

        local content = string.format(
            "%s\n%s\n%s / %s",
            tostring(state.songName or "No song"),
            tostring(state.status or "Ready"),
            clock(elapsed),
            clock(duration)
        )
        pcall(function() statusParagraph:SetValue(content) end)
        task.wait(0.25)
    end
    stopPlayback(true)
    releaseAllKeys()
    if pillGui then pillGui:Destroy() end
end)
