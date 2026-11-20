--[[
╔══════════════════════════════════════════════════════════════╗
║       KANHA AUTO PIANO  ·  FLUENT MODDED  v2.3              ║
║       Fix: FluentGui nil · pill on mobile · piano detection  ║
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

assert(Fluent, "[AutoPiano] Fluent failed to load. Make sure HttpService is enabled.")

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
--  §2  SERVICES
-- ════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RS               = game:GetService("ReplicatedStorage")

local lp      = Players.LocalPlayer
local pgui    = lp:WaitForChild("PlayerGui")
local Options = Fluent.Options

local isMob = UserInputService.TouchEnabled
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
    Playing     = false,
    CurrentSong = 1,
    PianoModel  = nil,
    PlayThread  = nil,
    ScanLog     = "Not scanned yet",
    KeyMethod   = "none",
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
for i,n in ipairs(ALL_NOTES) do NoteIdx[n]=i end

local function TNote(note,semi)
    if semi==0 then return note end
    local i=NoteIdx[note]; if not i then return note end
    return ALL_NOTES[math.clamp(i+semi,1,#ALL_NOTES)]
end

-- ════════════════════════════════════════════════════════
--  §5  SONGS  (15 tracks)
-- ════════════════════════════════════════════════════════

local Songs = {
    {name="Twinkle Twinkle",bpm=110,notes={
        {"C4",.3},{"C4",.3},{"G4",.3},{"G4",.3},{"A4",.3},{"A4",.3},{"G4",.6},
        {"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.3},{"D4",.3},{"C4",.6},
        {"G4",.3},{"G4",.3},{"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.6},
        {"G4",.3},{"G4",.3},{"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.6},
        {"C4",.3},{"C4",.3},{"G4",.3},{"G4",.3},{"A4",.3},{"A4",.3},{"G4",.6},
        {"F4",.3},{"F4",.3},{"E4",.3},{"E4",.3},{"D4",.3},{"D4",.3},{"C4",.6},
    }},
    {name="Happy Birthday",bpm=100,notes={
        {"C4",.3},{"C4",.15},{"D4",.45},{"C4",.45},{"F4",.45},{"E4",.9},
        {"C4",.3},{"C4",.15},{"D4",.45},{"C4",.45},{"G4",.45},{"F4",.9},
        {"C4",.3},{"C4",.15},{"C5",.45},{"A4",.45},{"F4",.45},{"E4",.45},{"D4",.9},
        {"Bb4",.3},{"Bb4",.15},{"A4",.45},{"F4",.45},{"G4",.45},{"F4",.9},
    }},
    {name="Für Elise",bpm=138,notes={
        {"E5",.2},{"Eb5",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},
        {"B4",.2},{"D5",.2},{"C5",.2},{"A4",.4},
        {"C4",.2},{"E4",.2},{"A4",.2},{"B4",.4},
        {"E4",.2},{"Ab4",.2},{"B4",.2},{"C5",.4},
        {"E4",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},{"Eb5",.2},{"E5",.2},
        {"B4",.2},{"D5",.2},{"C5",.2},{"A4",.4},
        {"C4",.2},{"E4",.2},{"A4",.2},{"B4",.4},
        {"E4",.2},{"C5",.2},{"B4",.2},{"A4",.6},
    }},
    {name="Megalovania",bpm=200,notes={
        {"D4",.15},{"D4",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},{"D4",.15},{"F4",.15},{"G4",.3},
        {"C4",.15},{"C4",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},{"D4",.15},{"F4",.15},{"G4",.3},
        {"B3",.15},{"B3",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},{"D4",.15},{"F4",.15},{"G4",.3},
        {"Bb3",.15},{"Bb3",.15},{"D5",.3},{"A4",.3},{"Ab4",.3},{"G4",.3},{"F4",.3},{"D4",.15},{"F4",.15},{"G4",.3},
    }},
    {name="Among Us Theme",bpm=120,notes={
        {"F4",.3},{"Ab4",.3},{"Bb4",.3},{"B4",.3},{"Bb4",.3},{"Ab4",.6},{"F4",.3},
        {"Ab4",.3},{"Ab4",.3},{"G4",.3},{"Ab4",.3},{"Eb4",.9},
        {"F4",.3},{"Ab4",.3},{"Bb4",.3},{"B4",.3},{"Bb4",.3},{"Ab4",.3},{"F4",.3},
        {"Ab4",.3},{"Ab4",.3},{"G4",.3},{"Ab4",.3},{"Eb4",.6},
    }},
    {name="Jingle Bells",bpm=140,notes={
        {"E4",.25},{"E4",.25},{"E4",.5},{"E4",.25},{"E4",.25},{"E4",.5},
        {"E4",.25},{"G4",.25},{"C4",.25},{"D4",.25},{"E4",1},
        {"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"E4",.25},{"E4",.25},{"E4",.25},
        {"E4",.25},{"D4",.25},{"D4",.25},{"E4",.25},{"D4",.5},{"G4",.5},
        {"E4",.25},{"E4",.25},{"E4",.5},{"E4",.25},{"E4",.25},{"E4",.5},
        {"E4",.25},{"G4",.25},{"C4",.25},{"D4",.25},{"E4",1},
        {"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"F4",.25},{"E4",.25},{"E4",.25},{"E4",.25},
        {"G4",.25},{"G4",.25},{"F4",.25},{"D4",.25},{"C4",1},
    }},
    {name="Ode To Joy",bpm=120,notes={
        {"E4",.3},{"E4",.3},{"F4",.3},{"G4",.3},{"G4",.3},{"F4",.3},{"E4",.3},{"D4",.3},
        {"C4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"E4",.45},{"D4",.15},{"D4",.6},
        {"E4",.3},{"E4",.3},{"F4",.3},{"G4",.3},{"G4",.3},{"F4",.3},{"E4",.3},{"D4",.3},
        {"C4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"D4",.45},{"C4",.15},{"C4",.6},
    }},
    {name="Super Mario Bros",bpm=200,notes={
        {"E5",.15},{"E5",.3},{"E5",.3},{"C5",.15},{"E5",.3},{"G5",.6},{"G4",.6},
        {"C5",.45},{"G4",.3},{"E4",.45},{"A4",.3},{"B4",.3},{"Bb4",.15},{"A4",.3},
        {"G4",.2},{"E5",.2},{"G5",.2},{"A5",.3},{"F5",.15},{"G5",.3},
        {"E5",.3},{"C5",.15},{"D5",.15},{"B4",.45},
    }},
    {name="Pirates of Caribbean",bpm=140,notes={
        {"A4",.2},{"B4",.2},{"C5",.3},{"C5",.15},{"C5",.15},{"D5",.15},{"E5",.15},
        {"E5",.3},{"E5",.15},{"E5",.15},{"F5",.15},{"E5",.15},
        {"D5",.3},{"D5",.15},{"D5",.15},{"E5",.15},{"F5",.15},{"E5",.6},
        {"A4",.2},{"B4",.2},{"C5",.3},{"C5",.15},{"C5",.15},{"D5",.15},{"E5",.15},
        {"E5",.3},{"E5",.15},{"E5",.15},{"F5",.15},{"E5",.15},
        {"D5",.3},{"D5",.15},{"D5",.15},{"G5",.15},{"F5",.15},{"E5",.9},
    }},
    {name="Tetris",bpm=160,notes={
        {"E5",.3},{"B4",.15},{"C5",.15},{"D5",.3},{"C5",.15},{"B4",.15},
        {"A4",.3},{"A4",.15},{"C5",.15},{"E5",.3},{"D5",.15},{"C5",.15},
        {"B4",.45},{"C5",.15},{"D5",.3},{"E5",.3},{"C5",.3},{"A4",.3},{"A4",.6},
        {"D5",.45},{"F5",.15},{"A5",.3},{"G5",.15},{"F5",.15},
        {"E5",.45},{"C5",.15},{"E5",.3},{"D5",.15},{"C5",.15},
        {"B4",.3},{"B4",.15},{"C5",.15},{"D5",.3},{"E5",.3},{"C5",.3},{"A4",.3},{"A4",.6},
    }},
    {name="Never Gonna Give You Up",bpm=113,notes={
        {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},{"Gb5",.54},{"Gb5",.27},{"E5",.81},
        {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},{"E5",.54},{"E5",.27},{"D5",.54},{"C5",.27},{"B4",.27},
        {"A4",.27},{"B4",.27},{"D5",.27},{"B4",.27},{"D5",.54},{"E5",.27},{"C5",.54},{"B4",.27},{"A4",.27},
        {"A4",.54},{"D5",.54},{"D5",.27},{"C5",.27},{"B4",.54},
        {"A4",.54},{"A4",.27},{"D5",.54},{"D5",.27},{"E5",.27},{"C5",.54},{"B4",.27},{"A4",.9},
    }},
    {name="Coffin Dance",bpm=126,notes={
        {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},{"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
        {"G4",.25},{"F4",.25},{"Eb4",.25},{"F4",.25},{"G4",.5},{"Ab4",.5},
        {"G4",.25},{"F4",.25},{"Eb4",.25},{"F4",.25},{"G4",1},
        {"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},{"G4",.25},{"Ab4",.25},{"G4",.25},{"Eb4",.75},
        {"Bb4",.5},{"Ab4",.5},{"G4",.5},{"F4",.5},{"Eb4",1},
    }},
    {name="Despacito Intro",bpm=176,notes={
        {"B4",.2},{"Ab4",.2},{"E4",.4},{"E4",.2},{"Gb4",.2},{"Ab4",.2},{"B4",.2},{"Ab4",.2},{"E4",.6},
        {"B4",.2},{"Ab4",.2},{"E4",.4},{"E4",.2},{"Gb4",.2},{"Ab4",.2},{"B4",.2},{"Ab4",.2},{"Gb4",.4},{"E4",.2},
        {"Gb4",.6},
    }},
    {name="All Star",bpm=104,notes={
        {"G4",.29},{"G4",.29},{"G4",.29},{"G4",.29},{"A4",.29},{"G4",.29},{"F4",.29},
        {"G4",.58},{"F4",.29},{"F4",.29},{"F4",.29},{"F4",.29},{"G4",.29},{"F4",.29},{"E4",.87},
        {"G4",.29},{"G4",.29},{"G4",.29},{"G4",.29},{"A4",.29},{"G4",.29},{"F4",.29},
        {"G4",.58},{"F4",.29},{"F4",.29},{"F4",.29},{"G4",.29},{"A4",.29},{"G4",.58},
        {"E4",.29},{"F4",.29},{"G4",.29},{"F4",.29},{"E4",.87},
    }},
    {name="Mary Had A Little Lamb",bpm=110,notes={
        {"E4",.3},{"D4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"E4",.3},{"E4",.6},
        {"D4",.3},{"D4",.3},{"D4",.6},{"E4",.3},{"G4",.3},{"G4",.6},
        {"E4",.3},{"D4",.3},{"C4",.3},{"D4",.3},{"E4",.3},{"E4",.3},{"E4",.3},{"E4",.3},
        {"D4",.3},{"D4",.3},{"E4",.3},{"D4",.3},{"C4",.9},
    }},
}
local SongNames={}; for _,s in ipairs(Songs) do table.insert(SongNames,s.name) end

-- ════════════════════════════════════════════════════════
--  §6  PIANO DETECTION  (exhaustive — every strategy)
-- ════════════════════════════════════════════════════════

local PIANO_KW  = {"piano","keyboard","keys","instrument","grand","organ","music"}
local REMOTE_KW = {"playnote","notepress","keypress","presskey","play","note","key","piano","sound"}

local function kwMatch(name,list)
    local low=name:lower()
    for _,k in ipairs(list) do if low:find(k,1,true) then return true end end
    return false
end

-- Returns: piano-container, method-string, remote-event-or-nil
local function ScanForPiano()
    local containers = {workspace, RS}

    -- Pass A: Model/Folder whose NAME sounds like a piano
    for _,ct in ipairs(containers) do
        for _,o in ipairs(ct:GetDescendants()) do
            if (o:IsA("Model") or o:IsA("Folder")) and kwMatch(o.Name, PIANO_KW) then
                return o, "A:name="..o.Name, nil
            end
        end
    end

    -- Pass B: ANY RemoteEvent whose name sounds like a piano event
    for _,ct in ipairs(containers) do
        for _,o in ipairs(ct:GetDescendants()) do
            if o:IsA("RemoteEvent") and kwMatch(o.Name, REMOTE_KW) then
                return o.Parent, "B:remote="..o.Name, o
            end
        end
    end

    -- Pass C: Part that is named like a piano key (C4, KeyboardNote_C4, etc.)
    --         → walk up two parents to get the piano model
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") or o:IsA("UnionOperation") then
            local n = o.Name
            if n:match("^[A-Ga-g][b]?%d$")        -- bare note: C4, Bb3
            or n:find("KeyboardNote")               -- KeyboardNote_C4
            or n:lower():find("key%a?%d")           -- Key_C4, keyC4
            or n:lower():find("note%a?%d") then     -- NoteC4
                local container = o.Parent and o.Parent.Parent
                if container then
                    return container, "C:keypart="..n, nil
                end
            end
        end
    end

    -- Pass D: ANY ClickDetector/ProximityPrompt in workspace
    --         whose parent is part of a grouped structure (piano must be near player)
    for _,o in ipairs(workspace:GetDescendants()) do
        if (o:IsA("ClickDetector") or o:IsA("ProximityPrompt")) then
            local part = o.Parent
            if part and part:IsA("BasePart") then
                local mdl = part.Parent
                if mdl then
                    return mdl, "D:clickdet="..part.Name, nil
                end
            end
        end
    end

    return nil, "NOT FOUND (tried 4 passes)", nil
end

local cachedRemote = nil

local function FindPiano()
    cachedRemote = nil
    local piano, method, remote = ScanForPiano()
    State.ScanLog = method
    if remote then cachedRemote = remote end
    if Config.Debug then print("[AutoPiano] scan →", method) end
    return piano
end

-- ════════════════════════════════════════════════════════
--  §7  PRESS KEY  (5 strategies, tried in order)
-- ════════════════════════════════════════════════════════

local function PressKey(piano, note)
    if not piano then return end
    local final = TNote(note, Config.Transpose)

    -- S1: cached remote from scan
    if cachedRemote and cachedRemote:IsA("RemoteEvent") then
        pcall(function() cachedRemote:FireServer(final) end)
        pcall(function() cachedRemote:FireServer("KeyboardNote_"..final) end)
        State.KeyMethod="S1:cached-remote"; return
    end

    -- S2: search RemoteEvent inside the piano model
    local reNames = {"PlayNote","NotePressed","KeyPressed","PressKey","Note","Piano","Key"}
    for _,rn in ipairs(reNames) do
        local re = piano:FindFirstChild(rn, true)
        if re and re:IsA("RemoteEvent") then
            pcall(function() re:FireServer(final) end)
            pcall(function() re:FireServer("KeyboardNote_"..final) end)
            State.KeyMethod="S2:re="..rn; return
        end
    end

    -- S3: ClickDetector on a part named like the note
    local partNames = {
        "KeyboardNote_"..final, final, "Key_"..final,
        "Note_"..final, "key"..final:lower(), "note"..final:lower()
    }
    for _,pn in ipairs(partNames) do
        local part = piano:FindFirstChild(pn, true)
        if part then
            local cd = part:FindFirstChildOfClass("ClickDetector")
            local pp = part:FindFirstChildOfClass("ProximityPrompt")
            if cd then pcall(fireclickdetector, cd); State.KeyMethod="S3:click="..pn; return end
            if pp then pcall(fireproximityprompt, pp); State.KeyMethod="S3:prox="..pn; return end
        end
    end

    -- S4: blast every RemoteEvent in the piano model
    for _,o in ipairs(piano:GetDescendants()) do
        if o:IsA("RemoteEvent") then
            pcall(function() o:FireServer(final) end)
            State.KeyMethod="S4:blast="..o.Name; return
        end
    end

    -- S5: game-wide RemoteEvent blast (last resort)
    for _,o in ipairs(game:GetDescendants()) do
        if o:IsA("RemoteEvent") and kwMatch(o.Name, REMOTE_KW) then
            pcall(function() o:FireServer(final) end)
            State.KeyMethod="S5:gameblast="..o.Name; return
        end
    end

    State.KeyMethod="FAILED:no-handler"
    if Config.Debug then warn("[AutoPiano] No key handler for:", final) end
end

-- ════════════════════════════════════════════════════════
--  §8  PLAY / STOP
-- ════════════════════════════════════════════════════════

local function DoStop(silent)
    State.Playing=false
    if State.PlayThread then task.cancel(State.PlayThread); State.PlayThread=nil end
    pcall(function() Options.PlayToggle:SetValue(false) end)
    if not silent then
        Fluent:Notify({Title="Piano",Content="Stopped",Type="Warning",Duration=2})
    end
end

local function DoPlay()
    if State.Playing then DoStop(true) end

    if Config.AutoDetect then
        State.PianoModel = FindPiano()
        -- Always notify scan result so player can debug
        Fluent:Notify({
            Title      = State.PianoModel and "Piano Found" or "Piano NOT Found",
            Content    = State.ScanLog,
            Type       = State.PianoModel and "Success" or "Error",
            Duration   = 4,
        })
        if not State.PianoModel then
            pcall(function() Options.PlayToggle:SetValue(false) end)
            return
        end
    end

    if not State.PianoModel then
        Fluent:Notify({Title="No Piano Set",Content="Scan first or disable Auto-Detect.",Type="Error",Duration=3})
        pcall(function() Options.PlayToggle:SetValue(false) end)
        return
    end

    local song=Songs[State.CurrentSong]
    State.Playing=true

    Fluent:Notify({
        Title      = "▶  Playing",
        Content    = song.name,
        SubContent = song.bpm.." BPM · "..#song.notes.." notes · "..State.ScanLog,
        Type       = "Success",
        Duration   = 4,
    })

    State.PlayThread = task.spawn(function()
        repeat
            for _,e in ipairs(song.notes) do
                if not State.Playing then return end
                PressKey(State.PianoModel, e[1])
                task.wait(e[2]/Config.Speed)
            end
        until not Config.Loop or not State.Playing
        if State.Playing then
            State.Playing=false
            pcall(function() Options.PlayToggle:SetValue(false) end)
            Fluent:Notify({Title="Finished",Content=song.name,Type="Success",Duration=3})
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  §9  CAPTURE FLUENT'S SCREENGUI
--      Use ChildAdded — fires the instant Fluent parents its GUI,
--      so there's no timing race with task.wait snapshots.
-- ════════════════════════════════════════════════════════

local FluentGui   = nil
local guiVisible  = true

local captureConn = pgui.ChildAdded:Connect(function(child)
    if child:IsA("ScreenGui") then
        FluentGui = child
    end
end)

-- ════════════════════════════════════════════════════════
--  §10  FLUENT WINDOW
-- ════════════════════════════════════════════════════════

local Window = Fluent:CreateWindow({
    Title        = "Kanha Piano",
    SubTitle     = "Auto Player · v2.3",
    TabWidth     = isMob and 100 or 130,
    Size         = isMob
                   and UDim2.fromOffset(440, 480)
                   or  UDim2.fromOffset(560, 540),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = Enum.KeyCode.RightControl,
    Search       = false,
    Tags         = {{Text=" v2.3 ",Color=Color3.fromRGB(0,190,220)},
                    {Text=" Fixed ",Color=Color3.fromRGB(100,40,200)}},
    UserInfoTop      = true,
    UserInfoTitle    = "Auto Piano",
    UserInfoSubtitle = lp.DisplayName,
    UserInfoColor    = Color3.fromRGB(0,200,240),
    Animated         = true,
})

-- Now FluentGui should be set (ChildAdded fired synchronously)
task.defer(function() captureConn:Disconnect() end)

-- Fallback: if ChildAdded somehow missed it, search manually
if not FluentGui then
    for _,g in ipairs(pgui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Name ~= "KanhaPianoPill" then
            FluentGui = g   -- most recently added ScreenGui
        end
    end
end

local Tabs = {
    Play     = Window:AddTab({Title="Play",     Icon="music"   }),
    Songs    = Window:AddTab({Title="Songs",    Icon="disc"    }),
    Settings = Window:AddTab({Title="Settings", Icon="settings"}),
    Info     = Window:AddTab({Title="Info",     Icon="info"    }),
}

-- ════════════════════════════════════════════════════════
--  §11  TOGGLE PILL  (native ScreenGui, always on screen)
--       Positioned bottom-right so it's reachable on mobile
--       without clashing with the Roblox menu button.
-- ════════════════════════════════════════════════════════

-- Clean up any old pill from a previous inject
local oldPill = pgui:FindFirstChild("KanhaPianoPill")
if oldPill then oldPill:Destroy() end

local PillGui = Instance.new("ScreenGui")
PillGui.Name            = "KanhaPianoPill"
PillGui.ResetOnSpawn    = false
PillGui.DisplayOrder    = 9999
PillGui.IgnoreGuiInset  = false   -- respect safe area so it's not behind status bar
PillGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
PillGui.Parent          = pgui

-- Size — bigger on mobile for thumb targets
local PS = isMob and 60 or 48

-- Glow ring
local Glow = Instance.new("Frame")
Glow.Size               = UDim2.fromOffset(PS+12, PS+12)
Glow.AnchorPoint        = Vector2.new(1, 1)
Glow.Position           = UDim2.new(1, -6, 1, -6)
Glow.BackgroundColor3   = Color3.fromRGB(0,180,255)
Glow.BackgroundTransparency = 0.7
Glow.BorderSizePixel    = 0
Glow.Parent             = PillGui
local gc=Instance.new("UICorner"); gc.CornerRadius=UDim.new(1,0); gc.Parent=Glow

-- Main pill button
local Pill = Instance.new("TextButton")
Pill.Name               = "Pill"
Pill.Size               = UDim2.fromOffset(PS, PS)
Pill.AnchorPoint        = Vector2.new(1, 1)
Pill.Position           = UDim2.new(1, -12, 1, -12)
Pill.BackgroundColor3   = Color3.fromRGB(14,10,40)
Pill.Text               = "🎹"
Pill.TextSize           = isMob and 26 or 22
Pill.Font               = Enum.Font.GothamBold
Pill.TextColor3         = Color3.fromRGB(0,220,255)
Pill.AutoButtonColor    = false
Pill.BorderSizePixel    = 0
Pill.ZIndex             = 2
Pill.Parent             = PillGui
local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(1,0); pc.Parent=Pill
local ps2=Instance.new("UIStroke"); ps2.Color=Color3.fromRGB(0,180,255); ps2.Thickness=1.5; ps2.Parent=Pill

-- State label above the pill
local PillLbl = Instance.new("TextLabel")
PillLbl.Size               = UDim2.fromOffset(PS+10, 16)
PillLbl.AnchorPoint        = Vector2.new(1,1)
PillLbl.Position           = UDim2.new(1,-7,1,-12-PS-2)
PillLbl.BackgroundTransparency = 1
PillLbl.Text               = "CLOSE"
PillLbl.TextSize            = 9
PillLbl.Font               = Enum.Font.GothamBold
PillLbl.TextColor3         = Color3.fromRGB(0,180,220)
PillLbl.TextXAlignment     = Enum.TextXAlignment.Center
PillLbl.Parent             = PillGui

-- Animated glow + hue
local gt = 0
local function hsvRgb(h,s,v)
    local i=math.floor(h*6); local f=h*6-i
    local p=v*(1-s); local q=v*(1-f*s); local t2=v*(1-(1-f)*s)
    i=i%6
    if i==0 then return Color3.new(v,t2,p) elseif i==1 then return Color3.new(q,v,p)
    elseif i==2 then return Color3.new(p,v,t2) elseif i==3 then return Color3.new(p,q,v)
    elseif i==4 then return Color3.new(t2,p,v) else return Color3.new(v,p,q) end
end
RunService.RenderStepped:Connect(function(dt)
    gt=gt+dt*2
    Glow.BackgroundTransparency = 0.65+0.2*math.sin(gt)
    local hue=(gt/(2*math.pi))%1
    local c=hsvRgb(hue,0.7,1)
    Glow.BackgroundColor3=c; ps2.Color=c
end)

-- Hover / press feedback
Pill.MouseEnter:Connect(function()
    TweenService:Create(Pill,TweenInfo.new(.1),{BackgroundColor3=Color3.fromRGB(0,45,70)}):Play()
end)
Pill.MouseLeave:Connect(function()
    TweenService:Create(Pill,TweenInfo.new(.1),{BackgroundColor3=Color3.fromRGB(14,10,40)}):Play()
end)

-- Core toggle function
local function SetVisible(v)
    guiVisible=v
    -- Toggle Fluent's ScreenGui
    if FluentGui then
        FluentGui.Enabled=v
    else
        -- Last-resort: re-search
        for _,g in ipairs(pgui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name~="KanhaPianoPill" then
                g.Enabled=v
            end
        end
    end
    PillLbl.Text     = v and "CLOSE" or "OPEN"
    Pill.TextColor3  = v
        and Color3.fromRGB(0,220,255)
        or  Color3.fromRGB(90,90,140)
    ps2.Color = v and Color3.fromRGB(0,180,255) or Color3.fromRGB(60,60,100)
    -- Bounce animation
    local big = UDim2.fromOffset(PS+8,PS+8)
    local nrm = UDim2.fromOffset(PS,PS)
    TweenService:Create(Pill,TweenInfo.new(.1,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=big}):Play()
    task.delay(.12,function()
        TweenService:Create(Pill,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=nrm}):Play()
    end)
end

Pill.MouseButton1Click:Connect(function() SetVisible(not guiVisible) end)
-- Also handle touch (mobile)
Pill.TouchTap:Connect(function() SetVisible(not guiVisible) end)

-- Sync with RightControl
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.RightControl then
        SetVisible(not guiVisible)
    end
end)

-- ════════════════════════════════════════════════════════
--  §12  PLAY TAB
-- ════════════════════════════════════════════════════════

local secSel = Tabs.Play:AddSection("Song","disc")
secSel:AddDropdown("SongSelect",{
    Title="Select Song",Icon="list-music",
    Values=SongNames, Default=SongNames[1],
    Description="Song to play",
    Callback=function(v)
        for i,s in ipairs(Songs) do
            if s.name==v then State.CurrentSong=i; break end
        end
    end,
})

local secCtrl = Tabs.Play:AddSection("Controls","play-circle")
secCtrl:AddToggle("PlayToggle",{
    Title="Playing", Icon="play", Default=false,
    Description="ON = play  ·  OFF = stop",
    Callback=function(en)
        if en then DoPlay()
        elseif State.Playing then DoStop(false) end
    end,
})
secCtrl:AddButton({
    Title="↺  Restart", Icon="rotate-ccw",
    Description="Stop and restart from note 1",
    Callback=function()
        DoStop(true); task.wait(0.08)
        Options.PlayToggle:SetValue(true)
    end,
})

local secOpts = Tabs.Play:AddSection("Options","sliders-horizontal")
secOpts:AddSlider("SpeedSlider",{
    Title="Speed", Icon="gauge",
    Min=25, Max=400, Default=100, Rounding=0,
    Description="100 = normal  ·  200 = double speed",
    Callback=function(v) Config.Speed=v/100 end,
})
secOpts:AddToggle("LoopToggle",{
    Title="Loop", Icon="repeat", Default=false,
    Description="Repeat when finished",
    Callback=function(v) Config.Loop=v end,
})
secOpts:AddKeybind("PlayKeybind",{
    Title="Play / Stop Key", Icon="keyboard",
    Default="P", Mode="Toggle",
    Description="Hotkey to toggle playback",
    Callback=function()
        Options.PlayToggle:SetValue(not State.Playing)
    end,
})

-- ════════════════════════════════════════════════════════
--  §13  SONGS TAB
-- ════════════════════════════════════════════════════════

local secLib=Tabs.Songs:AddSection("Library","library")
secLib:AddParagraph({Title="15 songs",Content="Click to select · then switch to Play tab."})
secLib:AddDivider()

local function AddRow(parent,idx)
    local s=Songs[idx]
    parent:AddButton({
        Title=s.name, Icon="music-2",
        Description=s.bpm.." BPM · "..#s.notes.." notes",
        Callback=function()
            State.CurrentSong=idx
            Options.SongSelect:SetValue(s.name)
            Fluent:Notify({Title="Selected",Content=s.name,Type="Info",Duration=2})
        end,
    })
end

local groups={
    {label="Classics",  idx={1,2,7,8}         },
    {label="Game OST",  idx={4,9,10,11}        },
    {label="Pop & Misc",idx={5,6,12,13,14,15}  },
    {label="Piano Solo",idx={3}                },
}
local shown={}
for _,g in ipairs(groups) do
    local sec=Tabs.Songs:AddSection(g.label,"music")
    for _,i in ipairs(g.idx) do
        if Songs[i] and not shown[i] then shown[i]=true; AddRow(sec,i) end
    end
end
local misc=Tabs.Songs:AddSection("Others","more-horizontal")
for i=1,#Songs do if not shown[i] then AddRow(misc,i) end end

-- ════════════════════════════════════════════════════════
--  §14  SETTINGS TAB
-- ════════════════════════════════════════════════════════

local secDet=Tabs.Settings:AddSection("Piano Detection","search")
secDet:AddToggle("AutoDetectToggle",{
    Title="Auto-Detect", Icon="scan", Default=true,
    Description="Scan on Play",
    Callback=function(v) Config.AutoDetect=v end,
})
secDet:AddButton({
    Title="Scan Now", Icon="radar",
    Description="Run all 4 detection passes and show result",
    Callback=function()
        State.PianoModel=FindPiano()
        Fluent:Notify({
            Title   = State.PianoModel and "✓ Found" or "✗ Not Found",
            Content = State.ScanLog,
            Type    = State.PianoModel and "Success" or "Error",
            Duration= 5,
        })
    end,
})
secDet:AddButton({
    Title="Fire C4 Test", Icon="music",
    Description="Test-fire C4 and show which method was used",
    Callback=function()
        if not State.PianoModel then
            State.PianoModel=FindPiano()
        end
        if State.PianoModel then
            PressKey(State.PianoModel,"C4")
            Fluent:Notify({
                Title   = "Test C4",
                Content = "Method: "..State.KeyMethod,
                SubContent= "Piano: "..State.ScanLog,
                Type    = "Info",
                Duration= 4,
            })
        else
            Fluent:Notify({Title="No Piano",Content=State.ScanLog,Type="Error",Duration=4})
        end
    end,
})

local secTrans=Tabs.Settings:AddSection("Transpose","arrow-up-down")
secTrans:AddSlider("TransposeSlider",{
    Title="Semitones", Icon="move-vertical",
    Min=-12, Max=12, Default=0, Rounding=0,
    Description="±12 semitone shift",
    Callback=function(v) Config.Transpose=v end,
})

local secDev=Tabs.Settings:AddSection("Debug","terminal")
secDev:AddToggle("DebugToggle",{
    Title="Debug Mode", Icon="bug", Default=false,
    Description="Print scan and key events to output",
    Callback=function(v) Config.Debug=v end,
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
--  §15  INFO TAB
-- ════════════════════════════════════════════════════════

Tabs.Info:AddSection("About","info"):AddParagraph({
    Title="Kanha Piano v2.3",
    Content="v2.3 changes:\n"
        .."· Toggle pill bottom-right (mobile friendly)\n"
        .."· ChildAdded event for reliable Fluent GUI capture\n"
        .."· Fallback: if nil, toggles ALL ScreenGuis in PlayerGui\n"
        .."· 4-pass + 5-strategy piano detection\n"
        .."· Scan result always shown in notification\n"
        .."· TouchTap on pill for mobile",
})
Tabs.Info:AddSection("API","terminal"):AddParagraph({
    Title="_G.Piano",
    Content="_G.Piano.Play()\n_G.Piano.Stop()\n_G.Piano.SetSong(n)\n"
        .."_G.Piano.SetSpeed(x)\n_G.Piano.SetLoop(bool)\n"
        .."_G.Piano.Transpose(n)\n_G.Piano.Show()\n_G.Piano.Hide()",
})

-- ════════════════════════════════════════════════════════
--  §16  GLOBAL API
-- ════════════════════════════════════════════════════════

_G.Piano={
    Play     =function() Options.PlayToggle:SetValue(true)  end,
    Stop     =function() Options.PlayToggle:SetValue(false) end,
    SetSong  =function(n)
        n=math.clamp(n,1,#Songs); State.CurrentSong=n
        Options.SongSelect:SetValue(Songs[n].name)
    end,
    SetSpeed =function(x)
        Config.Speed=math.clamp(x,.1,10)
        Options.SpeedSlider:SetValue(math.round(Config.Speed*100))
    end,
    SetLoop  =function(v) Config.Loop=v; Options.LoopToggle:SetValue(v) end,
    Transpose=function(n)
        Config.Transpose=math.clamp(n,-12,12)
        Options.TransposeSlider:SetValue(Config.Transpose)
    end,
    Show     =function() SetVisible(true)  end,
    Hide     =function() SetVisible(false) end,
    Toggle   =function() SetVisible(not guiVisible) end,
    Scan     =function() State.PianoModel=FindPiano(); return State.ScanLog end,
    Songs=Songs, Config=Config, State=State,
}

-- ════════════════════════════════════════════════════════
--  §17  STARTUP
-- ════════════════════════════════════════════════════════

Window:SelectTab(1)

Fluent:Notify({
    Title      = "Kanha Piano v2.3 Ready",
    Content    = "🎹 pill is bottom-right corner",
    SubContent = "Tap it to open/close the GUI",
    Type       = "Success",
    Duration   = 5,
})

if SaveManager then pcall(function() SaveManager:LoadAutoloadConfig() end) end

print("╔══════════════════════════════════════╗")
print("║  Kanha Piano v2.3                    ║")
print("║  Pill = bottom-right corner          ║")
print("║  _G.Piano.Scan() → shows what found  ║")
print("║  _G.Piano.Play() / .Stop()           ║")
print("╚══════════════════════════════════════╝")
