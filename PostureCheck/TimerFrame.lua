local _, ns = ...

-- The character (3D peon or pixel orc) stands on the left, next to either a
-- progress bar or (with the bar disabled) a large time readout. Borders and
-- backgrounds come from Styles.lua.

local GAP = 12
local PAD = 8
local ALERT_RGB = { 1, 0.2, 0.2 }
local CHARACTERS = { peon = "CreatePeon", pixel = "CreateOrc" }

local frame, figure, bar, barBorder, castBorder, overlay, spark, nameText, timeText, bigText
local barBorderColor, frameBorderColor  -- base colors, tinted red while alerting
local figures = {}

-- Characters are created the first time they are picked.
local function SelectFigure()
    local key = CHARACTERS[ns.db.character] and ns.db.character or "peon"
    if not figures[key] then
        figures[key] = ns[CHARACTERS[key]](frame)
    end
    for k, f in pairs(figures) do
        f.frame:SetShown(k == key and ns.db.showOrc)
    end
    figure = figures[key]
end

local function SavePosition(self)
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.point = { point, relPoint, x, y }
end

local function FormatTime(remaining)
    local secs = math.ceil(remaining)
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
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
    local rgb = ns.FindStyle(ns.BAR_COLORS, mode).rgb or { 1, 0.7, 0 }
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
    timeText:SetShown(db.showBarText)

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

-- Returns the padding between the frame edge and its content.
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
    local showOrc, showBar = db.showOrc, db.showBar
    local pad = ApplyFrameStyle()
    local outset = ApplyBarStyle()
    SelectFigure()
    local orcW, orcH = figure.frame:GetSize()

    bar:SetShown(showBar)
    bigText:SetShown(not showBar)

    local content = showBar and bar or bigText
    local contentW = showBar and (db.barWidth + 2 * outset) or 80
    local contentH = showBar and (db.barHeight + 2 * outset) or 24
    local innerW = (showOrc and (orcW + GAP) or 0) + contentW
    local innerH = math.max(showOrc and orcH or 0, contentH)
    local frameH = innerH + 2 * pad
    frame:SetSize(innerW + 2 * pad, frameH)

    -- The character and the bar/text share the frame's vertical centre; the
    -- character can be nudged from there with the offset settings.
    figure.frame:ClearAllPoints()
    figure.frame:SetPoint("LEFT", frame, "LEFT", pad + db.characterX, db.characterY)

    local x = pad + (showOrc and (orcW + GAP) or 0) + (showBar and outset or 0)
    content:ClearAllPoints()
    content:SetPoint("LEFT", frame, "LEFT", x, 0)
end

function ns.ApplyTimerFrameSettings()
    if not frame then return end
    Layout()
    frame:SetScale(ns.db.scale)
    frame:ClearAllPoints()
    local p = ns.db.point
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    frame:SetShown(ns.db.shown)
end

function ns.InitTimerFrame()
    frame = CreateFrame("Frame", "PostureCheckFrame", UIParent, "BackdropTemplate")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not ns.db.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.ResetTimer() end
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Posture Check")
        if not ns.db.locked then
            GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine("Right-click: reset timer", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
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

    nameText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", 4, 1)

    timeText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", -4, 1)

    -- Text-only readout used when the bar is disabled
    bigText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    bigText:SetJustifyH("LEFT")

    ns.TimerFrame = frame
    ns.ApplyTimerFrameSettings()
end

function ns.UpdateTimerFrame(progress, remaining, alerting)
    if not frame or not frame:IsShown() then return end

    figure:SetHunch(progress)

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

        timeText:SetText(FormatTime(remaining))
        if alerting then
            nameText:SetText("Sit up straight!")
            nameText:SetTextColor(1, 0.25, 0.25)
        else
            nameText:SetText("Posture Check")
            nameText:SetTextColor(1, 1, 1)
        end
        overlay:SetAlpha(pulse * 0.35)
        if barBorderColor then TintBorder(barBorder, barBorderColor, pulse) end
    else
        if alerting then
            bigText:SetText("Sit up!")
            bigText:SetTextColor(1, 0.25 + 0.3 * pulse, 0.25 + 0.3 * pulse)
        else
            bigText:SetText(FormatTime(remaining))
            bigText:SetTextColor(1, 0.82, 0)
        end
    end
end
