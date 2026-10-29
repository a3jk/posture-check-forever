local _, ns = ...

-- Built-in sound choices. Entries use either a FileDataID (`file`) or a
-- SOUNDKIT key (`kit`). Kit entries missing from the client are skipped.
local SOUNDS = {
    { key = "bell_alliance",  name = "Bell Toll (Alliance)",  file = 566564 },
    { key = "bell_horde",     name = "Bell Toll (Horde)",     file = 565853 },
    { key = "bell_nightelf",  name = "Bell Toll (Night Elf)", file = 566558 },
    { key = "bell_tribal",    name = "Bell Toll (Tribal)",    file = 566027 },
    { key = "raid_warning",   name = "Raid Warning",          kit = "RAID_WARNING" },
    { key = "ready_check",    name = "Ready Check",           kit = "READY_CHECK" },
    { key = "alarm2",         name = "Alarm Clock",           kit = "ALARM_CLOCK_WARNING_2" },
    { key = "alarm3",         name = "Alarm Clock (loud)",    kit = "ALARM_CLOCK_WARNING_3" },
    { key = "quest_complete", name = "Quest Complete",        kit = "IG_QUEST_LIST_COMPLETE" },
    { key = "whisper",        name = "Whisper",               kit = "TELL_MESSAGE" },
    { key = "custom_kit",     name = "Custom: SoundKit ID or name", custom = "kit" },
    { key = "custom_file",    name = "Custom: File ID or path",     custom = "file" },
}

local CHANNEL = "Master"

function ns.GetSoundList()
    local list = {}
    for _, entry in ipairs(SOUNDS) do
        if not entry.kit or (SOUNDKIT and SOUNDKIT[entry.kit]) then
            list[#list + 1] = entry
        end
    end
    return list
end

function ns.GetSoundEntry(key)
    for _, entry in ipairs(SOUNDS) do
        if entry.key == key then
            return entry
        end
    end
    return SOUNDS[1]
end

local function PlayKit(id)
    if type(id) == "string" then
        id = SOUNDKIT and SOUNDKIT[id:upper()]
    end
    if not id then return false end
    local ok, willPlay = pcall(PlaySound, id, CHANNEL)
    return ok and willPlay ~= false
end

local function PlayFile(file)
    local ok, willPlay = pcall(PlaySoundFile, file, CHANNEL)
    return ok and willPlay ~= false
end

function ns.PlayConfiguredSound()
    local entry = ns.GetSoundEntry(ns.db.sound)
    local played

    if entry.file then
        played = PlayFile(entry.file)
    elseif entry.kit then
        played = PlayKit(entry.kit)
    elseif entry.custom then
        local text = strtrim(ns.db.customSound or "")
        local value = tonumber(text) or (text ~= "" and text) or nil
        if value then
            if entry.custom == "kit" then
                played = PlayKit(value)
            else
                played = PlayFile(value)
            end
        end
    end

    if not played then
        PlayKit("RAID_WARNING")
    end
end
