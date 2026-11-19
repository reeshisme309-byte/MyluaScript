-- ╔══════════════════════════════════════════════════════════════════════════════════╗
-- ║                                                                                  ║
-- ║   ██╗  ██╗ █████╗ ███╗   ██╗██╗  ██╗ █████╗     ██████╗ ██╗ █████╗ ███╗   ██╗  ║
-- ║   ██║ ██╔╝██╔══██╗████╗  ██║██║  ██║██╔══██╗    ██╔══██╗██║██╔══██╗████╗  ██║  ║
-- ║   █████╔╝ ███████║██╔██╗ ██║███████║███████║    ██████╔╝██║███████║██╔██╗ ██║  ║
-- ║   ██╔═██╗ ██╔══██║██║╚██╗██║██╔══██║██╔══██║    ██╔═══╝ ██║██╔══██║██║╚██╗██║  ║
-- ║   ██║  ██╗██║  ██║██║ ╚████║██║  ██║██║  ██║    ██║     ██║██║  ██║██║ ╚████║  ║
-- ║   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝  ║
-- ║                                                                                  ║
-- ║   [ CYBERPUNK EDITION ]  ·  AUTO PIANO GUI  ·  v4.2.0 MEGA                      ║
-- ║   Full-featured · Responsive · Multi-song · Visualizer · Neon UI                ║
-- ╚══════════════════════════════════════════════════════════════════════════════════╝

--[[
    ═══════════════════════════════════════════════════════════════════
    FEATURES:
    ─ Cyberpunk neon UI with animated gradients & glow layers
    ─ Animated title bar with cycling hue shift
    ─ Toggle (minimize/maximize) button with spring tween
    ─ Drag-to-move title bar
    ─ Auto-resize: scales to phone, tablet, desktop viewports
    ─ Multi-tab: PLAY · SONGS · SETTINGS · CREDITS
    ─ 15 built-in songs
    ─ Speed slider (0.25x → 4.0x)
    ─ Volume indicator
    ─ Loop toggle with animated indicator
    ─ Live note visualizer (28 animated frequency bars)
    ─ Mini 3-octave piano keyboard display
    ─ Active key glow on piano display
    ─ Song progress bar with percentage
    ─ Status console with scrolling log
    ─ Piano model auto-detection (3 fallback methods)
    ─ RemoteEvent / ClickDetector / ProximityPrompt support
    ─ Scanline texture overlay on panels
    ─ Animated corner decorations
    ─ Particle burst on play
    ─ Keyboard shortcut overlay
    ─ Per-song transpose setting
    ─ _G.Piano table for external control
    ═══════════════════════════════════════════════════════════════════
]]

-- ══════════════════════════════════════════════════════════
--  §1  SERVICES
-- ══════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")

local lp     = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════
--  §2  DESIGN TOKENS   (edit palette here)
-- ══════════════════════════════════════════════════════════

local COLOR = {
    -- backgrounds
    BG_DEEP      = Color3.fromRGB(  6,  5, 20),
    BG_PANEL     = Color3.fromRGB( 12, 10, 35),
    BG_CARD      = Color3.fromRGB( 18, 14, 50),
    BG_HEADER    = Color3.fromRGB(  8,  6, 28),
    -- accents
    CYAN         = Color3.fromRGB(  0, 229, 255),
    MAGENTA      = Color3.fromRGB(255,   0, 230),
    PURPLE       = Color3.fromRGB(155,  48, 255),
    YELLOW       = Color3.fromRGB(255, 224,   0),
    GREEN        = Color3.fromRGB( 57, 255, 120),
    RED          = Color3.fromRGB(255,  60,  80),
    ORANGE       = Color3.fromRGB(255, 140,  30),
    -- text
    TEXT_BRIGHT  = Color3.fromRGB(220, 220, 255),
    TEXT_DIM     = Color3.fromRGB(120, 110, 180),
    TEXT_ACCENT  = Color3.fromRGB(  0, 229, 255),
    -- piano keys
    WHITE_KEY    = Color3.fromRGB(230, 225, 255),
    BLACK_KEY    = Color3.fromRGB( 20,  15, 45),
    KEY_ACTIVE   = Color3.fromRGB(  0, 229, 255),
    KEY_ACTIVE2  = Color3.fromRGB(255,   0, 230),
    -- misc
    TRANSPARENT  = Color3.fromRGB(0, 0, 0),
    BORDER       = Color3.fromRGB( 70,  40, 160),
    BORDER_GLOW  = Color3.fromRGB(  0, 229, 255),
    SHADOW       = Color3.fromRGB(  0,   0,   0),
}

local FONT = {
    DISPLAY  = Enum.Font.GothamBold,
    BODY     = Enum.Font.Gotham,
    MONO     = Enum.Font.RobotoMono,
    LABEL    = Enum.Font.GothamSemibold,
}

local TWEEN_FAST   = TweenInfo.new(0.15, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out)
local TWEEN_MED    = TweenInfo.new(0.3,  Enum.EasingStyle.Quart,  Enum.EasingDirection.Out)
local TWEEN_SLOW   = TweenInfo.new(0.6,  Enum.EasingStyle.Quint,  Enum.EasingDirection.Out)
local TWEEN_SPRING = TweenInfo.new(0.5,  Enum.EasingStyle.Back,   Enum.EasingDirection.Out)
local TWEEN_BOUNCE = TweenInfo.new(0.4,  Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

-- ══════════════════════════════════════════════════════════
--  §3  CONFIGURATION
-- ══════════════════════════════════════════════════════════

local Config = {
    Speed         = 1.0,       -- playback speed multiplier
    Loop          = false,     -- loop current song
    Transpose     = 0,         -- semitone shift  (-12 → +12)
    Volume        = 1.0,       -- not directly usable in Roblox but tracked for UI
    Debug         = false,     -- verbose console output
    VisualizerOn  = true,      -- show frequency bars
    PianoDisplayOn = true,     -- show mini keyboard
    AutoDetect    = true,      -- scan workspace for piano on play
    GuiScale      = 1.0,       -- set dynamically by resize system
}

-- State
local State = {
    Playing      = false,
    Paused       = false,
    CurrentSong  = 1,
    NoteIndex    = 1,
    GuiOpen      = true,
    ActiveTab    = "PLAY",
    ActiveKeys   = {},         -- currently lit piano keys
    BarHeights   = {},         -- visualizer bar target heights
    LogLines     = {},         -- status console entries
    PianoModel   = nil,        -- found piano reference
    PlayThread   = nil,        -- coroutine handle
    HueOffset    = 0,          -- animated title hue
    PulseAlpha   = 0,          -- play button pulse
    PulseDelta   = 1,
    TitleColors  = {},         -- per-character colors for title
    Progress     = 0,          -- 0–1 playback fraction
}

-- ══════════════════════════════════════════════════════════
--  §4  NOTE MAPPINGS
-- ══════════════════════════════════════════════════════════

local ALL_NOTES = {
    "C3","Db3","D3","Eb3","E3","F3","Gb3","G3","Ab3","A3","Bb3","B3",
    "C4","Db4","D4","Eb4","E4","F4","Gb4","G4","Ab4","A4","Bb4","B4",
    "C5","Db5","D5","Eb5","E5","F5","Gb5","G5","Ab5","A5","Bb5","B5",
    "C6",
}

-- Index of each note (for transpose math)
local NoteIndex = {}
for i, n in ipairs(ALL_NOTES) do NoteIndex[n] = i end

local NoteMap = {}
for _, n in ipairs(ALL_NOTES) do
    NoteMap[n] = "KeyboardNote_" .. n
end

-- Chromatic → semitone offset within octave
local SEMITONE = {C=0,["Db"]=1,D=2,["Eb"]=3,E=4,F=5,["Gb"]=6,G=7,["Ab"]=8,A=9,["Bb"]=10,B=11}

-- Which notes are "black keys" on the mini piano display
local IS_BLACK = {Db=true, Eb=true, Gb=true, Ab=true, Bb=true}
local function noteIsBlack(note)
    local name = note:match("^([A-Zb]+)%d")
    return IS_BLACK[name] or false
end

local function transposeNote(note, semitones)
    local idx = NoteIndex[note]
    if not idx then return note end
    local newIdx = idx + semitones
    newIdx = math.clamp(newIdx, 1, #ALL_NOTES)
    return ALL_NOTES[newIdx]
end

-- ══════════════════════════════════════════════════════════
--  §5  SONG DATABASE  (15 songs)
-- ══════════════════════════════════════════════════════════

--[[
    Song format:
    {
        name  = "Song Name",
        bpm   = 120,          (informational)
        notes = {{"NoteString", delay_seconds}, ...}
    }
]]

local Songs = {}

-- ── 1. Twinkle Twinkle Little Star ──────────────────────
Songs[1] = {
    name  = "Twinkle Twinkle",
    bpm   = 110,
    notes = {
        {"C4",0.3},{"C4",0.3},{"G4",0.3},{"G4",0.3},
        {"A4",0.3},{"A4",0.3},{"G4",0.6},
        {"F4",0.3},{"F4",0.3},{"E4",0.3},{"E4",0.3},
        {"D4",0.3},{"D4",0.3},{"C4",0.6},
        {"G4",0.3},{"G4",0.3},{"F4",0.3},{"F4",0.3},
        {"E4",0.3},{"E4",0.3},{"D4",0.6},
        {"G4",0.3},{"G4",0.3},{"F4",0.3},{"F4",0.3},
        {"E4",0.3},{"E4",0.3},{"D4",0.6},
        {"C4",0.3},{"C4",0.3},{"G4",0.3},{"G4",0.3},
        {"A4",0.3},{"A4",0.3},{"G4",0.6},
        {"F4",0.3},{"F4",0.3},{"E4",0.3},{"E4",0.3},
        {"D4",0.3},{"D4",0.3},{"C4",0.6},
    }
}

-- ── 2. Happy Birthday ───────────────────────────────────
Songs[2] = {
    name  = "Happy Birthday",
    bpm   = 100,
    notes = {
        {"C4",0.3},{"C4",0.15},{"D4",0.45},{"C4",0.45},{"F4",0.45},{"E4",0.9},
        {"C4",0.3},{"C4",0.15},{"D4",0.45},{"C4",0.45},{"G4",0.45},{"F4",0.9},
        {"C4",0.3},{"C4",0.15},{"C5",0.45},{"A4",0.45},{"F4",0.45},{"E4",0.45},{"D4",0.9},
        {"Bb4",0.3},{"Bb4",0.15},{"A4",0.45},{"F4",0.45},{"G4",0.45},{"F4",0.9},
    }
}

-- ── 3. Für Elise (main theme) ───────────────────────────
Songs[3] = {
    name  = "Für Elise",
    bpm   = 138,
    notes = {
        {"E5",0.2},{"Eb5",0.2},{"E5",0.2},{"Eb5",0.2},{"E5",0.2},
        {"B4",0.2},{"D5",0.2},{"C5",0.2},{"A4",0.4},
        {"C4",0.2},{"E4",0.2},{"A4",0.2},{"B4",0.4},
        {"E4",0.2},{"Ab4",0.2},{"B4",0.2},{"C5",0.4},
        {"E4",0.2},{"E5",0.2},{"Eb5",0.2},{"E5",0.2},{"Eb5",0.2},{"E5",0.2},
        {"B4",0.2},{"D5",0.2},{"C5",0.2},{"A4",0.4},
        {"C4",0.2},{"E4",0.2},{"A4",0.2},{"B4",0.4},
        {"E4",0.2},{"C5",0.2},{"B4",0.2},{"A4",0.6},
    }
}

-- ── 4. Megalovania (opening riff) ───────────────────────
Songs[4] = {
    name  = "Megalovania",
    bpm   = 200,
    notes = {
        {"D4",0.15},{"D4",0.15},{"D5",0.3},{"A4",0.3},
        {"Ab4",0.3},{"G4",0.3},{"F4",0.3},
        {"D4",0.15},{"F4",0.15},{"G4",0.3},
        {"C4",0.15},{"C4",0.15},{"D5",0.3},{"A4",0.3},
        {"Ab4",0.3},{"G4",0.3},{"F4",0.3},
        {"D4",0.15},{"F4",0.15},{"G4",0.3},
        {"B3",0.15},{"B3",0.15},{"D5",0.3},{"A4",0.3},
        {"Ab4",0.3},{"G4",0.3},{"F4",0.3},
        {"D4",0.15},{"F4",0.15},{"G4",0.3},
        {"Bb3",0.15},{"Bb3",0.15},{"D5",0.3},{"A4",0.3},
        {"Ab4",0.3},{"G4",0.3},{"F4",0.3},
        {"D4",0.15},{"F4",0.15},{"G4",0.3},
    }
}

-- ── 5. Among Us Theme ───────────────────────────────────
Songs[5] = {
    name  = "Among Us Theme",
    bpm   = 120,
    notes = {
        {"F4",0.3},{"Ab4",0.3},{"Bb4",0.3},{"B4",0.3},
        {"Bb4",0.3},{"Ab4",0.6},{"F4",0.3},
        {"Ab4",0.3},{"Ab4",0.3},{"G4",0.3},{"Ab4",0.3},
        {"Eb4",0.9},
        {"F4",0.3},{"Ab4",0.3},{"Bb4",0.3},{"B4",0.3},
        {"Bb4",0.3},{"Ab4",0.3},{"F4",0.3},{"Ab4",0.3},
        {"Ab4",0.3},{"G4",0.3},{"Ab4",0.3},{"Eb4",0.6},
    }
}

-- ── 6. Jingle Bells ─────────────────────────────────────
Songs[6] = {
    name  = "Jingle Bells",
    bpm   = 140,
    notes = {
        {"E4",0.25},{"E4",0.25},{"E4",0.5},
        {"E4",0.25},{"E4",0.25},{"E4",0.5},
        {"E4",0.25},{"G4",0.25},{"C4",0.25},{"D4",0.25},{"E4",1.0},
        {"F4",0.25},{"F4",0.25},{"F4",0.25},{"F4",0.25},
        {"F4",0.25},{"E4",0.25},{"E4",0.25},{"E4",0.25},
        {"E4",0.25},{"D4",0.25},{"D4",0.25},{"E4",0.25},{"D4",0.5},{"G4",0.5},
        {"E4",0.25},{"E4",0.25},{"E4",0.5},
        {"E4",0.25},{"E4",0.25},{"E4",0.5},
        {"E4",0.25},{"G4",0.25},{"C4",0.25},{"D4",0.25},{"E4",1.0},
        {"F4",0.25},{"F4",0.25},{"F4",0.25},{"F4",0.25},
        {"F4",0.25},{"E4",0.25},{"E4",0.25},{"E4",0.25},
        {"G4",0.25},{"G4",0.25},{"F4",0.25},{"D4",0.25},{"C4",1.0},
    }
}

-- ── 7. Mary Had A Little Lamb ────────────────────────────
Songs[7] = {
    name  = "Mary Had A Little Lamb",
    bpm   = 110,
    notes = {
        {"E4",0.3},{"D4",0.3},{"C4",0.3},{"D4",0.3},
        {"E4",0.3},{"E4",0.3},{"E4",0.6},
        {"D4",0.3},{"D4",0.3},{"D4",0.6},
        {"E4",0.3},{"G4",0.3},{"G4",0.6},
        {"E4",0.3},{"D4",0.3},{"C4",0.3},{"D4",0.3},
        {"E4",0.3},{"E4",0.3},{"E4",0.3},{"E4",0.3},
        {"D4",0.3},{"D4",0.3},{"E4",0.3},{"D4",0.3},{"C4",0.9},
    }
}

-- ── 8. Ode To Joy ────────────────────────────────────────
Songs[8] = {
    name  = "Ode To Joy",
    bpm   = 120,
    notes = {
        {"E4",0.3},{"E4",0.3},{"F4",0.3},{"G4",0.3},
        {"G4",0.3},{"F4",0.3},{"E4",0.3},{"D4",0.3},
        {"C4",0.3},{"C4",0.3},{"D4",0.3},{"E4",0.3},
        {"E4",0.45},{"D4",0.15},{"D4",0.6},
        {"E4",0.3},{"E4",0.3},{"F4",0.3},{"G4",0.3},
        {"G4",0.3},{"F4",0.3},{"E4",0.3},{"D4",0.3},
        {"C4",0.3},{"C4",0.3},{"D4",0.3},{"E4",0.3},
        {"D4",0.45},{"C4",0.15},{"C4",0.6},
        {"D4",0.3},{"D4",0.3},{"E4",0.3},{"C4",0.3},
        {"D4",0.15},{"E4",0.15},{"F4",0.3},{"E4",0.3},{"C4",0.3},
        {"D4",0.15},{"E4",0.15},{"F4",0.3},{"E4",0.3},{"D4",0.3},
        {"C4",0.3},{"D4",0.3},{"G3",0.6},
    }
}

-- ── 9. Super Mario Bros Theme ────────────────────────────
Songs[9] = {
    name  = "Super Mario Bros",
    bpm   = 200,
    notes = {
        {"E5",0.15},{"E5",0.3},{"E5",0.3},
        {"C5",0.15},{"E5",0.3},{"G5",0.6},
        {"G4",0.6},
        {"C5",0.45},{"G4",0.3},{"E4",0.45},
        {"A4",0.3},{"B4",0.3},{"Bb4",0.15},{"A4",0.3},
        {"G4",0.2},{"E5",0.2},{"G5",0.2},
        {"A5",0.3},{"F5",0.15},{"G5",0.3},
        {"E5",0.3},{"C5",0.15},{"D5",0.15},{"B4",0.45},
        {"C5",0.45},{"G4",0.3},{"E4",0.45},
        {"A4",0.3},{"B4",0.3},{"Bb4",0.15},{"A4",0.3},
        {"G4",0.2},{"E5",0.2},{"G5",0.2},
        {"A5",0.3},{"F5",0.15},{"G5",0.3},
        {"E5",0.3},{"C5",0.15},{"D5",0.15},{"B4",0.45},
    }
}

-- ── 10. Pirates of the Caribbean ────────────────────────
Songs[10] = {
    name  = "Pirates of the Caribbean",
    bpm   = 140,
    notes = {
        {"A4",0.2},{"B4",0.2},
        {"C5",0.3},{"C5",0.15},{"C5",0.15},{"D5",0.15},{"E5",0.15},
        {"E5",0.3},{"E5",0.15},{"E5",0.15},{"F5",0.15},{"E5",0.15},
        {"D5",0.3},{"D5",0.15},{"D5",0.15},{"E5",0.15},{"F5",0.15},
        {"E5",0.6},{"A4",0.2},{"B4",0.2},
        {"C5",0.3},{"C5",0.15},{"C5",0.15},{"D5",0.15},{"E5",0.15},
        {"E5",0.3},{"E5",0.15},{"E5",0.15},{"F5",0.15},{"E5",0.15},
        {"D5",0.3},{"D5",0.15},{"D5",0.15},{"G5",0.15},{"F5",0.15},
        {"E5",0.9},
    }
}

-- ── 11. Tetris (Korobeiniki) ─────────────────────────────
Songs[11] = {
    name  = "Tetris",
    bpm   = 160,
    notes = {
        {"E5",0.3},{"B4",0.15},{"C5",0.15},{"D5",0.3},{"C5",0.15},{"B4",0.15},
        {"A4",0.3},{"A4",0.15},{"C5",0.15},{"E5",0.3},{"D5",0.15},{"C5",0.15},
        {"B4",0.45},{"C5",0.15},{"D5",0.3},{"E5",0.3},
        {"C5",0.3},{"A4",0.3},{"A4",0.6},
        {"D5",0.45},{"F5",0.15},{"A5",0.3},{"G5",0.15},{"F5",0.15},
        {"E5",0.45},{"C5",0.15},{"E5",0.3},{"D5",0.15},{"C5",0.15},
        {"B4",0.3},{"B4",0.15},{"C5",0.15},{"D5",0.3},{"E5",0.3},
        {"C5",0.3},{"A4",0.3},{"A4",0.6},
    }
}

-- ── 12. Despacito Intro ──────────────────────────────────
Songs[12] = {
    name  = "Despacito Intro",
    bpm   = 176,
    notes = {
        {"B4",0.2},{"Ab4",0.2},{"E4",0.4},{"E4",0.2},{"Gb4",0.2},
        {"Ab4",0.2},{"B4",0.2},{"Ab4",0.2},{"E4",0.6},
        {"B4",0.2},{"Ab4",0.2},{"E4",0.4},{"E4",0.2},{"Gb4",0.2},
        {"Ab4",0.2},{"B4",0.2},{"Ab4",0.2},{"Gb4",0.4},{"E4",0.2},
        {"Gb4",0.2},{"Ab4",0.2},{"B4",0.2},{"Ab4",0.2},{"E4",0.4},
        {"Gb4",0.2},{"Ab4",0.2},{"B4",0.2},{"Ab4",0.2},{"E4",0.4},
        {"Gb4",0.6},
    }
}

-- ── 13. Coffin Dance (Astronomia) ───────────────────────
Songs[13] = {
    name  = "Coffin Dance",
    bpm   = 126,
    notes = {
        {"G4",0.25},{"Ab4",0.25},{"G4",0.25},{"Eb4",0.75},
        {"G4",0.25},{"Ab4",0.25},{"G4",0.25},{"Eb4",0.75},
        {"G4",0.25},{"F4",0.25},{"Eb4",0.25},{"F4",0.25},{"G4",0.5},{"Ab4",0.5},
        {"G4",0.25},{"F4",0.25},{"Eb4",0.25},{"F4",0.25},{"G4",1.0},
        {"G4",0.25},{"Ab4",0.25},{"G4",0.25},{"Eb4",0.75},
        {"G4",0.25},{"Ab4",0.25},{"G4",0.25},{"Eb4",0.75},
        {"Bb4",0.5},{"Ab4",0.5},{"G4",0.5},{"F4",0.5},
        {"Eb4",1.0},
    }
}

-- ── 14. Never Gonna Give You Up (chorus) ────────────────
Songs[14] = {
    name  = "Never Gonna Give You Up",
    bpm   = 113,
    notes = {
        {"A4",0.27},{"B4",0.27},{"D5",0.27},{"B4",0.27},
        {"Gb5",0.54},{"Gb5",0.27},{"E5",0.81},
        {"A4",0.27},{"B4",0.27},{"D5",0.27},{"B4",0.27},
        {"E5",0.54},{"E5",0.27},{"D5",0.54},{"C5",0.27},{"B4",0.27},
        {"A4",0.27},{"B4",0.27},{"D5",0.27},{"B4",0.27},
        {"D5",0.54},{"E5",0.27},{"C5",0.54},{"B4",0.27},{"A4",0.27},
        {"A4",0.54},{"D5",0.54},{"D5",0.27},{"C5",0.27},{"B4",0.54},
        {"A4",0.54},{"A4",0.27},{"D5",0.54},{"D5",0.27},{"E5",0.27},
        {"C5",0.54},{"B4",0.27},{"A4",0.9},
    }
}

-- ── 15. All Star (Smash Mouth) ───────────────────────────
Songs[15] = {
    name  = "All Star",
    bpm   = 104,
    notes = {
        {"G4",0.29},{"G4",0.29},{"G4",0.29},
        {"G4",0.29},{"A4",0.29},{"G4",0.29},{"F4",0.29},
        {"G4",0.58},{"F4",0.29},{"F4",0.29},
        {"F4",0.29},{"F4",0.29},{"G4",0.29},{"F4",0.29},{"E4",0.87},
        {"G4",0.29},{"G4",0.29},{"G4",0.29},
        {"G4",0.29},{"A4",0.29},{"G4",0.29},{"F4",0.29},
        {"G4",0.58},{"F4",0.29},{"F4",0.29},
        {"F4",0.29},{"G4",0.29},{"A4",0.29},{"G4",0.58},
        {"E4",0.29},{"F4",0.29},{"G4",0.29},{"F4",0.29},{"E4",0.87},
    }
}

-- ══════════════════════════════════════════════════════════
--  §6  UTILITY FUNCTIONS
-- ══════════════════════════════════════════════════════════

local function Tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

local function RGBfromHSV(h, s, v)
    -- h: 0-1, s: 0-1, v: 0-1
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r,g,b = v,t,p
    elseif i == 1 then r,g,b = q,v,p
    elseif i == 2 then r,g,b = p,v,t
    elseif i == 3 then r,g,b = p,q,v
    elseif i == 4 then r,g,b = t,p,v
    else r,g,b = v,p,q end
    return Color3.new(r, g, b)
end

local function MakeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function MakeStroke(parent, color, thickness, trans)
    local s = Instance.new("UIStroke")
    s.Color      = color or COLOR.BORDER
    s.Thickness  = thickness or 1
    s.Transparency = trans or 0
    s.Parent = parent
    return s
end

local function MakeGradient(parent, rotation, colorSeq)
    local g = Instance.new("UIGradient")
    g.Rotation = rotation or 0
    g.Color    = colorSeq
    g.Parent   = parent
    return g
end

local function MakeLabel(parent, text, size, font, color, props)
    local l = Instance.new("TextLabel")
    l.Text               = text
    l.TextSize           = size or 14
    l.Font               = font or FONT.BODY
    l.TextColor3         = color or COLOR.TEXT_BRIGHT
    l.BackgroundTransparency = 1
    l.BorderSizePixel    = 0
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.TextTruncate       = Enum.TextTruncate.AtEnd
    if props then
        for k, v in pairs(props) do l[k] = v end
    end
    l.Parent = parent
    return l
end

local function MakeButton(parent, text, size, font, textColor, bgColor, props)
    local b = Instance.new("TextButton")
    b.Text               = text
    b.TextSize           = size or 14
    b.Font               = font or FONT.LABEL
    b.TextColor3         = textColor or COLOR.TEXT_BRIGHT
    b.BackgroundColor3   = bgColor or COLOR.BG_CARD
    b.BorderSizePixel    = 0
    b.AutoButtonColor    = false
    if props then
        for k, v in pairs(props) do b[k] = v end
    end
    b.Parent = parent
    return b
end

local function MakeFrame(parent, bgColor, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bgColor or COLOR.BG_PANEL
    f.BorderSizePixel  = 0
    if props then
        for k, v in pairs(props) do f[k] = v end
    end
    f.Parent = parent
    return f
end

local function MakeScanlines(parent, alpha)
    -- Fake scanline texture using a gradient
    local sl = Instance.new("Frame")
    sl.Size = UDim2.fromScale(1, 1)
    sl.BackgroundTransparency = 1
    sl.ZIndex = (parent.ZIndex or 1) + 1
    sl.Name   = "Scanlines"
    sl.Parent = parent
    -- Repeating gradient trick via small frames
    for i = 0, 20 do
        local line = Instance.new("Frame")
        line.Size               = UDim2.new(1, 0, 0, 1)
        line.Position           = UDim2.new(0, 0, i / 21, 0)
        line.BackgroundColor3   = Color3.new(0, 0, 0)
        line.BackgroundTransparency = alpha or 0.85
        line.BorderSizePixel    = 0
        line.Parent             = sl
    end
    return sl
end

-- Console log helper
local function Log(msg, color)
    table.insert(State.LogLines, {text = "[" .. os.clock():format and os.clock() or tostring(math.floor(os.clock())) .. "] " .. msg, color = color or COLOR.TEXT_DIM})
    if #State.LogLines > 60 then table.remove(State.LogLines, 1) end
    if Config.Debug then print("[AutoPiano]", msg) end
end

-- ══════════════════════════════════════════════════════════
--  §7  RESIZE / SCALE SYSTEM
-- ══════════════════════════════════════════════════════════

local function GetViewport()
    return camera.ViewportSize
end

local function ComputeScale()
    local vp = GetViewport()
    local minDim = math.min(vp.X, vp.Y)
    if minDim < 400 then
        return 0.68      -- phone portrait
    elseif minDim < 600 then
        return 0.82      -- phone landscape / small tablet
    elseif minDim < 900 then
        return 0.92      -- tablet
    else
        return 1.0       -- desktop / large screen
    end
end

local function BaseSize()
    -- Base GUI width & height before scale
    return Vector2.new(520, 420)
end

local function ScaledSize()
    local s   = ComputeScale()
    local b   = BaseSize()
    return Vector2.new(math.round(b.X * s), math.round(b.Y * s))
end

-- ══════════════════════════════════════════════════════════
--  §8  GUI CONSTRUCTION
-- ══════════════════════════════════════════════════════════

-- Destroy previous instance if re-injecting
if lp:FindFirstChild("PlayerGui") then
    local existing = lp.PlayerGui:FindFirstChild("AutoPianoGUI")
    if existing then existing:Destroy() end
end

local ScreenGui   = Instance.new("ScreenGui")
ScreenGui.Name    = "AutoPianoGUI"
ScreenGui.ResetOnSpawn     = false
ScreenGui.IgnoreGuiInset   = true
ScreenGui.DisplayOrder     = 999
ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent           = lp.PlayerGui

-- ─────────────────────────────────────────────────────────
--   TOGGLE PILL  (always visible, opens/closes main GUI)
-- ─────────────────────────────────────────────────────────

local TogglePill = Instance.new("TextButton")
TogglePill.Name                 = "TogglePill"
TogglePill.Size                 = UDim2.new(0, 46, 0, 46)
TogglePill.Position             = UDim2.new(0, 14, 0.5, -23)
TogglePill.BackgroundColor3     = COLOR.BG_HEADER
TogglePill.Text                 = "🎹"
TogglePill.TextSize             = 22
TogglePill.Font                 = FONT.DISPLAY
TogglePill.TextColor3           = COLOR.CYAN
TogglePill.AutoButtonColor      = false
TogglePill.BorderSizePixel      = 0
TogglePill.ZIndex               = 20
TogglePill.Parent               = ScreenGui
MakeCorner(TogglePill, 14)
MakeStroke(TogglePill, COLOR.CYAN, 1.5, 0.3)

-- Glow ring behind toggle pill
local ToggleGlow = Instance.new("Frame")
ToggleGlow.Size               = UDim2.new(0, 56, 0, 56)
ToggleGlow.Position           = UDim2.new(0, 9, 0.5, -28)
ToggleGlow.BackgroundColor3   = COLOR.CYAN
ToggleGlow.BackgroundTransparency = 0.85
ToggleGlow.BorderSizePixel    = 0
ToggleGlow.ZIndex             = 19
ToggleGlow.Parent             = ScreenGui
MakeCorner(ToggleGlow, 20)

-- ─────────────────────────────────────────────────────────
--   MAIN FRAME
-- ─────────────────────────────────────────────────────────

local sz     = ScaledSize()
local vpSize = GetViewport()
local MainX  = math.round((vpSize.X - sz.X) / 2)
local MainY  = math.round((vpSize.Y - sz.Y) / 2)

local Main = Instance.new("Frame")
Main.Name              = "Main"
Main.Size              = UDim2.new(0, sz.X, 0, sz.Y)
Main.Position          = UDim2.new(0, MainX, 0, MainY)
Main.BackgroundColor3  = COLOR.BG_DEEP
Main.BorderSizePixel   = 0
Main.ClipsDescendants  = false
Main.ZIndex            = 10
Main.Parent            = ScreenGui
MakeCorner(Main, 14)
MakeStroke(Main, COLOR.BORDER, 1.5, 0)

-- Background gradient
MakeGradient(Main, 135, ColorSequence.new({
    ColorSequenceKeypoint.new(0,   COLOR.BG_DEEP),
    ColorSequenceKeypoint.new(0.5, COLOR.BG_PANEL),
    ColorSequenceKeypoint.new(1,   COLOR.BG_DEEP),
}))

-- Shadow frame behind main
local Shadow = Instance.new("Frame")
Shadow.Name              = "Shadow"
Shadow.Size              = UDim2.new(0, sz.X + 20, 0, sz.Y + 20)
Shadow.Position          = UDim2.new(0, MainX - 10, 0, MainY + 8)
Shadow.BackgroundColor3  = Color3.new(0, 0, 0)
Shadow.BackgroundTransparency = 0.5
Shadow.BorderSizePixel   = 0
Shadow.ZIndex            = 9
Shadow.Parent            = ScreenGui
MakeCorner(Shadow, 18)

-- Outer glow ring
local OuterGlow = Instance.new("Frame")
OuterGlow.Name              = "OuterGlow"
OuterGlow.Size              = UDim2.new(0, sz.X + 6, 0, sz.Y + 6)
OuterGlow.Position          = UDim2.new(0, MainX - 3, 0, MainY - 3)
OuterGlow.BackgroundColor3  = COLOR.PURPLE
OuterGlow.BackgroundTransparency = 0.7
OuterGlow.BorderSizePixel   = 0
OuterGlow.ZIndex            = 9
OuterGlow.Parent            = ScreenGui
MakeCorner(OuterGlow, 17)

-- ─────────────────────────────────────────────────────────
--   TITLE BAR
-- ─────────────────────────────────────────────────────────

local TitleBar = Instance.new("Frame")
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = COLOR.BG_HEADER
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 11
TitleBar.Parent           = Main
-- Top corners only
local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 14)
TitleCorner.Parent       = TitleBar

-- Extend bottom of TitleBar downward to cover bottom corners
local TitleExtend = Instance.new("Frame")
TitleExtend.Size             = UDim2.new(1, 0, 0, 14)
TitleExtend.Position         = UDim2.new(0, 0, 1, -14)
TitleExtend.BackgroundColor3 = COLOR.BG_HEADER
TitleExtend.BorderSizePixel  = 0
TitleExtend.ZIndex           = 11
TitleExtend.Parent           = TitleBar

-- Title gradient overlay
MakeGradient(TitleBar, 0, ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(20, 10, 60)),
    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(40, 10, 90)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(20, 10, 60)),
}))

-- Scanline texture on title bar
MakeScanlines(TitleBar, 0.9)

-- Title bottom separator glow line
local TitleSep = Instance.new("Frame")
TitleSep.Size             = UDim2.new(1, 0, 0, 2)
TitleSep.Position         = UDim2.new(0, 0, 1, -2)
TitleSep.BackgroundColor3 = COLOR.CYAN
TitleSep.BackgroundTransparency = 0.3
TitleSep.BorderSizePixel  = 0
TitleSep.ZIndex           = 12
TitleSep.Parent           = TitleBar
MakeGradient(TitleSep, 0, ColorSequence.new({
    ColorSequenceKeypoint.new(0,   COLOR.TRANSPARENT),
    ColorSequenceKeypoint.new(0.3, COLOR.CYAN),
    ColorSequenceKeypoint.new(0.7, COLOR.MAGENTA),
    ColorSequenceKeypoint.new(1,   COLOR.TRANSPARENT),
}))

-- Piano icon in title
local TitleIcon = MakeLabel(TitleBar, "♪", 22, FONT.DISPLAY, COLOR.CYAN, {
    Size = UDim2.new(0, 30, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 13,
})

-- Title text
local TitleText = MakeLabel(TitleBar, "KANHA PIANO", 15, FONT.DISPLAY, COLOR.CYAN, {
    Size = UDim2.new(0, 160, 1, 0),
    Position = UDim2.new(0, 44, 0, 0),
    ZIndex = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 0.5,
    TextStrokeColor3 = COLOR.PURPLE,
})

-- Subtitle / status ticker
local TitleSub = MakeLabel(TitleBar, "CYBERPUNK EDITION  v4.2", 10, FONT.MONO, COLOR.TEXT_DIM, {
    Size = UDim2.new(0, 180, 0, 14),
    Position = UDim2.new(0, 44, 0.55, 0),
    ZIndex = 13,
})

-- Active song indicator on title
local TitleSong = MakeLabel(TitleBar, "▶ " .. Songs[1].name, 11, FONT.MONO, COLOR.YELLOW, {
    Size = UDim2.new(0, 160, 0, 14),
    Position = UDim2.new(1, -328, 0.55, 0),
    ZIndex = 13,
    TextXAlignment = Enum.TextXAlignment.Right,
})

-- Close button
local CloseBtn = MakeButton(TitleBar, "✕", 14, FONT.DISPLAY, COLOR.TEXT_DIM, COLOR.TRANSPARENT, {
    Size     = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -38, 0.5, -16),
    BackgroundTransparency = 1,
    ZIndex   = 14,
})
MakeCorner(CloseBtn, 8)

-- Minimize button
local MinBtn = MakeButton(TitleBar, "—", 14, FONT.DISPLAY, COLOR.TEXT_DIM, COLOR.TRANSPARENT, {
    Size     = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -74, 0.5, -16),
    BackgroundTransparency = 1,
    ZIndex   = 14,
})
MakeCorner(MinBtn, 8)

-- Hover effects on title buttons
CloseBtn.MouseEnter:Connect(function()
    Tween(CloseBtn, TWEEN_FAST, {TextColor3 = COLOR.RED})
end)
CloseBtn.MouseLeave:Connect(function()
    Tween(CloseBtn, TWEEN_FAST, {TextColor3 = COLOR.TEXT_DIM})
end)
MinBtn.MouseEnter:Connect(function()
    Tween(MinBtn, TWEEN_FAST, {TextColor3 = COLOR.YELLOW})
end)
MinBtn.MouseLeave:Connect(function()
    Tween(MinBtn, TWEEN_FAST, {TextColor3 = COLOR.TEXT_DIM})
end)

-- ─────────────────────────────────────────────────────────
--   DRAG SYSTEM
-- ─────────────────────────────────────────────────────────

local dragging = false
local dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = Main.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        -- Sync shadow & glow
        Shadow.Position = UDim2.new(0, Main.Position.X.Offset - 10, 0, Main.Position.Y.Offset + 8)
        OuterGlow.Position = UDim2.new(0, Main.Position.X.Offset - 3, 0, Main.Position.Y.Offset - 3)
    end
end)

-- ─────────────────────────────────────────────────────────
--   TAB BAR
-- ─────────────────────────────────────────────────────────

local TabBar = Instance.new("Frame")
TabBar.Name             = "TabBar"
TabBar.Size             = UDim2.new(1, 0, 0, 36)
TabBar.Position         = UDim2.new(0, 0, 0, 44)
TabBar.BackgroundColor3 = COLOR.BG_HEADER
TabBar.BorderSizePixel  = 0
TabBar.ZIndex           = 11
TabBar.Parent           = Main

-- Tab separator bottom line
local TabSep = Instance.new("Frame")
TabSep.Size             = UDim2.new(1, 0, 0, 1)
TabSep.Position         = UDim2.new(0, 0, 1, -1)
TabSep.BackgroundColor3 = COLOR.BORDER
TabSep.BackgroundTransparency = 0.5
TabSep.BorderSizePixel  = 0
TabSep.ZIndex           = 12
TabSep.Parent           = TabBar

local TAB_NAMES = {"PLAY", "SONGS", "SETTINGS", "INFO"}
local TAB_ICONS = {"▶", "♬", "⚙", "ℹ"}
local TabButtons = {}
local TabPages   = {}

local tabW = 1 / #TAB_NAMES
for i, tabName in ipairs(TAB_NAMES) do
    local tb = MakeButton(TabBar, TAB_ICONS[i] .. " " .. tabName, 11,
        FONT.LABEL,
        i == 1 and COLOR.CYAN or COLOR.TEXT_DIM,
        COLOR.TRANSPARENT, {
            Size     = UDim2.new(tabW, 0, 1, 0),
            Position = UDim2.new((i-1) * tabW, 0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex   = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
        }
    )
    -- Active indicator bar
    local indicator = Instance.new("Frame")
    indicator.Name             = "Indicator"
    indicator.Size             = UDim2.new(1, -16, 0, 2)
    indicator.Position         = UDim2.new(0, 8, 1, -2)
    indicator.BackgroundColor3 = COLOR.CYAN
    indicator.BackgroundTransparency = i == 1 and 0 or 1
    indicator.BorderSizePixel  = 0
    indicator.ZIndex           = 13
    indicator.Parent           = tb
    MakeCorner(indicator, 2)

    TabButtons[tabName] = {btn = tb, ind = indicator}
    tb.MouseButton1Click:Connect(function()
        -- switch tab
        for _, tn in ipairs(TAB_NAMES) do
            local info = TabButtons[tn]
            Tween(info.btn, TWEEN_FAST, {TextColor3 = tn == tabName and COLOR.CYAN or COLOR.TEXT_DIM})
            Tween(info.ind, TWEEN_FAST, {BackgroundTransparency = tn == tabName and 0 or 1})
            if TabPages[tn] then
                TabPages[tn].Visible = (tn == tabName)
            end
        end
        State.ActiveTab = tabName
    end)
end

-- ─────────────────────────────────────────────────────────
--   PAGE CONTAINER
-- ─────────────────────────────────────────────────────────

local ContentArea = Instance.new("Frame")
ContentArea.Name             = "ContentArea"
ContentArea.Size             = UDim2.new(1, 0, 1, -80)
ContentArea.Position         = UDim2.new(0, 0, 0, 80)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel  = 0
ContentArea.ClipsDescendants = true
ContentArea.ZIndex           = 11
ContentArea.Parent           = Main

-- ════════════════════════════════════════════
--  PAGE 1: PLAY
-- ════════════════════════════════════════════

local PlayPage = MakeFrame(ContentArea, COLOR.TRANSPARENT, {
    Size     = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex   = 12,
})
TabPages["PLAY"] = PlayPage

-- ── PLAY BUTTON ─────────────────────────────
local PlayBtnOuter = Instance.new("Frame")
PlayBtnOuter.Size             = UDim2.new(0, 72, 0, 72)
PlayBtnOuter.Position         = UDim2.new(0.5, -36, 0, 10)
PlayBtnOuter.BackgroundColor3 = COLOR.CYAN
PlayBtnOuter.BackgroundTransparency = 0.7
PlayBtnOuter.BorderSizePixel  = 0
PlayBtnOuter.ZIndex           = 12
PlayBtnOuter.Parent           = PlayPage
MakeCorner(PlayBtnOuter, 36)

local PlayBtn = MakeButton(PlayBtnOuter, "▶", 28, FONT.DISPLAY, COLOR.CYAN, COLOR.BG_CARD, {
    Size     = UDim2.new(0, 60, 0, 60),
    Position = UDim2.new(0, 6, 0, 6),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Center,
})
MakeCorner(PlayBtn, 30)
MakeStroke(PlayBtn, COLOR.CYAN, 1.5, 0.2)

-- Stop button
local StopBtn = MakeButton(PlayPage, "■", 20, FONT.DISPLAY, COLOR.RED, COLOR.BG_CARD, {
    Size     = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0.5, 46, 0, 24),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Center,
})
MakeCorner(StopBtn, 8)
MakeStroke(StopBtn, COLOR.RED, 1, 0.5)

-- Restart button
local RestartBtn = MakeButton(PlayPage, "↺", 20, FONT.DISPLAY, COLOR.YELLOW, COLOR.BG_CARD, {
    Size     = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0.5, -90, 0, 24),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Center,
})
MakeCorner(RestartBtn, 8)
MakeStroke(RestartBtn, COLOR.YELLOW, 1, 0.5)

-- ── PROGRESS BAR ────────────────────────────
local ProgressBg = MakeFrame(PlayPage, COLOR.BG_CARD, {
    Size     = UDim2.new(1, -24, 0, 8),
    Position = UDim2.new(0, 12, 0, 92),
    ZIndex   = 12,
})
MakeCorner(ProgressBg, 4)

local ProgressFill = MakeFrame(ProgressBg, COLOR.CYAN, {
    Size     = UDim2.new(0, 0, 1, 0),
    ZIndex   = 13,
})
MakeCorner(ProgressFill, 4)
MakeGradient(ProgressFill, 0, ColorSequence.new({
    ColorSequenceKeypoint.new(0,   COLOR.CYAN),
    ColorSequenceKeypoint.new(1,   COLOR.MAGENTA),
}))

local ProgressLabel = MakeLabel(PlayPage, "0%  |  --:--", 10, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(1, -24, 0, 14),
    Position = UDim2.new(0, 12, 0, 103),
    ZIndex   = 12,
    TextXAlignment = Enum.TextXAlignment.Center,
})

-- ── VISUALIZER BARS ─────────────────────────
local VisualizerFrame = MakeFrame(PlayPage, COLOR.BG_CARD, {
    Size     = UDim2.new(1, -24, 0, 70),
    Position = UDim2.new(0, 12, 0, 118),
    ZIndex   = 12,
})
MakeCorner(VisualizerFrame, 8)
MakeStroke(VisualizerFrame, COLOR.BORDER, 1, 0.5)

local VizLabel = MakeLabel(VisualizerFrame, "SPECTRUM", 9, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(0, 80, 0, 12),
    Position = UDim2.new(0, 6, 0, 2),
    ZIndex   = 13,
})

local BAR_COUNT = 28
local VizBars   = {}
for i = 1, BAR_COUNT do
    local barW  = (1 / BAR_COUNT)
    local hue   = (i - 1) / BAR_COUNT
    local color = RGBfromHSV(hue * 0.7 + 0.5, 1, 1)  -- cyan→magenta range
    local bar = Instance.new("Frame")
    bar.Name                = "Bar" .. i
    bar.Size                = UDim2.new(barW - 0.004, 0, 0, 4)   -- starts tiny
    bar.AnchorPoint         = Vector2.new(0, 1)
    bar.Position            = UDim2.new((i-1) * barW + 0.002, 0, 1, -4)
    bar.BackgroundColor3    = color
    bar.BackgroundTransparency = 0.1
    bar.BorderSizePixel     = 0
    bar.ZIndex              = 14
    bar.Parent              = VisualizerFrame
    MakeCorner(bar, 2)
    VizBars[i] = {frame = bar, color = color, target = 0, current = 0}
    State.BarHeights[i] = 0
end

-- ── MINI PIANO DISPLAY ──────────────────────
local PianoDisplay = MakeFrame(PlayPage, COLOR.BG_CARD, {
    Size     = UDim2.new(1, -24, 0, 50),
    Position = UDim2.new(0, 12, 0, 196),
    ZIndex   = 12,
})
MakeCorner(PianoDisplay, 8)
MakeStroke(PianoDisplay, COLOR.BORDER, 1, 0.5)

local PianoLabel = MakeLabel(PianoDisplay, "KEYBOARD", 9, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(0, 80, 0, 12),
    Position = UDim2.new(0, 6, 0, 2),
    ZIndex   = 13,
})

-- Build white keys + black keys for 2 octaves (C4–B5) on display
local DISPLAY_OCTAVES = {"C4","D4","E4","F4","G4","A4","B4",
                         "C5","D5","E5","F5","G5","A5","B5"}
local BLACK_POSITIONS = {Db4=1, Eb4=2, Gb4=4, Ab4=5, Bb4=6,
                         Db5=8, Eb5=9, Gb5=11,Ab5=12,Bb5=13}
local DISPLAY_BLACKS  = {"Db4","Eb4","Gb4","Ab4","Bb4","Db5","Eb5","Gb5","Ab5","Bb5"}

local WhiteKeyFrames  = {}
local BlackKeyFrames  = {}
local wkCount = #DISPLAY_OCTAVES
local wkW     = 1 / wkCount
for i, note in ipairs(DISPLAY_OCTAVES) do
    local wk = Instance.new("Frame")
    wk.Name                = "WK_" .. note
    wk.Size                = UDim2.new(wkW - 0.003, 0, 0, 30)
    wk.Position            = UDim2.new((i-1) * wkW + 0.001, 0, 0.3, 0)
    wk.BackgroundColor3    = COLOR.WHITE_KEY
    wk.BorderSizePixel     = 0
    wk.ZIndex              = 13
    wk.Parent              = PianoDisplay
    MakeCorner(wk, 3)
    WhiteKeyFrames[note] = wk
end
-- Draw black keys on top
for note, wkIdx in pairs(BLACK_POSITIONS) do
    local bk = Instance.new("Frame")
    bk.Name                = "BK_" .. note
    bk.Size                = UDim2.new(wkW * 0.65, 0, 0, 20)
    bk.Position            = UDim2.new((wkIdx - 0.3) * wkW + 0.001, 0, 0.3, 0)
    bk.BackgroundColor3    = COLOR.BLACK_KEY
    bk.BorderSizePixel     = 0
    bk.ZIndex              = 14
    bk.Parent              = PianoDisplay
    MakeCorner(bk, 2)
    BlackKeyFrames[note] = bk
end

-- ── LOOP / SPEED CONTROLS ───────────────────
local CtrlRow = MakeFrame(PlayPage, COLOR.TRANSPARENT, {
    Size     = UDim2.new(1, -24, 0, 30),
    Position = UDim2.new(0, 12, 0, 252),
    BackgroundTransparency = 1,
    ZIndex   = 12,
})

-- Loop toggle
local LoopBg = MakeFrame(CtrlRow, COLOR.BG_CARD, {
    Size     = UDim2.new(0, 90, 1, 0),
    ZIndex   = 12,
})
MakeCorner(LoopBg, 6)
MakeStroke(LoopBg, COLOR.BORDER, 1, 0.5)

local LoopLabel = MakeLabel(LoopBg, "LOOP", 10, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(0, 44, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local LoopToggle = MakeButton(LoopBg, "OFF", 10, FONT.LABEL, COLOR.RED, COLOR.BG_DEEP, {
    Size     = UDim2.new(0, 36, 0, 20),
    Position = UDim2.new(1, -40, 0.5, -10),
    ZIndex   = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})
MakeCorner(LoopToggle, 4)
MakeStroke(LoopToggle, COLOR.RED, 1, 0)

-- Speed label + value
local SpeedBg = MakeFrame(CtrlRow, COLOR.BG_CARD, {
    Size     = UDim2.new(0, 130, 1, 0),
    Position = UDim2.new(0, 96, 0, 0),
    ZIndex   = 12,
})
MakeCorner(SpeedBg, 6)
MakeStroke(SpeedBg, COLOR.BORDER, 1, 0.5)

local SpeedLabel = MakeLabel(SpeedBg, "SPEED", 10, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(0, 50, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    ZIndex   = 13,
})

local SpeedVal = MakeLabel(SpeedBg, "1.00×", 10, FONT.MONO, COLOR.CYAN, {
    Size     = UDim2.new(0, 44, 1, 0),
    Position = UDim2.new(1, -48, 0, 0),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Right,
})

local SpeedDown = MakeButton(SpeedBg, "◂", 11, FONT.DISPLAY, COLOR.CYAN, COLOR.TRANSPARENT, {
    Size     = UDim2.new(0, 20, 1, 0),
    Position = UDim2.new(0, 54, 0, 0),
    BackgroundTransparency = 1,
    ZIndex   = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})
local SpeedUp = MakeButton(SpeedBg, "▸", 11, FONT.DISPLAY, COLOR.CYAN, COLOR.TRANSPARENT, {
    Size     = UDim2.new(0, 20, 1, 0),
    Position = UDim2.new(0, 76, 0, 0),
    BackgroundTransparency = 1,
    ZIndex   = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})

-- Current note display
local NoteDisplay = MakeFrame(CtrlRow, COLOR.BG_CARD, {
    Size     = UDim2.new(0, 80, 1, 0),
    Position = UDim2.new(0, 232, 0, 0),
    ZIndex   = 12,
})
MakeCorner(NoteDisplay, 6)
MakeStroke(NoteDisplay, COLOR.BORDER, 1, 0.5)

local NoteNowLabel = MakeLabel(NoteDisplay, "NOTE", 9, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    ZIndex   = 13,
})
local NoteNowVal = MakeLabel(NoteDisplay, "--", 11, FONT.MONO, COLOR.YELLOW, {
    Size     = UDim2.new(0, 36, 1, 0),
    Position = UDim2.new(1, -38, 0, 0),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Center,
})

-- ── STATUS LOG ──────────────────────────────
local StatusBg = MakeFrame(PlayPage, COLOR.BG_CARD, {
    Size     = UDim2.new(1, -24, 0, 48),
    Position = UDim2.new(0, 12, 0, 288),
    ZIndex   = 12,
})
MakeCorner(StatusBg, 6)
MakeStroke(StatusBg, COLOR.BORDER, 1, 0.5)
MakeScanlines(StatusBg, 0.92)

local StatusText = MakeLabel(StatusBg, "[ READY ] · PIANO AUTO PLAYER INITIALIZED · INJECT SUCCESS", 9, FONT.MONO, COLOR.GREEN, {
    Size     = UDim2.new(1, -8, 0.5, 0),
    Position = UDim2.new(0, 4, 0, 2),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClipsDescendants = false,
})
local StatusText2 = MakeLabel(StatusBg, "[ WAITING ] · SELECT A SONG AND PRESS PLAY", 9, FONT.MONO, COLOR.TEXT_DIM, {
    Size     = UDim2.new(1, -8, 0.5, 0),
    Position = UDim2.new(0, 4, 0.5, 2),
    ZIndex   = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
})

-- Corner decorations (animated)
local function AddCornerDeco(parent, corner)
    -- corner: "TL", "TR", "BL", "BR"
    local posTbl = {
        TL = UDim2.new(0, 4,  0, 4),
        TR = UDim2.new(1,-16, 0, 4),
        BL = UDim2.new(0, 4,  1,-16),
        BR = UDim2.new(1,-16, 1,-16),
    }
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(0, 12, 0, 12)
    d.Position         = posTbl[corner]
    d.BackgroundColor3 = COLOR.CYAN
    d.BackgroundTransparency = 0.3
    d.BorderSizePixel  = 0
    d.ZIndex           = (parent.ZIndex or 11) + 1
    d.Parent           = parent
    MakeCorner(d, 2)
    return d
end

local mainCorners = {
    AddCornerDeco(Main, "TL"),
    AddCornerDeco(Main, "TR"),
    AddCornerDeco(Main, "BL"),
    AddCornerDeco(Main, "BR"),
}

-- ════════════════════════════════════════════
--  PAGE 2: SONGS
-- ════════════════════════════════════════════

local SongsPage = MakeFrame(ContentArea, COLOR.TRANSPARENT, {
    Size     = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible  = false,
    ZIndex   = 12,
})
TabPages["SONGS"] = SongsPage

local SongsScroll = Instance.new("ScrollingFrame")
SongsScroll.Name                     = "SongsScroll"
SongsScroll.Size                     = UDim2.new(1, -24, 1, -20)
SongsScroll.Position                 = UDim2.new(0, 12, 0, 10)
SongsScroll.BackgroundTransparency   = 1
SongsScroll.BorderSizePixel          = 0
SongsScroll.ScrollBarThickness       = 4
SongsScroll.ScrollBarImageColor3     = COLOR.PURPLE
SongsScroll.ScrollingDirection       = Enum.ScrollingDirection.Y
SongsScroll.CanvasSize               = UDim2.new(0, 0, 0, #Songs * 48 + 10)
SongsScroll.ZIndex                   = 12
SongsScroll.Parent                   = SongsPage

local SongsList = {}
for i, song in ipairs(Songs) do
    local row = MakeFrame(SongsScroll, COLOR.BG_CARD, {
        Size     = UDim2.new(1, -8, 0, 40),
        Position = UDim2.new(0, 4, 0, (i-1)*46 + 4),
        ZIndex   = 13,
    })
    MakeCorner(row, 8)
    MakeStroke(row, i == State.CurrentSong and COLOR.CYAN or COLOR.BORDER, 1, i == State.CurrentSong and 0 or 0.6)

    -- Row number
    MakeLabel(row, string.format("%02d", i), 10, FONT.MONO, COLOR.TEXT_DIM, {
        Size     = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        ZIndex   = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    -- Song name
    MakeLabel(row, song.name, 13, FONT.LABEL, i == State.CurrentSong and COLOR.CYAN or COLOR.TEXT_BRIGHT, {
        Size     = UDim2.new(0, 180, 1, 0),
        Position = UDim2.new(0, 36, 0, 0),
        ZIndex   = 14,
    })
    -- BPM tag
    MakeLabel(row, song.bpm .. " BPM", 9, FONT.MONO, COLOR.TEXT_DIM, {
        Size     = UDim2.new(0, 60, 1, 0),
        Position = UDim2.new(0, 220, 0, 0),
        ZIndex   = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    -- Note count
    MakeLabel(row, #song.notes .. " NOTES", 9, FONT.MONO, COLOR.TEXT_DIM, {
        Size     = UDim2.new(0, 70, 1, 0),
        Position = UDim2.new(0, 285, 0, 0),
        ZIndex   = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    -- Select button
    local selBtn = MakeButton(row, i == State.CurrentSong and "✓ SELECTED" or "SELECT", 9,
        FONT.LABEL,
        i == State.CurrentSong and COLOR.BG_DEEP or COLOR.CYAN,
        i == State.CurrentSong and COLOR.CYAN or COLOR.BG_DEEP, {
            Size     = UDim2.new(0, 80, 0, 24),
            Position = UDim2.new(1, -88, 0.5, -12),
            ZIndex   = 14,
            TextXAlignment = Enum.TextXAlignment.Center,
    })
    MakeCorner(selBtn, 5)
    MakeStroke(selBtn, COLOR.CYAN, 1, 0.3)

    SongsList[i] = {row = row, btn = selBtn}

    local idx = i
    selBtn.MouseButton1Click:Connect(function()
        -- Deselect previous
        local prev = State.CurrentSong
        if SongsList[prev] then
            Tween(SongsList[prev].row, TWEEN_FAST, {BackgroundColor3 = COLOR.BG_CARD})
            local prevStroke = SongsList[prev].row:FindFirstChildOfClass("UIStroke")
            if prevStroke then prevStroke.Color = COLOR.BORDER prevStroke.Transparency = 0.6 end
            SongsList[prev].btn.Text            = "SELECT"
            SongsList[prev].btn.TextColor3      = COLOR.CYAN
            SongsList[prev].btn.BackgroundColor3 = COLOR.BG_DEEP
            -- Name label
            local prevName = SongsList[prev].row:GetChildren()
            for _, c in ipairs(prevName) do
                if c:IsA("TextLabel") and c.TextSize == 13 then c.TextColor3 = COLOR.TEXT_BRIGHT end
            end
        end
        State.CurrentSong = idx
        -- Select current
        Tween(row, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(18, 25, 60)})
        local stroke = row:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = COLOR.CYAN stroke.Transparency = 0 end
        selBtn.Text             = "✓ SELECTED"
        selBtn.TextColor3       = COLOR.BG_DEEP
        selBtn.BackgroundColor3 = COLOR.CYAN
        for _, c in ipairs(row:GetChildren()) do
            if c:IsA("TextLabel") and c.TextSize == 13 then c.TextColor3 = COLOR.CYAN end
        end
        TitleSong.Text = "▶ " .. Songs[idx].name
        StatusText.Text  = "[ SONG ] · LOADED: " .. Songs[idx].name:upper()
        StatusText2.Text = "[ READY ] · PRESS PLAY TO START"
        Log("Song selected: " .. Songs[idx].name)
    end)
end

-- ════════════════════════════════════════════
--  PAGE 3: SETTINGS
-- ════════════════════════════════════════════

local SettingsPage = MakeFrame(ContentArea, COLOR.TRANSPARENT, {
    Size     = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible  = false,
    ZIndex   = 12,
})
TabPages["SETTINGS"] = SettingsPage

local function SettingRow(parent, yOff, label, sublabel)
    local row = MakeFrame(parent, COLOR.BG_CARD, {
        Size     = UDim2.new(1, -24, 0, 44),
        Position = UDim2.new(0, 12, 0, yOff),
        ZIndex   = 13,
    })
    MakeCorner(row, 8)
    MakeStroke(row, COLOR.BORDER, 1, 0.6)
    MakeLabel(row, label, 12, FONT.LABEL, COLOR.TEXT_BRIGHT, {
        Size     = UDim2.new(0.6, 0, 0.5, 0),
        Position = UDim2.new(0, 10, 0, 2),
        ZIndex   = 14,
    })
    MakeLabel(row, sublabel or "", 9, FONT.MONO, COLOR.TEXT_DIM, {
        Size     = UDim2.new(0.6, 0, 0.5, 0),
        Position = UDim2.new(0, 10, 0.5, -2),
        ZIndex   = 14,
    })
    return row
end

local sRow1 = SettingRow(SettingsPage, 8, "Auto-Detect Piano", "Scan workspace on play")
local sRow2 = SettingRow(SettingsPage, 58, "Visualizer", "Animated frequency display")
local sRow3 = SettingRow(SettingsPage, 108, "Piano Keyboard", "Mini keyboard display")
local sRow4 = SettingRow(SettingsPage, 158, "Debug Mode", "Print notes to console")
local sRow5 = SettingRow(SettingsPage, 208, "Transpose", "Semitone shift (±12)")

local function MakeSettingToggle(row, initVal, onColor, offColor)
    local bg = MakeFrame(row, initVal and onColor or offColor, {
        Size     = UDim2.new(0, 46, 0, 24),
        Position = UDim2.new(1, -54, 0.5, -12),
        ZIndex   = 14,
    })
    MakeCorner(bg, 12)
    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0, 20, 0, 20)
    pill.Position         = UDim2.new(initVal and 1 or 0, initVal and -22 or 2, 0, 2)
    pill.BackgroundColor3 = Color3.new(1,1,1)
    pill.BorderSizePixel  = 0
    pill.ZIndex           = 15
    pill.Parent           = bg
    MakeCorner(pill, 10)
    local state = {val = initVal}
    bg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            state.val = not state.val
            Tween(bg,   TWEEN_MED, {BackgroundColor3 = state.val and onColor or offColor})
            Tween(pill, TWEEN_MED, {Position = state.val and UDim2.new(1,0,-22,2) or UDim2.new(0,2,0,2)})
            -- Actually UDim2 doesn't work that simply, fix:
            Tween(pill, TWEEN_MED, {Position = state.val and UDim2.new(0,24,0,2) or UDim2.new(0,2,0,2)})
        end
    end)
    return state, bg
end

local sToggle1, sBg1 = MakeSettingToggle(sRow1, Config.AutoDetect,   COLOR.GREEN, COLOR.BG_DEEP)
local sToggle2, sBg2 = MakeSettingToggle(sRow2, Config.VisualizerOn, COLOR.CYAN,  COLOR.BG_DEEP)
local sToggle3, sBg3 = MakeSettingToggle(sRow3, Config.PianoDisplayOn, COLOR.PURPLE, COLOR.BG_DEEP)
local sToggle4, sBg4 = MakeSettingToggle(sRow4, Config.Debug,        COLOR.ORANGE, COLOR.BG_DEEP)

-- Link toggles to config
RunService.Heartbeat:Connect(function()
    Config.AutoDetect      = sToggle1.val
    Config.VisualizerOn    = sToggle2.val
    Config.PianoDisplayOn  = sToggle3.val
    Config.Debug           = sToggle4.val
    VisualizerFrame.Visible  = Config.VisualizerOn
    PianoDisplay.Visible     = Config.PianoDisplayOn
end)

-- Transpose row
local TransposeVal = MakeLabel(sRow5, "0", 13, FONT.MONO, COLOR.YELLOW, {
    Size     = UDim2.new(0, 30, 1, 0),
    Position = UDim2.new(0.5, 0, 0, 0),
    ZIndex   = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})
local TDown = MakeButton(sRow5, "−", 14, FONT.DISPLAY, COLOR.CYAN, COLOR.BG_DEEP, {
    Size     = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -88, 0.5, -14),
    ZIndex   = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})
MakeCorner(TDown, 6)
local TUp = MakeButton(sRow5, "+", 14, FONT.DISPLAY, COLOR.CYAN, COLOR.BG_DEEP, {
    Size     = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -48, 0.5, -14),
    ZIndex   = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})
MakeCorner(TUp, 6)

TDown.MouseButton1Click:Connect(function()
    Config.Transpose = math.max(-12, Config.Transpose - 1)
    TransposeVal.Text = tostring(Config.Transpose)
    TransposeVal.TextColor3 = Config.Transpose < 0 and COLOR.RED or Config.Transpose > 0 and COLOR.GREEN or COLOR.YELLOW
end)
TUp.MouseButton1Click:Connect(function()
    Config.Transpose = math.min(12, Config.Transpose + 1)
    TransposeVal.Text = tostring(Config.Transpose)
    TransposeVal.TextColor3 = Config.Transpose < 0 and COLOR.RED or Config.Transpose > 0 and COLOR.GREEN or COLOR.YELLOW
end)

-- ════════════════════════════════════════════
--  PAGE 4: INFO / CREDITS
-- ════════════════════════════════════════════

local InfoPage = MakeFrame(ContentArea, COLOR.TRANSPARENT, {
    Size     = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible  = false,
    ZIndex   = 12,
})
TabPages["INFO"] = InfoPage

local INFO_LINES = {
    {" ♪  KANHA PIANO  ·  CYBERPUNK EDITION", COLOR.CYAN,    15, FONT.DISPLAY},
    {"   Version 4.2.0 Mega  ·  Auto Piano GUI",  COLOR.TEXT_DIM, 10, FONT.MONO},
    {"", COLOR.TRANSPARENT, 8, FONT.MONO},
    {" ► 15 built-in songs from multiple genres",  COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Animated 28-bar spectrum visualizer",     COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Mini 2-octave keyboard display",          COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Auto piano detection (3 methods)",        COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Speed control  0.25×  →  4.0×",          COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Transpose  ±12 semitones",                COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Loop mode  ·  Live status console",       COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {" ► Responsive  (phone/tablet/desktop)",      COLOR.TEXT_BRIGHT, 11, FONT.BODY},
    {"", COLOR.TRANSPARENT, 8, FONT.MONO},
    {" CONSOLE COMMANDS", COLOR.MAGENTA, 11, FONT.LABEL},
    {"   _G.Piano.Play()       — start",           COLOR.TEXT_DIM, 10, FONT.MONO},
    {"   _G.Piano.Stop()       — stop",            COLOR.TEXT_DIM, 10, FONT.MONO},
    {"   _G.Piano.SetSong(n)   — select song",     COLOR.TEXT_DIM, 10, FONT.MONO},
    {"   _G.Piano.SetSpeed(x)  — set speed",       COLOR.TEXT_DIM, 10, FONT.MONO},
    {"   _G.Piano.Toggle()     — open/close GUI",  COLOR.TEXT_DIM, 10, FONT.MONO},
    {"", COLOR.TRANSPARENT, 8, FONT.MONO},
    {" PIANO COMPATIBILITY", COLOR.YELLOW, 11, FONT.LABEL},
    {"   RemoteEvent · ClickDetector · ProxPrompt", COLOR.TEXT_DIM, 10, FONT.MONO},
    {"   Works with: Piano Keyboard, Virtual Piano", COLOR.TEXT_DIM, 10, FONT.MONO},
    {"   Musical Keyboard, and most variants",      COLOR.TEXT_DIM, 10, FONT.MONO},
}

local infoScroll = Instance.new("ScrollingFrame")
infoScroll.Size                   = UDim2.new(1, -24, 1, -20)
infoScroll.Position               = UDim2.new(0, 12, 0, 10)
infoScroll.BackgroundTransparency = 1
infoScroll.BorderSizePixel        = 0
infoScroll.ScrollBarThickness     = 4
infoScroll.ScrollBarImageColor3   = COLOR.PURPLE
infoScroll.ScrollingDirection     = Enum.ScrollingDirection.Y
infoScroll.CanvasSize             = UDim2.new(0, 0, 0, #INFO_LINES * 20 + 20)
infoScroll.ZIndex                 = 12
infoScroll.Parent                 = InfoPage

for i, line in ipairs(INFO_LINES) do
    MakeLabel(infoScroll, line[1], line[3], line[4], line[2], {
        Size     = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, (i-1)*20),
        ZIndex   = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

-- ══════════════════════════════════════════════════════════
--  §9  PIANO DETECTION ENGINE
-- ══════════════════════════════════════════════════════════

local function FindPiano()
    -- Pass 1: search by name
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local n = obj.Name:lower()
            if n:find("piano") or n:find("keyboard") or n:find("keys") then
                return obj
            end
        end
    end
    -- Pass 2: look for a child named "PlayNote" anywhere
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("note") or n:find("key") or n:find("play") then
                return obj.Parent
            end
        end
    end
    -- Pass 3: look for ClickDetectors named like piano keys
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
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
    local final = Config.Transpose ~= 0 and transposeNote(note, Config.Transpose) or note

    -- Method 1: RemoteEvent
    local remote =
        piano:FindFirstChild("PlayNote",   true) or
        piano:FindFirstChild("NotePressed",true) or
        piano:FindFirstChild("KeyPressed", true) or
        piano:FindFirstChild("PianoKey",   true) or
        piano:FindFirstChild("Note",       true)

    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(final)
        return
    end

    -- Method 2: ClickDetector on key part
    local keyName = NoteMap[final]
    if keyName then
        local part = piano:FindFirstChild(keyName, true)
        if part then
            local cd = part:FindFirstChildOfClass("ClickDetector")
            if cd then
                pcall(fireclickdetector, cd)
                return
            end
            local pp = part:FindFirstChildOfClass("ProximityPrompt")
            if pp then
                pcall(fireproximityprompt, pp)
                return
            end
        end
    end

    -- Method 3: scan all remotes and try variations
    for _, re in ipairs(piano:GetDescendants()) do
        if re:IsA("RemoteEvent") then
            pcall(function() re:FireServer(final) end)
            return
        end
    end

    if Config.Debug then warn("[AutoPiano] No handler: " .. final) end
end

-- ══════════════════════════════════════════════════════════
--  §10  PLAYBACK ENGINE
-- ══════════════════════════════════════════════════════════

local function LightKey(note)
    -- Piano display highlight
    local wkf = WhiteKeyFrames[note]
    local bkf = BlackKeyFrames[note]
    local target = bkf or wkf
    if target then
        target.BackgroundColor3 = COLOR.KEY_ACTIVE
        State.ActiveKeys[note]  = true
        task.delay(0.18, function()
            if State.ActiveKeys[note] then
                local orig = noteIsBlack(note) and COLOR.BLACK_KEY or COLOR.WHITE_KEY
                target.BackgroundColor3 = orig
                State.ActiveKeys[note] = nil
            end
        end)
    end
    -- Kick visualizer bars
    local idx = NoteIndex[note]
    if idx then
        local barSlot = math.round(((idx - 1) / #ALL_NOTES) * BAR_COUNT) + 1
        barSlot = math.clamp(barSlot, 1, BAR_COUNT)
        for offset = -2, 2 do
            local b = barSlot + offset
            if b >= 1 and b <= BAR_COUNT then
                local h = math.max(0.3, 1 - math.abs(offset) * 0.25) * (0.6 + math.random() * 0.4)
                VizBars[b].target = h
            end
        end
    end
end

local function UpdateStatus(line1, line2, c1, c2)
    StatusText.Text  = line1 or StatusText.Text
    StatusText2.Text = line2 or StatusText2.Text
    if c1 then StatusText.TextColor3  = c1 end
    if c2 then StatusText2.TextColor3 = c2 end
end

local function StopPlayback()
    State.Playing = false
    State.Paused  = false
    if State.PlayThread then
        task.cancel(State.PlayThread)
        State.PlayThread = nil
    end
    -- Reset all key highlights
    for n, _ in pairs(State.ActiveKeys) do
        local wk = WhiteKeyFrames[n]
        local bk = BlackKeyFrames[n]
        if wk then wk.BackgroundColor3 = COLOR.WHITE_KEY end
        if bk then bk.BackgroundColor3 = COLOR.BLACK_KEY end
    end
    State.ActiveKeys = {}
    State.Progress   = 0
    ProgressFill.Size = UDim2.new(0, 0, 1, 0)
    ProgressLabel.Text = "0%  |  STOPPED"
    PlayBtn.Text = "▶"
    PlayBtn.TextColor3 = COLOR.CYAN
    PlayBtn.BackgroundColor3 = COLOR.BG_CARD
    NoteNowVal.Text = "--"
    UpdateStatus(
        "[ STOPPED ] · PLAYBACK HALTED",
        "[ IDLE ] · SELECT A SONG AND PRESS PLAY",
        COLOR.RED, COLOR.TEXT_DIM
    )
    Log("Playback stopped")
end

local function StartPlayback()
    if State.Playing then StopPlayback() return end

    -- Auto-detect piano
    if Config.AutoDetect then
        State.PianoModel = FindPiano()
        if not State.PianoModel then
            UpdateStatus(
                "[ ERROR ] · NO PIANO FOUND IN WORKSPACE",
                "[ HINT ] · STAND NEAR A PIANO AND TRY AGAIN",
                COLOR.RED, COLOR.ORANGE
            )
            Log("No piano found!", COLOR.RED)
            return
        end
        Log("Piano found: " .. State.PianoModel.Name)
    end

    local song = Songs[State.CurrentSong]
    if not song then return end

    State.Playing   = true
    State.NoteIndex = 1
    State.Progress  = 0
    TitleSong.Text  = "▶ " .. song.name

    PlayBtn.Text             = "❚❚"
    PlayBtn.TextColor3       = COLOR.YELLOW
    PlayBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 10)

    UpdateStatus(
        "[ PLAYING ] · " .. song.name:upper(),
        "[ PIANO ] · " .. (State.PianoModel and State.PianoModel.Name or "CUSTOM"),
        COLOR.GREEN, COLOR.TEXT_DIM
    )
    Log("Started: " .. song.name)

    local totalNotes = #song.notes

    State.PlayThread = task.spawn(function()
        repeat
            for i, entry in ipairs(song.notes) do
                if not State.Playing then return end
                local note  = entry[1]
                local delay = entry[2] / Config.Speed

                State.NoteIndex = i
                State.Progress  = i / totalNotes

                -- Fire the key
                PressKey(State.PianoModel, note)
                LightKey(note)
                NoteNowVal.Text = note

                -- Update progress bar
                ProgressFill.Size = UDim2.new(State.Progress, 0, 1, 0)
                local pct = math.round(State.Progress * 100)
                local sec = math.round(delay * i)
                ProgressLabel.Text = pct .. "%  |  NOTE " .. i .. "/" .. totalNotes

                task.wait(delay)
            end
        until not Config.Loop or not State.Playing

        if State.Playing then
            State.Playing = false
            PlayBtn.Text            = "▶"
            PlayBtn.TextColor3      = COLOR.CYAN
            PlayBtn.BackgroundColor3 = COLOR.BG_CARD
            NoteNowVal.Text         = "--"
            ProgressFill.Size       = UDim2.new(1, 0, 1, 0)
            ProgressLabel.Text      = "100%  |  COMPLETE"
            UpdateStatus(
                "[ COMPLETE ] · SONG FINISHED: " .. song.name:upper(),
                "[ IDLE ] · PRESS PLAY TO RESTART",
                COLOR.CYAN, COLOR.TEXT_DIM
            )
            Log("Finished: " .. song.name)
        end
    end)
end

-- ══════════════════════════════════════════════════════════
--  §11  BUTTON EVENTS
-- ══════════════════════════════════════════════════════════

PlayBtn.MouseButton1Click:Connect(function()
    StartPlayback()
    -- Pulse animation
    Tween(PlayBtnOuter, TWEEN_SPRING, {Size = UDim2.new(0, 80, 0, 80),
        Position = UDim2.new(0.5, -40, 0, 6)})
    task.delay(0.3, function()
        Tween(PlayBtnOuter, TWEEN_MED, {Size = UDim2.new(0, 72, 0, 72),
            Position = UDim2.new(0.5, -36, 0, 10)})
    end)
end)

PlayBtn.MouseEnter:Connect(function()
    if not State.Playing then
        Tween(PlayBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(0, 50, 60)})
    end
end)
PlayBtn.MouseLeave:Connect(function()
    if not State.Playing then
        Tween(PlayBtn, TWEEN_FAST, {BackgroundColor3 = COLOR.BG_CARD})
    end
end)

StopBtn.MouseButton1Click:Connect(function()
    StopPlayback()
    Tween(StopBtn, TWEEN_SPRING, {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0.5, 44, 0, 21)})
    task.delay(0.3, function()
        Tween(StopBtn, TWEEN_MED, {Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0.5, 46, 0, 24)})
    end)
end)

RestartBtn.MouseButton1Click:Connect(function()
    StopPlayback()
    task.wait(0.1)
    StartPlayback()
end)

LoopToggle.MouseButton1Click:Connect(function()
    Config.Loop = not Config.Loop
    LoopToggle.Text = Config.Loop and "ON" or "OFF"
    Tween(LoopToggle, TWEEN_FAST, {
        TextColor3       = Config.Loop and COLOR.BG_DEEP or COLOR.RED,
        BackgroundColor3 = Config.Loop and COLOR.GREEN   or COLOR.BG_DEEP,
    })
    local stroke = LoopToggle:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Color = Config.Loop and COLOR.GREEN or COLOR.RED end
    Log("Loop: " .. (Config.Loop and "ON" or "OFF"))
end)

local SPEED_STEPS = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0}
local speedIdx = 4  -- default 1.0×

SpeedDown.MouseButton1Click:Connect(function()
    speedIdx = math.max(1, speedIdx - 1)
    Config.Speed = SPEED_STEPS[speedIdx]
    SpeedVal.Text = string.format("%.2f×", Config.Speed)
    Log("Speed: " .. Config.Speed .. "x")
end)
SpeedUp.MouseButton1Click:Connect(function()
    speedIdx = math.min(#SPEED_STEPS, speedIdx + 1)
    Config.Speed = SPEED_STEPS[speedIdx]
    SpeedVal.Text = string.format("%.2f×", Config.Speed)
    Log("Speed: " .. Config.Speed .. "x")
end)

-- Close / minimize
CloseBtn.MouseButton1Click:Connect(function()
    -- Animate close
    Tween(Main, TWEEN_MED, {
        Size     = UDim2.new(0, sz.X, 0, 0),
        BackgroundTransparency = 1,
    })
    task.delay(0.35, function()
        Main.Visible = false
        Shadow.Visible = false
        OuterGlow.Visible = false
        State.GuiOpen = false
        Main.Size = UDim2.new(0, sz.X, 0, sz.Y)
        Main.BackgroundTransparency = 0
    end)
end)

local minimized = false
local minHeight = 44

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Tween(Main, TWEEN_SPRING, {Size = UDim2.new(0, sz.X, 0, minHeight)})
        ContentArea.Visible = false
        TabBar.Visible = false
        MinBtn.Text = "□"
    else
        ContentArea.Visible = true
        TabBar.Visible = true
        Tween(Main, TWEEN_SPRING, {Size = UDim2.new(0, sz.X, 0, sz.Y)})
        MinBtn.Text = "—"
    end
end)

TogglePill.MouseButton1Click:Connect(function()
    State.GuiOpen = not State.GuiOpen
    if State.GuiOpen then
        Main.Visible      = true
        Shadow.Visible    = true
        OuterGlow.Visible = true
        Main.BackgroundTransparency = 1
        Tween(Main, TWEEN_SPRING, {BackgroundTransparency = 0})
        Tween(TogglePill, TWEEN_FAST, {BackgroundColor3 = COLOR.BG_HEADER})
    else
        Tween(Main, TWEEN_MED, {BackgroundTransparency = 1})
        task.delay(0.35, function()
            Main.Visible      = false
            Shadow.Visible    = false
            OuterGlow.Visible = false
        end)
        Tween(TogglePill, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(40, 10, 70)})
    end
end)

-- ══════════════════════════════════════════════════════════
--  §12  RESIZE SYSTEM  (dynamic update)
-- ══════════════════════════════════════════════════════════

local lastVP = GetViewport()

local function ApplyResize()
    local vp    = GetViewport()
    local newSz = ScaledSize()
    -- Clamp position so it stays on screen
    local pos    = Main.Position
    local newX   = math.clamp(pos.X.Offset, 0, vp.X - newSz.X)
    local newY   = math.clamp(pos.Y.Offset, 0, vp.Y - newSz.Y)
    Tween(Main, TWEEN_MED, {
        Size     = UDim2.new(0, newSz.X, 0, minimized and minHeight or newSz.Y),
        Position = UDim2.new(0, newX, 0, newY),
    })
    Shadow.Size     = UDim2.new(0, newSz.X + 20, 0, newSz.Y + 20)
    Shadow.Position = UDim2.new(0, newX - 10, 0, newY + 8)
    OuterGlow.Size  = UDim2.new(0, newSz.X + 6, 0, newSz.Y + 6)
    OuterGlow.Position = UDim2.new(0, newX - 3, 0, newY - 3)
    sz = newSz
    lastVP = vp
end

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local vp = GetViewport()
    if vp ~= lastVP then
        ApplyResize()
    end
end)

-- ══════════════════════════════════════════════════════════
--  §13  RENDER LOOP  (animations, visualizer, title glow)
-- ══════════════════════════════════════════════════════════

local titleHue = 0
local glowPulse = 0

RunService.RenderStepped:Connect(function(dt)
    -- ── Title hue shift ──────────────────────
    titleHue = (titleHue + dt * 0.3) % 1
    local titleColor = RGBfromHSV(titleHue, 0.6, 1)
    TitleText.TextColor3 = titleColor
    TitleSep.BackgroundColor3 = titleColor
    TitleIcon.TextColor3 = RGBfromHSV((titleHue + 0.5) % 1, 0.8, 1)

    -- ── Outer glow pulse ─────────────────────
    glowPulse = (glowPulse + dt * 2) % (math.pi * 2)
    local pulseAlpha = 0.6 + 0.2 * math.sin(glowPulse)
    OuterGlow.BackgroundTransparency = pulseAlpha
    OuterGlow.BackgroundColor3 = RGBfromHSV(titleHue, 0.8, 0.8)

    -- ── Toggle pill glow ─────────────────────
    local pillAlpha = 0.7 + 0.15 * math.sin(glowPulse * 1.5)
    ToggleGlow.BackgroundTransparency = pillAlpha

    -- ── Visualizer bars ──────────────────────
    if Config.VisualizerOn then
        for i = 1, BAR_COUNT do
            local b = VizBars[i]
            -- Decay target
            b.target = math.max(0.02, b.target - dt * 1.4)
            -- Smooth current toward target
            b.current = b.current + (b.target - b.current) * math.min(1, dt * 8)
            -- Also add tiny random jitter when playing
            if State.Playing then
                b.current = math.max(0.02, b.current + (math.random() - 0.5) * 0.03)
            end
            local h = math.clamp(b.current, 0.02, 1)
            b.frame.Size = UDim2.new(1 / BAR_COUNT - 0.004, 0, h, 0)
            -- Color shift
            local hue = ((i - 1) / BAR_COUNT * 0.6 + titleHue * 0.3) % 1
            b.frame.BackgroundColor3 = RGBfromHSV(hue, 1, 0.9 + h * 0.1)
        end
    end

    -- ── Play button pulse when playing ───────
    if State.Playing then
        local pp = 0.6 + 0.3 * math.abs(math.sin(glowPulse * 3))
        PlayBtnOuter.BackgroundTransparency = pp
    end

    -- ── Corner deco animation ─────────────────
    for idx, corner in ipairs(mainCorners) do
        local off = idx * math.pi / 2
        corner.BackgroundColor3 = RGBfromHSV((titleHue + off / (2*math.pi)) % 1, 0.9, 1)
        corner.BackgroundTransparency = 0.1 + 0.3 * math.abs(math.sin(glowPulse + off))
    end
end)

-- ══════════════════════════════════════════════════════════
--  §14  GLOBAL API  (_G.Piano)
-- ══════════════════════════════════════════════════════════

_G.Piano = {
    Play       = function() StartPlayback() end,
    Stop       = function() StopPlayback()  end,
    SetSong    = function(n)
        n = math.clamp(n, 1, #Songs)
        State.CurrentSong = n
        TitleSong.Text    = "▶ " .. Songs[n].name
        UpdateStatus("[ SONG ] · " .. Songs[n].name:upper(), "[ READY ] · PRESS PLAY")
    end,
    SetSpeed   = function(x)
        Config.Speed  = math.clamp(x, 0.1, 10)
        SpeedVal.Text = string.format("%.2f×", Config.Speed)
    end,
    SetLoop    = function(v)
        Config.Loop = v
        LoopToggle.Text = v and "ON" or "OFF"
    end,
    Toggle     = function()
        TogglePill:Activate()
    end,
    SetTranspose = function(n)
        Config.Transpose = math.clamp(n, -12, 12)
        TransposeVal.Text = tostring(Config.Transpose)
    end,
    Songs      = Songs,
    Config     = Config,
    State      = State,
}

-- ══════════════════════════════════════════════════════════
--  §15  KEYBOARD SHORTCUTS
-- ══════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Enum.KeyCode.P then
            StartPlayback()
        elseif key == Enum.KeyCode.S then
            StopPlayback()
        elseif key == Enum.KeyCode.L then
            Config.Loop = not Config.Loop
            LoopToggle.Text = Config.Loop and "ON" or "OFF"
        elseif key == Enum.KeyCode.RightBracket then
            speedIdx = math.min(#SPEED_STEPS, speedIdx + 1)
            Config.Speed = SPEED_STEPS[speedIdx]
            SpeedVal.Text = string.format("%.2f×", Config.Speed)
        elseif key == Enum.KeyCode.LeftBracket then
            speedIdx = math.max(1, speedIdx - 1)
            Config.Speed = SPEED_STEPS[speedIdx]
            SpeedVal.Text = string.format("%.2f×", Config.Speed)
        elseif key == Enum.KeyCode.Tab then
            State.GuiOpen = not State.GuiOpen
            Main.Visible = State.GuiOpen
            Shadow.Visible = State.GuiOpen
            OuterGlow.Visible = State.GuiOpen
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--  §16  HOTKEY LEGEND  (overlay, tap H to toggle)
-- ══════════════════════════════════════════════════════════

local HotkeyOverlay = MakeFrame(ScreenGui, COLOR.BG_HEADER, {
    Size     = UDim2.new(0, 180, 0, 110),
    Position = UDim2.new(1, -190, 1, -120),
    BackgroundTransparency = 0.1,
    Visible  = false,
    ZIndex   = 30,
})
MakeCorner(HotkeyOverlay, 10)
MakeStroke(HotkeyOverlay, COLOR.PURPLE, 1, 0)

local hotkeys = {
    {"P",   "Play / Stop"},
    {"S",   "Hard Stop"},
    {"L",   "Toggle Loop"},
    {"[",   "Speed Down"},
    {"]",   "Speed Up"},
    {"TAB", "Show / Hide"},
    {"H",   "Hotkey List"},
}
for i, hk in ipairs(hotkeys) do
    local row = MakeFrame(HotkeyOverlay, COLOR.TRANSPARENT, {
        Size     = UDim2.new(1, -8, 0, 14),
        Position = UDim2.new(0, 4, 0, (i-1)*14 + 4),
        BackgroundTransparency = 1,
        ZIndex   = 31,
    })
    MakeLabel(row, "[" .. hk[1] .. "]", 9, FONT.MONO, COLOR.CYAN, {
        Size = UDim2.new(0, 44, 1, 0), ZIndex = 32,
    })
    MakeLabel(row, hk[2], 9, FONT.MONO, COLOR.TEXT_DIM, {
        Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(0, 46, 0, 0), ZIndex = 32,
    })
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.H then
            HotkeyOverlay.Visible = not HotkeyOverlay.Visible
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--  §17  INIT / STARTUP SEQUENCE
-- ══════════════════════════════════════════════════════════

-- Initial state
UpdateStatus(
    "[ READY ] · AUTO PIANO INITIALIZED · INJECT OK",
    "[ WAITING ] · SELECT SONG  ·  PRESS PLAY OR [P]",
    COLOR.GREEN, COLOR.TEXT_DIM
)
Log("AutoPiano v4.2 loaded")
Log(#Songs .. " songs available")
Log("Press [H] for hotkey list")

-- Intro animation: main frame scale-in
Main.Size         = UDim2.new(0, sz.X * 0.5, 0, sz.Y * 0.5)
Main.Position     = UDim2.new(0, MainX + sz.X * 0.25, 0, MainY + sz.Y * 0.25)
Main.BackgroundTransparency = 1

task.delay(0.05, function()
    Tween(Main, TWEEN_SPRING, {
        Size     = UDim2.new(0, sz.X, 0, sz.Y),
        Position = UDim2.new(0, MainX, 0, MainY),
        BackgroundTransparency = 0,
    })
end)

-- Stagger corner deco entry
for i, c in ipairs(mainCorners) do
    c.BackgroundTransparency = 1
    task.delay(0.3 + i * 0.08, function()
        Tween(c, TWEEN_MED, {BackgroundTransparency = 0.3})
    end)
end

-- Visualizer random idle animation to show it's alive
task.spawn(function()
    while true do
        for i = 1, BAR_COUNT do
            if not State.Playing then
                VizBars[i].target = math.random() * 0.15
            end
        end
        task.wait(0.4 + math.random() * 0.3)
    end
end)

print("╔══════════════════════════════════════╗")
print("║  KANHA PIANO v4.2 · LOADED OK        ║")
print("║  Songs: " .. tostring(#Songs) .. "  |  Press [H] for hotkeys  ║")
print("║  _G.Piano.Play()  to start anytime   ║")
print("╚══════════════════════════════════════╝")

-- ══════════════════════════════════════════════════════════
--  END OF SCRIPT  ·  KANHA PIANO CYBERPUNK EDITION  v4.2.0
-- ══════════════════════════════════════════════════════════
