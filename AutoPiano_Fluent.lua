--[[
╔══════════════════════════════════════════════════════════════╗
║          KANHA AUTO PIANO  ·  FLUENT MODDED EDITION          ║
║          Built on StyearX/Fluent-modded UI library           ║
╚══════════════════════════════════════════════════════════════╝

  INJECT (paste in executor):
  loadstring(game:HttpGet("YOUR_RAW_URL_HERE"))()

  LIBRARY SOURCE:
  https://github.com/StyearX/Fluent-modded

  FEATURES:
  · 15 built-in songs  ·  Fluent Modded native UI
  · Speed slider 0.25×–4×  ·  Loop toggle
  · Transpose ±12 semitones  ·  Song dropdown
  · Live note label  ·  Progress bar  ·  Notifications
  · Keyboard shortcut (Keybind element)
  · Auto piano detection (3 fallback methods)
  · Settings tab with debug, auto-detect toggles
  · _G.Piano API for console control
]]

-- ════════════════════════════════════════════════════════
--  §1  LOAD FLUENT MODDED
-- ════════════════════════════════════════════════════════

local Fluent = loadstring(game:HttpGet(
    "https://github.com/StyearX/Fluent-modded/releases/latest/download/main.lua"
))()

local SaveManager      = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/SaveManager.lua"
))()

local InterfaceManager = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/InterfaceManager.lua"
))()

-- ════════════════════════════════════════════════════════
--  §2  SERVICES
-- ════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local lp     = Players.LocalPlayer
local isMob  = UserInputService.TouchEnabled
              and not UserInputService.MouseEnabled
              and not UserInputService.KeyboardEnabled

-- ════════════════════════════════════════════════════════
--  §3  CONFIGURATION
-- ════════════════════════════════════════════════════════

local Config = {
    Speed      = 1.0,
    Loop       = false,
    Transpose  = 0,
    AutoDetect = true,
    Debug      = false,
}

local State = {
    Playing     = false,
    CurrentSong = 1,
    PianoModel  = nil,
    PlayThread  = nil,
    Progress    = 0,
    ActiveNote  = "--",
}

-- ════════════════════════════════════════════════════════
--  §4  NOTE TABLE
-- ════════════════════════════════════════════════════════

local ALL_NOTES = {
    "C3","Db3","D3","Eb3","E3","F3","Gb3","G3","Ab3","A3","Bb3","B3",
    "C4","Db4","D4","Eb4","E4","F4","Gb4","G4","Ab4","A4","Bb4","B4",
    "C5","Db5","D5","Eb5","E5","F5","Gb5","G5","Ab5","A5","Bb5","B5",
    "C6",
}

local NoteIdx = {}
for i, n in ipairs(ALL_NOTES) do NoteIdx[n] = i end

local function TransposeNote(note, semi)
    local i = NoteIdx[note]
    if not i then return note end
    return ALL_NOTES[math.clamp(i + semi, 1, #ALL_NOTES)]
end

-- ════════════════════════════════════════════════════════
--  §5  SONG DATABASE  (15 songs)
-- ════════════════════════════════════════════════════════

local Songs = {}

Songs[1] = { name="Twinkle Twinkle", bpm=110, notes={
    {"C4",.3},{"C4",.3},{"G4",.3},{"G4",.3},{"A4",.3},{"A4",.3},{"G4",.6},
    {"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.3},{"D4",.3},{"C4",.6},
    {"G4",.3},{"G4",.3},{"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.6},
    {"G4",.3},{"G4",.3},{"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.6},
    {"C4",.3},{"C4",.3},{"G4",.3},{"G4",.3},{"A4",.3},{"A4",.3},{"G4",.6},
    {"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.3},{"D4",.3},{"C4",.6},
}}

Songs[2] = { name="Happy Birthday", bpm=100, notes={
    {"C4",.3},{"C4",.15},{"D4",.45},{"C4",.45},{"F4",.45},{"E4",.9},
    {"C4",.3},{"C4",.15},{"D4",.45},{"C4",.45},{"G4",.45},{"F4",.9},
    {"C4",.3},{"C4",.15},{"C5",.45},{"A4",.45},{"F4",.45},{"E4",.45},{"D4",.9},
    {"Bb4",.3},{"Bb4",.15},{"A4",.45},{"F4",.45},{"G4",.45},{"F4",.9},
}}

Songs[3] = { name="Für Elise", bpm=138, notes={
    {"E5",.2},{"Eb5",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},
    {"B4",.2},{"D5",.2},{"C5",.2},{"A4",.4},
    {"C4",.2},{"E4",.2},{"A4",.2},{"B4",.4},
    {"E4",.2},{"Ab4",.2},{"B4",.2},{"C5",.4},
    {"E4",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},
    {"B4",.2},{"D5",.2},{"C5",.2},{"A4",.4},
    {"C4",.2},{"E4",.2},{"A4",.2},{"B4",.4},
    {"E4",.2},{"C5",.2},{"B4",.2},{"A4",.6},
}}

Songs[4] = { name="Megalovania", bpm=200, notes={
    {"D4",.15},{"D4",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
    {"D4",.15},{"F4",.15},{"G4",.3},
    {"C4",.15},{"C4",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
    {"D4",.15},{"F4",.15},{"G4",.3},
    {"B3",.15},{"B3",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
    {"D4",.15},{"F4",.15},{"G4",.3},
    {"Bb3",.15},{"Bb3",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
    {"D4",.15},{"F4",.15},{"G4",.3},
}}

Songs[5] = { name="Among Us Theme", bpm=120, notes={
    {"F4",.3},{"Ab4",.3},{"Bb4",.3},{"B4",.3},{"Bb4",.3},{"Ab4",.6},{"F4",.3},
    {"Ab4",.3},{"Ab4",.3},{"G4",.3},{"Ab4",.3},{"Eb4",.9},
    {"F4",.3},{"Ab4",.3},{"Bb4",.3},{"B4",.3},{"Bb4",.3},{"Ab4",.3},{"F4",.3},
    {"Ab4",.3},{"Ab4",.3},{"G4",.3},{"Ab4",.3},{"Eb4",.6},
}}

Songs[6] = { name="Jingle Bells", bpm=140, notes={
    {"E4",.25},{"E4",.25},{"E4",.5},{"E4",.25},{"E4",.25},{"E4",.5},
    {"E4",.25},{"G4",.25},{"C4",.25},{"D4",.25},{"E4",1},
    {"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"E4",.25},{"E4",.25},{"E4",.25},
    {"E4",.25},{"D4",.25},{"D4",.25},{"E4",.25},{"D4",.5},{"G4",.5},
    {"E4",.25},{"E4",.25},{"E4",.5},{"E4",.25},{"E4",.25},{"E4",.5},
    {"E4",.25},{"G4",.25},{"C4",.25},{"D4",.25},{"E4",1},
    {"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"E4",.25},{"E4",.25},{"E4",.25},
    {"G4",.25},{"G4",.25},{"F4",.25},{"D4",.25},{"C4",1},
}}

Songs[7] = { name="Ode To Joy", bpm=120, notes={
    {"E4",.3},{"E4",.3},{"F4",.3},{"G4",.3},{"G4",.3},{"F4",.3},{"E4",.3},{"D4",.3},
    {"C4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"E4",.45},{"D4",.15},{"D4",.6},
    {"E4",.3},{"E4",.3},{"F4",.3},{"G4",.3},{"G4",.3},{"F4",.3},{"E4",.3},{"D4",.3},
    {"C4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"D4",.45},{"C4",.15},{"C4",.6},
}}

Songs[8] = { name="Super Mario Bros", bpm=200, notes={
    {"E5",.15},{"E5",.3},{"E5",.3},{"C5",.15},{"E5",.3},{"G5",.6},{"G4",.6},
    {"C5",.45},{"G4",.3},{"E4",.45},{"A4",.3},{"B4",.3},{"Bb4",.15},{"A4",.3},
    {"G4",.2},{"E5",.2},{"G5",.2},{"A5",.3},{"F5",.15},{"G5",.3},
    {"E5",.3},{"C5",.15},{"D5",.15},{"B4",.45},
}}

Songs[9] = { name="Pirates of Caribbean", bpm=140, notes={
    {"A4",.2},{"B4",.2},
    {"C5",.3},{"C5",.15},{"C5",.15},{"D5",.15},{"E5",.15},
    {"E5",.3},{"E5",.15},{"E5",.15},{"F5",.15},{"E5",.15},
    {"D5",.3},{"D5",.15},{"D5",.15},{"E5",.15},{"F5",.15},
    {"E5",.6},{"A4",.2},{"B4",.2},
    {"C5",.3},{"C5",.15},{"C5",.15},{"D5",.15},{"E5",.15},
    {"E5",.3},{"E5",.15},{"E5",.15},{"F5",.15},{"E5",.15},
    {"D5",.3},{"D5",.15},{"D5",.15},{"G5",.15},{"F5",.15},{"E5",.9},
}}

Songs[10] = { name="Tetris", bpm=160, notes={
    {"E5",.3},{"B4",.15},{"C5",.15},{"D5",.3},{"C5",.15},{"B4",.15},
    {"A4",.3},{"A4",.15},{"C5",.15},{"E5",.3},{"D5",.15},{"C5",.15},
    {"B4",.45},{"C5",.15},{"D5",.3},{"E5",.3},
    {"C5",.3},{"A4",.3},{"A4",.6},
    {"D5",.45},{"F5",.15},{"A5",.3},{"G5",.15},{"F5",.15},
    {"E5",.45},{"C5",.15},{"E5",.3},{"D5",.15},{"C5",.15},
    {"B4",.3},{"B4",.15},{"C5",.15},{"D5",.3},{"E5",.3},
    {"C5",.3},{"A4",.3},{"A4",.6},
}}

Songs[11] = { name="Never Gonna Give You Up", bpm=113, notes={
    {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},{"Gb5",.54},{"Gb5",.27},{"E5",.81},
    {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},{"E5",.54},{"E5",.27},{"D5",.54},{"C5",.27},{"B4",.27},
    {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},{"D5",.54},{"E5",.27},{"C5",.54},{"B4",.27},{"A4",.27},
    {"A4",.54},{"D5",.54},{"D5",.27},{"C5",.27},{"B4",.54},
    {"A4",.54},{"A4",.27},{"D5",.54},{"D5",.27},{"E5",.27},{"C5",.54},{"B4",.27},{"A4",.9},
}}

Songs[12] = { name="Coffin Dance", bpm=126, notes={
    {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
    {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
    {"G4",.25},{"F4",.25},{"Eb4",.25},{"F4",.25},{"G4",.5},{"Ab4",.5},
    {"G4",.25},{"F4",.25},{"Eb4",.25},{"F4",.25},{"G4",1},
    {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
    {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
    {"Bb4",.5},{"Ab4",.5},{"G4",.5},{"F4",.5},{"Eb4",1},
}}

Songs[13] = { name="Despacito Intro", bpm=176, notes={
    {"B4",.2},{"Ab4",.2},{"E4",.4},{"E4",.2},{"Gb4",.2},
    {"Ab4",.2},{"B4",.2},{"Ab4",.2},{"E4",.6},
    {"B4",.2},{"Ab4",.2},{"E4",.4},{"E4",.2},{"Gb4",.2},
    {"Ab4",.2},{"B4",.2},{"Ab4",.2},{"Gb4",.4},{"E4",.2},
    {"Gb4",.2},{"Ab4",.2},{"B4",.2},{"Ab4",.2},{"E4",.4},
    {"Gb4",.6},
}}

Songs[14] = { name="All Star", bpm=104, notes={
    {"G4",.29},{"G4",.29},{"G4",.29},{"G4",.29},{"A4",.29},{"G4",.29},{"F4",.29},
    {"G4",.58},{"F4",.29},{"F4",.29},{"F4",.29},{"F4",.29},{"G4",.29},{"F4",.29},{"E4",.87},
    {"G4",.29},{"G4",.29},{"G4",.29},{"G4",.29},{"A4",.29},{"G4",.29},{"F4",.29},
    {"G4",.58},{"F4",.29},{"F4",.29},{"F4",.29},{"G4",.29},{"A4",.29},{"G4",.58},
    {"E4",.29},{"F4",.29},{"G4",.29},{"F4",.29},{"E4",.87},
}}

Songs[15] = { name="Mary Had A Little Lamb", bpm=110, notes={
    {"E4",.3},{"D4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"E4",.3},{"E4",.6},
    {"D4",.3},{"D4",.3},{"D4",.6},{"E4",.3},{"G4",.3},{"G4",.6},
    {"E4",.3},{"D4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"E4",.3},{"E4",.3},{"E4",.3},
    {"D4",.3},{"D4",.3},{"E4",.3},{"D4",.3},{"C4",.9},
}}

-- Build name list for dropdown
local SongNames = {}
for _, s in ipairs(Songs) do
    table.insert(SongNames, s.name)
end

-- ════════════════════════════════════════════════════════
--  §6  PIANO ENGINE
-- ════════════════════════════════════════════════════════

local function FindPiano()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local n = obj.Name:lower()
            if n:find("piano") or n:find("keyboard") or n:find("keys") then
                return obj
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("note") or n:find("key") or n:find("play") then
                return obj.Parent
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local p = obj.Parent
            if p and (p.Name:lower():find("key") or p.Name:lower():find("note")) then
                return p.Parent
            end
        end
    end
    return nil
end

local function PressKey(piano, note)
    if not piano then return end
    local final = Config.Transpose ~= 0 and TransposeNote(note, Config.Transpose) or note

    -- Method 1: RemoteEvent
    local remote =
        piano:FindFirstChild("PlayNote",    true) or
        piano:FindFirstChild("NotePressed", true) or
        piano:FindFirstChild("KeyPressed",  true) or
        piano:FindFirstChild("Note",        true)

    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer(final) end)
        return
    end

    -- Method 2: ClickDetector on named key part
    local keyName = "KeyboardNote_" .. final
    local part = piano:FindFirstChild(keyName, true)
    if part then
        local cd = part:FindFirstChildOfClass("ClickDetector")
        if cd then pcall(fireclickdetector, cd) return end
        local pp = part:FindFirstChildOfClass("ProximityPrompt")
        if pp then pcall(fireproximityprompt, pp) return end
    end

    -- Method 3: blast all remote events
    for _, re in ipairs(piano:GetDescendants()) do
        if re:IsA("RemoteEvent") then
            pcall(function() re:FireServer(final) end)
            return
        end
    end

    if Config.Debug then warn("[Piano] No handler: " .. final) end
end

-- ════════════════════════════════════════════════════════
--  §7  WINDOW & TABS
-- ════════════════════════════════════════════════════════

local Window = Fluent:CreateWindow({
    Title           = "Kanha Piano",
    SubTitle        = "Auto Player",
    TabWidth        = isMob and 110 or 130,
    Size            = isMob and UDim2.fromOffset(460, 500) or UDim2.fromOffset(560, 540),
    Acrylic         = true,
    Theme           = "Dark",
    MinimizeKey     = Enum.KeyCode.RightControl,
    Search          = false,
    Tags            = {
        { Text = " v2.0 ", Color = Color3.fromRGB(0, 180, 220) },
        { Text = " Fluent Mod ", Color = Color3.fromRGB(100, 40, 200) },
    },
    UserInfoTop     = true,
    UserInfoTitle   = "Auto Piano",
    UserInfoSubtitle = lp.DisplayName,
    UserInfoColor   = Color3.fromRGB(0, 200, 240),
    Animated        = true,
})

local Tabs = {
    Play     = Window:AddTab({ Title = "Play",     Icon = "music" }),
    Songs    = Window:AddTab({ Title = "Songs",    Icon = "list-music" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Info     = Window:AddTab({ Title = "Info",     Icon = "info" }),
}

local Options = Fluent.Options

-- ════════════════════════════════════════════════════════
--  §8  PLAY TAB
-- ════════════════════════════════════════════════════════

local secControls = Tabs.Play:AddSection("Controls", "play-circle")

-- Status paragraph (updated dynamically)
local StatusPara = secControls:AddParagraph({
    Title   = "Status",
    Content = "⏸  Idle — select a song and press Play",
})

-- Song dropdown (synced with Songs tab)
local SongDrop = secControls:AddDropdown("SongSelect", {
    Title       = "Song",
    Icon        = "disc",
    Values      = SongNames,
    Default     = SongNames[1],
    Description = "Currently selected song to play",
    Callback    = function(value)
        for i, s in ipairs(Songs) do
            if s.name == value then
                State.CurrentSong = i
                break
            end
        end
    end,
})

-- Play / Stop button
local PlayBtn = secControls:AddButton({
    Title       = "▶  Play",
    Icon        = "play",
    Description = "Start or stop playback",
    Callback    = function()
        if State.Playing then
            -- stop
            State.Playing = false
            if State.PlayThread then
                task.cancel(State.PlayThread)
                State.PlayThread = nil
            end
            PlayBtn.Title = "▶  Play"
            StatusPara:SetContent("Status", "⏹  Stopped")
            State.ActiveNote = "--"
            Fluent:Notify({
                Title    = "Piano",
                Content  = "Playback stopped",
                Type     = "Warning",
                Duration = 2,
            })
            return
        end

        -- detect piano
        if Config.AutoDetect then
            State.PianoModel = FindPiano()
            if not State.PianoModel then
                StatusPara:SetContent("Status", "❌  No piano found in workspace!")
                Fluent:Notify({
                    Title    = "Piano",
                    Content  = "No piano found. Stand near one.",
                    Type     = "Error",
                    Duration = 4,
                })
                return
            end
        end

        local song   = Songs[State.CurrentSong]
        State.Playing = true
        PlayBtn.Title = "⏹  Stop"

        StatusPara:SetContent("Status", "▶  Playing: " .. song.name)
        Fluent:Notify({
            Title      = "Piano — Now Playing",
            Content    = song.name,
            SubContent = song.bpm .. " BPM  ·  " .. #song.notes .. " notes",
            Type       = "Success",
            Icon       = "music",
            Duration   = 3,
        })

        State.PlayThread = task.spawn(function()
            local total = #song.notes
            repeat
                for i, entry in ipairs(song.notes) do
                    if not State.Playing then return end
                    local note  = entry[1]
                    local delay = entry[2] / Config.Speed
                    State.ActiveNote = note
                    State.Progress   = i / total

                    PressKey(State.PianoModel, note)

                    -- Update live label
                    local pct = math.round(State.Progress * 100)
                    StatusPara:SetContent("Status",
                        "▶  " .. song.name ..
                        "  |  " .. note ..
                        "  |  " .. pct .. "%"
                    )

                    task.wait(delay)
                end
            until not Config.Loop or not State.Playing

            if State.Playing then
                State.Playing = false
                PlayBtn.Title = "▶  Play"
                State.ActiveNote = "--"
                StatusPara:SetContent("Status", "✅  Finished: " .. song.name)
                Fluent:Notify({
                    Title    = "Piano",
                    Content  = "Finished: " .. song.name,
                    Type     = "Success",
                    Duration = 3,
                })
            end
        end)
    end,
})

-- Restart button
secControls:AddButton({
    Title       = "↺  Restart",
    Icon        = "rotate-ccw",
    Description = "Stop and restart from the beginning",
    Callback    = function()
        -- stop first
        State.Playing = false
        if State.PlayThread then
            task.cancel(State.PlayThread)
            State.PlayThread = nil
        end
        PlayBtn.Title = "▶  Play"
        task.wait(0.05)
        PlayBtn.Callback()   -- re-trigger play
    end,
})

-- ── PLAYBACK SECTION ────────────────────────────────────

local secPlayback = Tabs.Play:AddSection("Playback", "sliders-horizontal")

-- Speed slider
local SpeedSlider = secPlayback:AddSlider("SpeedSlider", {
    Title       = "Speed",
    Icon        = "gauge",
    Min         = 25,
    Max         = 400,
    Default     = 100,
    Rounding    = 0,
    Description = "Playback speed (% of normal tempo)",
    Callback    = function(value)
        Config.Speed = value / 100
    end,
})

-- Loop toggle
local LoopToggle = secPlayback:AddToggle("LoopToggle", {
    Title       = "Loop",
    Icon        = "repeat",
    Default     = false,
    Description = "Repeat the song when it finishes",
    Callback    = function(state)
        Config.Loop = state
        Fluent:Notify({
            Title    = "Loop",
            Content  = state and "Loop ON" or "Loop OFF",
            Type     = state and "Success" or "Warning",
            Duration = 2,
        })
    end,
})

-- Keyboard shortcut for play/stop
secPlayback:AddKeybind("PlayKeybind", {
    Title       = "Play / Stop Hotkey",
    Icon        = "keyboard",
    Default     = "P",
    Mode        = "Toggle",
    Description = "Press this key to toggle playback",
    Callback    = function(state)
        PlayBtn.Callback()
    end,
})

-- ════════════════════════════════════════════════════════
--  §9  SONGS TAB
-- ════════════════════════════════════════════════════════

local secSongList = Tabs.Songs:AddSection("Song Library", "library")

secSongList:AddParagraph({
    Title   = "15 Songs Available",
    Content = "Select a song then switch to the Play tab.\nSongs are sorted by genre.",
})

secSongList:AddDivider()

-- Song buttons grouped by category
local categories = {
    { label = "Classics",  range = {1, 2, 7, 8} },
    { label = "Game OST",  range = {4, 9, 10, 11} },
    { label = "Pop / Misc", range = {5, 6, 11, 12, 13, 14, 15} },
    { label = "Piano",     range = {3} },
}
local shownSongs = {}

local function AddSongBtn(tab, idx)
    if shownSongs[idx] then return end
    shownSongs[idx] = true
    local song = Songs[idx]
    tab:AddButton({
        Title       = song.name,
        Icon        = "music-2",
        Description = song.bpm .. " BPM  ·  " .. #song.notes .. " notes",
        Callback    = function()
            State.CurrentSong = idx
            SongDrop:SetValue(song.name)
            Fluent:Notify({
                Title    = "Song Selected",
                Content  = song.name,
                SubContent = song.bpm .. " BPM",
                Type     = "Info",
                Duration = 2,
            })
        end,
    })
end

for _, cat in ipairs(categories) do
    local sec = Tabs.Songs:AddSection(cat.label, "music")
    for _, idx in ipairs(cat.range) do
        if Songs[idx] then
            AddSongBtn(sec, idx)
        end
    end
end

-- Catch any songs not in categories
local missedSec = Tabs.Songs:AddSection("Others", "more-horizontal")
for i = 1, #Songs do
    if not shownSongs[i] then
        AddSongBtn(missedSec, i)
    end
end

-- ════════════════════════════════════════════════════════
--  §10  SETTINGS TAB
-- ════════════════════════════════════════════════════════

local secAuto = Tabs.Settings:AddSection("Piano Detection", "search")

secAuto:AddToggle("AutoDetect", {
    Title       = "Auto-Detect Piano",
    Icon        = "scan",
    Default     = true,
    Description = "Scan workspace for a piano model on play",
    Callback    = function(v) Config.AutoDetect = v end,
})

secAuto:AddButton({
    Title       = "Scan Now",
    Icon        = "radar",
    Description = "Manually trigger a piano scan",
    Callback    = function()
        local p = FindPiano()
        if p then
            State.PianoModel = p
            Fluent:Notify({
                Title    = "Piano Found",
                Content  = p.Name,
                Type     = "Success",
                Duration = 3,
            })
        else
            Fluent:Notify({
                Title    = "Piano Not Found",
                Content  = "Stand near a piano and try again.",
                Type     = "Error",
                Duration = 3,
            })
        end
    end,
})

local secTranspose = Tabs.Settings:AddSection("Transpose", "arrow-up-down")

secTranspose:AddSlider("TransposeSlider", {
    Title       = "Semitones",
    Icon        = "move-vertical",
    Min         = -12,
    Max         = 12,
    Default     = 0,
    Rounding    = 0,
    Description = "Shift all notes up or down by semitones",
    Callback    = function(v)
        Config.Transpose = v
        Fluent:Notify({
            Title    = "Transpose",
            Content  = v == 0 and "Reset to original key" or (v > 0 and "+" or "") .. v .. " semitones",
            Type     = "Info",
            Duration = 1,
        })
    end,
})

local secDev = Tabs.Settings:AddSection("Developer", "terminal")

secDev:AddToggle("DebugMode", {
    Title       = "Debug Mode",
    Icon        = "bug",
    Default     = false,
    Description = "Print note events to console",
    Callback    = function(v) Config.Debug = v end,
})

secDev:AddButton({
    Title       = "Test Note (C4)",
    Icon        = "music",
    Description = "Fire a single C4 note immediately",
    Callback    = function()
        if State.PianoModel then
            PressKey(State.PianoModel, "C4")
            Fluent:Notify({ Title="Test", Content="Fired C4", Type="Info", Duration=1 })
        else
            Fluent:Notify({ Title="No Piano", Content="Scan for a piano first.", Type="Warning", Duration=2 })
        end
    end,
})

-- Interface Manager section in Settings
local secInterface = Tabs.Settings:AddSection("Interface", "layout")
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("KanhaPiano")
InterfaceManager:BuildInterfaceSection(secInterface)

-- ════════════════════════════════════════════════════════
--  §11  INFO TAB
-- ════════════════════════════════════════════════════════

local secAbout = Tabs.Info:AddSection("About", "info")

secAbout:AddParagraph({
    Title   = "Kanha Auto Piano  v2.0",
    Content = "A full-featured auto piano built on the\n<b>StyearX / Fluent Modded</b> UI library.\n\nUse the Play tab to start, Songs to pick a track,\nand Settings to tune behaviour.",
})

secAbout:AddDivider()

secAbout:AddParagraph({
    Title   = "Songs Included",
    Content = "1. Twinkle Twinkle\n2. Happy Birthday\n3. Für Elise\n4. Megalovania\n5. Among Us Theme\n6. Jingle Bells\n7. Ode To Joy\n8. Super Mario Bros\n9. Pirates of Caribbean\n10. Tetris\n11. Never Gonna Give You Up\n12. Coffin Dance\n13. Despacito Intro\n14. All Star\n15. Mary Had A Little Lamb",
})

secAbout:AddDivider()

local secConsole = Tabs.Info:AddSection("Console API", "terminal")

secConsole:AddParagraph({
    Title   = "_G.Piano",
    Content = "_G.Piano.Play()         — start playback\n_G.Piano.Stop()         — stop playback\n_G.Piano.SetSong(n)     — select song by index\n_G.Piano.SetSpeed(x)    — set speed (1.0 = normal)\n_G.Piano.SetLoop(bool)  — toggle loop\n_G.Piano.Transpose(n)   — set transpose (±12)",
})

secConsole:AddCode({
    Title = "Quick Start",
    Code  = '_G.Piano.SetSong(4)   -- Megalovania\n_G.Piano.SetSpeed(1.5)\n_G.Piano.Play()',
    OnCopy = function()
        Fluent:Notify({ Title="Copied", Content="Paste in console", Type="Info", Duration=2 })
    end,
})

local secHotkeys = Tabs.Info:AddSection("Hotkeys", "keyboard")

secHotkeys:AddParagraph({
    Title   = "Default Keys",
    Content = "RightControl — minimize / restore window\nP (Keybind)  — toggle play / stop\n\nAll keys are rebindable from the Play tab.",
})

-- ════════════════════════════════════════════════════════
--  §12  GLOBAL API
-- ════════════════════════════════════════════════════════

_G.Piano = {
    Play = function()
        if not State.Playing then PlayBtn.Callback() end
    end,
    Stop = function()
        if State.Playing then PlayBtn.Callback() end
    end,
    SetSong = function(n)
        n = math.clamp(n, 1, #Songs)
        State.CurrentSong = n
        SongDrop:SetValue(Songs[n].name)
        Fluent:Notify({ Title="Song", Content=Songs[n].name, Type="Info", Duration=2 })
    end,
    SetSpeed = function(x)
        Config.Speed = math.clamp(x, 0.1, 10)
        SpeedSlider:SetValue(math.round(Config.Speed * 100))
    end,
    SetLoop = function(v)
        Config.Loop = v
        LoopToggle:SetValue(v)
    end,
    Transpose = function(n)
        Config.Transpose = math.clamp(n, -12, 12)
        Options.TransposeSlider:SetValue(Config.Transpose)
    end,
    Songs  = Songs,
    Config = Config,
    State  = State,
}

-- ════════════════════════════════════════════════════════
--  §13  INIT
-- ════════════════════════════════════════════════════════

Window:SelectTab(1)

Fluent:Notify({
    Title      = "Kanha Piano Loaded",
    Content    = "15 songs ready · Select a song and press Play",
    SubContent = "RightCtrl to minimize",
    Type       = "Success",
    Icon       = "music",
    Duration   = 5,
})

print("╔═════════════════════════════════════╗")
print("║  Kanha Piano v2.0 · Fluent Modded   ║")
print("║  _G.Piano.Play() to start anytime   ║")
print("╚═════════════════════════════════════╝")
