--[[
╔══════════════════════════════════════════════════════════════╗
║          KANHA AUTO PIANO  ·  FLUENT MODDED EDITION  v2.1   ║
║          Fixed: library URL · static paragraphs · API calls  ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════════════════
--  §1  SAFE LIBRARY LOADER  (3 fallback URLs)
--      StyearX/Fluent-modded has no GitHub Releases yet,
--      so we fall through to the original Fluent if needed.
-- ════════════════════════════════════════════════════════

local function tryGet(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    return (ok and type(result) == "table") and result or nil
end

local Fluent =
    tryGet("https://raw.githubusercontent.com/StyearX/Fluent-modded/main/dist/main.lua")  or
    tryGet("https://raw.githubusercontent.com/Vraigos/Fluent-Moded/main/dist/main.lua")   or
    tryGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")

if not Fluent then
    error("[AutoPiano] Could not load Fluent from any source. Check HttpService is ON.")
end

-- Addons (graceful fail — UI still works without them)
local InterfaceManager = tryGet(
    "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/InterfaceManager.lua"
) or tryGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"
)

local SaveManager = tryGet(
    "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/SaveManager.lua"
) or tryGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
)

-- ════════════════════════════════════════════════════════
--  §2  SERVICES
-- ════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local lp    = Players.LocalPlayer
local isMob = UserInputService.TouchEnabled
           and not UserInputService.MouseEnabled
           and not UserInputService.KeyboardEnabled

local Options = Fluent.Options   -- reference the shared options table

-- ════════════════════════════════════════════════════════
--  §3  CONFIG & STATE
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
}

-- ════════════════════════════════════════════════════════
--  §4  NOTES + TRANSPOSE
-- ════════════════════════════════════════════════════════

local ALL_NOTES = {
    "C3","Db3","D3","Eb3","E3","F3","Gb3","G3","Ab3","A3","Bb3","B3",
    "C4","Db4","D4","Eb4","E4","F4","Gb4","G4","Ab4","A4","Bb4","B4",
    "C5","Db5","D5","Eb5","E5","F5","Gb5","G5","Ab5","A5","Bb5","B5",
    "C6",
}
local NoteIdx = {}
for i, n in ipairs(ALL_NOTES) do NoteIdx[n] = i end

local function TNote(note, semi)
    if semi == 0 then return note end
    local i = NoteIdx[note]
    if not i then return note end
    return ALL_NOTES[math.clamp(i + semi, 1, #ALL_NOTES)]
end

-- ════════════════════════════════════════════════════════
--  §5  SONG DATABASE
-- ════════════════════════════════════════════════════════

local Songs = {
    { name="Twinkle Twinkle",        bpm=110, notes={
        {"C4",.3},{"C4",.3},{"G4",.3},{"G4",.3},{"A4",.3},{"A4",.3},{"G4",.6},
        {"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.3},{"D4",.3},{"C4",.6},
        {"G4",.3},{"G4",.3},{"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.6},
        {"G4",.3},{"G4",.3},{"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.6},
        {"C4",.3},{"C4",.3},{"G4",.3},{"G4",.3},{"A4",.3},{"A4",.3},{"G4",.6},
        {"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.3},{"D4",.3},{"C4",.6},
    }},
    { name="Happy Birthday",         bpm=100, notes={
        {"C4",.3},{"C4",.15},{"D4",.45},{"C4",.45},{"F4",.45},{"E4",.9},
        {"C4",.3},{"C4",.15},{"D4",.45},{"C4",.45},{"G4",.45},{"F4",.9},
        {"C4",.3},{"C4",.15},{"C5",.45},{"A4",.45},{"F4",.45},{"E4",.45},{"D4",.9},
        {"Bb4",.3},{"Bb4",.15},{"A4",.45},{"F4",.45},{"G4",.45},{"F4",.9},
    }},
    { name="Für Elise",              bpm=138, notes={
        {"E5",.2},{"Eb5",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},
        {"B4",.2},{"D5",.2},{"C5",.2},{"A4",.4},
        {"C4",.2},{"E4",.2},{"A4",.2},{"B4",.4},
        {"E4",.2},{"Ab4",.2},{"B4",.2},{"C5",.4},
        {"E4",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},
        {"B4",.2},{"D5",.2},{"C5",.2},{"A4",.4},
        {"C4",.2},{"E4",.2},{"A4",.2},{"B4",.4},
        {"E4",.2},{"C5",.2},{"B4",.2},{"A4",.6},
    }},
    { name="Megalovania",            bpm=200, notes={
        {"D4",.15},{"D4",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
        {"D4",.15},{"F4",.15},{"G4",.3},
        {"C4",.15},{"C4",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
        {"D4",.15},{"F4",.15},{"G4",.3},
        {"B3",.15},{"B3",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
        {"D4",.15},{"F4",.15},{"G4",.3},
        {"Bb3",.15},{"Bb3",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},
        {"D4",.15},{"F4",.15},{"G4",.3},
    }},
    { name="Among Us Theme",         bpm=120, notes={
        {"F4",.3},{"Ab4",.3},{"Bb4",.3},{"B4",.3},{"Bb4",.3},{"Ab4",.6},{"F4",.3},
        {"Ab4",.3},{"Ab4",.3},{"G4",.3},{"Ab4",.3},{"Eb4",.9},
        {"F4",.3},{"Ab4",.3},{"Bb4",.3},{"B4",.3},{"Bb4",.3},{"Ab4",.3},{"F4",.3},
        {"Ab4",.3},{"Ab4",.3},{"G4",.3},{"Ab4",.3},{"Eb4",.6},
    }},
    { name="Jingle Bells",           bpm=140, notes={
        {"E4",.25},{"E4",.25},{"E4",.5},{"E4",.25},{"E4",.25},{"E4",.5},
        {"E4",.25},{"G4",.25},{"C4",.25},{"D4",.25},{"E4",1},
        {"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},
        {"F4",.25},{"E4",.25},{"E4",.25},{"E4",.25},
        {"E4",.25},{"D4",.25},{"D4",.25},{"E4",.25},{"D4",.5},{"G4",.5},
        {"E4",.25},{"E4",.25},{"E4",.5},{"E4",.25},{"E4",.25},{"E4",.5},
        {"E4",.25},{"G4",.25},{"C4",.25},{"D4",.25},{"E4",1},
        {"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},
        {"F4",.25},{"E4",.25},{"E4",.25},{"E4",.25},
        {"G4",.25},{"G4",.25},{"F4",.25},{"D4",.25},{"C4",1},
    }},
    { name="Ode To Joy",             bpm=120, notes={
        {"E4",.3},{"E4",.3},{"F4",.3},{"G4",.3},
        {"G4",.3},{"F4",.3},{"E4",.3},{"D4",.3},
        {"C4",.3},{"C4",.3},{"D4",.3},{"E4",.3},
        {"E4",.45},{"D4",.15},{"D4",.6},
        {"E4",.3},{"E4",.3},{"F4",.3},{"G4",.3},
        {"G4",.3},{"F4",.3},{"E4",.3},{"D4",.3},
        {"C4",.3},{"C4",.3},{"D4",.3},{"E4",.3},
        {"D4",.45},{"C4",.15},{"C4",.6},
    }},
    { name="Super Mario Bros",       bpm=200, notes={
        {"E5",.15},{"E5",.3},{"E5",.3},{"C5",.15},{"E5",.3},
        {"G5",.6},{"G4",.6},
        {"C5",.45},{"G4",.3},{"E4",.45},
        {"A4",.3},{"B4",.3},{"Bb4",.15},{"A4",.3},
        {"G4",.2},{"E5",.2},{"G5",.2},
        {"A5",.3},{"F5",.15},{"G5",.3},
        {"E5",.3},{"C5",.15},{"D5",.15},{"B4",.45},
    }},
    { name="Pirates of Caribbean",   bpm=140, notes={
        {"A4",.2},{"B4",.2},
        {"C5",.3},{"C5",.15},{"C5",.15},{"D5",.15},{"E5",.15},
        {"E5",.3},{"E5",.15},{"E5",.15},{"F5",.15},{"E5",.15},
        {"D5",.3},{"D5",.15},{"D5",.15},{"E5",.15},{"F5",.15},
        {"E5",.6},{"A4",.2},{"B4",.2},
        {"C5",.3},{"C5",.15},{"C5",.15},{"D5",.15},{"E5",.15},
        {"E5",.3},{"E5",.15},{"E5",.15},{"F5",.15},{"E5",.15},
        {"D5",.3},{"D5",.15},{"D5",.15},{"G5",.15},{"F5",.15},{"E5",.9},
    }},
    { name="Tetris",                 bpm=160, notes={
        {"E5",.3},{"B4",.15},{"C5",.15},{"D5",.3},{"C5",.15},{"B4",.15},
        {"A4",.3},{"A4",.15},{"C5",.15},{"E5",.3},{"D5",.15},{"C5",.15},
        {"B4",.45},{"C5",.15},{"D5",.3},{"E5",.3},
        {"C5",.3},{"A4",.3},{"A4",.6},
        {"D5",.45},{"F5",.15},{"A5",.3},{"G5",.15},{"F5",.15},
        {"E5",.45},{"C5",.15},{"E5",.3},{"D5",.15},{"C5",.15},
        {"B4",.3},{"B4",.15},{"C5",.15},{"D5",.3},{"E5",.3},
        {"C5",.3},{"A4",.3},{"A4",.6},
    }},
    { name="Never Gonna Give You Up", bpm=113, notes={
        {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},
        {"Gb5",.54},{"Gb5",.27},{"E5",.81},
        {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},
        {"E5",.54},{"E5",.27},{"D5",.54},{"C5",.27},{"B4",.27},
        {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},
        {"D5",.54},{"E5",.27},{"C5",.54},{"B4",.27},{"A4",.27},
        {"A4",.54},{"D5",.54},{"D5",.27},{"C5",.27},{"B4",.54},
        {"A4",.54},{"A4",.27},{"D5",.54},{"D5",.27},
        {"E5",.27},{"C5",.54},{"B4",.27},{"A4",.9},
    }},
    { name="Coffin Dance",           bpm=126, notes={
        {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
        {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
        {"G4",.25},{"F4",.25},{"Eb4",.25},{"F4",.25},{"G4",.5},{"Ab4",.5},
        {"G4",.25},{"F4",.25},{"Eb4",.25},{"F4",.25},{"G4",1},
        {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
        {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
        {"Bb4",.5},{"Ab4",.5},{"G4",.5},{"F4",.5},{"Eb4",1},
    }},
    { name="Despacito Intro",        bpm=176, notes={
        {"B4",.2},{"Ab4",.2},{"E4",.4},{"E4",.2},{"Gb4",.2},
        {"Ab4",.2},{"B4",.2},{"Ab4",.2},{"E4",.6},
        {"B4",.2},{"Ab4",.2},{"E4",.4},{"E4",.2},{"Gb4",.2},
        {"Ab4",.2},{"B4",.2},{"Ab4",.2},{"Gb4",.4},{"E4",.2},
        {"Gb4",.2},{"Ab4",.2},{"B4",.2},{"Ab4",.2},{"E4",.4},
        {"Gb4",.6},
    }},
    { name="All Star",               bpm=104, notes={
        {"G4",.29},{"G4",.29},{"G4",.29},
        {"G4",.29},{"A4",.29},{"G4",.29},{"F4",.29},
        {"G4",.58},{"F4",.29},{"F4",.29},
        {"F4",.29},{"F4",.29},{"G4",.29},{"F4",.29},{"E4",.87},
        {"G4",.29},{"G4",.29},{"G4",.29},
        {"G4",.29},{"A4",.29},{"G4",.29},{"F4",.29},
        {"G4",.58},{"F4",.29},{"F4",.29},
        {"F4",.29},{"G4",.29},{"A4",.29},{"G4",.58},
        {"E4",.29},{"F4",.29},{"G4",.29},{"F4",.29},{"E4",.87},
    }},
    { name="Mary Had A Little Lamb", bpm=110, notes={
        {"E4",.3},{"D4",.3},{"C4",.3},{"D4",.3},
        {"E4",.3},{"E4",.3},{"E4",.6},
        {"D4",.3},{"D4",.3},{"D4",.6},
        {"E4",.3},{"G4",.3},{"G4",.6},
        {"E4",.3},{"D4",.3},{"C4",.3},{"D4",.3},
        {"E4",.3},{"E4",.3},{"E4",.3},{"E4",.3},
        {"D4",.3},{"D4",.3},{"E4",.3},{"D4",.3},{"C4",.9},
    }},
}

local SongNames = {}
for _, s in ipairs(Songs) do table.insert(SongNames, s.name) end

-- ════════════════════════════════════════════════════════
--  §6  PIANO ENGINE
-- ════════════════════════════════════════════════════════

local function FindPiano()
    for _, o in ipairs(workspace:GetDescendants()) do
        if (o:IsA("Model") or o:IsA("Folder")) then
            local n = o.Name:lower()
            if n:find("piano") or n:find("keyboard") or n:find("keys") then
                return o
            end
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("RemoteEvent") then
            local n = o.Name:lower()
            if n:find("note") or n:find("key") or n:find("play") then
                return o.Parent
            end
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ClickDetector") then
            local p = o.Parent
            if p and (p.Name:lower():find("key") or p.Name:lower():find("note")) then
                return p.Parent
            end
        end
    end
end

local function PressKey(piano, note)
    if not piano then return end
    local final = TNote(note, Config.Transpose)

    local re = piano:FindFirstChild("PlayNote",    true)
            or piano:FindFirstChild("NotePressed", true)
            or piano:FindFirstChild("KeyPressed",  true)
            or piano:FindFirstChild("Note",        true)
    if re and re:IsA("RemoteEvent") then
        pcall(function() re:FireServer(final) end)
        return
    end

    local part = piano:FindFirstChild("KeyboardNote_" .. final, true)
    if part then
        local cd = part:FindFirstChildOfClass("ClickDetector")
        local pp = part:FindFirstChildOfClass("ProximityPrompt")
        if cd then pcall(fireclickdetector, cd) return end
        if pp then pcall(fireproximityprompt, pp) return end
    end

    for _, re2 in ipairs(piano:GetDescendants()) do
        if re2:IsA("RemoteEvent") then
            pcall(function() re2:FireServer(final) end)
            return
        end
    end

    if Config.Debug then warn("[Piano] No handler for:", final) end
end

-- ════════════════════════════════════════════════════════
--  §7  SHARED PLAY / STOP LOGIC
--  All UI controls route through these two functions.
--  No "call a button's callback" hacks needed.
-- ════════════════════════════════════════════════════════

local function DoStop(silent)
    State.Playing = false
    if State.PlayThread then
        task.cancel(State.PlayThread)
        State.PlayThread = nil
    end
    -- Reset play toggle to OFF without firing its callback again
    -- (SetValue is safe to call even if already false)
    pcall(function() Options.PlayToggle:SetValue(false) end)

    if not silent then
        Fluent:Notify({
            Title    = "Piano",
            Content  = "Playback stopped",
            Type     = "Warning",
            Duration = 2,
        })
    end
end

local function DoPlay()
    if State.Playing then DoStop(true) end

    -- Detect piano
    if Config.AutoDetect then
        State.PianoModel = FindPiano()
        if not State.PianoModel then
            Fluent:Notify({
                Title    = "Piano Not Found",
                Content  = "Stand near a piano model and try again.",
                Type     = "Error",
                Duration = 4,
            })
            -- Flip toggle back to OFF since we can't play
            pcall(function() Options.PlayToggle:SetValue(false) end)
            return
        end
    end

    local song  = Songs[State.CurrentSong]
    local total = #song.notes
    State.Playing = true

    Fluent:Notify({
        Title      = "▶  Now Playing",
        Content    = song.name,
        SubContent = song.bpm .. " BPM  ·  " .. total .. " notes",
        Type       = "Success",
        Icon       = "music",
        Duration   = 3,
    })

    State.PlayThread = task.spawn(function()
        repeat
            for i, entry in ipairs(song.notes) do
                if not State.Playing then return end
                PressKey(State.PianoModel, entry[1])
                task.wait(entry[2] / Config.Speed)
            end
        until not Config.Loop or not State.Playing

        -- Natural finish
        if State.Playing then
            State.Playing = false
            pcall(function() Options.PlayToggle:SetValue(false) end)
            Fluent:Notify({
                Title    = "Piano",
                Content  = "Finished: " .. song.name,
                Type     = "Success",
                Duration = 3,
            })
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  §8  WINDOW
-- ════════════════════════════════════════════════════════

local Window = Fluent:CreateWindow({
    Title        = "Kanha Piano",
    SubTitle     = "Auto Player · v2.1",
    TabWidth     = isMob and 110 or 130,
    Size         = isMob
                   and UDim2.fromOffset(460, 500)
                   or  UDim2.fromOffset(560, 540),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = Enum.KeyCode.RightControl,
    Search       = false,
    Tags         = {
        { Text = " v2.1 Fixed ",   Color = Color3.fromRGB(0, 190, 220) },
        { Text = " Fluent Mod ",   Color = Color3.fromRGB(100, 40, 200) },
    },
    UserInfoTop      = true,
    UserInfoTitle    = "Auto Piano",
    UserInfoSubtitle = lp.DisplayName,
    UserInfoColor    = Color3.fromRGB(0, 200, 240),
    Animated         = true,
})

local Tabs = {
    Play     = Window:AddTab({ Title = "Play",     Icon = "music"    }),
    Songs    = Window:AddTab({ Title = "Songs",    Icon = "disc"     }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Info     = Window:AddTab({ Title = "Info",     Icon = "info"     }),
}

-- ════════════════════════════════════════════════════════
--  §9  PLAY TAB
-- ════════════════════════════════════════════════════════

-- ── Song Selector ───────────────────────────────────────
local secSel = Tabs.Play:AddSection("Song", "disc")

secSel:AddDropdown("SongSelect", {
    Title       = "Select Song",
    Icon        = "list-music",
    Values      = SongNames,
    Default     = SongNames[1],
    Description = "Song that will be played",
    Callback    = function(value)
        for i, s in ipairs(Songs) do
            if s.name == value then
                State.CurrentSong = i
                break
            end
        end
    end,
})

-- ── Playback Controls ───────────────────────────────────
local secCtrl = Tabs.Play:AddSection("Controls", "play-circle")

-- Play / Stop  →  Toggle so we can flip it via Options.PlayToggle:SetValue()
secCtrl:AddToggle("PlayToggle", {
    Title       = "Playing",
    Icon        = "play",
    Default     = false,
    Description = "Toggle to start or stop playback",
    Callback    = function(enabled)
        if enabled then
            DoPlay()
        else
            -- Only stop if we were actually playing
            -- (avoids a double-stop when DoPlay/DoStop resets this toggle)
            if State.Playing then
                DoStop(false)
            end
        end
    end,
})

-- Restart button — works independently of the toggle
secCtrl:AddButton({
    Title       = "↺  Restart",
    Icon        = "rotate-ccw",
    Description = "Stop current playback and restart from note 1",
    Callback    = function()
        DoStop(true)
        task.wait(0.08)
        Options.PlayToggle:SetValue(true)   -- this fires the toggle callback → DoPlay()
    end,
})

-- ── Options ─────────────────────────────────────────────
local secOpts = Tabs.Play:AddSection("Options", "sliders-horizontal")

secOpts:AddSlider("SpeedSlider", {
    Title       = "Speed",
    Icon        = "gauge",
    Min         = 25,
    Max         = 400,
    Default     = 100,
    Rounding    = 0,
    Description = "Playback speed  (100 = normal  ·  200 = double)",
    Callback    = function(v)
        Config.Speed = v / 100
    end,
})

secOpts:AddToggle("LoopToggle", {
    Title       = "Loop",
    Icon        = "repeat",
    Default     = false,
    Description = "Repeat the song when it finishes",
    Callback    = function(v)
        Config.Loop = v
    end,
})

-- Keybind — fires DoPlay/DoStop via the toggle so state stays in sync
secOpts:AddKeybind("PlayKeybind", {
    Title       = "Play / Stop Key",
    Icon        = "keyboard",
    Default     = "P",
    Mode        = "Toggle",
    Description = "Hotkey to toggle playback",
    Callback    = function()
        Options.PlayToggle:SetValue(not State.Playing)
    end,
})

-- ════════════════════════════════════════════════════════
--  §10  SONGS TAB
-- ════════════════════════════════════════════════════════

local secLib = Tabs.Songs:AddSection("Song Library", "library")
secLib:AddParagraph({
    Title   = "15 songs built in",
    Content = "Click a song to select it, then go to the Play tab.\nSongs sorted by style.",
})
secLib:AddDivider()

local function AddSongRow(parent, idx)
    local s = Songs[idx]
    parent:AddButton({
        Title       = s.name,
        Icon        = "music-2",
        Description = s.bpm .. " BPM  ·  " .. #s.notes .. " notes",
        Callback    = function()
            State.CurrentSong = idx
            Options.SongSelect:SetValue(s.name)
            Fluent:Notify({
                Title      = "Song Selected",
                Content    = s.name,
                SubContent = s.bpm .. " BPM",
                Type       = "Info",
                Duration   = 2,
            })
        end,
    })
end

local groups = {
    { label="Classics",    icon="music",         idx={1,2,7,8}            },
    { label="Game OST",    icon="gamepad-2",      idx={4,8,9,10}           },
    { label="Pop & Misc",  icon="radio",          idx={5,6,11,12,13,14,15} },
    { label="Piano Solo",  icon="piano",          idx={3}                  },
}
local shown = {}
for _, g in ipairs(groups) do
    local sec = Tabs.Songs:AddSection(g.label, g.icon)
    for _, i in ipairs(g.idx) do
        if Songs[i] and not shown[i] then
            shown[i] = true
            AddSongRow(sec, i)
        end
    end
end
-- Leftover catch-all
local miscSec = Tabs.Songs:AddSection("Others", "more-horizontal")
for i = 1, #Songs do
    if not shown[i] then AddSongRow(miscSec, i) end
end

-- ════════════════════════════════════════════════════════
--  §11  SETTINGS TAB
-- ════════════════════════════════════════════════════════

local secDetect = Tabs.Settings:AddSection("Piano Detection", "search")

secDetect:AddToggle("AutoDetectToggle", {
    Title       = "Auto-Detect",
    Icon        = "scan",
    Default     = true,
    Description = "Scan workspace for a piano on Play",
    Callback    = function(v) Config.AutoDetect = v end,
})

secDetect:AddButton({
    Title       = "Scan Now",
    Icon        = "radar",
    Description = "Manually trigger piano scan",
    Callback    = function()
        local p = FindPiano()
        if p then
            State.PianoModel = p
            Fluent:Notify({ Title="Found", Content=p.Name,              Type="Success", Duration=3 })
        else
            Fluent:Notify({ Title="Not Found", Content="No piano near you.", Type="Error",   Duration=3 })
        end
    end,
})

local secTrans = Tabs.Settings:AddSection("Transpose", "arrow-up-down")

secTrans:AddSlider("TransposeSlider", {
    Title       = "Semitones",
    Icon        = "move-vertical",
    Min         = -12,
    Max         = 12,
    Default     = 0,
    Rounding    = 0,
    Description = "Shift all notes up or down (0 = original key)",
    Callback    = function(v)
        Config.Transpose = v
        Fluent:Notify({
            Title    = "Transpose",
            Content  = v == 0 and "Original key" or (v > 0 and "+" or "") .. v .. " semitones",
            Type     = "Info",
            Duration = 1,
        })
    end,
})

local secDev = Tabs.Settings:AddSection("Debug", "terminal")

secDev:AddToggle("DebugToggle", {
    Title       = "Debug Mode",
    Icon        = "bug",
    Default     = false,
    Description = "Print note events to output",
    Callback    = function(v) Config.Debug = v end,
})

secDev:AddButton({
    Title       = "Fire C4 Test",
    Icon        = "music",
    Description = "Send a single C4 note to the detected piano",
    Callback    = function()
        if not State.PianoModel and Config.AutoDetect then
            State.PianoModel = FindPiano()
        end
        if State.PianoModel then
            PressKey(State.PianoModel, "C4")
            Fluent:Notify({ Title="Test", Content="Fired C4", Type="Info", Duration=1 })
        else
            Fluent:Notify({ Title="No Piano", Content="Run Scan Now first.", Type="Warning", Duration=2 })
        end
    end,
})

-- Interface / Save managers (only if loaded successfully)
if InterfaceManager and SaveManager then
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    InterfaceManager:SetFolder("KanhaPiano")
    SaveManager:SetFolder("KanhaPiano")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
end

-- ════════════════════════════════════════════════════════
--  §12  INFO TAB
-- ════════════════════════════════════════════════════════

local secAbout = Tabs.Info:AddSection("About", "info")
secAbout:AddParagraph({
    Title   = "Kanha Auto Piano  v2.1",
    Content = "Built on <b>StyearX / Fluent-Modded</b> UI library.\n\nv2.1 fixes:\n· Safe library loading with 3 fallbacks\n· Removed bad SetContent() calls on paragraphs\n· Play/Stop uses Toggle + Options API\n· No PlayBtn.Callback() hacks",
})
secAbout:AddDivider()
secAbout:AddParagraph({
    Title   = "15 Songs",
    Content = "Twinkle Twinkle · Happy Birthday · Für Elise\nMegalovania · Among Us · Jingle Bells\nOde To Joy · Super Mario Bros\nPirates of Caribbean · Tetris\nNever Gonna Give You Up · Coffin Dance\nDespacito · All Star · Mary Had A Little Lamb",
})

local secAPI = Tabs.Info:AddSection("Console API", "terminal")
secAPI:AddParagraph({
    Title   = "_G.Piano",
    Content = "_G.Piano.Play()\n_G.Piano.Stop()\n_G.Piano.SetSong(n)      — 1 to 15\n_G.Piano.SetSpeed(x)     — 1.0 normal\n_G.Piano.SetLoop(bool)\n_G.Piano.Transpose(n)    — ±12",
})
secAPI:AddCode({
    Title = "Quick Start Example",
    Code  = '_G.Piano.SetSong(4)   -- Megalovania\n_G.Piano.SetSpeed(1.5)\n_G.Piano.Play()',
    OnCopy = function()
        Fluent:Notify({ Title="Copied", Content="Paste in executor console", Type="Info", Duration=2 })
    end,
})

local secHotkeys = Tabs.Info:AddSection("Hotkeys", "keyboard")
secHotkeys:AddParagraph({
    Title   = "Keys",
    Content = "RightControl — minimize / restore window\nP (default)  — toggle Play / Stop\n\nRebind the play key in Play → Options → Play/Stop Key.",
})

-- ════════════════════════════════════════════════════════
--  §13  GLOBAL API
-- ════════════════════════════════════════════════════════

_G.Piano = {
    Play       = function() Options.PlayToggle:SetValue(true)  end,
    Stop       = function() Options.PlayToggle:SetValue(false) end,
    SetSong    = function(n)
        n = math.clamp(n, 1, #Songs)
        State.CurrentSong = n
        Options.SongSelect:SetValue(Songs[n].name)
    end,
    SetSpeed   = function(x)
        Config.Speed = math.clamp(x, 0.1, 10)
        Options.SpeedSlider:SetValue(math.round(Config.Speed * 100))
    end,
    SetLoop    = function(v)
        Config.Loop = v
        Options.LoopToggle:SetValue(v)
    end,
    Transpose  = function(n)
        Config.Transpose = math.clamp(n, -12, 12)
        Options.TransposeSlider:SetValue(Config.Transpose)
    end,
    Songs  = Songs,
    Config = Config,
    State  = State,
}

-- ════════════════════════════════════════════════════════
--  §14  FINISH
-- ════════════════════════════════════════════════════════

Window:SelectTab(1)

Fluent:Notify({
    Title      = "Kanha Piano Ready",
    Content    = "15 songs loaded · Pick a song → Press Play",
    SubContent = "RightCtrl to minimize · P to play",
    Type       = "Success",
    Icon       = "music",
    Duration   = 5,
})

if SaveManager then
    pcall(function() SaveManager:LoadAutoloadConfig() end)
end

print("╔══════════════════════════════════════╗")
print("║  Kanha Piano v2.1 · Fixed            ║")
print("║  _G.Piano.Play() / .Stop()           ║")
print("╚══════════════════════════════════════╝")
