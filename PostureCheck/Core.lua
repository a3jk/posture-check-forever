local addonName, ns = ...

ns.defaults = {
    duration = 30,          -- minutes
    sound = "bell_alliance",
    customSound = "",
    scale = 1.0,
    locked = false,
    autoRestart = true,
    showMessage = true,
    shown = true,
    showBar = true,
    showOrc = true,
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
    frameBorder = "none",
    frameBackground = "none",
    frameAlpha = 0.75,
    minimapAngle = 220,
    point = nil,
}

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

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66cc33Posture Check:|r " .. msg)
end

function ns.ResetTimer()
    timer.start = GetTime()
    timer.done = false
    timer.alertUntil = 0
end

function ns.GetRemaining()
    local total = ns.db.duration * 60
    if timer.done then return 0 end
    return math.max(total - (GetTime() - timer.start), 0)
end

local function OnComplete(now)
    ns.PlayConfiguredSound()
    if ns.db.showMessage and RaidNotice_AddMessage then
        RaidNotice_AddMessage(RaidWarningFrame, "Posture check! Sit up straight.", ChatTypeInfo["RAID_WARNING"])
    end
    timer.alertUntil = now + ALERT_SECONDS
    if ns.db.autoRestart then
        timer.start = now
    else
        timer.done = true
    end
end

local function Tick()
    local now = GetTime()
    local total = ns.db.duration * 60
    local elapsed = now - timer.start

    if not timer.done and elapsed >= total then
        OnComplete(now)
        elapsed = now - timer.start
    end

    local progress = timer.done and 1 or math.min(elapsed / total, 1)
    local remaining = timer.done and 0 or math.max(total - elapsed, 0)
    local alerting = timer.done or now < timer.alertUntil
    if ns.previewProgress then
        -- Freeze the display at a chosen point; the real timer keeps running.
        progress, remaining, alerting = ns.previewProgress, total * (1 - ns.previewProgress), false
    end
    ns.UpdateTimerFrame(progress, remaining, alerting)
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
        PostureCheckDB = CopyDefaults(ns.defaults, PostureCheckDB or {})
        ns.db = PostureCheckDB
    elseif event == "PLAYER_LOGIN" then
        ns.InitTimerFrame()
        ns.InitMinimapButton()
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
        ns.ResetTimer()
        ns.Print("Timer reset.")
    elseif cmd == "show" or cmd == "hide" then
        ns.db.shown = (cmd == "show")
        ns.ApplyTimerFrameSettings()
    elseif cmd == "lock" then
        ns.db.locked = not ns.db.locked
        ns.Print(ns.db.locked and "Frame locked." or "Frame unlocked.")
    elseif cmd == "preview" then
        local percent = tonumber(arg)
        if percent then
            ns.previewProgress = math.max(0, math.min(percent, 100)) / 100
            ns.Print(string.format("Previewing %d%%. Type /posture preview to stop.", percent))
        else
            ns.previewProgress = nil
            ns.Print("Preview off.")
        end
    else
        ns.Print("/posture [config | reset | show | hide | lock | preview <0-100>]")
    end
end
