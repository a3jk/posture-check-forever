local _, ns = ...

-- The timer window: the character (see Styles.lua) on the left, next to
-- either a progress bar or, with the bar turned off, the time as large text.
-- Borders and backgrounds come from Styles.lua.

local GAP = 12
local PAD = 8
local BIG_TEXT_W, BIG_TEXT_H = 80, 24
local DEFAULT_POINT = { "TOP", "TOP", 0, -120 }
local ALERT_RGB = { 1, 0.25, 0.25 }

local frame, figure, bar, barBorder, castBorder, overlay, spark, nameText, timeText, bigText
local barBorderColor, frameBorderColor  -- base colors, tinted red while alerting
local figures = {}
local dragged   -- true when the current mouse press turned into a drag

-- Characters are created the first time they are picked.
local function SelectFigure()
    local entry = ns.FindStyle(ns.CHARACTERS, ns.db.character)
    if not figures[entry.key] then
        figures[entry.key] = entry.create(frame)
    end
    for k, f in pairs(figures) do
        f.frame:SetShown(k == entry.key and ns.db.showCharacter)
    end
    figure = figures[entry.key]
end

-- Saved in screen units, so changing the scale leaves the window's anchor in place.
local function SavePosition(self)
    local point, _, relPoint, x, y = self:GetPoint()
    local scale = self:GetScale()
    ns.db.point = { point, relPoint, x * scale, y * scale }
end

local function WaitingForClick()
    return ns.IsFinished() and ns.WaitsForClick()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Posture Check")
    if ns.IsFinished() then
        GameTooltip:AddLine("Finished!", 1, 1, 1)
        if ns.WaitsForClick() then
            GameTooltip:AddLine("Click the glass for the next pint", 0.8, 0.8, 0.8)
        end
    else
        GameTooltip:AddLine("Time left: " .. ns.FormatTime(ns.GetRemaining()), 1, 1, 1)
    end
    if not ns.db.locked then
        GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Right-click: restart timer", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function TintBorder(f, color, pulse)
    f:SetBackdropBorderColor(
        color[1] + (ALERT_RGB[1] - color[1]) * pulse,
        color[2] + (ALERT_RGB[2] - color[2]) * pulse,
        color[3] + (ALERT_RGB[3] - color[3]) * pulse,
        color[4])
end

local function BarColor(progress)
    local mode = ns.db.barColor
    if mode == "gradient" then
        return math.min(1, progress * 2), math.min(1, (1 - progress) * 2), 0
    elseif mode == "class" then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if c then return c.r, c.g, c.b end
    end
    local rgb = ns.FindStyle(ns.BAR_COLORS, mode).rgb or ns.FindStyle(ns.BAR_COLORS, "gold").rgb
    return rgb[1], rgb[2], rgb[3]
end

-- Returns how far the bar's border sticks out past the bar.
local function ApplyBarStyle()
    local db = ns.db
    local w, h = db.barWidth, db.barHeight
    bar:SetSize(w, h)
    bar:SetStatusBarTexture(ns.FindStyle(ns.BAR_TEXTURES, db.barTexture).path)
    spark:SetSize(32, h * 2.4)
    nameText:SetShown(db.showBarText)
    timeText:SetShown(db.showTime)
    -- Without the time, the label may use the full width of the bar.
    nameText:ClearAllPoints()
    nameText:SetPoint("LEFT", 4, 1)
    if db.showTime then
        nameText:SetPoint("RIGHT", timeText, "LEFT", -4, 0)
    else
        nameText:SetPoint("RIGHT", -4, 1)
    end

    local style = ns.FindStyle(ns.BAR_BORDERS, db.barBorder)
    castBorder:SetShown(style.castbar == true)
    barBorder:SetShown(style.edgeFile ~= nil)
    barBorderColor = style.edgeFile and style.color or nil

    if style.castbar then
        -- The cast bar border art is made for a 195x13 bar; stretch it to fit.
        castBorder:SetSize(256 * w / 195, 64 * h / 13)
        castBorder:ClearAllPoints()
        castBorder:SetPoint("TOP", bar, "TOP", 0, 28 * h / 13)
    elseif style.edgeFile then
        local o = style.outset
        barBorder:ClearAllPoints()
        barBorder:SetPoint("TOPLEFT", -o, o)
        barBorder:SetPoint("BOTTOMRIGHT", o, -o)
        barBorder:SetBackdrop({ edgeFile = style.edgeFile, edgeSize = style.edgeSize })
        barBorder:SetBackdropBorderColor(unpack(style.color))
    end
    return style.outset or 0
end

-- Returns the padding between the window edge and its content.
local function ApplyFrameStyle()
    local db = ns.db
    local border = ns.FindStyle(ns.FRAME_BORDERS, db.frameBorder)
    local bg = ns.FindStyle(ns.BACKGROUNDS, db.frameBackground)
    frameBorderColor = border.edgeFile and border.color or nil

    if not border.edgeFile and not bg.bgFile then
        frame:SetBackdrop(nil)
        return 0
    end

    local inset = border.inset or 0
    frame:SetBackdrop({
        bgFile = bg.bgFile,
        edgeFile = border.edgeFile,
        tile = true, tileSize = 16,
        edgeSize = border.edgeSize or 1,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    if bg.bgFile then
        frame:SetBackdropColor(bg.color[1], bg.color[2], bg.color[3], db.frameAlpha)
    end
    if frameBorderColor then
        frame:SetBackdropBorderColor(unpack(frameBorderColor))
    end
    return PAD + inset
end

local function Layout()
    local db = ns.db
    local showCharacter, showBar = db.showCharacter, db.showBar
    local showBigText = not showBar and db.showTime
    local pad = ApplyFrameStyle()
    local outset = ApplyBarStyle()
    SelectFigure()

    bar:SetShown(showBar)
    bigText:SetShown(showBigText)

    -- Everything is laid out around a shared vertical centre (y = 0), and the
    -- window is sized to the box around whatever is shown. The offset
    -- settings nudge the character from its spot, and the window grows to fit.
    local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
    local function Include(x, w, y, h)
        left, right = math.min(left, x), math.max(right, x + w)
        bottom, top = math.min(bottom, y - h / 2), math.max(top, y + h / 2)
    end

    local x = 0
    if showCharacter then
        local w, h = figure.frame:GetSize()
        Include(db.characterX, w, db.characterY, h)
        x = w + GAP
    end

    -- With both the bar and the time off, only the character is left.
    local content, contentX
    if showBar then
        content, contentX = bar, x + outset
        Include(x, db.barWidth + 2 * outset, 0, db.barHeight + 2 * outset)
    elseif showBigText then
        content, contentX = bigText, x
        Include(x, BIG_TEXT_W, 0, BIG_TEXT_H)
    end

    if left > right then    -- nothing shown at all
        left, right, bottom, top = 0, 0, 0, 0
    end
    frame:SetSize(right - left + 2 * pad, top - bottom + 2 * pad)

    local function Place(region, rx, ry)
        region:ClearAllPoints()
        region:SetPoint("LEFT", frame, "BOTTOMLEFT", pad + rx - left, pad + ry - bottom)
    end
    if showCharacter then Place(figure.frame, db.characterX, db.characterY) end
    if content then Place(content, contentX, 0) end
end

function ns.ApplyTimerFrameSettings()
    if not frame then return end
    Layout()
    local scale = ns.db.scale
    local p = ns.db.point or DEFAULT_POINT
    frame:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3] / scale, p[4] / scale)
    frame:SetShown(ns.db.shown)
end

function ns.InitTimerFrame()
    frame = CreateFrame("Frame", "PostureCheckFrame", UIParent, "BackdropTemplate")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function()
        dragged = false
    end)
    frame:SetScript("OnDragStart", function(self)
        dragged = true
        if not ns.db.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.RestartTimer()
        elseif button == "LeftButton" and not dragged and WaitingForClick() and figure.frame:IsMouseOver() then
            GameTooltip:Hide()
            ns.RestartTimer()
        end
    end)
    frame:SetScript("OnEnter", ShowTooltip)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    bar = CreateFrame("StatusBar", nil, frame)
    bar:SetMinMaxValues(0, 1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    barBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")

    castBorder = bar:CreateTexture(nil, "OVERLAY")
    castBorder:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")

    overlay = bar:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints()
    overlay:SetColorTexture(1, 1, 1, 1)
    overlay:SetBlendMode("ADD")
    overlay:SetAlpha(0)

    spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")

    -- Text sits on its own frame so it draws above the bar's border.
    local textLayer = CreateFrame("Frame", nil, bar)
    textLayer:SetAllPoints()
    textLayer:SetFrameLevel(barBorder:GetFrameLevel() + 1)

    timeText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", -4, 1)

    -- The label is user text, so clip it before it runs into the time.
    nameText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)

    -- Text-only readout used when the bar is disabled
    bigText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    bigText:SetJustifyH("LEFT")

    ns.TimerFrame = frame
    ns.ApplyTimerFrameSettings()
end

function ns.UpdateTimerFrame(progress, remaining, alerting, finished)
    if not frame or not frame:IsShown() then return end

    figure:SetProgress(progress, finished)

    local pulse = alerting and (0.5 + 0.5 * math.sin(GetTime() * 8)) or 0
    if frameBorderColor then TintBorder(frame, frameBorderColor, pulse) end

    if ns.db.showBar then
        bar:SetValue(progress)
        bar:SetStatusBarColor(BarColor(progress))

        if ns.db.showSpark and progress > 0 and progress < 1 then
            spark:SetPoint("CENTER", bar, "LEFT", ns.db.barWidth * progress, 0)
            spark:Show()
        else
            spark:Hide()
        end

        timeText:SetText(ns.FormatTime(remaining))
        if alerting then
            nameText:SetText(ns.GetAlertMessage())
            nameText:SetTextColor(unpack(ALERT_RGB))
        else
            nameText:SetText(ns.GetBarLabel())
            nameText:SetTextColor(1, 1, 1)
        end
        overlay:SetAlpha(pulse * 0.35)
        if barBorderColor then TintBorder(barBorder, barBorderColor, pulse) end
    else
        -- The warning text can be long, so the big readout just flashes red.
        bigText:SetText(ns.FormatTime(remaining))
        if alerting then
            bigText:SetTextColor(ALERT_RGB[1], ALERT_RGB[2] + 0.3 * pulse, ALERT_RGB[3] + 0.3 * pulse)
        else
            bigText:SetTextColor(1, 0.82, 0)
        end
    end
end
