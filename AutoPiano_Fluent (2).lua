--[[
╔══════════════════════════════════════════════════════════════╗
║       KANHA AUTO PIANO  ·  FLUENT MODDED  v2.2              ║
║       Fixes: toggle pill · piano detection · key firing      ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════════════════
--  §1  SAFE LIBRARY LOADER
-- ════════════════════════════════════════════════════════

local function tryGet(url)
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    return (ok and type(res) == "table") and res or nil
end

local Fluent =
    tryGet("https://raw.githubusercontent.com/StyearX/Fluent-modded/main/dist/main.lua") or
    tryGet("https://raw.githubusercontent.com/Vraigos/Fluent-Moded/main/dist/main.lua")  or
    tryGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")

if not Fluent then
    error("[AutoPiano] Fluent failed to load from all sources. Enable HttpService.")
end

local SaveManager = tryGet(
    "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/SaveManager.lua"
) or tryGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
)

local InterfaceManager = tryGet(
    "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/InterfaceManager.lua"
) or tryGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"
)

-- ════════════════════════════════════════════════════════
--  §2  SERVICES & LOCALS
-- ════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp      = Players.LocalPlayer
local pgui    = lp:WaitForChild("PlayerGui")
local Options = Fluent.Options

local isMob = UserInputService.TouchEnabled
           and not UserInputService.MouseEnabled
           and not UserInputService.KeyboardEnabled

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
    Playing       = false,
    CurrentSong   = 1,
    PianoModel    = nil,
    PianoRemote   = nil,   -- cached remote event if found
    PlayThread    = nil,
    DetectLog     = "",    -- last detection result message
    KeyMethod     = "none",-- which method fired last key
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
--  §5  SONG DATABASE  (15 songs)
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
        {"G5",.6},{"G4",.6},{"C5",.45},{"G4",.3},{"E4",.45},
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
--  §6  PIANO DETECTION  (thorough — workspace + RS + RS children)
-- ════════════════════════════════════════════════════════

local PIANO_KEYWORDS = {
    "piano","keyboard","keys","instrument","grand","upright",
    "music","note","song","melody","organ"
}

local REMOTE_KEYWORDS = {
    "playnote","note","keypress","keydown","presskey","play",
    "soundkey","pianokey","trigger"
}

local function nameHits(name, keywords)
    local low = name:lower()
    for _, kw in ipairs(keywords) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

local function scanContainer(container)
    -- Pass 1: Model/Folder name match
    for _, o in ipairs(container:GetDescendants()) do
        if (o:IsA("Model") or o:IsA("Folder"))
        and nameHits(o.Name, PIANO_KEYWORDS) then
            return o, "model-name"
        end
    end
    -- Pass 2: RemoteEvent name match
    for _, o in ipairs(container:GetDescendants()) do
        if o:IsA("RemoteEvent") and nameHits(o.Name, REMOTE_KEYWORDS) then
            return o.Parent, "remote-event", o
        end
    end
    -- Pass 3: ClickDetector on a part whose name looks like a note key
    for _, o in ipairs(container:GetDescendants()) do
        if o:IsA("ClickDetector") or o:IsA("ProximityPrompt") then
            local p = o.Parent
            if p then
                local n = p.Name:lower()
                -- e.g. "C4", "KeyboardNote_C4", "Key_C4", "NoteC4"
                if n:match("[a-g]b?%d") or n:find("key") or n:find("note") then
                    -- walk up to the piano model
                    local piano = p.Parent
                    return piano, "click-detector"
                end
            end
        end
    end
    return nil
end

local function FindPiano()
    -- Search workspace first, then ReplicatedStorage
    local piano, method, remote = scanContainer(workspace)
    if not piano then
        piano, method, remote = scanContainer(ReplicatedStorage)
    end
    if piano then
        State.DetectLog = "Found [" .. method .. "]: " .. piano.Name
        if remote then State.PianoRemote = remote end
    else
        State.DetectLog = "Not found in workspace or ReplicatedStorage"
    end
    if Config.Debug then print("[AutoPiano]", State.DetectLog) end
    return piano
end

-- ════════════════════════════════════════════════════════
--  §7  PRESS KEY  (3 methods, all tried in order)
-- ════════════════════════════════════════════════════════

local function PressKey(piano, note)
    if not piano then return end
    local final = TNote(note, Config.Transpose)

    -- ── Method 1: cached or discovered RemoteEvent ───────
    local re = State.PianoRemote
           or piano:FindFirstChild("PlayNote",    true)
           or piano:FindFirstChild("NotePressed", true)
           or piano:FindFirstChild("KeyPressed",  true)
           or piano:FindFirstChild("PressKey",    true)
           or piano:FindFirstChild("Note",        true)
           or piano:FindFirstChild("Piano",       true)

    if re and re:IsA("RemoteEvent") then
        -- Try the note as a string, then as a key-name variant
        pcall(function() re:FireServer(final) end)
        pcall(function() re:FireServer("KeyboardNote_" .. final) end)
        State.KeyMethod = "remote"
        if Config.Debug then print("[Key] Remote →", final) end
        return
    end

    -- ── Method 2: ClickDetector on named key part ────────
    local targets = {
        "KeyboardNote_" .. final,
        final,
        "Key_"  .. final,
        "Note_" .. final,
        "key"   .. final:lower(),
    }
    for _, kn in ipairs(targets) do
        local part = piano:FindFirstChild(kn, true)
        if part then
            local cd = part:FindFirstChildOfClass("ClickDetector")
            local pp = part:FindFirstChildOfClass("ProximityPrompt")
            if cd then
                pcall(fireclickdetector, cd)
                State.KeyMethod = "clickdetector:" .. kn
                if Config.Debug then print("[Key] Click →", kn) end
                return
            end
            if pp then
                pcall(fireproximityprompt, pp)
                State.KeyMethod = "proxprompt:" .. kn
                if Config.Debug then print("[Key] Prox →", kn) end
                return
            end
        end
    end

    -- ── Method 3: blast every RemoteEvent in the model ───
    for _, o in ipairs(piano:GetDescendants()) do
        if o:IsA("RemoteEvent") then
            pcall(function() o:FireServer(final) end)
            State.KeyMethod = "blast-remote"
            if Config.Debug then print("[Key] Blast →", o.Name, final) end
            return
        end
    end

    -- ── Method 4: search all remote events in game ───────
    -- Some games keep the RE in ServerScriptService or elsewhere
    for _, o in ipairs(game:GetDescendants()) do
        if o:IsA("RemoteEvent") and nameHits(o.Name, REMOTE_KEYWORDS) then
            pcall(function() o:FireServer(final) end)
            State.KeyMethod = "game-blast:" .. o.Name
            if Config.Debug then print("[Key] GameBlast →", o.Name, final) end
            return
        end
    end

    if Config.Debug then warn("[AutoPiano] No key handler found for:", final) end
    State.KeyMethod = "FAILED"
end

-- ════════════════════════════════════════════════════════
--  §8  PLAY / STOP  (shared logic, all controls route here)
-- ════════════════════════════════════════════════════════

local function DoStop(silent)
    State.Playing = false
    if State.PlayThread then
        task.cancel(State.PlayThread)
        State.PlayThread = nil
    end
    pcall(function() Options.PlayToggle:SetValue(false) end)
    if not silent then
        Fluent:Notify({ Title="Piano", Content="Stopped", Type="Warning", Duration=2 })
    end
end

local function DoPlay()
    if State.Playing then DoStop(true) end

    if Config.AutoDetect then
        State.PianoModel  = FindPiano()
        State.PianoRemote = nil   -- reset cache so FindPiano can re-set it
        State.PianoModel  = FindPiano()   -- call twice so cache is populated

        if not State.PianoModel then
            Fluent:Notify({
                Title   = "Piano Not Found",
                Content = State.DetectLog,
                Type    = "Error",
                Duration = 4,
            })
            pcall(function() Options.PlayToggle:SetValue(false) end)
            return
        end
    end

    if not State.PianoModel then
        Fluent:Notify({ Title="No Piano", Content="Enable Auto-Detect or Scan first.", Type="Error", Duration=3 })
        pcall(function() Options.PlayToggle:SetValue(false) end)
        return
    end

    local song  = Songs[State.CurrentSong]
    local total = #song.notes
    State.Playing = true

    Fluent:Notify({
        Title      = "▶  Now Playing",
        Content    = song.name,
        SubContent = song.bpm .. " BPM · " .. total .. " notes · " .. State.DetectLog,
        Type       = "Success",
        Icon       = "music",
        Duration   = 4,
    })

    State.PlayThread = task.spawn(function()
        repeat
            for _, entry in ipairs(song.notes) do
                if not State.Playing then return end
                PressKey(State.PianoModel, entry[1])
                task.wait(entry[2] / Config.Speed)
            end
        until not Config.Loop or not State.Playing

        if State.Playing then
            State.Playing = false
            pcall(function() Options.PlayToggle:SetValue(false) end)
            Fluent:Notify({ Title="Finished", Content=song.name, Type="Success", Duration=3 })
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  §9  SNAPSHOT PlayerGui  (to find Fluent's ScreenGui later)
-- ════════════════════════════════════════════════════════

local snapBefore = {}
for _, g in ipairs(pgui:GetChildren()) do snapBefore[g] = true end

-- ════════════════════════════════════════════════════════
--  §10  FLUENT WINDOW
-- ════════════════════════════════════════════════════════

local Window = Fluent:CreateWindow({
    Title        = "Kanha Piano",
    SubTitle     = "Auto Player · v2.2",
    TabWidth     = isMob and 110 or 130,
    Size         = isMob
                   and UDim2.fromOffset(460, 500)
                   or  UDim2.fromOffset(560, 540),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = Enum.KeyCode.RightControl,
    Search       = false,
    Tags         = {
        { Text = " v2.2 ", Color = Color3.fromRGB(0,190,220) },
        { Text = " Fixed ", Color = Color3.fromRGB(100,40,200) },
    },
    UserInfoTop      = true,
    UserInfoTitle    = "Auto Piano",
    UserInfoSubtitle = lp.DisplayName,
    UserInfoColor    = Color3.fromRGB(0, 200, 240),
    Animated         = true,
})

local Tabs = {
    Play     = Window:AddTab({ Title="Play",     Icon="music"    }),
    Songs    = Window:AddTab({ Title="Songs",    Icon="disc"     }),
    Settings = Window:AddTab({ Title="Settings", Icon="settings" }),
    Info     = Window:AddTab({ Title="Info",     Icon="info"     }),
}

-- ════════════════════════════════════════════════════════
--  §11  GRAB FLUENT'S SCREENGUI  (for the toggle pill)
-- ════════════════════════════════════════════════════════

task.wait(0.2)   -- give Fluent time to parent its ScreenGui

local FluentGui = nil
for _, g in ipairs(pgui:GetChildren()) do
    if not snapBefore[g] and g:IsA("ScreenGui") then
        FluentGui = g
        break
    end
end

-- ════════════════════════════════════════════════════════
--  §12  TOGGLE PILL  (native ScreenGui, always visible)
--       Floats on the left edge — click to open/close Fluent
-- ════════════════════════════════════════════════════════

local PillGui = Instance.new("ScreenGui")
PillGui.Name           = "KanhaPianoPill"
PillGui.ResetOnSpawn   = false
PillGui.DisplayOrder   = 9999
PillGui.IgnoreGuiInset = true
PillGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
PillGui.Parent         = pgui

-- Glow behind pill
local PillGlow = Instance.new("Frame")
PillGlow.Size               = UDim2.fromOffset(54, 54)
PillGlow.Position           = UDim2.new(0, 8, 0.5, -27)
PillGlow.BackgroundColor3   = Color3.fromRGB(0, 180, 255)
PillGlow.BackgroundTransparency = 0.75
PillGlow.BorderSizePixel    = 0
PillGlow.Parent             = PillGui
local _gc = Instance.new("UICorner") _gc.CornerRadius = UDim.new(1,0) _gc.Parent = PillGlow

-- Main pill button
local Pill = Instance.new("TextButton")
Pill.Name               = "Pill"
Pill.Size               = UDim2.fromOffset(44, 44)
Pill.Position           = UDim2.new(0, 13, 0.5, -22)
Pill.BackgroundColor3   = Color3.fromRGB(14, 10, 40)
Pill.Text               = "🎹"
Pill.TextSize           = 22
Pill.Font               = Enum.Font.GothamBold
Pill.TextColor3         = Color3.fromRGB(0, 220, 255)
Pill.AutoButtonColor    = false
Pill.BorderSizePixel    = 0
Pill.ZIndex             = 2
Pill.Parent             = PillGui

local _pc = Instance.new("UICorner") _pc.CornerRadius = UDim.new(1,0) _pc.Parent = Pill

local _ps = Instance.new("UIStroke")
_ps.Color       = Color3.fromRGB(0, 180, 255)
_ps.Thickness   = 1.5
_ps.Transparency = 0.3
_ps.Parent      = Pill

-- Pill state label (shows OPEN / CLOSE)
local PillLabel = Instance.new("TextLabel")
PillLabel.Size               = UDim2.fromOffset(44, 14)
PillLabel.Position           = UDim2.new(0, 13, 0.5, 23)
PillLabel.BackgroundTransparency = 1
PillLabel.Text               = "CLOSE"
PillLabel.TextSize           = 8
PillLabel.Font               = Enum.Font.GothamBold
PillLabel.TextColor3         = Color3.fromRGB(0, 180, 220)
PillLabel.TextXAlignment     = Enum.TextXAlignment.Center
PillLabel.Parent             = PillGui

-- Animate glow pulse
local glowT = 0
RunService.RenderStepped:Connect(function(dt)
    glowT = glowT + dt * 2.5
    local alpha = 0.65 + 0.2 * math.sin(glowT)
    PillGlow.BackgroundTransparency = alpha
    -- Rainbow hue shift on border
    local hue = (glowT / (2 * math.pi)) % 1
    local function hsvToRgb(h, s, v)
        local i = math.floor(h*6); local f = h*6-i; local p = v*(1-s); local q = v*(1-f*s); local t2 = v*(1-(1-f)*s)
        i = i%6
        if i==0 then return Color3.new(v,t2,p) elseif i==1 then return Color3.new(q,v,p)
        elseif i==2 then return Color3.new(p,v,t2) elseif i==3 then return Color3.new(p,q,v)
        elseif i==4 then return Color3.new(t2,p,v) else return Color3.new(v,p,q) end
    end
    _ps.Color = hsvToRgb(hue, 0.6, 1)
    PillGlow.BackgroundColor3 = hsvToRgb(hue, 0.8, 0.9)
end)

-- Hover effect
Pill.MouseEnter:Connect(function()
    TweenService:Create(Pill, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(0, 50, 80)
    }):Play()
end)
Pill.MouseLeave:Connect(function()
    TweenService:Create(Pill, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(14, 10, 40)
    }):Play()
end)

-- Toggle logic
local guiVisible = true

local function SetGuiVisible(v)
    guiVisible = v
    if FluentGui then
        FluentGui.Enabled = v
    end
    PillLabel.Text      = v and "CLOSE" or "OPEN"
    Pill.TextColor3     = v
        and Color3.fromRGB(0, 220, 255)
        or  Color3.fromRGB(100, 100, 150)
    -- Spring-bounce the pill on toggle
    TweenService:Create(Pill, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(50, 50),
        Position = UDim2.new(0, 10, 0.5, -25),
    }):Play()
    task.delay(0.15, function()
        TweenService:Create(Pill, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(44, 44),
            Position = UDim2.new(0, 13, 0.5, -22),
        }):Play()
    end)
end

Pill.MouseButton1Click:Connect(function()
    SetGuiVisible(not guiVisible)
end)

-- Also close via RightControl (matches Fluent's MinimizeKey)
-- But we override with our own logic so the pill label stays in sync
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        SetGuiVisible(not guiVisible)
    end
end)

-- ════════════════════════════════════════════════════════
--  §13  PLAY TAB
-- ════════════════════════════════════════════════════════

local secSel = Tabs.Play:AddSection("Song", "disc")
secSel:AddDropdown("SongSelect", {
    Title       = "Select Song",
    Icon        = "list-music",
    Values      = SongNames,
    Default     = SongNames[1],
    Description = "Song that will be played",
    Callback    = function(value)
        for i, s in ipairs(Songs) do
            if s.name == value then State.CurrentSong = i break end
        end
    end,
})

local secCtrl = Tabs.Play:AddSection("Controls", "play-circle")
secCtrl:AddToggle("PlayToggle", {
    Title       = "Playing",
    Icon        = "play",
    Default     = false,
    Description = "Toggle ON to play, OFF to stop",
    Callback    = function(enabled)
        if enabled then
            DoPlay()
        else
            if State.Playing then DoStop(false) end
        end
    end,
})
secCtrl:AddButton({
    Title       = "↺  Restart",
    Icon        = "rotate-ccw",
    Description = "Stop and restart from the beginning",
    Callback    = function()
        DoStop(true)
        task.wait(0.08)
        Options.PlayToggle:SetValue(true)
    end,
})

local secOpts = Tabs.Play:AddSection("Options", "sliders-horizontal")
secOpts:AddSlider("SpeedSlider", {
    Title       = "Speed",
    Icon        = "gauge",
    Min         = 25, Max = 400, Default = 100, Rounding = 0,
    Description = "Playback speed (100 = normal)",
    Callback    = function(v) Config.Speed = v / 100 end,
})
secOpts:AddToggle("LoopToggle", {
    Title       = "Loop",
    Icon        = "repeat",
    Default     = false,
    Description = "Repeat song on finish",
    Callback    = function(v) Config.Loop = v end,
})
secOpts:AddKeybind("PlayKeybind", {
    Title   = "Play / Stop Key",
    Icon    = "keyboard",
    Default = "P",
    Mode    = "Toggle",
    Description = "Hotkey to toggle playback",
    Callback = function()
        Options.PlayToggle:SetValue(not State.Playing)
    end,
})

-- ════════════════════════════════════════════════════════
--  §14  SONGS TAB
-- ════════════════════════════════════════════════════════

local secLib = Tabs.Songs:AddSection("Library", "library")
secLib:AddParagraph({
    Title   = "15 songs built in",
    Content = "Click to select, then go to Play tab.",
})
secLib:AddDivider()

local function AddSongRow(parent, idx)
    local s = Songs[idx]
    parent:AddButton({
        Title       = s.name,
        Icon        = "music-2",
        Description = s.bpm .. " BPM · " .. #s.notes .. " notes",
        Callback    = function()
            State.CurrentSong = idx
            Options.SongSelect:SetValue(s.name)
            Fluent:Notify({ Title="Selected", Content=s.name, Type="Info", Duration=2 })
        end,
    })
end

local groups = {
    { label="Classics",   icon="music",     idx={1,2,7,8}            },
    { label="Game OST",   icon="gamepad-2", idx={4,9,10,11}          },
    { label="Pop & Misc", icon="radio",     idx={5,6,12,13,14,15}    },
    { label="Piano Solo", icon="piano",     idx={3}                  },
}
local shown = {}
for _, g in ipairs(groups) do
    local sec = Tabs.Songs:AddSection(g.label, g.icon)
    for _, i in ipairs(g.idx) do
        if Songs[i] and not shown[i] then shown[i]=true; AddSongRow(sec, i) end
    end
end
local misc = Tabs.Songs:AddSection("Others", "more-horizontal")
for i = 1, #Songs do if not shown[i] then AddSongRow(misc, i) end end

-- ════════════════════════════════════════════════════════
--  §15  SETTINGS TAB
-- ════════════════════════════════════════════════════════

local secDet = Tabs.Settings:AddSection("Piano Detection", "search")
secDet:AddToggle("AutoDetectToggle", {
    Title="Auto-Detect", Icon="scan", Default=true,
    Description="Scan for piano on Play",
    Callback = function(v) Config.AutoDetect = v end,
})
secDet:AddButton({
    Title="Scan Now", Icon="radar",
    Description="Manually scan workspace and ReplicatedStorage",
    Callback = function()
        State.PianoRemote = nil
        State.PianoModel  = FindPiano()
        if State.PianoModel then
            Fluent:Notify({ Title="Found", Content=State.DetectLog, Type="Success", Duration=4 })
        else
            Fluent:Notify({ Title="Not Found", Content=State.DetectLog, Type="Error", Duration=4 })
        end
    end,
})

local secTrans = Tabs.Settings:AddSection("Transpose", "arrow-up-down")
secTrans:AddSlider("TransposeSlider", {
    Title="Semitones", Icon="move-vertical",
    Min=-12, Max=12, Default=0, Rounding=0,
    Description="Shift all notes ±12 semitones",
    Callback = function(v)
        Config.Transpose = v
    end,
})

local secDev = Tabs.Settings:AddSection("Debug", "terminal")
secDev:AddToggle("DebugToggle", {
    Title="Debug Mode", Icon="bug", Default=false,
    Description="Print detection and key-fire events to output",
    Callback = function(v) Config.Debug = v end,
})
secDev:AddButton({
    Title="Fire C4 Test", Icon="music",
    Description="Test-fire C4 on the detected piano",
    Callback = function()
        if not State.PianoModel then
            State.PianoRemote = nil
            State.PianoModel  = FindPiano()
        end
        if State.PianoModel then
            PressKey(State.PianoModel, "C4")
            Fluent:Notify({ Title="Test Fired", Content="C4 · method: " .. State.KeyMethod, Type="Info", Duration=3 })
        else
            Fluent:Notify({ Title="No Piano", Content=State.DetectLog, Type="Error", Duration=3 })
        end
    end,
})

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
--  §16  INFO TAB
-- ════════════════════════════════════════════════════════

local secAb = Tabs.Info:AddSection("About", "info")
secAb:AddParagraph({
    Title   = "Kanha Auto Piano  v2.2",
    Content = "v2.2 fixes:\n· Toggle pill (always-on-screen open/close button)\n· 4-method piano detection (workspace, RS, game-wide blast)\n· Key firing tries string, name variants, blast, game-wide\n· RightControl synced with pill label\n· Debug mode shows exact method used per key",
})

local secAPI = Tabs.Info:AddSection("Console API", "terminal")
secAPI:AddParagraph({
    Title   = "_G.Piano",
    Content = "_G.Piano.Play()\n_G.Piano.Stop()\n_G.Piano.SetSong(n)\n_G.Piano.SetSpeed(x)\n_G.Piano.SetLoop(bool)\n_G.Piano.Transpose(n)",
})

-- ════════════════════════════════════════════════════════
--  §17  GLOBAL API
-- ════════════════════════════════════════════════════════

_G.Piano = {
    Play      = function() Options.PlayToggle:SetValue(true)  end,
    Stop      = function() Options.PlayToggle:SetValue(false) end,
    SetSong   = function(n)
        n = math.clamp(n, 1, #Songs); State.CurrentSong = n
        Options.SongSelect:SetValue(Songs[n].name)
    end,
    SetSpeed  = function(x)
        Config.Speed = math.clamp(x, 0.1, 10)
        Options.SpeedSlider:SetValue(math.round(Config.Speed * 100))
    end,
    SetLoop   = function(v) Config.Loop = v; Options.LoopToggle:SetValue(v) end,
    Transpose = function(n)
        Config.Transpose = math.clamp(n, -12, 12)
        Options.TransposeSlider:SetValue(Config.Transpose)
    end,
    Show      = function() SetGuiVisible(true)  end,
    Hide      = function() SetGuiVisible(false) end,
    Toggle    = function() SetGuiVisible(not guiVisible) end,
    Songs = Songs, Config = Config, State = State,
}

-- ════════════════════════════════════════════════════════
--  §18  FINISH
-- ════════════════════════════════════════════════════════

Window:SelectTab(1)

Fluent:Notify({
    Title      = "Kanha Piano Ready",
    Content    = "Pick a song → toggle Play\n🎹 pill on the left = open/close",
    SubContent = "RightCtrl or pill to toggle",
    Type       = "Success",
    Icon       = "music",
    Duration   = 5,
})

if SaveManager then pcall(function() SaveManager:LoadAutoloadConfig() end) end

print("╔══════════════════════════════════════╗")
print("║  Kanha Piano v2.2 · Pill + Fix       ║")
print("║  Pill on left edge → open/close GUI  ║")
print("║  _G.Piano.Play() / .Stop()           ║")
print("╚══════════════════════════════════════╝")
