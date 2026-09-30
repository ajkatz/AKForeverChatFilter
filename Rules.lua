-- Rules: one line of chat in, a verdict out - and the reason, in words, because a filter you cannot
-- argue with is a filter you switch off.
--
-- HOW A LINE IS SCORED. The line is lower-cased and cut into words; every word (and every phrase) on the
-- lists in Terms.lua adds its weight, every pattern that matches (a hyperlink, a sum of gold, a web
-- address) adds its own. Game business counts up, the world outside counts down:
--     +3  an item / spell / quest link           -3  politics, a country, a war, a faith
--     +2  a trade word (wts, lf, port, guild)    -1  a nationality, a screen, the life outside, in passing
--     +1  a word of the game (rogue, brd, mats)
-- The sum is the score. STRICT (the default) keeps a line only when the score is above nought: game
-- business, and nothing else. BALANCED keeps a line unless the score is below nought: the world outside
-- goes, plain chatter ("lol", "anyone else lagging") stays. A loud word of the world outside outweighs two
-- words of the game: "biden is a warlock" goes, "wts [Sulfuras] 50g made in china" stays.
--
-- A THREAD. Somebody whose line went for real-world talk is likely to go on ("lol no he didn't"): for a
-- few minutes their lines go too, unless one is clearly game business (score 2 or more).
--
-- Pure Lua: no frame, no API. The tests run it on a table of lines.
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local THREAD_SECONDS = 180  -- how long a real-world talker's lines keep going after one went
local THREAD_ESCAPE = 2     -- ... unless a line scores this much: clearly game business
local LOUD = 3              -- the weight that makes a word "real-world talk" rather than "in passing"
local REASON_TERMS = 4      -- how many of the words are named in the reason

-- word -> weight, phrase -> weight; built once from Terms.lua, rebuilt when a word is taught
local single, phrases, patterns = {}, {}, {}

local function addWord(word, weight, label)
    if string.find(word, " ", 1, true) then
        phrases[#phrases + 1] = { text = word, weight = weight, label = label }
    else
        single[word] = { weight = weight, label = label }
    end
end

function Rules.Rebuild(taught)
    single, phrases, patterns = {}, {}, {}
    for _, list in ipairs(ns.Terms.LISTS) do
        for _, word in ipairs(list.words) do
            addWord(word, list.weight, list.label)
        end
    end
    -- what you taught outranks the lists: '/gtf allow raid' and '/gtf block cheese'
    for word, kind in pairs(taught or {}) do
        if kind == "game" then
            addWord(word, 2, "taught")
        elseif kind == "real" then
            addWord(word, -3, "taught")
        end
    end
    for _, entry in ipairs(ns.Terms.PATTERNS) do
        patterns[#patterns + 1] = entry
    end
end

-- The line as words: lower case, links reduced to their [name], colours and textures gone, every mark
-- of punctuation but the apostrophe a space. "trump's" is "trump", "alt-right" is "alt right".
function Rules.Normalize(text)
    local line = string.lower(text)
    line = string.gsub(line, "|c%x%x%x%x%x%x%x%x", "")
    line = string.gsub(line, "|r", "")
    line = string.gsub(line, "|t[^|]*|t", " ")
    line = string.gsub(line, "|h[^|]*|h(%[[^%]]*%])|h", " %1 ") -- a link: its [name] stays, the rest goes
    line = string.gsub(line, "|h[^|]*|h", " ")                   -- a link without a name
    line = string.gsub(line, "|%a", " ")                          -- any escape left over
    line = string.gsub(line, "%.", "")                            -- "c.o.d" is cod, "u.s.a" is usa
    line = string.gsub(line, "[^%w%s']", " ")
    line = string.gsub(line, "%s+", " ")
    line = string.gsub(line, "^%s+", "")
    line = string.gsub(line, "%s+$", "")
    return line
end

local function words(line)
    local list = {}
    for word in string.gmatch(line, "%S+") do
        word = string.gsub(word, "^'+", "")
        word = string.gsub(word, "'+$", "")
        word = string.gsub(word, "'s$", "")
        word = string.gsub(word, "%.$", "")
        if word ~= "" then
            list[#list + 1] = word
        end
    end
    return list
end

-- The score of one line, and every term that took part: { score, hits = { {term, weight, label} ... },
-- game, real } - game and real being the sums of each side.
function Rules.Score(text)
    if #phrases == 0 and next(single) == nil then
        Rules.Rebuild()
    end
    local hits, score, game, real = {}, 0, 0, 0
    local function hit(term, weight, label)
        hits[#hits + 1] = { term = term, weight = weight, label = label }
        score = score + weight
        if weight > 0 then
            game = game + weight
        else
            real = real + weight
        end
    end
    -- "US" the country is a capital pair; "us" the pronoun is not a word to block - and in a line
    -- SHOUTED IN CAPITALS the pair says nothing
    if string.find(text, "%l") and (string.find(text, "%f[%w]US%f[%W]") or string.find(text, "%f[%w]U%.S%.")) then
        hit("US", -LOUD, "real-world")
    end
    local line = Rules.Normalize(text)
    local lower = string.lower(text)
    local seen = {}
    for _, word in ipairs(words(line)) do
        local entry = single[word]
        if entry and not seen[word] then
            seen[word] = true
            hit(word, entry.weight, entry.label)
        end
    end
    local padded = " " .. line .. " "
    for _, phrase in ipairs(phrases) do
        if string.find(padded, " " .. phrase.text .. " ", 1, true) then
            hit(phrase.text, phrase.weight, phrase.label)
        end
    end
    for _, entry in ipairs(patterns) do
        local found = string.match(lower, entry.pattern)
        if found then
            hit(entry.label == "link" and "a link" or found, entry.weight, entry.label)
        end
    end
    return { score = score, hits = hits, game = game, real = real }
end

-- The words behind a verdict, for the reason: the loudest first, at most a few
local function named(hits, side)
    local list = {}
    for _, h in ipairs(hits) do
        if (side > 0 and h.weight > 0) or (side < 0 and h.weight < 0) then
            list[#list + 1] = h
        end
    end
    table.sort(list, function(a, b)
        return math.abs(a.weight) > math.abs(b.weight)
    end)
    local names = {}
    for index = 1, math.min(REASON_TERMS, #list) do
        names[index] = list[index].term
    end
    if #list > REASON_TERMS then
        names[#names + 1] = "..."
    end
    return table.concat(names, ", ")
end

-- threads: sender -> the time their line went for real-world talk
local threads = {}

function Rules.ResetThreads()
    threads = {}
end

-- The verdict for one line: { keep = bool, reason, score, hits, sure }.
--   mode    "strict" | "balanced"
--   sender  who said it (for the thread rule), or nil
--   now     the time, seconds (for the thread rule), or nil
--   sticky  whether the thread rule is on
-- `sure` is false when the line had nothing to go by (no word of either side): the ones a trainer asks about.
function Rules.Verdict(text, mode, sender, now, sticky)
    local scored = Rules.Score(text)
    local score = scored.score
    local keep, reason
    local loud = scored.real <= -LOUD
    if loud and score <= 0 then
        keep, reason = false, "real-world talk: " .. named(scored.hits, -1)
    elseif score > 0 then
        keep, reason = true, "game business: " .. named(scored.hits, 1)
    elseif score < 0 then
        keep, reason = false, "the world outside: " .. named(scored.hits, -1)
    elseif mode == "balanced" then
        keep, reason = true, "chatter, kept"
    else
        keep, reason = false, "not game business"
    end
    -- the thread rule
    if sticky and sender and now then
        if not keep and loud then
            threads[sender] = now
        elseif keep and score < THREAD_ESCAPE then
            local since = threads[sender]
            if since and now - since <= THREAD_SECONDS then
                keep, reason = false, "goes on from a real-world line (" .. reason .. ")"
            end
        elseif keep then
            threads[sender] = nil -- clearly game business again
        end
    end
    return {
        keep = keep,
        reason = reason,
        score = score,
        hits = scored.hits,
        sure = #scored.hits > 0,
    }
end

-- What '/gtf test <line>' prints
function Rules.Explain(text, mode)
    local verdict = Rules.Verdict(text, mode or "strict")
    local parts = {}
    for _, h in ipairs(verdict.hits) do
        parts[#parts + 1] = h.term .. " " .. (h.weight > 0 and "+" or "") .. h.weight
    end
    return (verdict.keep and "KEPT" or "HIDDEN") .. " (" .. verdict.reason .. "; score " .. verdict.score
        .. (#parts > 0 and ": " .. table.concat(parts, ", ") or "") .. ")"
end
