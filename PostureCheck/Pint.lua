local _, ns = ...

-- A pixel-art pint glass (nonic shape) full of beer. As the timer runs the
-- beer drains and leaves rings of foam on the glass. Bubbles rise through the
-- beer on their own textures so they can move every frame without rebuilding
-- the grid. Grid row 0 is the bottom of the glass.

local W, H = 24, 38         -- grid size in pixels
local PIXEL = 2             -- on-screen size of one grid pixel
local CX = W / 2
local BASE_ROWS = 2         -- solid glass at the bottom
local RIM = 33              -- top row of the glass
local BEER_ROWS = 28        -- rows of beer in a full pint
local MAX_FOAM = 4
local LACE_EVERY = 4        -- spacing of the foam rings left on the glass
local DOME = { 7.5, 6.5, 4.5 }  -- half-widths of the foam heaped above the rim when full

local SPIN_TIME = 1.0        -- seconds for the finished glass to spin upside down
local SPIN_ANGLE = 3 * math.pi -- one and a half turns
local BLINKS = 3
local BLINK_STEP = 0.2      -- seconds dimmed, then the same lit, per blink

local BUBBLES = {
    { x = 9,  speed = 6.0, phase = 0 },
    { x = 12, speed = 4.5, phase = 11 },
    { x = 14, speed = 7.5, phase = 5 },
    { x = 11, speed = 5.2, phase = 19 },
}

local PALETTE = {
    outline   = { 0.10, 0.08, 0.06 },
    glass     = { 0.78, 0.88, 0.93, 0.85 },
    glassBase = { 0.66, 0.79, 0.86, 0.9 },
    air       = { 0.80, 0.90, 1.00, 0.18 },
    shine     = { 1.00, 1.00, 1.00, 0.55 },
    beer      = { 0.93, 0.62, 0.12 },
    beerLight = { 1.00, 0.78, 0.30 },
    beerDark  = { 0.78, 0.45, 0.06 },
    foam      = { 0.99, 0.96, 0.87 },
    foamShade = { 0.88, 0.82, 0.68 },
    lace      = { 0.97, 0.94, 0.84, 0.7 },
    bubble    = { 1.00, 0.92, 0.65, 0.8 },
}

local floor, ceil, abs, sin, cos, pi = math.floor, math.ceil, math.abs, math.sin, math.cos, math.pi

-- Outer half-width of the glass at a row: it widens toward the top and has
-- the nonic bulge a few rows below the rim.
local function HalfWidth(gy)
    local hw = 5.6 + 2.4 * gy / RIM
    if gy >= 27 and gy <= 30 then hw = hw + 1 end
    return hw
end

local function Sample(gx, gy, beerTop, foamTop, full)
    local dx = gx + 0.5 - CX
    if gy > RIM then
        local dome = DOME[gy - RIM]
        return (full and dome and abs(dx) <= dome) and "foam" or nil
    end

    local hw = HalfWidth(gy)
    if abs(dx) > hw then return nil end
    if gy < BASE_ROWS then return "glassBase" end
    if abs(dx) > hw - 1 then return "glass" end

    local left, right = dx <= 2 - hw, dx >= hw - 2
    if gy <= beerTop then
        if left then return "beerLight" end
        if right or gy < BASE_ROWS + 3 then return "beerDark" end
        return "beer"
    end
    if gy <= foamTop then
        return right and "foamShade" or "foam"
    end
    -- Rings of foam stuck to the glass where the beer used to be.
    if (left or right) and gy < BASE_ROWS + BEER_ROWS and gy % LACE_EVERY == 1 then
        return "lace"
    end
    return left and "shine" or "air"
end

local function BeerTop(beerRows)
    return BASE_ROWS + beerRows - 1
end

local function Rasterize(beerRows)
    local beerTop = BeerTop(beerRows)
    local foamRows = beerRows > 0 and math.max(1, floor(MAX_FOAM * beerRows / BEER_ROWS + 0.5)) or 0
    local foamTop = math.min(beerTop + foamRows, RIM)
    local full = beerRows == BEER_ROWS

    local grid = {}
    for gy = 0, H - 1 do
        for gx = 0, W - 1 do
            grid[gy * W + gx + 1] = Sample(gx, gy, beerTop, foamTop, full)
        end
    end
    return ns.Pixels.Outline(grid, W, H)
end

local cache = {}

local function Create(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(W * PIXEL, H * PIXEL)

    local pixels = ns.Pixels.CreateTextures(holder, W, H)
    local shown = {}    -- color currently on each pixel

    -- Lays the pixels out turned by `angle` around the middle of the glass.
    -- Tilted pixels are drawn a little larger so no gaps show between them.
    local function PlacePixels(angle)
        local c, s = cos(angle), sin(angle)
        local ox, oy = W * PIXEL / 2, H * PIXEL / 2
        local quarters = angle / (pi / 2)
        local straight = abs(quarters - floor(quarters + 0.5)) < 1e-6
        local size = straight and PIXEL or PIXEL + 1
        for gy = 0, H - 1 do
            for gx = 0, W - 1 do
                local tex = pixels[gy * W + gx + 1]
                local x, y = (gx + 0.5) * PIXEL - ox, (gy + 0.5) * PIXEL - oy
                tex:ClearAllPoints()
                tex:SetPoint("CENTER", holder, "BOTTOMLEFT", ox + x * c - y * s, oy + x * s + y * c)
                tex:SetSize(size, size)
                if tex.SetRotation then tex:SetRotation(angle) end
            end
        end
    end
    PlacePixels(0)

    local bubbles = {}
    for i = 1, #BUBBLES do
        local tex = holder:CreateTexture(nil, "OVERLAY")
        tex:SetSize(PIXEL, PIXEL)
        ns.Pixels.SetColor(tex, PALETTE.bubble)
        bubbles[i] = tex
    end

    local pint = { frame = holder, beerRows = -1 }

    local function MoveBubbles()
        local height = pint.beerRows - 1    -- keep bubbles below the foam
        local now = GetTime()
        for i, b in ipairs(BUBBLES) do
            local tex = bubbles[i]
            if height >= 3 then
                local y = BASE_ROWS + floor((now * b.speed + b.phase) % height)
                tex:SetPoint("BOTTOMLEFT", b.x * PIXEL, y * PIXEL)
                tex:Show()
            else
                tex:Hide()
            end
        end
    end

    -- After the last sip the glass spins upside down, blinks, and stays there.
    local function Finish(t)
        local spin = math.min(t / SPIN_TIME, 1)
        local angle = SPIN_ANGLE * (1 - (1 - spin) ^ 3)    -- eases out
        if angle ~= pint.angle then
            pint.angle = angle
            PlacePixels(angle)
        end
        local b = t - SPIN_TIME
        local dim = b > 0 and b < BLINKS * 2 * BLINK_STEP and floor(b / BLINK_STEP) % 2 == 0
        holder:SetAlpha(dim and 0.2 or 1)
    end

    -- Progress 0 is a full pint, 1 is empty.
    function pint:SetProgress(progress, finished)
        if finished then
            self.finishedAt = self.finishedAt or GetTime()
            Finish(GetTime() - self.finishedAt)
        elseif self.finishedAt then
            self.finishedAt = nil
            self.angle = 0
            holder:SetAlpha(1)
            PlacePixels(0)
        end

        if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
        local beerRows = ceil((1 - progress) * BEER_ROWS)
        if beerRows ~= self.beerRows then
            self.beerRows = beerRows
            local grid = cache[beerRows]
            if not grid then
                grid = Rasterize(beerRows)
                cache[beerRows] = grid
            end
            ns.Pixels.Paint(pixels, grid, PALETTE, shown)
        end
        MoveBubbles()
    end

    pint:SetProgress(0)
    return pint
end

-- Once finished, the glass waits for a click to be refilled (see TimerFrame.lua).
ns.RegisterCharacter({ key = "pint", name = "Pint of beer", create = Create, waitsForClick = true })
