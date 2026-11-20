--[[
╔══════════════════════════════════════════════════════════════╗
║       KANHA AUTO PIANO  ·  FLUENT MODDED  v3.1              ║
║       Toggle fix: VIM simulates RightControl key             ║
║       Engine: VirtualInputManager (MIDIow key_map)          ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════════════════
--  §1  LIBRARY LOADER
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
assert(Fluent, "[AutoPiano] Fluent failed to load.")

local SaveManager      = tryGet("https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/SaveManager.lua")
                      or tryGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
local InterfaceManager = tryGet("https://raw.githubusercontent.com/StyearX/Fluent-modded/main/Addons/InterfaceManager.lua")
                      or tryGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")

-- ════════════════════════════════════════════════════════
--  §2  SERVICES
-- ════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VIM              = game:GetService("VirtualInputManager")

local lp      = Players.LocalPlayer
local pgui    = lp:WaitForChild("PlayerGui")
local Options = Fluent.Options

-- Use gethui() if available — protects pill from game scripts
local GUIParent = (gethui and gethui()) or pgui

local isMob = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ════════════════════════════════════════════════════════
--  §3  KEY MAP  (MIDI note → Roblox KeyCode)
--      Source: MIDIow by antilua. (open source)
--      MIDI 60 = Middle C (C4)
-- ════════════════════════════════════════════════════════

local KM = {
    [21]={keycode=Enum.KeyCode.One,   ctrl=true}, [22]={keycode=Enum.KeyCode.Two,   ctrl=true},
    [23]={keycode=Enum.KeyCode.Three, ctrl=true}, [24]={keycode=Enum.KeyCode.Four,  ctrl=true},
    [25]={keycode=Enum.KeyCode.Five,  ctrl=true}, [26]={keycode=Enum.KeyCode.Six,   ctrl=true},
    [27]={keycode=Enum.KeyCode.Seven, ctrl=true}, [28]={keycode=Enum.KeyCode.Eight, ctrl=true},
    [29]={keycode=Enum.KeyCode.Nine,  ctrl=true}, [30]={keycode=Enum.KeyCode.Zero,  ctrl=true},
    [31]={keycode=Enum.KeyCode.Q,     ctrl=true}, [32]={keycode=Enum.KeyCode.W,     ctrl=true},
    [33]={keycode=Enum.KeyCode.E,     ctrl=true}, [34]={keycode=Enum.KeyCode.R,     ctrl=true},
    [35]={keycode=Enum.KeyCode.T,     ctrl=true},
    [36]={keycode=Enum.KeyCode.One,   shift=false}, [37]={keycode=Enum.KeyCode.One,   shift=true},
    [38]={keycode=Enum.KeyCode.Two,   shift=false}, [39]={keycode=Enum.KeyCode.Two,   shift=true},
    [40]={keycode=Enum.KeyCode.Three, shift=false}, [41]={keycode=Enum.KeyCode.Four,  shift=false},
    [42]={keycode=Enum.KeyCode.Four,  shift=true},  [43]={keycode=Enum.KeyCode.Five,  shift=false},
    [44]={keycode=Enum.KeyCode.Five,  shift=true},  [45]={keycode=Enum.KeyCode.Six,   shift=false},
    [46]={keycode=Enum.KeyCode.Six,   shift=true},  [47]={keycode=Enum.KeyCode.Seven, shift=false},
    [48]={keycode=Enum.KeyCode.Eight, shift=false}, [49]={keycode=Enum.KeyCode.Eight, shift=true},
    [50]={keycode=Enum.KeyCode.Nine,  shift=false}, [51]={keycode=Enum.KeyCode.Nine,  shift=true},
    [52]={keycode=Enum.KeyCode.Zero,  shift=false}, [53]={keycode=Enum.KeyCode.Q,     shift=false},
    [54]={keycode=Enum.KeyCode.Q,     shift=true},  [55]={keycode=Enum.KeyCode.W,     shift=false},
    [56]={keycode=Enum.KeyCode.W,     shift=true},  [57]={keycode=Enum.KeyCode.E,     shift=false},
    [58]={keycode=Enum.KeyCode.E,     shift=true},  [59]={keycode=Enum.KeyCode.R,     shift=false},
    [60]={keycode=Enum.KeyCode.T,     shift=false}, [61]={keycode=Enum.KeyCode.T,     shift=true},
    [62]={keycode=Enum.KeyCode.Y,     shift=false}, [63]={keycode=Enum.KeyCode.Y,     shift=true},
    [64]={keycode=Enum.KeyCode.U,     shift=false}, [65]={keycode=Enum.KeyCode.I,     shift=false},
    [66]={keycode=Enum.KeyCode.I,     shift=true},  [67]={keycode=Enum.KeyCode.O,     shift=false},
    [68]={keycode=Enum.KeyCode.O,     shift=true},  [69]={keycode=Enum.KeyCode.P,     shift=false},
    [70]={keycode=Enum.KeyCode.P,     shift=true},  [71]={keycode=Enum.KeyCode.A,     shift=false},
    [72]={keycode=Enum.KeyCode.S,     shift=false}, [73]={keycode=Enum.KeyCode.S,     shift=true},
    [74]={keycode=Enum.KeyCode.D,     shift=false}, [75]={keycode=Enum.KeyCode.D,     shift=true},
    [76]={keycode=Enum.KeyCode.F,     shift=false}, [77]={keycode=Enum.KeyCode.G,     shift=false},
    [78]={keycode=Enum.KeyCode.G,     shift=true},  [79]={keycode=Enum.KeyCode.H,     shift=false},
    [80]={keycode=Enum.KeyCode.H,     shift=true},  [81]={keycode=Enum.KeyCode.J,     shift=false},
    [82]={keycode=Enum.KeyCode.J,     shift=true},  [83]={keycode=Enum.KeyCode.K,     shift=false},
    [84]={keycode=Enum.KeyCode.L,     shift=false}, [85]={keycode=Enum.KeyCode.L,     shift=true},
    [86]={keycode=Enum.KeyCode.Z,     shift=false}, [87]={keycode=Enum.KeyCode.Z,     shift=true},
    [88]={keycode=Enum.KeyCode.X,     shift=false}, [89]={keycode=Enum.KeyCode.C,     shift=false},
    [90]={keycode=Enum.KeyCode.C,     shift=true},  [91]={keycode=Enum.KeyCode.V,     shift=false},
    [92]={keycode=Enum.KeyCode.V,     shift=true},  [93]={keycode=Enum.KeyCode.B,     shift=false},
    [94]={keycode=Enum.KeyCode.B,     shift=true},  [95]={keycode=Enum.KeyCode.N,     shift=false},
    [96]={keycode=Enum.KeyCode.M,     shift=false}, [97]={keycode=Enum.KeyCode.M,     shift=true},
    [98]={keycode=Enum.KeyCode.U,ctrl=true}, [99]={keycode=Enum.KeyCode.I,ctrl=true},
    [100]={keycode=Enum.KeyCode.O,ctrl=true},[101]={keycode=Enum.KeyCode.P,ctrl=true},
    [102]={keycode=Enum.KeyCode.A,ctrl=true},[103]={keycode=Enum.KeyCode.S,ctrl=true},
    [104]={keycode=Enum.KeyCode.D,ctrl=true},[105]={keycode=Enum.KeyCode.F,ctrl=true},
    [106]={keycode=Enum.KeyCode.G,ctrl=true},[107]={keycode=Enum.KeyCode.H,ctrl=true},
    [108]={keycode=Enum.KeyCode.J,ctrl=true},
}

-- ════════════════════════════════════════════════════════
--  §4  NOTE NAME → MIDI
-- ════════════════════════════════════════════════════════

local NS={C=0,D=2,E=4,F=5,G=7,A=9,B=11}
local NC={}
local function midi(str)
    if NC[str] then return NC[str] end
    local l,a,o=str:match("^([A-Ga-g])([b#]?)(%d+)$")
    if not l then NC[str]=nil; return nil end
    local s=(NS[l:upper()]or 0)+(a=="b" and -1 or a=="#" and 1 or 0)
    NC[str]=(tonumber(o)+1)*12+s; return NC[str]
end

-- ════════════════════════════════════════════════════════
--  §5  VIM ENGINE
-- ════════════════════════════════════════════════════════

local SH, CT = false, false
local function setMod(key, cur, want)
    if want==cur then return cur end
    VIM:SendKeyEvent(want, key, false, game); return want
end
local function ReleaseAll()
    if SH then VIM:SendKeyEvent(false,Enum.KeyCode.LeftShift,  false,game); SH=false end
    if CT then VIM:SendKeyEvent(false,Enum.KeyCode.LeftControl,false,game); CT=false end
end
local function PressNote(midiNum)
    local k=KM[midiNum]; if not k then return end
    SH=setMod(Enum.KeyCode.LeftShift,  SH, k.shift==true)
    CT=setMod(Enum.KeyCode.LeftControl,CT, k.ctrl==true)
    VIM:SendKeyEvent(true, k.keycode, false, game)
    VIM:SendKeyEvent(false,k.keycode, false, game)
end
local function PressName(name, transpose)
    local m=midi(name); if not m then return end
    PressNote(m+(transpose or 0))
end

-- ════════════════════════════════════════════════════════
--  §6  CONFIG & STATE
-- ════════════════════════════════════════════════════════

local Config={Speed=1.0,Loop=false,Transpose=0,Debug=false}
local State={Playing=false,CurrentSong=1,PlayThread=nil}

-- ════════════════════════════════════════════════════════
--  §7  SONGS  (15 tracks)
-- ════════════════════════════════════════════════════════

local Songs={
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

local SongNames={}
for _,s in ipairs(Songs) do
    table.insert(SongNames,s.name)
    for _,e in ipairs(s.notes) do e.midi=midi(e[1]) end
end

-- ════════════════════════════════════════════════════════
--  §8  PLAY / STOP
-- ════════════════════════════════════════════════════════

local function DoStop(silent)
    State.Playing=false
    if State.PlayThread then task.cancel(State.PlayThread); State.PlayThread=nil end
    ReleaseAll()
    pcall(function() Options.PlayToggle:SetValue(false) end)
    if not silent then Fluent:Notify({Title="Piano",Content="Stopped",Type="Warning",Duration=2}) end
end

local function DoPlay()
    if State.Playing then DoStop(true) end
    local song=Songs[State.CurrentSong]
    State.Playing=true
    Fluent:Notify({Title="▶  Playing",Content=song.name,SubContent=song.bpm.." BPM · "..#song.notes.." notes",Type="Success",Duration=3})
    State.PlayThread=task.spawn(function()
        repeat
            for _,e in ipairs(song.notes) do
                if not State.Playing then ReleaseAll(); return end
                PressNote((e.midi or 0)+Config.Transpose)
                if Config.Debug then print("[Piano]",e[1],"→",e.midi) end
                task.wait(e[2]/Config.Speed)
            end
        until not Config.Loop or not State.Playing
        if State.Playing then
            State.Playing=false; ReleaseAll()
            pcall(function() Options.PlayToggle:SetValue(false) end)
            Fluent:Notify({Title="Finished",Content=song.name,Type="Success",Duration=3})
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  §9  FLUENT WINDOW
-- ════════════════════════════════════════════════════════

local Window=Fluent:CreateWindow({
    Title="Kanha Piano", SubTitle="Auto Player · v3.1",
    TabWidth=isMob and 100 or 130,
    Size=isMob and UDim2.fromOffset(440,480) or UDim2.fromOffset(560,540),
    Acrylic=true, Theme="Dark",
    MinimizeKey=Enum.KeyCode.RightControl,
    Search=false,
    Tags={{Text=" v3.1 ",Color=Color3.fromRGB(0,190,220)},{Text=" VIM ",Color=Color3.fromRGB(100,40,200)}},
    UserInfoTop=true, UserInfoTitle="Auto Piano",
    UserInfoSubtitle=lp.DisplayName,
    UserInfoColor=Color3.fromRGB(0,200,240),
    Animated=true,
})

local Tabs={
    Play=Window:AddTab({Title="Play",Icon="music"}),
    Songs=Window:AddTab({Title="Songs",Icon="disc"}),
    Settings=Window:AddTab({Title="Settings",Icon="settings"}),
    Info=Window:AddTab({Title="Info",Icon="info"}),
}

-- ════════════════════════════════════════════════════════
--  §10  TOGGLE PILL
--  FIX: use VIM to simulate RightControl, which Fluent
--  already listens to as its MinimizeKey. No ScreenGui
--  reference needed — no more nil reference bugs.
-- ════════════════════════════════════════════════════════

local oldPill=pgui:FindFirstChild("KanhaPianoPill")
if oldPill then oldPill:Destroy() end

local PillGui=Instance.new("ScreenGui")
PillGui.Name="KanhaPianoPill"
PillGui.ResetOnSpawn=false
PillGui.DisplayOrder=9999
PillGui.IgnoreGuiInset=false
PillGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
PillGui.Parent=GUIParent

local PS=isMob and 62 or 50

local Glow=Instance.new("Frame")
Glow.Size=UDim2.fromOffset(PS+14,PS+14)
Glow.AnchorPoint=Vector2.new(1,1)
Glow.Position=UDim2.new(1,-4,1,-4)
Glow.BackgroundColor3=Color3.fromRGB(0,180,255)
Glow.BackgroundTransparency=0.7
Glow.BorderSizePixel=0
Glow.Parent=PillGui
local _gc=Instance.new("UICorner"); _gc.CornerRadius=UDim.new(1,0); _gc.Parent=Glow

local Pill=Instance.new("TextButton")
Pill.Name="Pill"
Pill.Size=UDim2.fromOffset(PS,PS)
Pill.AnchorPoint=Vector2.new(1,1)
Pill.Position=UDim2.new(1,-11,1,-11)
Pill.BackgroundColor3=Color3.fromRGB(14,10,40)
Pill.Text="🎹"
Pill.TextSize=isMob and 28 or 24
Pill.Font=Enum.Font.GothamBold
Pill.TextColor3=Color3.fromRGB(0,220,255)
Pill.AutoButtonColor=false
Pill.BorderSizePixel=0
Pill.ZIndex=2
Pill.Parent=PillGui
local _pc=Instance.new("UICorner"); _pc.CornerRadius=UDim.new(1,0); _pc.Parent=Pill
local _ps=Instance.new("UIStroke"); _ps.Color=Color3.fromRGB(0,180,255); _ps.Thickness=2; _ps.Parent=Pill

local PillLbl=Instance.new("TextLabel")
PillLbl.Size=UDim2.fromOffset(PS+10,16)
PillLbl.AnchorPoint=Vector2.new(1,1)
PillLbl.Position=UDim2.new(1,-6,1,-14-PS)
PillLbl.BackgroundTransparency=1
PillLbl.Text="CLOSE"
PillLbl.TextSize=10
PillLbl.Font=Enum.Font.GothamBold
PillLbl.TextColor3=Color3.fromRGB(0,180,220)
PillLbl.TextXAlignment=Enum.TextXAlignment.Center
PillLbl.Parent=PillGui

-- Animated glow
local gt=0
local function hsvC(h,s,v)
    local i=math.floor(h*6); local f=h*6-i
    local p=v*(1-s); local q=v*(1-f*s); local t2=v*(1-(1-f)*s); i=i%6
    if i==0 then return Color3.new(v,t2,p) elseif i==1 then return Color3.new(q,v,p)
    elseif i==2 then return Color3.new(p,v,t2) elseif i==3 then return Color3.new(p,q,v)
    elseif i==4 then return Color3.new(t2,p,v) else return Color3.new(v,p,q) end
end
RunService.RenderStepped:Connect(function(dt)
    gt=gt+dt*2
    Glow.BackgroundTransparency=0.65+0.2*math.sin(gt)
    local c=hsvC((gt/6.28)%1,0.7,1)
    Glow.BackgroundColor3=c; _ps.Color=c
end)

Pill.MouseEnter:Connect(function()
    TweenService:Create(Pill,TweenInfo.new(.1),{BackgroundColor3=Color3.fromRGB(0,45,70)}):Play()
end)
Pill.MouseLeave:Connect(function()
    TweenService:Create(Pill,TweenInfo.new(.1),{BackgroundColor3=Color3.fromRGB(14,10,40)}):Play()
end)

local guiOpen=true
local function pillBounce()
    local big=UDim2.fromOffset(PS+10,PS+10)
    local nrm=UDim2.fromOffset(PS,PS)
    TweenService:Create(Pill,TweenInfo.new(.1,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=big}):Play()
    task.delay(.12,function()
        TweenService:Create(Pill,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=nrm}):Play()
    end)
end

-- ══ THE FIX ══════════════════════════════════════════
-- Instead of trying to find and toggle Fluent's ScreenGui
-- (which breaks when Fluent uses gethui() as parent),
-- we simulate pressing RightControl via VIM.
-- Fluent's MinimizeKey listener handles the actual hide/show.
-- ═════════════════════════════════════════════════════
local function SimulateToggle()
    guiOpen = not guiOpen
    PillLbl.Text     = guiOpen and "CLOSE" or "OPEN"
    Pill.TextColor3  = guiOpen and Color3.fromRGB(0,220,255) or Color3.fromRGB(90,90,140)
    _ps.Color        = guiOpen and Color3.fromRGB(0,180,255) or Color3.fromRGB(60,60,100)
    pillBounce()
    -- VIM fires RightControl → Fluent's internal listener hides/shows the window
    VIM:SendKeyEvent(true,  Enum.KeyCode.RightControl, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
end

Pill.MouseButton1Click:Connect(SimulateToggle)
Pill.TouchTap:Connect(SimulateToggle)

-- Sync label when user presses RightControl directly
-- (don't simulate again, just update our label)
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightControl then
        guiOpen = not guiOpen
        PillLbl.Text    = guiOpen and "CLOSE" or "OPEN"
        Pill.TextColor3 = guiOpen and Color3.fromRGB(0,220,255) or Color3.fromRGB(90,90,140)
        pillBounce()
    end
end)

-- ════════════════════════════════════════════════════════
--  §11  PLAY TAB
-- ════════════════════════════════════════════════════════

Tabs.Play:AddSection("Song","disc"):AddDropdown("SongSelect",{
    Title="Select Song",Icon="list-music",Values=SongNames,Default=SongNames[1],
    Description="Song that will be played",
    Callback=function(v) for i,s in ipairs(Songs) do if s.name==v then State.CurrentSong=i;break end end end,
})

local sc=Tabs.Play:AddSection("Controls","play-circle")
sc:AddToggle("PlayToggle",{
    Title="Playing",Icon="play",Default=false,
    Description="ON = play  ·  OFF = stop",
    Callback=function(en) if en then DoPlay() elseif State.Playing then DoStop(false) end end,
})
sc:AddButton({Title="↺  Restart",Icon="rotate-ccw",Description="Stop and restart",
    Callback=function() DoStop(true); task.wait(0.08); Options.PlayToggle:SetValue(true) end,
})

local so=Tabs.Play:AddSection("Options","sliders-horizontal")
so:AddSlider("SpeedSlider",{Title="Speed",Icon="gauge",Min=25,Max=400,Default=100,Rounding=0,
    Description="100 = normal",Callback=function(v) Config.Speed=v/100 end,
})
so:AddToggle("LoopToggle",{Title="Loop",Icon="repeat",Default=false,
    Description="Repeat when finished",Callback=function(v) Config.Loop=v end,
})
so:AddKeybind("PlayKeybind",{Title="Play / Stop Key",Icon="keyboard",Default="P",Mode="Toggle",
    Description="Hotkey to toggle playback",
    Callback=function() Options.PlayToggle:SetValue(not State.Playing) end,
})

-- ════════════════════════════════════════════════════════
--  §12  SONGS TAB
-- ════════════════════════════════════════════════════════

local slib=Tabs.Songs:AddSection("Library","library")
slib:AddParagraph({Title="15 songs",Content="Click to select · then go to Play."})
slib:AddDivider()

local function AddRow(parent,idx)
    local s=Songs[idx]
    parent:AddButton({Title=s.name,Icon="music-2",Description=s.bpm.." BPM · "..#s.notes.." notes",
        Callback=function()
            State.CurrentSong=idx; Options.SongSelect:SetValue(s.name)
            Fluent:Notify({Title="Selected",Content=s.name,Type="Info",Duration=2})
        end,
    })
end
local groups={{label="Classics",idx={1,2,7,8}},{label="Game OST",idx={4,9,10,11}},
              {label="Pop & Misc",idx={5,6,12,13,14,15}},{label="Piano Solo",idx={3}}}
local shown={}
for _,g in ipairs(groups) do
    local s=Tabs.Songs:AddSection(g.label,"music")
    for _,i in ipairs(g.idx) do if Songs[i] and not shown[i] then shown[i]=true; AddRow(s,i) end end
end
local misc=Tabs.Songs:AddSection("Others","more-horizontal")
for i=1,#Songs do if not shown[i] then AddRow(misc,i) end end

-- ════════════════════════════════════════════════════════
--  §13  SETTINGS TAB
-- ════════════════════════════════════════════════════════

Tabs.Settings:AddSection("Transpose","arrow-up-down"):AddSlider("TransposeSlider",{
    Title="Semitones",Icon="move-vertical",Min=-12,Max=12,Default=0,Rounding=0,
    Description="±12 semitone shift",Callback=function(v) Config.Transpose=v end,
})
Tabs.Settings:AddSection("Test","music"):AddButton({
    Title="Test: Fire C4",Icon="music",
    Description="Sends C4 via VIM to verify the engine works",
    Callback=function()
        PressName("C4",Config.Transpose)
        Fluent:Notify({Title="C4 Fired",Content="Key: T (no shift) via VirtualInputManager",
            SubContent="Must be seated at the piano in-game",Type="Info",Duration=4})
    end,
})
Tabs.Settings:AddSection("Debug","bug"):AddToggle("DebugToggle",{
    Title="Debug Mode",Icon="bug",Default=false,
    Description="Print notes to output",Callback=function(v) Config.Debug=v end,
})
if InterfaceManager and SaveManager then
    SaveManager:SetLibrary(Fluent); InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    InterfaceManager:SetFolder("KanhaPiano"); SaveManager:SetFolder("KanhaPiano")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
end

-- ════════════════════════════════════════════════════════
--  §14  INFO TAB
-- ════════════════════════════════════════════════════════

Tabs.Info:AddSection("About","info"):AddParagraph({Title="Kanha Piano v3.1",
    Content="Toggle fix: pill now simulates RightControl via VIM.\n"
        .."Fluent listens to RightControl via MinimizeKey — no\n"
        .."ScreenGui reference needed. Works regardless of\n"
        .."whether Fluent uses PlayerGui or gethui().\n\n"
        .."Engine: VirtualInputManager:SendKeyEvent\n"
        .."Key map: MIDIow by antilua. (open source)\n\n"
        .."⚠  Sit at the piano before pressing Play.",
})
Tabs.Info:AddSection("API","terminal"):AddParagraph({Title="_G.Piano",
    Content="_G.Piano.Play()  /  .Stop()\n_G.Piano.SetSong(n)\n"
        .."_G.Piano.SetSpeed(x)\n_G.Piano.SetLoop(bool)\n"
        .."_G.Piano.Transpose(n)\n_G.Piano.PillToggle()",
})

-- ════════════════════════════════════════════════════════
--  §15  GLOBAL API
-- ════════════════════════════════════════════════════════

_G.Piano={
    Play       =function() Options.PlayToggle:SetValue(true)  end,
    Stop       =function() Options.PlayToggle:SetValue(false) end,
    SetSong    =function(n) n=math.clamp(n,1,#Songs); State.CurrentSong=n; Options.SongSelect:SetValue(Songs[n].name) end,
    SetSpeed   =function(x) Config.Speed=math.clamp(x,.1,10); Options.SpeedSlider:SetValue(math.round(Config.Speed*100)) end,
    SetLoop    =function(v) Config.Loop=v; Options.LoopToggle:SetValue(v) end,
    Transpose  =function(n) Config.Transpose=math.clamp(n,-12,12); Options.TransposeSlider:SetValue(Config.Transpose) end,
    PillToggle =SimulateToggle,
    Songs=Songs, Config=Config, State=State,
}

-- ════════════════════════════════════════════════════════
--  §16  START
-- ════════════════════════════════════════════════════════

Window:SelectTab(1)
Fluent:Notify({Title="Kanha Piano v3.1",Content="VIM engine · pill bottom-right",
    SubContent="Sit at the piano · RightCtrl or pill to toggle",Type="Success",Duration=5})
if SaveManager then pcall(function() SaveManager:LoadAutoloadConfig() end) end
print("╔══════════════════════════════════╗")
print("║  Kanha Piano v3.1 — Toggle Fixed ║")
print("║  Pill uses VIM → RightControl    ║")
print("║  _G.Piano.Play() / .Stop()       ║")
print("╚══════════════════════════════════╝")
