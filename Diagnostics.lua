-- Diagnostics: '/gtf diag' writes a report into the saved file - the options, the counts, how the filter
-- was registered, the last lines with their verdicts, your answers from training, every error. Nothing
-- in it is a frame; every value is checked before it is copied so that a secret cannot poison the file.
local _, ns = ...

local Diagnostics = {}
ns.Diagnostics = Diagnostics

local LOG_LINES = 150 -- of the saved log, the newest in the report

local function sanitize(value, depth)
    depth = depth or 0
    local kind = type(value)
    if ns.IsSecret(value) then
        return "<secret>"
    end
    if kind == "table" then
        if depth >= 7 then
            return "<too deep>"
        end
        if type(value.GetObjectType) == "function" then
            return "<frame>"
        end
        local copy = {}
        for k, v in pairs(value) do
            local key = k
            if ns.IsSecret(k) then
                key = "<secret key>"
            elseif type(k) ~= "string" and type(k) ~= "number" then
                key = tostring(k)
            end
            copy[key] = sanitize(v, depth + 1)
        end
        return copy
    elseif kind == "string" or kind == "number" or kind == "boolean" then
        return value
    elseif kind == "nil" then
        return nil
    end
    return "<" .. kind .. ">"
end

local function tail(list, count)
    local out = {}
    for index = math.max(1, #list - count + 1), #list do
        out[#out + 1] = list[index]
    end
    return out
end

function Diagnostics:Collect()
    local db = ns.db or {}
    local termCount = 0
    for _, list in ipairs(ns.Terms.LISTS) do
        termCount = termCount + #list.words
    end
    local taught = 0
    for _ in pairs(db.words or {}) do
        taught = taught + 1
    end
    local report = {
        capturedAt = date and date("%Y-%m-%d %H:%M:%S") or "?",
        addonVersion = ns.version,
        character = ns.characterKey,
        savedStateSource = ns.savedStateSource,
        savedVariableLoads = db.loads,
        options = {
            enabled = ns:GetOption("enabled"), mode = ns.Filter.ModeName(), kinds = ns.Filter.Shown(), trade = ns:GetOption("trade"),
            general = ns:GetOption("general"), sticky = ns:GetOption("sticky"), training = ns:GetOption("training"),
            answers = ns:GetOption("answers"),
        },
        filter = { how = ns.Filter.how, stats = ns.Filter.stats },
        terms = { builtIn = termCount, patterns = #ns.Terms.PATTERNS, taught = taught, words = db.words },
        trainer = ns.Trainer:Describe(),
        trainStats = db.trainStats,
        log = tail(db.log or {}, LOG_LINES),
        labels = db.labels,
        errors = {},
        unknownEvents = ns.unknownEvents,
        session = ns.sessionLog,
    }
    if GetBuildInfo then
        local version, build, buildDate, toc = GetBuildInfo()
        report.build = { version = version, build = build, date = buildDate, toc = toc }
    end
    for message, count in pairs(ns.errors) do
        report.errors[#report.errors + 1] = { message = message, count = count }
    end
    return sanitize(report)
end

-- A report asked for with '/gtf diag' is kept; the one taken at logout goes beside it.
function Diagnostics:Save(asked)
    if not ns.db then
        return
    end
    local report = self:Collect()
    if asked then
        report.asked = true
        ns.db.diag = report
        Diagnostics.asked = true
    elseif Diagnostics.asked then
        ns.db.diagAtLogout = report
    else
        ns.db.diag = report
        ns.db.diagAtLogout = nil
    end
end

ns:RegisterCommand("diag", "save a report into the settings file (then /reload, so that it is written to disk)", function()
    Diagnostics:Save(true)
    local s = ns.Filter.stats
    ns:Print(string.format("report saved - /reload (or log out) writes it to disk. This session: %d seen, %d hidden.", s.seen, s.hidden))
end)

ns:On("PLAYER_LOGOUT", function()
    Diagnostics:Save()
end)
