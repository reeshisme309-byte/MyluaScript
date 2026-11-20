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

-- UI helpers ------------------------------------------------------------------
local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent, color, transparency)
    create("UIStroke", { Color = color or COLORS.border, Transparency = transparency or 0, Thickness = 1 }, parent)
end

local function padding(parent, left, right, top, bottom)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function label(parent, text, size, color, font)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or COLORS.text,
        TextSize = size or 14,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    }, parent)
end

local function button(parent, text, callback, variant)
    local isAccent = variant == "accent"
    local isDanger = variant == "danger"
    local b = create("TextButton", {
        AutoButtonColor = true,
        BackgroundColor3 = isAccent and COLORS.accent or (isDanger and Color3.fromRGB(76, 35, 47) or COLORS.panel3),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        Size = UDim2.new(0, 110, 0, 36),
    }, parent)
    corner(b, 9)
    if not isAccent and not isDanger then stroke(b, COLORS.border, 0.25) end
    b.Activated:Connect(function()
        if callback then callback() end
    end)
    return b
end

local function textBox(parent, placeholder, initial, multiLine, height)
    local box = create("TextBox", {
        BackgroundColor3 = COLORS.panel2,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = initial or "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = COLORS.muted,
        TextColor3 = COLORS.text,
        TextSize = 13,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextWrapped = multiLine == true,
        MultiLine = multiLine == true,
        ClearTextOnFocus = false,
        Size = UDim2.new(1, 0, 0, height or 38),
    }, parent)
    corner(box, 8)
    stroke(box, COLORS.border, 0.25)
    padding(box, 10, 10, 8, 8)
    return box
end

local function section(parent, titleText, subtitleText)
    local wrap = create("Frame", {
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
    }, parent)
    corner(wrap, 12)
    stroke(wrap, COLORS.border, 0.45)
    padding(wrap, 12, 12, 11, 12)
    local title = label(wrap, titleText, 14, COLORS.text, Enum.Font.GothamBold)
    title.Size = UDim2.new(1, 0, 0, 22)
    local subtitle = label(wrap, subtitleText or "", 11, COLORS.muted)
    subtitle.Size = UDim2.new(1, 0, 0, 18)
    subtitle.Position = UDim2.fromOffset(0, 22)
    local content = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, wrap)
    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        wrap.Size = UDim2.new(1, 0, 0, 60 + layout.AbsoluteContentSize.Y)
    end)
    return wrap, content
end

-- Remove an older copy of this GUI, if present.
local GUI_NAME = "MIDIowAutoPianoGui"
local hiddenGuiParent = nil
if type(gethui) == "function" then
    local ok, hui = pcall(gethui)
    if ok then hiddenGuiParent = hui end
end
for _, container in ipairs({ PLAYER_GUI, hiddenGuiParent }) do
    if container then
        local old = container:FindFirstChild(GUI_NAME)
        if old then old:Destroy() end
    end
end

local guiParent = hiddenGuiParent or PLAYER_GUI

local screenGui = create("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false,
}, guiParent)

local main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0.92, 0, 0.84, 0),
    BackgroundColor3 = COLORS.background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, screenGui)
corner(main, 16)
stroke(main, COLORS.border, 0.1)

local sizeConstraint = create("UISizeConstraint", {
    MinSize = Vector2.new(300, 340),
    MaxSize = Vector2.new(780, 650),
}, main)

local header = create("Frame", {
    BackgroundColor3 = COLORS.panel,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 58),
}, main)
local accentLine = create("Frame", {
    BackgroundColor3 = COLORS.accent,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -2),
    Size = UDim2.new(1, 0, 0, 2),
}, header)
local appTitle = label(header, "MIDIow", 18, COLORS.text, Enum.Font.GothamBold)
appTitle.Position = UDim2.fromOffset(16, 7)
appTitle.Size = UDim2.new(1, -110, 0, 25)
local appSubtitle = label(header, "AUTO PIANO  •  MIDI + SHEET PLAYER", 9, COLORS.muted, Enum.Font.GothamSemibold)
appSubtitle.Position = UDim2.fromOffset(17, 32)
appSubtitle.Size = UDim2.new(1, -120, 0, 15)
local closeButton = button(header, "×", function() screenGui:Destroy(); releaseAllKeys() end, "danger")
closeButton.Size = UDim2.fromOffset(36, 34)
closeButton.Position = UDim2.new(1, -48, 0, 12)
closeButton.TextSize = 20

-- Drag window using header.
do
    local dragging = false
    local dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local tabBar = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 68),
    Size = UDim2.new(1, -24, 0, 38),
}, main)
local tabLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local pageHost = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 114),
    Size = UDim2.new(1, -24, 1, -126),
}, main)

local pages = {}
local tabButtons = {}
local activeTab = nil
local function makePage(name)
    local scroll = create("ScrollingFrame", {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLORS.accent,
        Visible = false,
    }, pageHost)
    padding(scroll, 1, 7, 1, 8)
    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)
    pages[name] = scroll
    local tab = button(tabBar, name, function()
        for pageName, page in pairs(pages) do page.Visible = pageName == name end
        for tabName, tabButton in pairs(tabButtons) do
            tabButton.BackgroundColor3 = tabName == name and COLORS.accent or COLORS.panel3
        end
        activeTab = name
    end, "normal")
    tab.Size = UDim2.new(0.333, -5, 1, 0)
    tabButtons[name] = tab
    return scroll
end

local playerPage = makePage("Player")
local sheetPage = makePage("Sheet")
local libraryPage = makePage("Library")

-- Player page -----------------------------------------------------------------
local playerSection, playerContent = section(playerPage, "Now playing", "Control your loaded MIDI or piano sheet")
local songLabel = label(playerContent, state.songName, 14, COLORS.text, Enum.Font.GothamSemibold)
songLabel.Size = UDim2.new(1, 0, 0, 24)
songLabel.LayoutOrder = 1
local statusLabel = label(playerContent, "Ready", 11, COLORS.muted)
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.LayoutOrder = 2
local progressBack = create("Frame", {
    BackgroundColor3 = COLORS.panel3,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 9),
    LayoutOrder = 3,
}, playerContent)
corner(progressBack, 8)
local progressFill = create("Frame", {
    BackgroundColor3 = COLORS.accent2,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 0, 1, 0),
}, progressBack)
corner(progressFill, 8)
local timeLabel = label(playerContent, "00:00 / 00:00", 10, COLORS.muted)
timeLabel.Size = UDim2.new(1, 0, 0, 16)
timeLabel.LayoutOrder = 4

local playbackButtons = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 38),
    LayoutOrder = 5,
}, playerContent)
local playbackLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 7),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, playbackButtons)
local playBtn = button(playbackButtons, "▶ Play", resumePlayback, "accent")
local pauseBtn = button(playbackButtons, "Ⅱ Pause", pausePlayback)
local stopBtn = button(playbackButtons, "■ Stop", stopPlayback, "danger")
playBtn.Size = UDim2.new(0.32, -5, 1, 0)
pauseBtn.Size = UDim2.new(0.32, -5, 1, 0)
stopBtn.Size = UDim2.new(0.32, -5, 1, 0)

local optionsSection, optionsContent = section(playerPage, "Playback settings", "Adjust speed, transpose, BPM and looping")
local speedTitle = label(optionsContent, "Speed: 1.00×", 12, COLORS.text, Enum.Font.GothamSemibold)
speedTitle.Size = UDim2.new(1, 0, 0, 20)
speedTitle.LayoutOrder = 1
local speedSlider = create("TextButton", {
    BackgroundColor3 = COLORS.panel3, BorderSizePixel = 0, Text = "Drag / tap to change speed (0.50× – 2.00×)",
    TextColor3 = COLORS.muted, TextSize = 11, Font = Enum.Font.Gotham, Size = UDim2.new(1, 0, 0, 34),
    LayoutOrder = 2,
}, optionsContent)
corner(speedSlider, 8)
local speedValue = 1
local function setSpeedFromX(x)
    local f = math.clamp((x - speedSlider.AbsolutePosition.X) / math.max(speedSlider.AbsoluteSize.X, 1), 0, 1)
    speedValue = math.floor((0.5 + f * 1.5) * 100 + 0.5) / 100
    state.speed = speedValue
    speedTitle.Text = string.format("Speed: %.2f×", speedValue)
end
speedSlider.Activated:Connect(function() setSpeedFromX(UserInputService:GetMouseLocation().X) end)
speedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then setSpeedFromX(input.Position.X) end
end)
speedSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then setSpeedFromX(input.Position.X) end
    end
end)

local transposeBox = textBox(optionsContent, "Transpose semitones (e.g. -2, 0, 3)", "0", false, 36)
transposeBox.LayoutOrder = 3
transposeBox.FocusLost:Connect(function()
    local n = tonumber(transposeBox.Text)
    if n then state.transpose = math.clamp(math.floor(n), -24, 24); transposeBox.Text = tostring(state.transpose)
    else transposeBox.Text = tostring(state.transpose) end
end)

local bpmBox = textBox(optionsContent, "Sheet BPM", "120", false, 36)
bpmBox.LayoutOrder = 4
local loopButton
loopButton = button(optionsContent, "Loop: OFF", function()
    state.loop = not state.loop
    loopButton.Text = "Loop: " .. (state.loop and "ON" or "OFF")
    loopButton.BackgroundColor3 = state.loop and COLORS.accent or COLORS.panel3
end)
loopButton.Size = UDim2.new(1, 0, 0, 34)
loopButton.LayoutOrder = 5

local midiSection, midiContent = section(playerPage, "Load MIDI", "Load a MIDI file from the MIDI folder or from a direct URL")
local midiPathBox = textBox(midiContent, "MIDI filename, e.g. song.mid", "", false, 36)
midiPathBox.LayoutOrder = 1
local midiRow = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 }, midiContent)
local midiRowLayout = create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7) }, midiRow)
local loadFileBtn = button(midiRow, "Load file", function()
    if not fileApiAvailable() then notify(APP_NAME, "Executor file APIs are unavailable"); return end
    local filename = midiPathBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if filename == "" then notify(APP_NAME, "Enter a MIDI filename"); return end
    local path = filename:find("/") and filename or (MIDI_FOLDER .. "/" .. filename)
    local ok, data = pcall(readfile, path)
    if not ok then
        -- Some executors return a path from listfiles with a leading ./
        ok, data = pcall(readfile, "./" .. path)
    end
    if not ok or type(data) ~= "string" then notify(APP_NAME, "Could not read: " .. path); return end
    local parseOk, events, duration = pcall(parseMidi, data)
    if not parseOk then notify(APP_NAME, tostring(events), 5); return end
    loadEventSong(events, duration, filename, "midi")
    state.currentSource = data
    notify(APP_NAME, "Loaded " .. filename)
end, "accent")
loadFileBtn.Size = UDim2.new(0.5, -4, 1, 0)
local loadUrlBtn = button(midiRow, "Load URL", function()
    local url = midiPathBox.Text
    if not url:match("^https?://") then notify(APP_NAME, "Paste a direct MIDI file URL"); return end
    if type(game.HttpGet) ~= "function" then notify(APP_NAME, "HTTP loading is unavailable"); return end
    local ok, data = pcall(function() return game:HttpGet(url) end)
    if not ok or type(data) ~= "string" then notify(APP_NAME, "Download failed"); return end
    local parseOk, events, duration = pcall(parseMidi, data)
    if not parseOk then notify(APP_NAME, tostring(events), 5); return end
    loadEventSong(events, duration, url:match("([^/]+)$") or "Downloaded MIDI", "midi")
    state.currentSource = data
    if fileApiAvailable() then
        local filename = (url:match("([^/]+)$") or "download.mid"):gsub("[^%w%._%-]", "_")
        if not filename:lower():match("%.midi?$") then filename ..= ".mid" end
        pcall(writefile, MIDI_FOLDER .. "/" .. filename, data)
    end
    notify(APP_NAME, "MIDI downloaded and loaded")
end)
loadUrlBtn.Size = UDim2.new(0.5, -4, 1, 0)

-- Sheet page ------------------------------------------------------------------
local sheetSection, sheetContent = section(sheetPage, "Piano sheet player", "Type Roblox piano notation. Chords use [brackets], uppercase uses Shift.")
local sheetInput = textBox(sheetContent, "Example: q q [et] y y - [qet] ...", "q q [et] y y - [qet]", true, 170)
sheetInput.LayoutOrder = 1
local sheetBpmRow = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 }, sheetContent)
local sheetBpmBox = textBox(sheetBpmRow, "BPM", "120", false, 36)
sheetBpmBox.Size = UDim2.new(0.33, -4, 1, 0)
sheetBpmBox.Position = UDim2.new(0, 0, 0, 0)
local sheetNameBox = textBox(sheetBpmRow, "Song name", "My Sheet", false, 36)
sheetNameBox.Size = UDim2.new(0.67, -4, 1, 0)
sheetNameBox.Position = UDim2.new(0.33, 4, 0, 0)
local sheetButtons = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3 }, sheetContent)
local sheetButtonsLayout = create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7) }, sheetButtons)
local previewBtn = button(sheetButtons, "Load sheet", function()
    local bpm = tonumber(sheetBpmBox.Text) or tonumber(bpmBox.Text) or 120
    bpm = math.clamp(bpm, 30, 300)
    sheetBpmBox.Text = tostring(bpm)
    local ok, events, duration = pcall(parseSheet, sheetInput.Text, bpm)
    if not ok then notify(APP_NAME, tostring(events), 5); return end
    local name = sheetNameBox.Text ~= "" and sheetNameBox.Text or "My Sheet"
    loadEventSong(events, duration, name, "sheet")
    notify(APP_NAME, "Sheet loaded")
end, "accent")
previewBtn.Size = UDim2.new(0.5, -4, 1, 0)
local clearSheetBtn = button(sheetButtons, "Clear", function() sheetInput.Text = "" end)
clearSheetBtn.Size = UDim2.new(0.5, -4, 1, 0)

local notationInfo = label(sheetContent,
    "Supported: a-z, A-Z (Shift), 0-9, common punctuation, [chords], - / . for rests. Spaces and line breaks are ignored. Each key or chord is one beat.",
    10, COLORS.muted)
notationInfo.Size = UDim2.new(1, 0, 0, 42)
notationInfo.LayoutOrder = 4

local saveSection, saveContent = section(sheetPage, "Save current sheet", "Saved locally in MIDIow/Saves")
local saveNameBox = textBox(saveContent, "Filename (without extension)", "My Sheet", false, 36)
saveNameBox.LayoutOrder = 1
local saveBtn = button(saveContent, "Save sheet", function()
    if type(writefile) ~= "function" then notify(APP_NAME, "writefile is not available in this executor"); return end
    local name = saveNameBox.Text:gsub("[^%w%-%_ ]", ""):gsub("%s+", "_")
    if name == "" then notify(APP_NAME, "Enter a filename"); return end
    local path = SAVE_FOLDER .. "/" .. name .. ".txt"
    local ok, err = pcall(writefile, path, sheetInput.Text)
    if not ok then notify(APP_NAME, "Save failed: " .. tostring(err)); return end
    notify(APP_NAME, "Saved " .. name)
end, "accent")
saveBtn.Size = UDim2.new(1, 0, 0, 36)
saveBtn.LayoutOrder = 2

-- Library page ----------------------------------------------------------------
local librarySection, libraryContent = section(libraryPage, "Saved sheets", "Select a saved sheet to load, rename or delete")
local libraryList = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 1,
}, libraryContent)
local libraryLayout = create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, libraryList)
local refreshLibrary

local renameBox = textBox(libraryContent, "New filename for selected sheet", "", false, 36)
renameBox.LayoutOrder = 2
local libraryActionRow = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 }, libraryContent)
local libraryActionLayout = create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7) }, libraryActionRow)
local renameBtn = button(libraryActionRow, "Rename", function() end)
renameBtn.Size = UDim2.new(0.5, -4, 1, 0)
local deleteBtn = button(libraryActionRow, "Delete", function() end, "danger")
deleteBtn.Size = UDim2.new(0.5, -4, 1, 0)
local selectedSavedPath = nil
local selectedSavedName = nil

local function getFiles(path)
    if type(listfiles) ~= "function" then return {} end
    local ok, files = pcall(listfiles, path)
    if not ok or type(files) ~= "table" then
        ok, files = pcall(listfiles, "./" .. path)
    end
    if not ok or type(files) ~= "table" then return {} end
    table.sort(files, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return files
end

local function clearLibraryRows()
    for _, child in ipairs(libraryList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

refreshLibrary = function()
    clearLibraryRows()
    selectedSavedPath, selectedSavedName = nil, nil
    renameBox.Text = ""
    if not fileApiAvailable() then
        local unavailable = label(libraryList, "Executor file APIs are unavailable.", 11, COLORS.muted)
        unavailable.Size = UDim2.new(1, 0, 0, 28)
        return
    end
    local found = 0
    for _, path in ipairs(getFiles(SAVE_FOLDER)) do
        local pathText = tostring(path)
        if pathText:lower():match("%.txt$") then
            found += 1
            local displayName = pathText:match("([^/\\]+)$") or pathText
            displayName = displayName:gsub("%.txt$", "")
            local row = create("TextButton", {
                BackgroundColor3 = COLORS.panel2,
                BorderSizePixel = 0,
                Text = "  " .. displayName,
                TextColor3 = COLORS.text,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 34),
            }, libraryList)
            corner(row, 8)
            stroke(row, COLORS.border, 0.45)
            row.Activated:Connect(function()
                selectedSavedPath = pathText
                selectedSavedName = displayName
                renameBox.Text = displayName
                for _, item in ipairs(libraryList:GetChildren()) do
                    if item:IsA("TextButton") then item.BackgroundColor3 = item == row and COLORS.panel3 or COLORS.panel2 end
                end
            end)
            row.MouseButton2Click:Connect(function()
                selectedSavedPath = pathText
                selectedSavedName = displayName
                renameBox.Text = displayName
            end)
        end
    end
    if found == 0 then
        local empty = label(libraryList, "No saved sheets yet. Save one from the Sheet tab.", 11, COLORS.muted)
        empty.Size = UDim2.new(1, 0, 0, 30)
    end
end

renameBtn.Activated:Connect(function()
    if not selectedSavedPath then notify(APP_NAME, "Select a saved sheet first"); return end
    if type(readfile) ~= "function" or type(writefile) ~= "function" then notify(APP_NAME, "File APIs unavailable"); return end
    local newName = renameBox.Text:gsub("[^%w%-%_ ]", ""):gsub("%s+", "_")
    if newName == "" then notify(APP_NAME, "Enter a valid new name"); return end
    local ok, data = pcall(readfile, selectedSavedPath)
    if not ok then notify(APP_NAME, "Could not read selected sheet"); return end
    local newPath = SAVE_FOLDER .. "/" .. newName .. ".txt"
    local writeOk = pcall(writefile, newPath, data)
    if not writeOk then notify(APP_NAME, "Rename failed"); return end
    if type(delfile) == "function" then pcall(delfile, selectedSavedPath) end
    refreshLibrary()
    notify(APP_NAME, "Renamed to " .. newName)
end)

deleteBtn.Activated:Connect(function()
    if not selectedSavedPath then notify(APP_NAME, "Select a saved sheet first"); return end
    if type(delfile) ~= "function" then notify(APP_NAME, "delfile is unavailable in this executor"); return end
    local ok = pcall(delfile, selectedSavedPath)
    if not ok then notify(APP_NAME, "Delete failed"); return end
    refreshLibrary()
    notify(APP_NAME, "Saved sheet deleted")
end)

-- Add a selected file load button to the library list by tapping a row twice:
-- one tap selects; the small load button below loads the selected row.
local loadSavedBtn = button(libraryContent, "Load selected sheet", function()
    if not selectedSavedPath then notify(APP_NAME, "Select a saved sheet first"); return end
    if type(readfile) ~= "function" then notify(APP_NAME, "readfile unavailable"); return end
    local ok, data = pcall(readfile, selectedSavedPath)
    if not ok or type(data) ~= "string" then notify(APP_NAME, "Could not read saved sheet"); return end
    sheetInput.Text = data
    sheetNameBox.Text = selectedSavedName or "Saved Sheet"
    activeTab = "Sheet"
    for name, page in pairs(pages) do page.Visible = name == "Sheet" end
    for name, tab in pairs(tabButtons) do tab.BackgroundColor3 = name == "Sheet" and COLORS.accent or COLORS.panel3 end
    notify(APP_NAME, "Loaded saved sheet into editor")
end, "accent")
loadSavedBtn.Size = UDim2.new(1, 0, 0, 36)
loadSavedBtn.LayoutOrder = 4

local midiFilesSection, midiFilesContent = section(libraryPage, "MIDI folder", "Put .mid files in the MIDI folder, then enter the filename in Player")
local midiFolderNote = label(midiFilesContent, "Folder: MIDI/", 11, COLORS.muted)
midiFolderNote.Size = UDim2.new(1, 0, 0, 20)
midiFolderNote.LayoutOrder = 1
local midiFileList = label(midiFilesContent, "", 11, COLORS.text)
midiFileList.Size = UDim2.new(1, 0, 0, 0)
midiFileList.AutomaticSize = Enum.AutomaticSize.Y
midiFileList.LayoutOrder = 2
local refreshMidiBtn = button(midiFilesContent, "Refresh MIDI list", function()
    local names = {}
    for _, path in ipairs(getFiles(MIDI_FOLDER)) do
        local s = tostring(path)
        if s:lower():match("%.mid[ i]?$" ) or s:lower():match("%.midi$") then
            names[#names + 1] = s:match("([^/\\]+)$") or s
        end
    end
    midiFileList.Text = #names > 0 and table.concat(names, "\n") or "No MIDI files found."
end)
refreshMidiBtn.Size = UDim2.new(1, 0, 0, 34)
refreshMidiBtn.LayoutOrder = 3

-- First tab selection and refresh.
for name, page in pairs(pages) do page.Visible = name == "Player" end
for name, tab in pairs(tabButtons) do tab.BackgroundColor3 = name == "Player" and COLORS.accent or COLORS.panel3 end
activeTab = "Player"
refreshLibrary()

-- UI status/progress refresh ---------------------------------------------------
local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

local updateAccumulator = 0
local renderConnection
renderConnection = RunService.RenderStepped:Connect(function(dt)
    if not screenGui.Parent then
        if renderConnection then renderConnection:Disconnect() end
        releaseAllKeys()
        return
    end
    updateAccumulator += dt
    if updateAccumulator < 0.08 then return end
    updateAccumulator = 0
    songLabel.Text = state.songName
    statusLabel.Text = state.status
    local fraction = state.duration > 0 and math.clamp(state.elapsed / state.duration, 0, 1) or 0
    progressFill.Size = UDim2.new(fraction, 0, 1, 0)
    timeLabel.Text = formatTime(state.elapsed) .. " / " .. formatTime(state.duration)
end)

screenGui.Destroying:Connect(function()
    stopPlayback(true)
    releaseAllKeys()
    if renderConnection then renderConnection:Disconnect() end
end)

-- Optional quick open/close key: RightControl.
local toggleConnection
local guiVisible = true
toggleConnection = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        guiVisible = not guiVisible
        main.Visible = guiVisible
    end
end)
screenGui.Destroying:Connect(function()
    if toggleConnection then toggleConnection:Disconnect() end
end)

notify(APP_NAME, "Loaded. Press RightCtrl to hide/show the GUI.", 4)
