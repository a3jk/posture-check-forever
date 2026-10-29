local _, ns = ...

-- A tiny side-view orc drawn as pixel art from simple shapes along a curved
-- spine. Hunch 0 = standing tall; as it grows the back rounds and the head
-- droops. Past SACK_AT he gives up entirely and becomes a sack of potatoes.
-- Shapes are defined in "units"; SCALE grid pixels make up one unit.

local SCALE = 1.35
local W, H = 33, 37         -- grid size in pixels
local PIXEL = 2             -- on-screen size of one grid pixel
local HIP_X, HIP_Y = 8.5, 9
local SPINE_LEN = 9
local SPINE_STEPS = 16
local MAX_ANGLE = 1.35      -- forward lean at the neck (radians) when fully hunched
local HEAD_DIST = 2.2
local HEAD_R = 2.6
local JAW_R = 1.9
local LEVELS = 40           -- distinct poses; the grid is only rebuilt when the level changes
local SACK_AT = 0.9
local SACK_LEVEL = math.floor(SACK_AT * LEVELS + 0.5)
local SACK_X = 11

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
    burlap     = { 0.78, 0.64, 0.42 },
    burlapDark = { 0.62, 0.49, 0.30 },
    rope       = { 0.45, 0.32, 0.17 },
    stitch     = { 0.35, 0.25, 0.14 },
    potato     = { 0.72, 0.54, 0.31 },
    potatoSpot = { 0.46, 0.32, 0.17 },
}

local sin, cos, floor, abs, pi = math.sin, math.cos, math.floor, math.abs, math.pi

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

local function Stamp(grid, x, y, color)
    local gx, gy = floor(x * SCALE), floor(y * SCALE)
    if gx >= 0 and gx < W and gy >= 0 and gy < H then
        grid[gy * W + gx + 1] = color
    end
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

local function BuildPose(bend)
    local spine = {}
    local x, y, a = HIP_X, HIP_Y, 0
    local ds = SPINE_LEN / SPINE_STEPS
    spine[0] = { x = x, y = y, s = 0, a = 0, r = 2.6 }
    for i = 1, SPINE_STEPS do
        local s = i / SPINE_STEPS
        -- Lean grows toward the top of the spine, which rounds the upper back.
        a = bend * MAX_ANGLE * s ^ 1.4
        x = x + sin(a) * ds
        y = y + cos(a) * ds
        spine[i] = { x = x, y = y, s = s, a = a, r = 2.6 + 1.0 * sin(pi * s * 0.9) }
    end

    local neck = spine[SPINE_STEPS]
    local hx = neck.x + sin(a) * HEAD_DIST
    local hy = neck.y + cos(a) * HEAD_DIST

    -- The head tilts less than the neck, so the orc peers forward and down.
    local ha = a * 0.6
    local ux, uy = sin(ha), cos(ha)     -- head "up"
    local fx, fy = cos(ha), -sin(ha)    -- head "forward"

    local shoulder = spine[13]
    local sa = shoulder.a
    local sx = shoulder.x + cos(sa) * 0.8
    local sy = shoulder.y - sin(sa) * 0.8
    local knotX, knotY = hx + ux * 2.6 - fx * 0.9, hy + uy * 2.6 - fy * 0.9

    return {
        spine = spine,
        headX = hx, headY = hy,
        fx = fx, fy = fy, ux = ux, uy = uy,
        jawX = hx + fx * 1.1 - ux * 1.0, jawY = hy + fy * 1.1 - uy * 1.0,
        earX = hx - fx * 0.4 + ux * 0.2, earY = hy - fy * 0.4 + uy * 0.2,
        earTipX = hx - fx * 1.1 + ux * 0.9, earTipY = hy - fy * 1.1 + uy * 0.9,
        knotX = knotX, knotY = knotY,
        bandX = hx + ux * 1.8 - fx * 0.7, bandY = hy + uy * 1.8 - fy * 0.7,
        tailX = knotX - fx * 2.0 - ux * 1.4, tailY = knotY - fy * 2.0 - uy * 1.4,
        eyeX = hx + fx * 1.3 + ux * 0.6, eyeY = hy + fy * 1.3 + uy * 0.6,
        tuskX = hx + fx * 2.2 - ux * 1.1, tuskY = hy + fy * 2.2 - uy * 1.1,
        padX = shoulder.x + sin(sa) * 0.4 - cos(sa) * 0.2,
        padY = shoulder.y + cos(sa) * 0.4 + sin(sa) * 0.2,
        rivetX = shoulder.x + sin(sa) * 1.2, rivetY = shoulder.y + cos(sa) * 1.2,
        shoulderX = sx, shoulderY = sy,
        handX = sx + 0.6 + bend, handY = sy - 6,
    }
end

local function SampleOrc(pose, px, py)
    -- Hair: band, topknot and ponytail
    if Dist2(px, py, pose.bandX, pose.bandY) <= 0.3 then return "leather" end
    if Dist2(px, py, pose.knotX, pose.knotY) <= 1.2
        or SegDist2(px, py, pose.knotX, pose.knotY, pose.tailX, pose.tailY) <= 0.25 then
        return "hair"
    end

    -- Head
    if Dist2(px, py, pose.earTipX, pose.earTipY) <= 0.2 or Dist2(px, py, pose.earX, pose.earY) <= 0.55 then
        return "skinDark"
    end
    if Dist2(px, py, pose.headX, pose.headY) <= HEAD_R * HEAD_R
        or Dist2(px, py, pose.jawX, pose.jawY) <= JAW_R * JAW_R then
        local front = (px - pose.headX) * pose.fx + (py - pose.headY) * pose.fy
        return front < -1.4 and "skinShade" or "skin"
    end

    -- Shoulder pad
    if Dist2(px, py, pose.padX, pose.padY) <= 2.9 then
        return py < pose.padY - 0.6 and "padDark" or "pad"
    end

    -- Arm with a leather bracer near the wrist
    if Dist2(px, py, pose.handX, pose.handY) <= 1.7 then return "skinDark" end
    local armD, armT = SegDist2(px, py, pose.shoulderX, pose.shoulderY, pose.handX, pose.handY)
    if armD <= 1.2 then
        return (armT > 0.62 and armT < 0.85) and "leather" or "skinDark"
    end

    -- Loincloth hanging from the belt
    if px >= HIP_X + 0.3 and px <= HIP_X + 2.8 and py >= HIP_Y - 4 and py <= HIP_Y then
        return py < HIP_Y - 3.3 and "clothDark" or "cloth"
    end

    -- Torso, shaded darker along the back and lighter on the chest
    for i = 0, SPINE_STEPS do
        local p = pose.spine[i]
        if Dist2(px, py, p.x, p.y) <= p.r * p.r then
            if py < HIP_Y then return "pants" end
            if py < HIP_Y + 1.5 then return "leather" end
            local front = (px - p.x) * cos(p.a) - (py - p.y) * sin(p.a)
            if front < -0.45 * p.r then return "skinShade" end
            if front > 0.5 * p.r and p.s > 0.4 then return "skinLight" end
            return "skin"
        end
    end

    -- Legs and boots
    if py < 2 then
        local boot = (px >= HIP_X - 0.2 and px <= HIP_X + 3.6) or (px >= HIP_X - 2.6 and px <= HIP_X + 1.0)
        if boot then return py >= 1.4 and "bootsLight" or "boots" end
    elseif py <= HIP_Y then
        if px >= HIP_X - 0.2 and px <= HIP_X + 2.4 then return "pants" end
        if px >= HIP_X - 2.6 and px <= HIP_X - 0.2 then return "pantsDark" end
    end
    return nil
end

local function DrawOrc(bend)
    local pose = BuildPose(bend)
    local grid = {}
    Fill(grid, function(px, py) return SampleOrc(pose, px, py) end)

    local ux, uy, fx, fy = pose.ux, pose.uy, pose.fx, pose.fy
    Stamp(grid, pose.eyeX, pose.eyeY, "eye")
    Stamp(grid, pose.eyeX + ux * 0.8, pose.eyeY + uy * 0.8, "outline")     -- heavy brow
    Stamp(grid, pose.eyeX + ux * 0.8 - fx * 0.7, pose.eyeY + uy * 0.8 - fy * 0.7, "outline")
    Stamp(grid, pose.tuskX, pose.tuskY, "tusk")
    Stamp(grid, pose.tuskX + ux * 0.7, pose.tuskY + uy * 0.7, "tusk")
    Stamp(grid, pose.tuskX - fx * 0.9 - ux * 0.5, pose.tuskY - fy * 0.9 - uy * 0.5, "outline")  -- mouth
    Stamp(grid, pose.rivetX, pose.rivetY, "rivet")
    Stamp(grid, HIP_X + 2.1, HIP_Y + 0.7, "buckle")
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

local function Rasterize(level)
    if level >= SACK_LEVEL then
        return Outline(DrawSack((level - SACK_LEVEL) / (LEVELS - SACK_LEVEL)))
    end
    return Outline(DrawOrc(level / SACK_LEVEL))
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

    local orc = { frame = holder, level = -1 }

    function orc:SetHunch(amount)
        if amount < 0 then amount = 0 elseif amount > 1 then amount = 1 end
        local level = floor(amount * LEVELS)
        if level == self.level then return end
        self.level = level

        local grid = cache[level]
        if not grid then
            grid = Rasterize(level)
            cache[level] = grid
        end
        for i = 1, W * H do
            local c = grid[i]
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

    orc:SetHunch(0)
    return orc
end
