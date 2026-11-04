local _, ns = ...

-- Helpers shared by the pixel-art characters (Orc.lua, Pint.lua). A grid is
-- a flat array indexed by gy * w + gx + 1 that holds palette names, or nil
-- for an empty pixel. Row 0 is the bottom.

local Pixels = {}
ns.Pixels = Pixels

-- Returns a copy of the grid with an "outline" pixel around every shape.
function Pixels.Outline(grid, w, h)
    local out = {}
    for gy = 0, h - 1 do
        for gx = 0, w - 1 do
            local i = gy * w + gx + 1
            local c = grid[i]
            if not c then
                if (gx > 0 and grid[i - 1]) or (gx < w - 1 and grid[i + 1])
                    or (gy > 0 and grid[i - w]) or (gy < h - 1 and grid[i + w]) then
                    c = "outline"
                end
            end
            out[i] = c
        end
    end
    return out
end

-- Creates one hidden texture per grid pixel; placing them is up to the caller.
function Pixels.CreateTextures(holder, w, h)
    local textures = {}
    for i = 1, w * h do
        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:Hide()
        textures[i] = tex
    end
    return textures
end

-- Palette colors are { r, g, b } or { r, g, b, a }.
function Pixels.SetColor(tex, rgb)
    tex:SetColorTexture(rgb[1], rgb[2], rgb[3], rgb[4] or 1)
end

-- Paints a grid onto the textures. `shown` remembers the color on each
-- pixel, so only the pixels that changed are touched.
function Pixels.Paint(textures, grid, palette, shown)
    for i = 1, #textures do
        local c = grid[i]
        if c ~= shown[i] then
            shown[i] = c
            local tex = textures[i]
            if c then
                Pixels.SetColor(tex, palette[c])
                tex:Show()
            else
                tex:Hide()
            end
        end
    end
end
