local _, ns = ...

-- A tiny orc seen from the front, drawn as pixel art from simple shapes.
-- Hunch 0 = standing tall; as it grows his head sinks and bows (so you see
-- more of his scalp), his shoulders round inward, his belly pushes out and his
-- hands drift together. He breathes and blinks, gets drowsy, dozes off, and
-- past SACK_AT gives up entirely and becomes a sack of potatoes.
-- Shapes are defined in "units"; SCALE grid pixels make up one unit. Face
-- details are stamped in grid pixels around the centre column so they stay
-- symmetric.

local SCALE = 1.35
local W, H = 33, 37         -- grid size in pixels
local PIXEL = 2             -- on-screen size of one grid pixel
local CX = W / SCALE / 2    -- centre line in units
local CC = (W - 1) / 2      -- centre column in grid pixels
local WAIST_Y = 9
local HEAD_R = 2.7
local LEVELS = 40           -- distinct poses
local SACK_AT = 0.9
local SACK_LEVEL = math.floor(SACK_AT * LEVELS + 0.5)
local SACK_X = 11

-- Animation timing, in seconds.
local BREATH_PERIOD = 3.2   -- grows as he slouches, so he breathes slower
local BLINK_EVERY = 4
local BLINK_TIME = 0.15
local DROWSY_AT = 0.5       -- blinks get longer from here...
local DOZE_AT = 0.78        -- ...and from here his eyes stay shut
local Z_STEP = 0.6          -- time per step of the rising "z"

local PALETTE = {
    outline    = { 0.08, 0.06, 0.04 },
    skin       = { 0.38, 0.64, 0.22 },
    skinLight  = { 0.50, 0.76, 0.30 },
    skinShade  = { 0.30, 0.53, 0.17 },
    skinDark   = { 0.25, 0.45, 0.14 },
    leather    = { 0.55, 0.38, 0.18 },
    buckle     = { 0.95, 0.80, 0.25 },
    cloth      = { 0.62, 0.13, 0.10 },
    clothDark  = { 0.42, 0.08, 0.07 },
    pad        = { 0.50, 0.50, 0.54 },
    padDark    = { 0.34, 0.34, 0.38 },
    rivet      = { 0.86, 0.86, 0.90 },
    pants      = { 0.42, 0.28, 0.15 },
    pantsDark  = { 0.32, 0.21, 0.11 },
    boots      = { 0.20, 0.14, 0.08 },
    bootsLight = { 0.32, 0.23, 0.14 },
    hair       = { 0.10, 0.08, 0.08 },
    eye        = { 0.95, 0.20, 0.10 },
    tusk       = { 0.96, 0.93, 0.80 },
    snore      = { 0.85, 0.90, 1.00 },
    burlap     = { 0.78, 0.64, 0.42 },
    burlapDark = { 0.62, 0.49, 0.30 },
    rope       = { 0.45, 0.32, 0.17 },
    stitch     = { 0.35, 0.25, 0.14 },
    potato     = { 0.72, 0.54, 0.31 },
    potatoSpot = { 0.46, 0.32, 0.17 },
}

-- A "z" in grid pixels, top row first.
local Z_SHAPE = { "xxx", "..x", ".x.", "x..", "xxx" }

local sin, floor, abs, max, pi = math.sin, math.floor, math.abs, math.max, math.pi

local function Dist2(px, py, x, y)
    local dx, dy = px - x, py - y
    return dx * dx + dy * dy
end

-- Squared distance to segment AB, plus how far along AB (0..1) the closest point is.
local function SegDist2(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local t = ((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return Dist2(px, py, ax + abx * t, ay + aby * t), t
end

local function InEllipse(px, py, cx, cy, rx, ry)
    local dx, dy = (px - cx) / rx, (py - cy) / ry
    return dx * dx + dy * dy <= 1
end

local function Fill(grid, sample)
    for gy = 0, H - 1 do
        for gx = 0, W - 1 do
            grid[gy * W + gx + 1] = sample((gx + 0.5) / SCALE, (gy + 0.5) / SCALE, gx, gy)
        end
    end
end

-- Paints a grid pixel; x and y are in grid pixels.
local function Put(grid, gx, gy, color)
    if gx >= 0 and gx < W and gy >= 0 and gy < H then
        grid[gy * W + gx + 1] = color
    end
end

-- Paints a pixel at (CC - dx) and its mirror at (CC + dx).
local function PutPair(grid, dx, gy, color)
    Put(grid, CC - dx, gy, color)
    Put(grid, CC + dx, gy, color)
end

local function Row(y)
    return floor(y * SCALE)
end

local function Outline(grid)
    local out = {}
    for gy = 0, H - 1 do
        for gx = 0, W - 1 do
            local i = gy * W + gx + 1
            local c = grid[i]
            if not c then
                if (gx > 0 and grid[i - 1]) or (gx < W - 1 and grid[i + 1])
                    or (gy > 0 and grid[i - W]) or (gy < H - 1 and grid[i + W]) then
                    c = "outline"
                end
            end
            out[i] = c
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Orc
---------------------------------------------------------------------------

-- `bend` 0..1 is how slouched he is; `lift` raises the upper body (breathing).
local function BuildPose(bend, lift)
    local sh = 16 - 1.6 * bend + lift       -- shoulder line
    local shoulderW = 5.2 - 0.9 * bend
    local headY = sh + 3.4 - 2.2 * bend     -- the head sinks between the shoulders
    local handX = 6.6 - 2.8 * bend          -- hands drift in front of the belly
    local knotY = headY + 2.8 - 1.2 * bend

    return {
        bend = bend,
        sh = sh,
        shoulderW = shoulderW,
        waistW = 3.8 + 0.6 * bend,
        headY = headY,
        jawY = headY - 1.3 - 0.5 * bend,
        -- Bowing the head tips the face down and shows more of the scalp.
        scalpY = headY + 2.3 - 1.6 * bend,
        eyeY = headY + 0.3 - 1.0 * bend,
        knotY = knotY,
        bandY = knotY - 0.9,
        padX = shoulderW + 0.4, padY = sh - 0.2 + 0.5 * bend,
        armX = shoulderW + 0.6, armY = sh - 1.2,
        handX = handX, handY = 8.2 - 0.6 * bend + lift * 0.5,
    }
end

local function SampleOrc(pose, px, py)
    local dx = px - CX
    local ax = abs(dx)

    -- Topknot with a leather band
    if Dist2(ax, py, 0, pose.bandY) <= 0.3 then return "leather" end
    if Dist2(ax, py, 0, pose.knotY) <= 1.1 then return "hair" end

    -- Head and jaw, with the scalp shaded where it tips toward us
    if Dist2(ax, py, 0, pose.headY) <= HEAD_R * HEAD_R
        or InEllipse(ax, py, 0, pose.jawY, 2.6, 1.8) then
        if py > pose.scalpY then return "skinShade" end
        return dx < -1.6 and "skinLight" or "skin"
    end

    -- Pointy ears
    if SegDist2(ax, py, 2.4, pose.headY + 0.2, 3.7, pose.headY + 1.1 - 0.6 * pose.bend) <= 0.3 then
        return "skinDark"
    end

    -- Shoulder pads
    if Dist2(ax, py, pose.padX, pose.padY) <= 3.6 then
        return py < pose.padY - 0.6 and "padDark" or "pad"
    end

    -- Arms with leather bracers near the wrists
    if Dist2(ax, py, pose.handX, pose.handY) <= 1.5 then return "skinDark" end
    local armD, armT = SegDist2(ax, py, pose.armX, pose.armY, pose.handX, pose.handY + 0.8)
    if armD <= 1.3 then
        return (armT > 0.62 and armT < 0.85) and "leather" or "skinDark"
    end

    -- Neck
    if ax <= 1.6 and py >= pose.sh - 0.5 and py <= pose.headY then return "skinShade" end

    -- Torso: widens from the waist to the shoulders, plus a belly that grows
    local t = (py - WAIST_Y) / (pose.sh - WAIST_Y)
    local hw = pose.waistW + (pose.shoulderW - pose.waistW) * t
    local belly = pose.bend > 0 and InEllipse(ax, py, 0, WAIST_Y + 1.8, pose.waistW + 0.8 * pose.bend, 2.2)
    if (t >= 0 and t <= 1 and ax <= hw) or belly then
        if py < WAIST_Y + 0.6 then return "leather" end     -- belt
        if ax > hw - 0.8 then return "skinShade" end
        -- Chest line and a line down the middle fade as he slumps.
        if pose.bend < 0.5 then
            local pecY = pose.sh - 2.9
            if abs(py - pecY) < 0.35 and ax > 0.6 and ax < 3.2 then return "skinShade" end
            if ax < 0.3 and py > WAIST_Y + 1 and py < pecY then return "skinShade" end
        end
        return dx < 1.8 - hw and "skinLight" or "skin"
    end

    -- Belt
    if ax <= pose.waistW + 0.1 and py >= WAIST_Y - 0.6 and py < WAIST_Y + 0.6 then return "leather" end

    -- Loincloth over the legs
    if py >= 3.8 and py < WAIST_Y - 0.6 and ax <= 1.6 - (WAIST_Y - 0.6 - py) * 0.1 then
        return py < 4.5 and "clothDark" or "cloth"
    end

    -- Legs and boots
    if py < 1.6 then
        if ax >= 0.2 and ax <= 3.6 then return py >= 1.1 and "bootsLight" or "boots" end
    elseif py < WAIST_Y then
        if ax >= 0.3 and ax <= 3.3 then return ax < 1.0 and "pantsDark" or "pants" end
    end
    return nil
end

local function DrawOrc(bend, lift, eyesShut, zStep)
    local pose = BuildPose(bend, lift)
    local grid = {}
    Fill(grid, function(px, py) return SampleOrc(pose, px, py) end)

    local eye = Row(pose.eyeY)
    if eyesShut then
        PutPair(grid, 2, eye, "outline")
        PutPair(grid, 1, eye, "skinShade")      -- heavy lids
    else
        PutPair(grid, 2, eye, "eye")
    end
    -- Angry brows, lower on the inside; they relax as he gets tired.
    PutPair(grid, 1, eye + (bend < DROWSY_AT and 1 or 2), "outline")
    PutPair(grid, 2, eye + 2, "outline")
    PutPair(grid, 3, eye + 2, "outline")

    Put(grid, CC, eye - 1, "skinDark")          -- nose
    for dx = -1, 1 do Put(grid, CC + dx, eye - 3, "outline") end    -- mouth
    PutPair(grid, 2, eye - 3, "tusk")
    PutPair(grid, 2, eye - 2, "tusk")

    PutPair(grid, floor(pose.padX * SCALE), Row(pose.padY + 0.7), "rivet")
    Put(grid, CC, Row(WAIST_Y), "buckle")

    -- A "z" floating up beside his head while he dozes.
    if zStep then
        local left, top = CC + 5 + zStep, Row(pose.headY + 2.5) + 2 * zStep + #Z_SHAPE
        for r, line in ipairs(Z_SHAPE) do
            for c = 1, #line do
                if line:sub(c, c) == "x" then Put(grid, left + c - 1, top - r, "snore") end
            end
        end
    end
    return grid
end

---------------------------------------------------------------------------
-- Sack of potatoes
---------------------------------------------------------------------------

local POTATOES = {
    { 19.5, 1.3, 2.0, 1.3 },
    { 21.8, 3.2, 1.5, 1.1 },
    { 3.0, 1.1, 1.6, 1.1 },
}

local function Stamp(grid, x, y, color)
    Put(grid, floor(x * SCALE), floor(y * SCALE), color)
end

-- slump 0..1 squashes the sack a little flatter and wider.
local function SampleSack(px, py, slump)
    for _, p in ipairs(POTATOES) do
        if InEllipse(px, py, p[1], p[2], p[3], p[4]) then return "potato" end
    end

    local qx = SACK_X + (px - SACK_X) / (1 + 0.12 * slump)
    local qy = py / (1 - 0.15 * slump)

    if qy >= 13 and qy <= 14.2 and abs(qx - SACK_X) <= 1.6 then return "rope" end

    local inside = InEllipse(qx, qy, SACK_X, 5.5, 6, 5.5)
        or Dist2(qx, qy, 8.5, 9.5) <= 6.8
        or Dist2(qx, qy, 13.2, 9.8) <= 5.8
        or Dist2(qx, qy, SACK_X, 11) <= 6.2
        or (abs(qx - SACK_X) <= 1.2 and qy <= 15.2)
        or Dist2(qx, qy, 9.8, 15.8) <= 1.4
        or Dist2(qx, qy, 12.3, 16.0) <= 1.2
    if not inside then return nil end

    if abs(qx - 7.6) < 0.35 and qy > 2 and qy < 9 then return "stitch" end
    if qx > SACK_X + 3.6 or qy < 1.3 then return "burlapDark" end
    return "burlap"
end

local function DrawSack(slump)
    local grid = {}
    Fill(grid, function(px, py, gx, gy)
        local c = SampleSack(px, py, slump)
        -- Sparse darker pixels give the burlap a woven look.
        if c == "burlap" and (gx * 3 + gy * 2) % 7 == 0 then c = "burlapDark" end
        return c
    end)
    for _, p in ipairs(POTATOES) do
        Stamp(grid, p[1] - p[3] * 0.4, p[2] + p[4] * 0.2, "potatoSpot")
        Stamp(grid, p[1] + p[3] * 0.4, p[2] - p[4] * 0.3, "potatoSpot")
    end
    return grid
end

---------------------------------------------------------------------------

-- Picks the animation frame for a level at time `now`. Returns a cache key
-- and the arguments for DrawOrc (nothing for the sack, which doesn't move).
local function Frame(level, now)
    if level >= SACK_LEVEL then return tostring(level) end
    local bend = level / SACK_LEVEL

    local period = BREATH_PERIOD * (1 + bend)
    local lift = sin(2 * pi * now / period) > 0 and 1 / SCALE or 0     -- one pixel

    local shut, zStep
    if bend >= DOZE_AT then
        shut = true
        zStep = floor(now / Z_STEP) % 3
    else
        local blink = BLINK_TIME + max(0, bend - DROWSY_AT) * 6
        shut = now % BLINK_EVERY < blink
    end

    local key = string.format("%d:%d:%s:%s", level, lift > 0 and 1 or 0, tostring(shut), tostring(zStep))
    return key, bend, lift, shut, zStep
end

local function Rasterize(level, bend, lift, shut, zStep)
    if level >= SACK_LEVEL then
        return Outline(DrawSack((level - SACK_LEVEL) / (LEVELS - SACK_LEVEL)))
    end
    return Outline(DrawOrc(bend, lift, shut, zStep))
end

local cache = {}

function ns.CreateOrc(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(W * PIXEL, H * PIXEL)

    local pixels = {}
    for gy = 0, H - 1 do
        for gx = 0, W - 1 do
            local tex = holder:CreateTexture(nil, "ARTWORK")
            tex:SetSize(PIXEL, PIXEL)
            tex:SetPoint("BOTTOMLEFT", gx * PIXEL, gy * PIXEL)
            tex:Hide()
            pixels[gy * W + gx + 1] = tex
        end
    end

    local orc = { frame = holder }
    local shown = {}    -- color currently on each pixel

    -- Called every tick: the pose follows `amount`, the animation follows the clock.
    function orc:SetHunch(amount)
        if amount < 0 then amount = 0 elseif amount > 1 then amount = 1 end
        local level = floor(amount * LEVELS)
        local key, bend, lift, shut, zStep = Frame(level, GetTime())
        if key == self.key then return end
        self.key = key

        local grid = cache[key]
        if not grid then
            grid = Rasterize(level, bend, lift, shut, zStep)
            cache[key] = grid
        end
        -- Only touch the pixels that changed since the last frame.
        for i = 1, W * H do
            local c = grid[i]
            if c ~= shown[i] then
                shown[i] = c
                local tex = pixels[i]
                if c then
                    local rgb = PALETTE[c]
                    tex:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
                    tex:Show()
                else
                    tex:Hide()
                end
            end
        end
    end

    orc:SetHunch(0)
    return orc
end
