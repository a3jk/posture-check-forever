local addonName, ns = ...

ns.ACCENT = "66cc33"    -- hex color for the addon's name in chat and titles

ns.defaults = {
    duration = 30,          -- minutes
    sound = "bell_alliance",
    customSound = "",
    scale = 1.0,
    locked = false,
    autoRestart = true,
    showMessage = true,
    announceGroup = false,
    barLabel = "Posture Check",
    alertMessage = "Posture check! Sit up straight.",
    shown = true,
    showBar = true,
    showCharacter = true,
    character = "peon",
    characterX = 0,
    characterY = 0,
    barWidth = 195,
    barHeight = 13,
    barTexture = "blizzard",
    barColor = "gradient",
    barBorder = "castbar",
    showSpark = true,
    showBarText = true,
    showTime = true,
    frameBorder = "none",
    frameBackground = "none",
    frameAlpha = 0.75,
    showMinimapButton = true,
    minimapAngle = 220,
    uplift = false,
}

-- One-click setups for what the timer is used for. They only change what
-- depends on the purpose; the sound and the looks are left alone.
ns.PRESETS = {
    { name = "Posture", character = "peon", barLabel = ns.defaults.barLabel,
      alertMessage = ns.defaults.alertMessage },
    { name = "Beer", character = "pint", barLabel = "Drink up",
      alertMessage = "Bottoms up! Finish your pint." },
}

local DB_VERSION = 3
-- Saved keys without a default, which a settings reset leaves alone.
local EXTRA_KEYS = { point = true, dbVersion = true, upliftDay = true, upliftCount = true, upliftGreeted = true }
local ALERT_SECONDS = 5

local timer = { start = 0, done = false, alertUntil = 0 }

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function Migrate(db)
    if (db.dbVersion or 1) < 2 then
        if db.showOrc ~= nil then db.showCharacter = db.showOrc end
        -- The window position used to be saved in the window's own scale.
        if db.point and db.scale then
            db.point[3], db.point[4] = db.point[3] * db.scale, db.point[4] * db.scale
        end
    end
    -- 1.2.0 had the uplifting checkbox on by default; start everyone with it off.
    if (db.dbVersion or 1) < 3 then
        db.uplift = nil
    end
    db.dbVersion = DB_VERSION
    for k in pairs(db) do
        if ns.defaults[k] == nil and not EXTRA_KEYS[k] then
            db[k] = nil
        end
    end
    return db
end

-- Resets choices whose saved key is no longer offered, such as a removed
-- style or a sound this client doesn't have.
local function ValidateChoices()
    local choices = {
        character = ns.CHARACTERS,
        sound = ns.GetSoundList(),
        barTexture = ns.BAR_TEXTURES,
        barColor = ns.BAR_COLORS,
        barBorder = ns.BAR_BORDERS,
        frameBorder = ns.FRAME_BORDERS,
        frameBackground = ns.BACKGROUNDS,
    }
    for key, list in pairs(choices) do
        local found = false
        for _, entry in ipairs(list) do
            if entry.key == ns.db[key] then found = true end
        end
        if not found then ns.db[key] = ns.defaults[key] end
    end
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. ns.ACCENT .. "Posture Check:|r " .. msg)
end

function ns.FormatTime(remaining)
    local secs = math.ceil(remaining)
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

function ns.ApplyPreset(preset)
    ns.db.character = preset.character
    ns.db.barLabel = preset.barLabel
    ns.db.alertMessage = preset.alertMessage
    ns.ApplyTimerFrameSettings()
end

-- Restores every setting except where the window and minimap button are.
function ns.ResetSettings()
    for k, v in pairs(ns.defaults) do
        if k ~= "minimapAngle" then
            ns.db[k] = v
        end
    end
    ns.ApplyTimerFrameSettings()
    ns.ApplyMinimapButtonSettings()
end

function ns.ResetTimer()
    timer.start = GetTime()
    timer.done = false
    timer.alertUntil = 0
end

-- A restart the player asked for, from any of the places that offer it.
function ns.RestartTimer()
    ns.ResetTimer()
    ns.Print("Timer restarted.")
end

-- A new length starts a new timer, so a shorter one can't go off at once.
function ns.SetDuration(minutes)
    if minutes == ns.db.duration then return end
    ns.db.duration = minutes
    ns.ResetTimer()
end

function ns.GetRemaining()
    local total = ns.db.duration * 60
    if timer.done then return 0 end
    return math.max(total - (GetTime() - timer.start), 0)
end

function ns.IsFinished()
    return timer.done
end

-- True when the shown character (the pint) is the way to restart the timer.
function ns.WaitsForClick()
    local entry = ns.FindStyle(ns.CHARACTERS, ns.db.character)
    return entry.waitsForClick == true and ns.db.shown and ns.db.showCharacter
end

local function TextOrDefault(key)
    local text = strtrim(ns.db[key] or "")
    return text ~= "" and text or ns.defaults[key]
end

function ns.GetAlertMessage()
    return TextOrDefault("alertMessage")
end

function ns.GetBarLabel()
    return TextOrDefault("barLabel")
end

local function GroupChannel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

local function OnComplete(now)
    ns.PlayConfiguredSound()
    local msg = ns.GetAlertMessage()
    if ns.db.showMessage and RaidNotice_AddMessage then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    local channel = ns.db.announceGroup and GroupChannel()
    if channel then
        SendChatMessage(msg, channel)
    end
    timer.alertUntil = now + ALERT_SECONDS
    if ns.db.autoRestart and not ns.WaitsForClick() then
        timer.start = now
    else
        timer.done = true
        if not ns.WaitsForClick() then
            ns.Print("Right-click the timer window or type /posture reset to start again.")
        end
    end
end

local function Tick()
    local now = GetTime()
    local total = ns.db.duration * 60

    -- A timer left waiting for the pint carries on once nothing waits for a
    -- click any more (another character picked, or the pint hidden).
    if timer.done and ns.db.autoRestart and not ns.WaitsForClick() then
        ns.ResetTimer()
    end

    local elapsed = now - timer.start
    if not timer.done and elapsed >= total then
        OnComplete(now)
        elapsed = now - timer.start
    end

    local progress = timer.done and 1 or math.min(elapsed / total, 1)
    local remaining = timer.done and 0 or math.max(total - elapsed, 0)
    local alerting = timer.done or now < timer.alertUntil
    local finished = timer.done
    if ns.previewProgress then
        -- Freeze the display at a chosen point; the real timer keeps running.
        progress, remaining, alerting, finished = ns.previewProgress, total * (1 - ns.previewProgress), false, false
    end
    ns.UpdateTimerFrame(progress, remaining, alerting, finished)
end

-- The timer runs on its own frame so it keeps ticking while the display is hidden.
local driver = CreateFrame("Frame")
local throttle = 0

local function OnUpdate(_, dt)
    throttle = throttle + dt
    if throttle < 0.05 then return end
    throttle = 0
    Tick()
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        PostureCheckDB = CopyDefaults(ns.defaults, Migrate(PostureCheckDB or {}))
        ns.db = PostureCheckDB
    elseif event == "PLAYER_LOGIN" then
        ValidateChoices()
        ns.InitTimerFrame()
        ns.InitMinimapButton()
        ns.InitOptions()
        ns.InitUplift()
        ns.ResetTimer()
        self:SetScript("OnUpdate", OnUpdate)
    end
end)

SLASH_POSTURECHECK1 = "/posture"
SLASH_POSTURECHECK2 = "/pcheck"
SlashCmdList.POSTURECHECK = function(msg)
    local cmd, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleOptions()
    elseif cmd == "reset" then
        ns.RestartTimer()
    elseif cmd == "show" or cmd == "hide" then
        ns.db.shown = (cmd == "show")
        ns.ApplyTimerFrameSettings()
        ns.Print(ns.db.shown and "Timer window shown." or "Timer window hidden.")
    elseif cmd == "lock" then
        ns.db.locked = not ns.db.locked
        ns.Print(ns.db.locked and "Window locked." or "Window unlocked.")
    elseif cmd == "minimap" then
        ns.db.showMinimapButton = not ns.db.showMinimapButton
        ns.ApplyMinimapButtonSettings()
        ns.Print(ns.db.showMinimapButton and "Minimap button shown."
            or "Minimap button hidden. Type /posture minimap to bring it back.")
    elseif cmd == "preview" then
        local percent = tonumber(arg)
        if percent then
            percent = math.floor(math.max(0, math.min(percent, 100)))
            ns.previewProgress = percent / 100
            ns.Print(string.format("Previewing %d%%. Type /posture preview to stop.", percent))
        else
            ns.previewProgress = nil
            ns.Print("Preview off.")
        end
    else
        ns.Print("/posture [config | reset | show | hide | lock | minimap | preview <0-100>]")
    end
    ns.RefreshOptions()
end
