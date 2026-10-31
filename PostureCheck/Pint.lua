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

local floor, ceil, abs = math.floor, math.ceil, math.abs

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
    return Outline(grid)
end

local function SetColor(tex, name)
    local rgb = PALETTE[name]
    tex:SetColorTexture(rgb[1], rgb[2], rgb[3], rgb[4] or 1)
end

local cache = {}

function ns.CreatePint(parent)
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

    local bubbles = {}
    for i = 1, #BUBBLES do
        local tex = holder:CreateTexture(nil, "OVERLAY")
        tex:SetSize(PIXEL, PIXEL)
        SetColor(tex, "bubble")
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

    -- Shares the characters' interface: amount 0 is a full pint, 1 is empty.
    function pint:SetHunch(amount)
        if amount < 0 then amount = 0 elseif amount > 1 then amount = 1 end
        local beerRows = ceil((1 - amount) * BEER_ROWS)
        if beerRows ~= self.beerRows then
            self.beerRows = beerRows
            local grid = cache[beerRows]
            if not grid then
                grid = Rasterize(beerRows)
                cache[beerRows] = grid
            end
            for i = 1, W * H do
                local c = grid[i]
                local tex = pixels[i]
                if c then
                    SetColor(tex, c)
                    tex:Show()
                else
                    tex:Hide()
                end
            end
        end
        MoveBubbles()
    end

    pint:SetHunch(0)
    return pint
end
