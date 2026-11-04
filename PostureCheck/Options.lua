local _, ns = ...

local COLUMN_W = 270
local CONTROL_W = 220
local PANEL_H = 600
local FIRST_ROW_Y = -64

local panel
local refreshers = {}   -- copy the saved settings into the controls
local updaters = {}     -- grey out or hide controls that don't apply right now
local textBoxes = {}
local dropdownCount = 0

local function Update()
    for _, update in ipairs(updaters) do update() end
end

-- Overwrites the text boxes, so don't call it while the player is typing.
local function Refresh()
    for _, refresh in ipairs(refreshers) do refresh() end
    Update()
end

-- Drops focus from the text boxes, which saves what was typed.
local function SaveTextBoxes()
    for _, box in ipairs(textBoxes) do box:ClearFocus() end
end

local function Changed()
    ns.ApplyTimerFrameSettings()
    Update()
end

-- Stacks controls top-to-bottom in one column of the panel. A control
-- placed with `isShown` only takes up space while that returns true.
local function NewColumn(index, title)
    local x = 20 + (index - 1) * COLUMN_W
    local col = { entries = {} }

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x, -34)
    header:SetText(title)

    function col:Place(region, height, dx, isShown)
        tinsert(self.entries, { region = region, height = height, dx = dx or 0, isShown = isShown })
    end

    updaters[#updaters + 1] = function()
        local y = FIRST_ROW_Y
        for _, e in ipairs(col.entries) do
            local shown = not e.isShown or e.isShown()
            if e.isShown then e.region:SetShown(shown) end
            if shown then
                e.region:ClearAllPoints()
                e.region:SetPoint("TOPLEFT", panel, "TOPLEFT", x + e.dx, y)
                y = y - e.height
            end
        end
    end
    return col
end

-- Greys out the controls while `isEnabled` returns false.
local function EnableWhen(isEnabled, ...)
    local controls = { ... }
    updaters[#updaters + 1] = function()
        local on = isEnabled() and true or false
        for _, c in ipairs(controls) do
            if c.isDropdown then
                if on then UIDropDownMenu_EnableDropDown(c) else UIDropDownMenu_DisableDropDown(c) end
            elseif c.Enable then
                if on then c:Enable() else c:Disable() end
            end
            c:SetAlpha(on and 1 or 0.5)
            if c.label then c.label:SetAlpha(on and 1 or 0.5) end
        end
    end
end

local function AddButton(col, text, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(106, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    if col then col:Place(button, 34) end
    return button
end

local function AddHint(col, text, height, isShown)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetWidth(CONTROL_W)
    hint:SetJustifyH("LEFT")
    hint:SetText(text)
    col:Place(hint, height, 0, isShown)
    return hint
end

-- `format` turns a value into text, such as "30 min".
local function AddSlider(col, text, minV, maxV, step, format, get, set)
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

    local low = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, 0)
    low:SetText(format(minV))
    local high = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, 0)
    high:SetText(format(maxV))

    local function SetLabel(value)
        label:SetText(text .. ": " .. format(value))
    end
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        SetLabel(value)
        set(value)
    end)
    refreshers[#refreshers + 1] = function()
        local value = get()
        slider:SetValue(value)
        SetLabel(value)
    end

    slider.label = label
    col:Place(label, 60)
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
        Changed()
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
    -- Shows the same entry the addon falls back to for an unknown key.
    refreshers[#refreshers + 1] = function()
        UIDropDownMenu_SetText(dd, ns.FindStyle(List(), get()).name)
    end

    dd.isDropdown = true
    dd.label = label
    col:Place(label, 54)
    return dd
end

-- Saves when the box loses focus (Enter and Escape both drop focus).
local function AddTextBox(col, text, key, isShown)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    col:Place(label, 18, 0, isShown)

    local box = CreateFrame("EditBox", "PostureCheckTextBox" .. (#textBoxes + 1), panel, "InputBoxTemplate")
    box:SetSize(CONTROL_W - 6, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(255)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        ns.db[key] = strtrim(self:GetText())
        Changed()
    end)
    refreshers[#refreshers + 1] = function()
        box:SetText(ns.db[key] or "")
    end

    box.label = label
    tinsert(textBoxes, box)
    col:Place(box, 32, 6, isShown)
    return box
end

local function StyleSetting(key)
    return function() return ns.db[key] end, function(value)
        ns.db[key] = value
        Changed()
    end
end

local function Percent(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

local function Number(v)
    return string.format("%d", v)
end

local function BuildTimer(col)
    local presetLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetLabel:SetText("Use it for")
    col:Place(presetLabel, 22)

    local prev
    for _, preset in ipairs(ns.PRESETS) do
        local button = AddButton(prev == nil and col or nil, preset.name, function()
            SaveTextBoxes()     -- so an open box doesn't save over the preset
            ns.ApplyPreset(preset)
            Refresh()
        end)
        if prev then button:SetPoint("LEFT", prev, "RIGHT", 8, 0) end
        prev = button
    end
    AddHint(col, "Sets the character, bar label and warning message. "
        .. "To keep a drinking pace together, everyone uses the same timer length.", 44)

    AddSlider(col, "Timer length", 1, 120, 1,
        function(v) return string.format("%d min", v) end,
        function() return ns.db.duration end,
        ns.SetDuration)
    AddHint(col, "Changing the length restarts the timer.", 18)

    local autoRestart = AddCheckbox(col, "Restart automatically", "autoRestart")
    EnableWhen(function() return not ns.WaitsForClick() end, autoRestart)
    AddHint(col, "The pint waits for you to click it.", 18, ns.WaitsForClick)
    AddButton(col, "Restart timer", ns.RestartTimer)

    AddTextBox(col, "Warning message", "alertMessage")
    AddCheckbox(col, "Show on-screen warning", "showMessage")
    AddCheckbox(col, "Also send it to party/raid chat", "announceGroup")

    local function IsCustomSound()
        return ns.GetSoundEntry(ns.db.sound).custom ~= nil
    end
    AddDropdown(col, "Alert sound", ns.GetSoundList,
        function() return ns.db.sound end,
        function(key, entry)
            ns.db.sound = key
            Update()
            if not entry.custom then ns.PlayConfiguredSound() end
        end)
    local customBox = AddTextBox(col, "", "customSound", IsCustomSound)
    updaters[#updaters + 1] = function()
        local kind = ns.GetSoundEntry(ns.db.sound).custom
        customBox.label:SetText(kind == "kit" and "SoundKit ID or name" or "FileDataID or file path")
    end
    AddButton(col, "Test sound", function()
        customBox:ClearFocus()
        if not ns.PlayConfiguredSound() then
            ns.Print("That sound couldn't be played, so the Raid Warning sound played instead. "
                .. "Check the ID or path.")
        end
    end)
end

local function BuildWindow(col)
    AddCheckbox(col, "Show timer window", "shown")
    AddCheckbox(col, "Lock window position", "locked")
    AddCheckbox(col, "Show minimap button", "showMinimapButton", ns.ApplyMinimapButtonSettings)
    AddSlider(col, "Scale", 0.5, 2.0, 0.05, Percent, StyleSetting("scale"))

    AddDropdown(col, "Character", ns.CHARACTERS, StyleSetting("character"))
    AddCheckbox(col, "Show character", "showCharacter")
    local offsetX = AddSlider(col, "Character offset X", -60, 60, 1, Number, StyleSetting("characterX"))
    local offsetY = AddSlider(col, "Character offset Y", -60, 60, 1, Number, StyleSetting("characterY"))
    EnableWhen(function() return ns.db.showCharacter end, offsetX, offsetY)

    AddDropdown(col, "Border", ns.FRAME_BORDERS, StyleSetting("frameBorder"))
    AddDropdown(col, "Background", ns.BACKGROUNDS, StyleSetting("frameBackground"))
    local opacity = AddSlider(col, "Background opacity", 0, 1, 0.05, Percent, StyleSetting("frameAlpha"))
    EnableWhen(function() return ns.db.frameBackground ~= "none" end, opacity)
end

local function BuildBar(col)
    AddCheckbox(col, "Show bar", "showBar")
    AddCheckbox(col, "Show time", "showTime")
    AddHint(col, "Without the bar, the time is shown as large text.", 30)

    local showLabel = AddCheckbox(col, "Show label", "showBarText")
    local labelBox = AddTextBox(col, "Label", "barLabel")
    local width = AddSlider(col, "Width", 60, 400, 5, Number, StyleSetting("barWidth"))
    local height = AddSlider(col, "Height", 4, 40, 1, Number, StyleSetting("barHeight"))
    local texture = AddDropdown(col, "Texture", ns.BAR_TEXTURES, StyleSetting("barTexture"))
    local color = AddDropdown(col, "Color", ns.BAR_COLORS, StyleSetting("barColor"))
    local border = AddDropdown(col, "Border", ns.BAR_BORDERS, StyleSetting("barBorder"))
    local spark = AddCheckbox(col, "Show spark", "showSpark")

    EnableWhen(function() return ns.db.showBar end, showLabel, width, height, texture, color, border, spark)
    EnableWhen(function() return ns.db.showBar and ns.db.showBarText end, labelBox)
end

StaticPopupDialogs.POSTURECHECK_RESET_SETTINGS = {
    text = "Reset all Posture Check settings to their defaults?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        ns.ResetSettings()
        Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function CreatePanel()
    panel = CreateFrame("Frame", "PostureCheckOptions", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(20 + 3 * COLUMN_W, PANEL_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")    -- below DIALOG, where the reset popup goes
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
    title:SetText("|cff" .. ns.ACCENT .. "Posture Check|r")

    BuildTimer(NewColumn(1, "Timer"))
    BuildWindow(NewColumn(2, "Window"))
    BuildBar(NewColumn(3, "Bar"))

    local defaults = AddButton(nil, "Defaults", function()
        SaveTextBoxes()
        StaticPopup_Show("POSTURECHECK_RESET_SETTINGS")
    end)
    defaults:SetPoint("BOTTOMRIGHT", -16, 14)

    panel:SetScript("OnShow", Refresh)
end

function ns.OpenOptions()
    if not panel then CreatePanel() end
    panel:Show()
end

function ns.ToggleOptions()
    if not panel then CreatePanel() end
    panel:SetShown(not panel:IsShown())
end

-- Picks up changes made elsewhere, such as slash commands.
function ns.RefreshOptions()
    if panel and panel:IsShown() then Refresh() end
end

-- A page in the game's own AddOns settings that opens the panel above.
function ns.InitOptions()
    local page = CreateFrame("Frame")
    page.name = "Posture Check"

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(page.name)

    local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    open:SetSize(160, 22)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    open:SetText("Open settings")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        ns.OpenOptions()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(page, page.name))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
end
