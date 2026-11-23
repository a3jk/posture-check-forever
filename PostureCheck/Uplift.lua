local _, ns = ...

-- Shares kind words with the guild while the uplifting checkbox is ticked:
--  * now and then, an inspirational message (at most MAX_PER_DAY a day per
--    account, at random moments);
--  * a greeting when a guild member comes online (each member at most once
--    a day, and never more often than every GREET_GAP seconds);
--  * a welcome when someone new joins the guild.
-- Greetings and welcomes wait a few seconds first, and are dropped if anyone
-- (another player, or another copy of this addon) says the name in guild
-- chat meanwhile, so the guild isn't flooded with them.

local MAX_PER_DAY = 2
local FIRST_DELAY = { 20 * 60, 90 * 60 }      -- seconds after logging in
local NEXT_DELAY = { 2 * 3600, 5 * 3600 }     -- seconds after a message was sent
local RETRY_DELAY = { 30 * 60, 75 * 60 }      -- when nothing could be sent
local GREET_DELAY = { 4, 15 }                 -- seconds before a greeting or welcome
local GREET_GAP = 10 * 60                     -- seconds between sign-in greetings

local MESSAGES = {
    "Every great adventurer started at level 1. Keep questing, friends!",
    "No raid boss is too big when you have the right people beside you. Glad to have you all.",
    "Remember to rest up like you're at the inn. The rested XP of life is real.",
    "The road from Goldshire to glory is long, but every step counts. Proud of all of you!",
    "A wipe is just a lesson with a repair bill. You've got this, guild.",
    "Be the healer you wish to see in the world.",
    "Some days you're the tank, some days you're the loot. Both are fine. Have a great one!",
    "Small kindnesses are like Major Healing Potions for the soul. Hand them out freely.",
    "Even the mightiest dragons were once whelps. Keep growing, everyone.",
    "Hearthstone home when you need to, but never forget how far you've already travelled.",
    "Your worth isn't measured in gear score. You're all epic quality to me.",
    "Every grind ends eventually, and the view from the top of the mountain is worth it.",
    "Like a well-timed buff: just a reminder that this guild makes everything better.",
    "Take a breath, stretch a little, drink some water. Then go be legendary.",
    "Fortune favours the bold, and so does the loot table. Good luck out there!",
    "The best mount in Azeroth is a good friend who waits for you at the flight path.",
    "When the world feels like a 40-man raid with no tank, remember: one step at a time.",
    "You can't control the drop rates, but you can control how kind you are. Make it count.",
    "Wherever your journey takes you today, may your path be free of elites and full of herbs.",
    "Some heroes wear tier sets. Some just show up for their friends. Both are heroes.",
    "A guild is like a campfire: it stays warm because everyone brings a little wood.",
    "Don't fear the corpse run. Every comeback starts with getting back up.",
    "May your bags be full, your repairs be cheap, and your day be wonderful.",
    "Remember to look up from the minimap once in a while. Azeroth is beautiful, and so is today.",
    "Patience is the rarest drop of all, and you all seem to have farmed plenty. Thank you!",
    "Even a murloc finds its way home eventually. Keep going, and be kind to yourself.",
    "The real epic loot was the friends we grouped with along the way.",
    "Not every quest is easy, but every quest can be finished. Believe in yourselves!",
    "Today's a great day to /hug someone. Consider yourselves hugged.",
    "Stay hydrated, stay positive, and always loot the chest.",
}

-- %s is the member's name.
local GREETINGS = {
    "Welcome back, %s! Azeroth got a little brighter just now.",
    "%s has entered the world! May your loot be epic and your queues be short.",
    "Hey %s! Good to see you. The inn kept your seat warm.",
    "Look who's online! Hi %s, hope today treats you like a lucky drop.",
    "%s is here! Everybody act natural... and also, hello!",
    "Welcome back, %s. Your rested XP missed you, and so did we.",
    "Hi %s! May your path be clear and your bags be roomy.",
    "%s logged in, and somewhere a murloc cheered. Welcome back!",
    "Good to have you back, %s! Ready for another adventure?",
    "Greetings, %s! The guild hall feels complete again.",
    "Welcome, %s! Grab a drink, stretch those legs, and conquer the day.",
    "Ah, %s! Just in time. Things are always better with you around.",
    "%s has arrived! Hearthstone to happiness, as they say.",
    "Hello %s! Wishing you crits, good company and zero corpse runs.",
    "There you are, %s! May the RNG gods smile on you today.",
    "Welcome back to Azeroth, %s. Let's make it a legendary session.",
    "%s is online! Somebody buff this person with good vibes.",
    "Hey hey, %s! Hope your day has been as smooth as a flight path.",
    "Hi %s! The world is full of quests, and you're the hero for them.",
    "Nice to see you, %s! Remember to have fun out there.",
    "Welcome back, %s! May your repairs be cheap and your gold plentiful.",
    "%s joins us once again! A fine day for adventuring.",
    "Hello, %s! Even the Crossroads is happier when you're online.",
    "%s has logged in. Morale +10. Welcome back!",
    "Hey %s, good to see you! Don't forget to check the auction house for bargains.",
    "Welcome home, %s. The guild fire is warm and the company is good.",
    "Oh hi, %s! Your arrival has been noted with great joy.",
    "%s is back! Let the questing commence.",
    "Hi %s! Today's forecast: sunny, with a high chance of epic drops.",
    "Welcome back, %s! Sit up straight and go be awesome.",
}

-- %s is the new member's name.
local WELCOMES = {
    "Welcome to the guild, %s! We're so glad you're here.",
    "A new adventurer joins us! Welcome aboard, %s!",
    "Everyone say hi to %s, our newest guildmate! Welcome!",
    "Welcome, %s! May this guild be your inn, your hearth and your raid group.",
    "%s has joined the guild! Let the adventures together begin.",
    "Welcome to the family, %s! Don't be shy, ask us anything.",
    "Big welcome to %s! The guild just got a little more legendary.",
    "Hello and welcome, %s! Pull up a chair by the fire.",
    "Welcome, %s! May your stay here be long and your loot be plentiful.",
    "The guild grows stronger! Welcome, %s!",
    "Welcome, %s! You've just unlocked the best achievement: friends.",
    "Hey %s, welcome! Every great story needs a new hero, and here you are.",
    "%s, welcome to the guild! We're happy to have you with us in Azeroth.",
    "A warm welcome to %s! Glad our paths crossed.",
    "Welcome aboard, %s! The tabard looks great on you.",
    "Hooray, %s has joined! Welcome to the team.",
    "Welcome, %s! If you ever need a hand, a group or a laugh, we're here.",
    "Please welcome %s! Another brave soul joins the cause.",
    "Welcome to the guild, %s! The road ahead is long, but you won't walk it alone.",
    "%s is one of us now! Welcome, and may your adventures be epic.",
    "Welcome, %s! Consider this your first guild buff: +100 friendship.",
    "Look who just joined! Welcome, %s. We saved you a spot.",
    "Welcome to the guild, %s! Fortune favours the bold, and you just made a bold choice.",
    "Glad to have you, %s! Welcome to the best guild in Azeroth (we're a little biased).",
    "A new name on the roster! Welcome, %s!",
    "Welcome, %s! Grab some bread and water and make yourself at home.",
    "Hi %s, and welcome! May every dungeon you run with us be a smooth one.",
    "Welcome to the guild, %s! Your adventure just got a lot more fun.",
    "Welcome, %s! The guild hall doors are always open for you.",
    "Everyone give %s a warm welcome! So happy you're here.",
}

local lastPick = {}          -- the list's last message, to avoid repeats
local pending = {}           -- short name -> true while a greeting or welcome waits
local guildNames = {}        -- short names of guild members, from the roster
local lastGreet = -math.huge

local function Today()
    return date("%Y-%m-%d")
end

-- Starts the daily counters over when the day has changed.
local function CheckDay()
    if ns.db.upliftDay ~= Today() then
        ns.db.upliftDay = Today()
        ns.db.upliftCount = 0
        ns.db.upliftGreeted = {}
    end
    ns.db.upliftCount = ns.db.upliftCount or 0
    ns.db.upliftGreeted = ns.db.upliftGreeted or {}
end

local function Pick(list)
    local index
    repeat
        index = math.random(#list)
    until #list < 2 or index ~= lastPick[list]
    lastPick[list] = index
    return list[index]
end

local function ShortName(name)
    return name and (Ambiguate and Ambiguate(name, "short") or name:match("^[^-]+"))
end

local function CanSpeak()
    return ns.db.uplift and IsInGuild()
end

-- Inspirational messages

local Schedule

local function TrySend()
    CheckDay()
    if not CanSpeak() or ns.db.upliftCount >= MAX_PER_DAY then
        Schedule(RETRY_DELAY)
        return
    end
    SendChatMessage(Pick(MESSAGES), "GUILD")
    ns.db.upliftCount = ns.db.upliftCount + 1
    Schedule(NEXT_DELAY)
end

Schedule = function(range)
    C_Timer.After(math.random(range[1], range[2]), TrySend)
end

-- Greetings and welcomes

-- Turns a global string such as "%s has joined the guild." into a pattern
-- that captures the name.
local function ToPattern(text)
    if not text then return nil end
    text = text:gsub("%%%d?%$?s", "\0")
    text = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return "^" .. text:gsub("%z", "(.-)") .. "$"
end

local ONLINE_PATTERN = ToPattern(ERR_FRIEND_ONLINE_SS)
local JOIN_PATTERN = ToPattern(ERR_GUILD_JOIN_S)

local function RequestRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function UpdateRoster()
    wipe(guildNames)
    for i = 1, GetNumGuildMembers() do
        local name = ShortName(GetGuildRosterInfo(i))
        if name then guildNames[name] = true end
    end
end

-- Says the message after a short pause, unless someone says the name first.
local function SayLater(name, list, onSent)
    pending[name] = true
    C_Timer.After(math.random(GREET_DELAY[1], GREET_DELAY[2]), function()
        if not pending[name] then return end
        pending[name] = nil
        if not CanSpeak() then return end
        SendChatMessage(Pick(list):format(name), "GUILD")
        if onSent then onSent() end
    end)
end

local function OnMemberOnline(name)
    CheckDay()
    if not guildNames[name] or ns.db.upliftGreeted[name] or pending[name] then return end
    if GetTime() - lastGreet < GREET_GAP then return end
    lastGreet = GetTime()     -- also counts a greeting someone else beats us to
    SayLater(name, GREETINGS, function()
        ns.db.upliftGreeted[name] = true
    end)
end

local function OnMemberJoined(name)
    guildNames[name] = true
    if pending[name] then return end
    SayLater(name, WELCOMES)
end

local function OnSystemMessage(text)
    if not CanSpeak() then return end
    local name = ONLINE_PATTERN and text:match(ONLINE_PATTERN)
    if name then
        name = ShortName(name)
        if name ~= UnitName("player") then OnMemberOnline(name) end
        return
    end
    name = JOIN_PATTERN and text:match(JOIN_PATTERN)
    if name then
        name = ShortName(name)
        if name ~= UnitName("player") then OnMemberJoined(name) end
    end
end

-- Someone already said hello (or something else) to them, so stay quiet.
local function OnGuildChat(text)
    for name in pairs(pending) do
        if text:lower():find(name:lower(), 1, true) then
            pending[name] = nil
        end
    end
end

function ns.InitUplift()
    local events = CreateFrame("Frame")
    events:RegisterEvent("CHAT_MSG_SYSTEM")
    events:RegisterEvent("CHAT_MSG_GUILD")
    events:RegisterEvent("GUILD_ROSTER_UPDATE")
    events:SetScript("OnEvent", function(_, event, text)
        if event == "CHAT_MSG_SYSTEM" then
            OnSystemMessage(text)
        elseif event == "CHAT_MSG_GUILD" then
            OnGuildChat(text)
        else
            UpdateRoster()
        end
    end)
    RequestRoster()
    Schedule(FIRST_DELAY)
end
