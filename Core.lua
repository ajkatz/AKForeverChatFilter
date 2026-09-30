-- AKForeverTradeFilter core: namespace, safe calls, event dispatch, message bus, saved variables,
-- session log and slash commands.
--
-- The mission of this addon family, built for the WoW: Forever game mode: minimalistic UI additions that
-- bring out the utility Blizzard's UI does not give - minimal in nature, no Lua errors, always smooth. So:
-- nothing runs on a timer, every entry point goes through ns.SafeCall, and every error is kept for /gtf diag.
--
-- House rules for this addon - it reads chat and decides what a chat window shows, nothing more:
--   * the one way in is the client's own message event filter (ChatFrameUtil.AddMessageEventFilter): the
--     callback returns true and the chat window skips the line. No chat frame is hooked, no message is
--     rewritten, nothing of Blizzard's is touched;
--   * whatever the client hands over may be a secret value: it is checked with ns.IsSecret before it is
--     looked at, and "unreadable" always means "hands off" - the line is left alone.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMetadata and getMetadata(ADDON_NAME, "Version")) or "dev"
if string.find(ns.version, "@", 1, true) then
    ns.version = "dev" -- a working copy: the packager has not replaced the @project-version@ token
end
ns.version = (string.gsub(ns.version, "^v", ""))

local PRINT_PREFIX = "|cff5ac8e8Great Trade Filter|r: "

function ns:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    print(PRINT_PREFIX .. table.concat(parts, " "))
end

------------------------------------------------------------------------
-- Secret values. WoW: Forever runs the Midnight-era API, where some values handed to addons may be
-- held but not inspected.
------------------------------------------------------------------------
local issecret = type(issecretvalue) == "function" and issecretvalue or nil

function ns.IsSecret(value)
    if issecret then
        return issecret(value) and true or false
    end
    return false
end

function ns.AnySecret(...)
    for i = 1, select("#", ...) do
        if ns.IsSecret((select(i, ...))) then
            return true
        end
    end
    return false
end

-- The results of a getter as a list - or nil when the call failed or any result is secret.
function ns.Readable(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok or ns.AnySecret(a, b, c, d, e) then
        return nil
    end
    return { a, b, c, d, e }
end

------------------------------------------------------------------------
-- Safe calls: every distinct error is kept for /gtf diag.
------------------------------------------------------------------------
ns.errors = {}

local function onError(err)
    err = tostring(err)
    local seen = ns.errors[err]
    ns.errors[err] = (seen or 0) + 1
    if not seen then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        end
    end
    return err
end

function ns.SafeCall(fn, ...)
    return xpcall(fn, onError, ...)
end

------------------------------------------------------------------------
-- Session log (ring buffer), saved with /gtf diag and on logout
------------------------------------------------------------------------
local LOG_MAX = 80
ns.sessionLog = {}

function ns:Log(kind, data)
    local log = ns.sessionLog
    log[#log + 1] = {
        t = math.floor(GetTime() * 1000) / 1000,
        k = kind,
        d = data,
    }
    if #log > LOG_MAX then
        table.remove(log, 1)
    end
end

------------------------------------------------------------------------
-- Internal message bus
------------------------------------------------------------------------
local listeners = {}

function ns:Listen(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns:Fire(message, ...)
    local list = listeners[message]
    if not list then
        return
    end
    for i = 1, #list do
        ns.SafeCall(list[i], ...)
    end
end

------------------------------------------------------------------------
-- Game events: one frame, handlers per event, every handler in a SafeCall
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}
ns.unknownEvents = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then
        return
    end
    for i = 1, #list do
        ns.SafeCall(list[i], event, ...)
    end
end)

function ns:On(event, fn)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            ns.unknownEvents[event] = true
        end
    end
    table.insert(eventHandlers[event], fn)
end

------------------------------------------------------------------------
-- Saved variables: ONE account-wide table, per-character options under db.chars["Name - Realm"].
-- One file is what lets the beta workaround (tools/Install-SavedStateBridge.ps1) restore it should
-- the client write SavedVariables and not read them back. The log, the labels and the words you teach
-- are account-wide: what is trade is trade on every character.
------------------------------------------------------------------------
local OPTION_DEFAULTS = {
    enabled = true,       -- the filter is on
    -- which kinds of line stay (the world outside never does): '/gtf mode trade|game|chat' sets them together,
    -- '/gtf show <kind>' / '/gtf hide <kind>' one at a time
    kinds = { trade = true, groups = true, guilds = true, questions = true, talk = true, chatter = false },
    -- OFF: the useful answers come by whisper, and what follows a question in Trade is mostly noise (the
    -- user's call, 2026-09-30). On, chatter right after a game question, naming somebody who just spoke
    -- about the game, or going on from the sender's own game line counts as game talk.
    answers = false,
    trade = true,         -- filter the Trade channel
    general = false,      -- ... and General
    sticky = true,        -- a sender's next lines follow a hidden real-world line for a while, unless clearly game business
    training = "off",     -- "off" | "all" (every line is asked) | "unsure" (only the lines the filter is not sure about)
}

-- The realm is squeezed ("Classic Beta PvE" -> "ClassicBetaPvE"): on a fresh login UnitFullName has no
-- realm yet and GetRealmName() gives the spaced display name, after a /reload UnitFullName gives the
-- normalized one. Unsqueezed, that would be two profiles for one character.
local function squeezeRealm(realm)
    return (string.gsub(realm, "[%s%-]", ""))
end

local function characterKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    if not name then
        name = UnitName("player")
    end
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName()
    end
    return (name or "Unknown") .. " - " .. squeezeRealm(realm or "Unknown")
end

local function initDB()
    local bridge = AKForeverTradeFilter_SavedStateBridge
    if type(AKForeverTradeFilterDB) ~= "table" then
        AKForeverTradeFilterDB = {}
        ns.savedStateSource = "none (first run, or the client did not load it)"
    elseif type(bridge) == "table" and bridge.table == AKForeverTradeFilterDB then
        ns.savedStateSource = "bridge addon"
    else
        ns.savedStateSource = "client"
    end
    local db = AKForeverTradeFilterDB

    db.schema = db.schema or 1
    db.loads = (db.loads or 0) + 1
    db.chars = db.chars or {}
    db.log = db.log or {}       -- every line the filter saw, with its verdict (Filter.lua)
    db.labels = db.labels or {} -- the lines you answered in training, with your call (Trainer.lua)
    db.words = db.words or {}   -- the words you taught: [word] = "game" | "real"

    local key = characterKey()
    if type(db.chars[key]) ~= "table" then
        db.chars[key] = {}
    end
    local cdb = db.chars[key]
    cdb.options = cdb.options or {}

    ns.characterKey = key
    ns.db, ns.cdb = db, cdb
end

function ns:GetOption(key)
    local options = ns.cdb and ns.cdb.options
    local value = options and options[key]
    if value == nil then
        return OPTION_DEFAULTS[key]
    end
    return value
end

function ns:SetOption(key, value)
    ns.cdb.options[key] = value
    ns:Fire("OPTION_CHANGED", key, value)
end

------------------------------------------------------------------------
-- Slash commands: modules register their own sub-commands
------------------------------------------------------------------------
local commands, commandOrder = {}, {}

function ns:RegisterCommand(name, help, fn)
    commands[name] = { help = help, fn = fn }
    commandOrder[#commandOrder + 1] = name
end

SLASH_AKFOREVERTRADEFILTER1 = "/akforevertradefilter"
SLASH_AKFOREVERTRADEFILTER2 = "/gtf"
SlashCmdList["AKFOREVERTRADEFILTER"] = function(message)
    local name, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    local command = commands[string.lower(name or "")]
    if command then
        ns.SafeCall(command.fn, rest or "")
        return
    end
    ns:Print("v" .. ns.version .. " commands:")
    for _, commandName in ipairs(commandOrder) do
        print("   |cffffd100/gtf " .. commandName .. "|r - " .. commands[commandName].help)
    end
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------
ns:On("ADDON_LOADED", function(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    initDB()
end)

ns:On("PLAYER_LOGIN", function()
    ns:Log("login", {
        version = ns.version,
        character = ns.characterKey,
        loads = ns.db and ns.db.loads,
        savedState = ns.savedStateSource,
    })
    ns:Fire("LOGIN")
end)
