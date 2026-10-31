local _, ns = ...

-- Appearance presets for the timer bar and the frame around the timer.

ns.CHARACTERS = {
    { key = "peon",  name = "Lazy Peon (3D)" },
    { key = "pixel", name = "Pixel orc" },
    { key = "pint",  name = "Pint of beer" },
}

ns.BAR_TEXTURES = {
    { key = "blizzard", name = "Blizzard",  path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "raid",     name = "Raid",      path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "skills",   name = "Skill bar", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { key = "flat",     name = "Flat",      path = "Interface\\Buttons\\WHITE8X8" },
}

ns.BAR_COLORS = {
    { key = "gradient", name = "Green to red" },
    { key = "class",    name = "Class color" },
    { key = "gold",     name = "Cast bar gold", rgb = { 1, 0.7, 0 } },
    { key = "green",    name = "Health green",  rgb = { 0, 0.8, 0 } },
    { key = "blue",     name = "Mana blue",     rgb = { 0, 0.44, 0.87 } },
    { key = "red",      name = "Rage red",      rgb = { 0.8, 0.1, 0.1 } },
}

-- `outset` is how far the border is drawn outside the element it surrounds,
-- `inset` is how far the background is pulled in from the border.
local EDGES = {
    { key = "tooltip", name = "Tooltip", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12, inset = 3, outset = 3, color = { 0.8, 0.8, 0.8, 1 } },
    { key = "dialog", name = "Dialog", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 14, inset = 4, outset = 4, color = { 1, 1, 1, 1 } },
    { key = "gold", name = "Gold dialog", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      edgeSize = 14, inset = 4, outset = 4, color = { 1, 1, 1, 1 } },
    { key = "thin", name = "Thin line", edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1, inset = 1, outset = 1, color = { 0, 0, 0, 1 } },
}

ns.BAR_BORDERS = {
    { key = "none",    name = "None" },
    { key = "castbar", name = "Cast bar", castbar = true, outset = 4 },
}

ns.FRAME_BORDERS = {
    { key = "none", name = "None" },
}

for _, edge in ipairs(EDGES) do
    tinsert(ns.BAR_BORDERS, edge)
    tinsert(ns.FRAME_BORDERS, edge)
end

ns.BACKGROUNDS = {
    { key = "none",    name = "None" },
    { key = "tooltip", name = "Tooltip", bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", color = { 0, 0, 0 } },
    { key = "dialog",  name = "Dialog",  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", color = { 1, 1, 1 } },
    { key = "marble",  name = "Marble",  bgFile = "Interface\\FrameGeneral\\UI-Background-Marble", color = { 1, 1, 1 } },
    { key = "rock",    name = "Rock",    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock", color = { 1, 1, 1 } },
    { key = "solid",   name = "Solid",   bgFile = "Interface\\Buttons\\WHITE8X8", color = { 0, 0, 0 } },
}

function ns.FindStyle(list, key)
    for _, entry in ipairs(list) do
        if entry.key == key then
            return entry
        end
    end
    return list[1]
end
