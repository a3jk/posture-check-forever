local _, ns = ...

local COLUMN_W = 270
local CONTROL_W = 220

-- One-click setups for what the timer is used for.
local PRESETS = {
    { name = "Posture", character = ns.defaults.character, barLabel = ns.defaults.barLabel,
      alertMessage = ns.defaults.alertMessage },
    { name = "Beer", character = "pint", barLabel = "Drink up",
      alertMessage = "Bottoms up! Finish your pint." },
}

local panel
local refreshers = {}
local dropdownCount = 0
local textBoxCount = 0

local function Apply()
    ns.ApplyTimerFrameSettings()
end

local function Refresh()
    for _, refresh in ipairs(refreshers) do refresh() end
end

-- Stacks controls top-to-bottom in one column of the panel.
local function NewColumn(parent, index, title)
    local x = 20 + (index - 1) * COLUMN_W
    local col = { y = -34 }

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x, col.y)
    header:SetText(title)
    col.y = col.y - 30

    function col:Place(region, height, dx)
        region:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (dx or 0), self.y)
        self.y = self.y - height
    end

    return col
end

local function AddSlider(col, minV, maxV, step, labelFn, get, set)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    local slider = CreateFrame("Slider", nil, panel, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(CONTROL_W, 17)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    slider:EnableMouse(true)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        label:SetText(labelFn(value))
        set(value)
    end)
    refreshers[#refreshers + 1] = function()
        local value = get()
        slider:SetValue(value)
        label:SetText(labelFn(value))
    end

    col:Place(label, 52)
    return slider
end

local function AddCheckbox(col, text, key, onChange)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(text)
    cb:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    refreshers[#refreshers + 1] = function()
        cb:SetChecked(ns.db[key])
    end

    col:Place(cb, 26, -4)
    return cb
end

-- `items` is a list of { key, name } entries, or a function returning one.
local function AddDropdown(col, text, items, get, set)
    local function List()
        return type(items) == "function" and items() or items
    end

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)

    dropdownCount = dropdownCount + 1
    local dd = CreateFrame("Frame", "PostureCheckDropDown" .. dropdownCount, panel, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(dd, CONTROL_W - 30)
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, entry in ipairs(List()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.name
            info.checked = (get() == entry.key)
            info.func = function()
                UIDropDownMenu_SetText(dd, entry.name)
                set(entry.key, entry)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    refreshers[#refreshers + 1] = function()
        for _, entry in ipairs(List()) do
            if entry.key == get() then
                UIDropDownMenu_SetText(dd, entry.name)
            end
        end
    end

    col:Place(label, 54)
    return dd
end

-- Saves when the box loses focus (Enter and Escape both drop focus).
local function AddTextBox(col, text, key)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    col:Place(label, 18)

    textBoxCount = textBoxCount + 1
    local box = CreateFrame("EditBox", "PostureCheckTextBox" .. textBoxCount, panel, "InputBoxTemplate")
    box:SetSize(CONTROL_W - 6, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(255)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        ns.db[key] = strtrim(self:GetText())
    end)
    refreshers[#refreshers + 1] = function()
        box:SetText(ns.db[key] or "")
    end
    col:Place(box, 32, 6)
    return box
end

local function StyleSetting(key)
    return function() return ns.db[key] end, function(value)
        ns.db[key] = value
        Apply()
    end
end

local function BuildGeneral(col)
    AddSlider(col, 1, 120, 1,
        function(v) return string.format("Timer length: %d min", v) end,
        function() return ns.db.duration end,
        function(v) ns.db.duration = v end)

    AddSlider(col, 0.5, 2.0, 0.05,
        function(v) return string.format("Scale: %.2f", v) end,
        StyleSetting("scale"))

    local customLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local customBox = CreateFrame("EditBox", "PostureCheckCustomSound", panel, "InputBoxTemplate")

    local function UpdateCustomVisibility()
        local isCustom = ns.GetSoundEntry(ns.db.sound).custom ~= nil
        customLabel:SetShown(isCustom)
        customBox:SetShown(isCustom)
    end

    AddDropdown(col, "Alert sound", ns.GetSoundList,
        function() return ns.db.sound end,
        function(key, entry)
            ns.db.sound = key
            UpdateCustomVisibility()
            if not entry.custom then ns.PlayConfiguredSound() end
        end)
    refreshers[#refreshers + 1] = UpdateCustomVisibility

    customLabel:SetText("SoundKit ID/name, or FileDataID/path:")
    col:Place(customLabel, 16)
    customBox:SetSize(CONTROL_W - 6, 20)
    customBox:SetAutoFocus(false)
    customBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    customBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    customBox:SetScript("OnEditFocusLost", function(self)
        ns.db.customSound = strtrim(self:GetText())
    end)
    refreshers[#refreshers + 1] = function()
        customBox:SetText(ns.db.customSound or "")
    end
    col:Place(customBox, 30, 6)

    local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testButton:SetSize(106, 22)
    testButton:SetText("Test sound")
    testButton:SetScript("OnClick", function()
        customBox:ClearFocus()
        ns.db.customSound = strtrim(customBox:GetText())
        ns.PlayConfiguredSound()
    end)
    col:Place(testButton, 34)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(106, 22)
    resetButton:SetPoint("LEFT", testButton, "RIGHT", 8, 0)
    resetButton:SetText("Reset timer")
    resetButton:SetScript("OnClick", ns.ResetTimer)

    AddDropdown(col, "Character", ns.CHARACTERS, StyleSetting("character"))

    AddCheckbox(col, "Show timer", "shown", Apply)
    AddCheckbox(col, "Show character", "showOrc", Apply)
    AddCheckbox(col, "Lock timer position", "locked")
    AddCheckbox(col, "Restart automatically", "autoRestart")
end

local function BuildBar(col)
    AddCheckbox(col, "Show timer bar (off = text only)", "showBar", Apply)

    AddSlider(col, 60, 400, 5,
        function(v) return string.format("Width: %d", v) end,
        StyleSetting("barWidth"))

    AddSlider(col, 4, 40, 1,
        function(v) return string.format("Height: %d", v) end,
        StyleSetting("barHeight"))

    AddDropdown(col, "Texture", ns.BAR_TEXTURES, StyleSetting("barTexture"))
    AddDropdown(col, "Color", ns.BAR_COLORS, StyleSetting("barColor"))
    AddDropdown(col, "Border", ns.BAR_BORDERS, StyleSetting("barBorder"))

    AddCheckbox(col, "Show spark", "showSpark")
    AddCheckbox(col, "Show text on bar", "showBarText", Apply)
end

local function BuildFrame(col)
    AddDropdown(col, "Border", ns.FRAME_BORDERS, StyleSetting("frameBorder"))
    AddDropdown(col, "Background", ns.BACKGROUNDS, StyleSetting("frameBackground"))

    AddSlider(col, 0, 1, 0.05,
        function(v) return string.format("Background opacity: %d%%", math.floor(v * 100 + 0.5)) end,
        StyleSetting("frameAlpha"))

    AddSlider(col, -60, 60, 1,
        function(v) return string.format("Character offset X: %d", v) end,
        StyleSetting("characterX"))

    AddSlider(col, -60, 60, 1,
        function(v) return string.format("Character offset Y: %d", v) end,
        StyleSetting("characterY"))
end

local function BuildMessages(col)
    local labelBox = AddTextBox(col, "Bar label", "barLabel")
    local messageBox = AddTextBox(col, "Warning message", "alertMessage")

    AddCheckbox(col, "Show on-screen warning", "showMessage")
    AddCheckbox(col, "Also send it to party/raid chat", "announceGroup")

    local presetLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetLabel:SetText("Presets")
    col:Place(presetLabel, 22)

    local prev
    for _, preset in ipairs(PRESETS) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(106, 22)
        button:SetText(preset.name)
        button:SetScript("OnClick", function()
            -- Drop focus first so an open box doesn't save over the preset.
            labelBox:ClearFocus()
            messageBox:ClearFocus()
            ns.db.character = preset.character
            ns.db.barLabel = preset.barLabel
            ns.db.alertMessage = preset.alertMessage
            Apply()
            Refresh()
        end)
        if prev then
            button:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        else
            col:Place(button, 34)
        end
        prev = button
    end

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetWidth(CONTROL_W)
    hint:SetJustifyH("LEFT")
    hint:SetText("Presets set the character, bar label and warning message. "
        .. "Use the same timer length as your party to keep pace together.")
    col:Place(hint, 40)
end

local function CreatePanel()
    panel = CreateFrame("Frame", "PostureCheckOptions", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(20 + 4 * COLUMN_W, 550)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    panel:Hide()
    tinsert(UISpecialFrames, panel:GetName())

    local title = panel.TitleText or panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not panel.TitleText then title:SetPoint("TOP", 0, -5) end
    title:SetText("Posture Check")

    BuildGeneral(NewColumn(panel, 1, "General"))
    BuildBar(NewColumn(panel, 2, "Timer Bar"))
    BuildFrame(NewColumn(panel, 3, "Frame"))
    BuildMessages(NewColumn(panel, 4, "Messages"))

    panel:SetScript("OnShow", Refresh)
end

function ns.ToggleOptions()
    if not panel then CreatePanel() end
    panel:SetShown(not panel:IsShown())
end
