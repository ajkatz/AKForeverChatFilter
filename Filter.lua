-- Filter: the one way in. The client's own message event filter hands every channel line to a callback
-- before a chat window shows it; the callback returns true and the window skips the line. Nothing of
-- Blizzard's is hooked or rewritten, no chat window is touched.
--
-- Every line the filter decides on is kept in the saved file with its verdict and reason (db.log, the
-- last few hundred): that is what the review window shows and what '/gtf diag' carries.
--
-- One line reaches EVERY chat window that shows its channel, so the callback runs once per window for
-- the same line; the verdict is remembered by the line's id and given again, without a second entry.
local _, ns = ...

local Filter = {}
ns.Filter = Filter

local LOG_MAX = 800     -- lines kept in the saved file, newest last (a session of Trade runs to several hundred)
local RECENT_MAX = 80   -- line ids whose verdict is remembered

-- Blizzard's own numbers for the city channels (zoneChannelID); the name is the fallback
local ZONE_CHANNELS = { [1] = "general", [2] = "trade" }

Filter.stats = { seen = 0, hidden = 0, kept = 0, secret = 0 }
Filter.how = "not registered yet"

local recent, recentOrder = {}, {}

local function remember(lineID, verdict)
    if recent[lineID] then
        return
    end
    recent[lineID] = verdict
    recentOrder[#recentOrder + 1] = lineID
    if #recentOrder > RECENT_MAX then
        recent[table.remove(recentOrder, 1)] = nil
    end
end

-- "trade" | "services" | "general" | "public" | nil - which of the channels this addon knows a line came
-- from. "public" is any other channel of the game's own (LocalDefense, LookingForGroup ...: they carry a
-- zone channel number); a channel players made themselves is nobody's business and gives nil.
function Filter.ChannelKind(zoneChannelID, channelBaseName, channelName)
    if type(zoneChannelID) == "number" and ZONE_CHANNELS[zoneChannelID] then
        return ZONE_CHANNELS[zoneChannelID]
    end
    for _, name in ipairs({ channelBaseName or false, channelName or false }) do
        if type(name) == "string" then
            local lower = string.lower(name)
            lower = string.gsub(lower, "^%d+%.%s*", "") -- "2. Trade - City"
            if string.find(lower, "^trade") then
                return "trade"
            elseif string.find(lower, "^services") then
                return "services"
            elseif string.find(lower, "^general") then
                return "general"
            end
        end
    end
    if type(zoneChannelID) == "number" and zoneChannelID > 0 then
        return "public"
    end
    return nil
end

-- the line's entry in the saved log
function Filter.Record(entry)
    local db = ns.db
    if not db then
        return entry
    end
    db.serial = (db.serial or 0) + 1
    entry.id = db.serial
    db.log = db.log or {}
    local log = db.log
    log[#log + 1] = entry
    while #log > LOG_MAX do
        table.remove(log, 1)
    end
    return entry
end

function Filter.EntryById(id)
    local log = ns.db and ns.db.log or {}
    for index = #log, 1, -1 do
        if log[index].id == id then
            return log[index], index
        end
    end
    return nil
end

-- Which kinds of line stay, as a table { trade = true, ... }. A setting saved by the first version
-- ("strict" / "balanced") is read as its preset.
function Filter.Shown()
    local options = ns.cdb and ns.cdb.options
    local kinds = options and options.kinds
    if type(kinds) ~= "table" then
        local preset = options and ns.Rules.PRESETS[options.mode]
        kinds = preset or ns:GetOption("kinds")
    end
    return kinds
end

-- "trade" | "game" | "chat" | "custom": the preset the kinds match, if any
function Filter.ModeName()
    local shown = Filter.Shown()
    for _, name in ipairs({ "trade", "game", "chat" }) do
        local preset, same = ns.Rules.PRESETS[name], true
        for kind, on in pairs(preset) do
            if (shown[kind] == true) ~= on then
                same = false
            end
        end
        if same then
            return name
        end
    end
    return "custom"
end

local function setKinds(kinds)
    local copy = {}
    for kind, on in pairs(kinds) do
        copy[kind] = on and true or false
    end
    ns:SetOption("kinds", copy)
end

-- The verdict for a line that reached the filter for the first time: scored, counted, logged.
function Filter.Decide(kind, sender, text)
    local now = GetTime()
    local verdict = ns.Rules.Verdict(text, Filter.Shown(), sender, now, ns:GetOption("sticky") ~= false, ns:GetOption("answers") == true)
    local stats = Filter.stats
    stats.seen = stats.seen + 1
    if verdict.keep then
        stats.kept = stats.kept + 1
    else
        stats.hidden = stats.hidden + 1
    end
    local entry = Filter.Record({
        t = type(time) == "function" and time() or math.floor(now),
        ch = kind,
        who = type(sender) == "string" and sender or "?",
        text = text,
        keep = verdict.keep,
        kind = verdict.kind,
        why = verdict.reason,
        score = verdict.score,
        work = verdict.work,
    })
    return verdict
end

-- A line in a public channel the full filter does not run on: only an advert goes - a web address, a
-- seller for real money, the anal joke. Everything else is left alone and leaves no trace: not counted, not logged.
function Filter.DecideAdvert(kind, sender, text)
    local reason, verdict = ns.Rules.Advert(text)
    if not reason then
        return { keep = true }
    end
    local stats = Filter.stats
    stats.seen, stats.hidden = stats.seen + 1, stats.hidden + 1
    stats.adverts = (stats.adverts or 0) + 1
    Filter.Record({
        t = type(time) == "function" and time() or math.floor(GetTime()),
        ch = kind,
        who = type(sender) == "string" and sender or "?",
        text = text,
        keep = false,
        kind = "world",
        why = reason,
        score = verdict.score,
        work = verdict.work,
    })
    return { keep = false }
end

-- The callback. Its arguments are the event's: text, sender, language, channel name, target, flags,
-- zone channel id, channel index, channel base name, language id, line id, sender guid, ...
local function onMessage(chatFrame, event, text, sender, _, channelName, _, _, zoneChannelID, _, channelBaseName, _, lineID)
    if not ns:GetOption("enabled") then
        return
    end
    local kind = Filter.ChannelKind(zoneChannelID, channelBaseName, channelName)
    if not kind then
        return
    end
    -- the whole filter where it is switched on (Trade, Services, General when asked); elsewhere in
    -- public, adverts only
    local whole = kind ~= "public" and ns:GetOption(kind) == true
    if not whole and (kind == "trade" or kind == "services" or ns:GetOption("adverts") == false) then
        return
    end
    if ns.AnySecret(text, sender, lineID) or type(text) ~= "string" then
        Filter.stats.secret = Filter.stats.secret + 1
        return -- unreadable: hands off, the line goes through
    end
    local verdict = type(lineID) == "number" and recent[lineID] or nil
    if not verdict then
        verdict = whole and Filter.Decide(kind, sender, text) or Filter.DecideAdvert(kind, sender, text)
        if type(lineID) == "number" then
            remember(lineID, verdict)
        end
    end
    if not verdict.keep then
        return true
    end
end

local function safeOnMessage(...)
    local ok, discard = ns.SafeCall(onMessage, ...)
    if ok then
        return discard
    end
end

local function register()
    local add = (type(ChatFrameUtil) == "table" and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(add) ~= "function" then
        Filter.how = "this client has no message event filter"
        ns:Log("filter_missing", Filter.how)
        return
    end
    local ok, err = pcall(add, "CHAT_MSG_CHANNEL", safeOnMessage)
    if ok then
        Filter.how = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) and "ChatFrameUtil.AddMessageEventFilter" or "ChatFrame_AddMessageEventFilter"
    else
        Filter.how = "registering failed: " .. tostring(err)
        ns:Log("filter_failed", Filter.how)
    end
end

ns:Listen("LOGIN", function()
    ns.Rules.Rebuild(ns.db and ns.db.words)
    ns.Rules.SetMemes(ns.db and ns.db.memes)
    register()
end)

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
local MODE_WORDS = {
    trade = "trade (trade only)",
    game = "game (everything about the game: trade, groups, guilds, questions, talk)",
    chat = "chat (everything but the world outside)",
}

local function describeKinds()
    local shown, on, off = Filter.Shown(), {}, {}
    for _, kind in ipairs(ns.Rules.KINDS) do
        if kind ~= "world" then
            if shown[kind] then
                on[#on + 1] = kind
            else
                off[#off + 1] = kind
            end
        end
    end
    return "shown: " .. (#on > 0 and table.concat(on, ", ") or "nothing") .. "; hidden: " .. (#off > 0 and table.concat(off, ", ") or "nothing") .. " - and the world outside, always"
end

local function describeMode()
    local mode = Filter.ModeName()
    if mode == "custom" then
        return "custom (" .. describeKinds() .. ")"
    end
    return MODE_WORDS[mode]
end

ns:RegisterCommand("on", "filter Trade chat (default)", function()
    ns:SetOption("enabled", true)
    ns:Print("on - " .. describeMode() .. ".")
end)

ns:RegisterCommand("off", "show every line again (the log goes on)", function()
    ns:SetOption("enabled", false)
    ns:Print("off - every line shows. |cffffd100/gtf on|r to filter again.")
end)

ns:RegisterCommand("mode", "'trade': trade only; 'game' (default): everything about the game - trade, groups forming, guilds, questions and their answers, talk; 'chat': everything but the world outside", function(rest)
    local preset = ns.Rules.PRESETS[string.lower(rest or "")]
    if not preset then
        ns:Print("usage: /gtf mode trade | game | chat   (now: " .. describeMode() .. ")")
        return
    end
    setKinds(preset)
    ns:Print("mode: " .. describeMode() .. ".")
end)

local function toggleKind(rest, on)
    local kind = string.lower(string.gsub(rest or "", "^%s+", ""))
    kind = string.gsub(kind, "%s+$", "")
    if kind == "world" or ns.Rules.PRESETS.game[kind] == nil then
        ns:Print("usage: /gtf " .. (on and "show" or "hide") .. " trade | groups | guilds | questions | talk | chatter   (" .. describeKinds() .. ")")
        return
    end
    local kinds = {}
    for k, v in pairs(Filter.Shown()) do
        kinds[k] = v
    end
    kinds[kind] = on
    setKinds(kinds)
    ns:Print(ns.Rules.KIND_WORDS[kind] .. ": " .. (on and "shown" or "hidden") .. ". Now " .. describeKinds() .. ".")
end

ns:RegisterCommand("show", "'/gtf show chatter': one kind of line back on - trade, groups, guilds, questions, talk, chatter", function(rest)
    toggleKind(rest, true)
end)

ns:RegisterCommand("hide", "'/gtf hide guilds': one kind of line off - a guild recruiting is the usual one", function(rest)
    toggleKind(rest, false)
end)

ns:RegisterCommand("kinds", "which kinds of line are shown and which are hidden", function()
    ns:Print(describeKinds() .. ".")
end)

ns:RegisterCommand("answers", "'off' (default): a line counts by its own words only; 'on': chatter right after a game question, or from somebody who just spoke about the game, counts as game talk", function(rest)
    local word = string.lower(rest or "")
    if word ~= "on" and word ~= "off" then
        ns:Print("usage: /gtf answers on | off   (now: " .. (ns:GetOption("answers") == true and "on" or "off") .. ")")
        return
    end
    ns:SetOption("answers", word == "on")
    ns:Print("answers: " .. (word == "on" and "chatter after a game question is an answer." or "every line by its own words."))
end)

ns:RegisterCommand("services", "'on' (default): filter the Services channel like Trade; 'off': leave it alone", function(rest)
    local word = string.lower(rest or "")
    if word ~= "on" and word ~= "off" then
        ns:Print("usage: /gtf services on | off   (now: " .. (ns:GetOption("services") and "on" or "off") .. ")")
        return
    end
    ns:SetOption("services", word == "on")
    ns:Print("Services: " .. (word == "on" and "filtered like Trade." or "left alone."))
end)

ns:RegisterCommand("adverts", "'on' (default): a web address, a seller for real money or the anal joke is hidden in every public channel - General, LocalDefense, LookingForGroup; 'off': only where the whole filter runs", function(rest)
    local word = string.lower(rest or "")
    if word ~= "on" and word ~= "off" then
        ns:Print("usage: /gtf adverts on | off   (now: " .. (ns:GetOption("adverts") ~= false and "on" or "off") .. ")")
        return
    end
    ns:SetOption("adverts", word == "on")
    ns:Print("adverts: " .. (word == "on" and "hidden in every public channel." or "hidden only where the whole filter runs."))
end)

ns:RegisterCommand("general", "'on': the whole filter on the General channel as well; 'off' (default): only adverts go from General", function(rest)
    local word = string.lower(rest or "")
    if word ~= "on" and word ~= "off" then
        ns:Print("usage: /gtf general on | off   (now: " .. (ns:GetOption("general") and "on" or "off") .. ")")
        return
    end
    ns:SetOption("general", word == "on")
    ns:Print("General: " .. (word == "on" and "filtered too." or "left alone, but for adverts."))
end)

ns:RegisterCommand("sticky", "'on' (default): after a real-world line, the same sender's next lines go too for a few minutes unless clearly game business; 'off'", function(rest)
    local word = string.lower(rest or "")
    if word ~= "on" and word ~= "off" then
        ns:Print("usage: /gtf sticky on | off   (now: " .. (ns:GetOption("sticky") ~= false and "on" or "off") .. ")")
        return
    end
    ns:SetOption("sticky", word == "on")
    ns:Print("threads: " .. (word == "on" and "a real-world talker's next lines go too." or "every line on its own."))
end)

ns:RegisterCommand("test", "'/gtf test wts sword 50g': what the filter would do with that line, and why", function(rest)
    if not rest or rest == "" then
        ns:Print("usage: /gtf test <a line of chat>")
        return
    end
    ns:Print(ns.Rules.Explain(rest, Filter.Shown()))
end)

-- Teach a word or a phrase: "game" (game business, +2) or "real" (the world outside, -3).
function Filter.Teach(word, kind)
    word = string.lower(string.gsub(tostring(word or ""), "^%s+", ""))
    word = string.gsub(word, "%s+$", "")
    if word == "" or not ns.db then
        return false
    end
    ns.db.words[word] = kind
    ns.Rules.Rebuild(ns.db.words)
    ns:Log("taught", { word = word, kind = kind })
    ns:Print("'" .. word .. "' is " .. (kind == "game" and "game business" or "the world outside") .. " from now on.")
    return word
end

local function teach(rest, kind, said)
    if not Filter.Teach(rest, kind) then
        ns:Print("usage: /gtf " .. said .. " <word or phrase>")
    end
end

ns:RegisterCommand("allow", "'/gtf allow raid': that word means game business from now on", function(rest)
    teach(rest, "game", "allow")
end)

ns:RegisterCommand("block", "'/gtf block cheese': that word means the world outside from now on", function(rest)
    teach(rest, "real", "block")
end)

ns:RegisterCommand("unlearn", "'/gtf unlearn cheese': forget a word you taught", function(rest)
    local word = string.lower(string.gsub(rest or "", "^%s+", ""))
    word = string.gsub(word, "%s+$", "")
    if word == "" or not ns.db or not ns.db.words[word] then
        ns:Print("usage: /gtf unlearn <a word you taught>; /gtf words lists them")
        return
    end
    ns.db.words[word] = nil
    ns.Rules.Rebuild(ns.db.words)
    ns:Print("'" .. word .. "' forgotten.")
end)

ns:RegisterCommand("meme", "'/gtf meme add gnome': lines joking with that word are chatter while the meme lasts; 'remove' ends it; '/gtf meme' lists the words (murloc from the start)", function(rest)
    local what, word = string.match(rest or "", "^%s*(%S*)%s*(.-)%s*$")
    what, word = string.lower(what or ""), string.lower(word or "")
    local list = ns.db.memes
    if what == "add" and word ~= "" then
        for _, known in ipairs(list) do
            if known == word then
                ns:Print("'" .. word .. "' is on the list already.")
                return
            end
        end
        list[#list + 1] = word
        ns.Rules.SetMemes(list)
        ns:Print("'" .. word .. "' is a meme: lines joking with it are chatter until |cffffd100/gtf meme remove " .. word .. "|r.")
    elseif what == "remove" and word ~= "" then
        for index, known in ipairs(list) do
            if known == word then
                table.remove(list, index)
                ns.Rules.SetMemes(list)
                ns:Print("'" .. word .. "' is a word of the game again.")
                return
            end
        end
        ns:Print("'" .. word .. "' is not on the list; |cffffd100/gtf meme|r lists it.")
    else
        ns:Print("meme words (lines joking with them are chatter):", #list > 0 and table.concat(list, ", ") or "none")
        ns:Print("|cffffd100/gtf meme add <word>|r, |cffffd100/gtf meme remove <word>|r")
    end
end)

ns:RegisterCommand("words", "the words you taught", function()
    local count = 0
    for word, kind in pairs(ns.db and ns.db.words or {}) do
        print("   " .. word .. " - " .. (kind == "game" and "game business" or "the world outside"))
        count = count + 1
    end
    ns:Print(count .. " word(s) taught. |cffffd100/gtf allow|r and |cffffd100/gtf block|r teach more.")
end)

ns:RegisterCommand("stats", "this session's count: lines seen, hidden, kept", function()
    local s = Filter.stats
    ns:Print(string.format("this session: %d line(s) seen, %d hidden, %d kept, %d unreadable. Filter: %s. Mode: %s.",
        s.seen, s.hidden, s.kept, s.secret, Filter.how, describeMode()))
end)
