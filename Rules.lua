-- Rules: one line of chat in, a verdict out - and the reason, in words, because a filter you cannot
-- argue with is a filter you switch off.
--
-- HOW A LINE IS SORTED. The line is lower-cased and cut into words; every word (and every phrase) on the
-- lists in Terms.lua counts for the KIND it belongs to, and every pattern that matches (a hyperlink, a
-- sum of gold, a guild's <name>, a web address) counts for its own. Seven kinds of line:
--     trade      selling, buying, a price, a service for a tip       (wts, wtb, 50g, ench, ports)
--     groups     a group forming for a dungeon, a raid, a quest       (lfm, lf2m, need healer, tank)
--     guilds     a guild recruiting, or somebody looking for one      (recruiting, <Forever Bound>, lf guild)
--     questions  a question about the game - and its answers          (where is the rfd entrance, "yes tomorrow")
--     talk       anything else about the game                         (gnome is fun, server just died)
--     chatter    nothing of the game in it                            (lol, thanks man)
--     world      the world outside                                    (a politician, a country, a war, a faith)
-- A loud word of the world outside - a politician, a country, a war, a faith - is a hard pass whatever
-- else the line says: "biden is a warlock" goes, and so does "wts [Sulfuras] 50g made in china" (a country
-- named is a line gone, the user's own rule). So are a web address, a seller for real money and the anal
-- joke ("anal [Thunderfury]"), link or no link. Then trade, groups and guilds are told apart by which of them
-- the words favour (a tie goes to guilds, then groups); a line with only words of the game is talk, or a
-- question if it looks like one; a line with nothing is chatter.
--
-- WHICH KINDS STAY is a setting per kind (Filter.lua): "/gtf mode trade" shows trade only, "/gtf mode
-- game" (the default) everything about the game, "/gtf mode chat" everything but the world outside;
-- "/gtf hide guilds" takes one kind out.
--
-- A CONVERSATION. The answer to a game question rarely has a word of the game in it ("yes tomorrow"), so
-- short chatter (four words, or eight sharing a word with the question) within three quarters of a
-- minute of a question that seeks one ("anyone know ...", "where is ...", with a word of the game in it)
-- is taken for an answer - each answer keeps the window open fifteen seconds longer, three at most, and
-- never opens a window of its own - and a line naming somebody who spoke about
-- the game in the last three minutes, written as a name (Holly, not holly: Forever's first names are
-- common words), is taken for a reply. Both count as questions. And somebody whose line went for the
-- world outside is likely to go on ("lol no he didn't"): for three minutes their chatter goes too, and so
-- does a reply naming them, unless a line is clearly game business. (All of it measured on the first
-- session's replay: a meme question had opened windows for the jokes that followed.)
--
-- Pure Lua: no frame, no API. The tests run it on a table of lines.
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local LOUD = 3              -- the weight that makes a word "real-world talk" rather than "in passing"
local REASON_TERMS = 4      -- how many of the words are named in the reason
local THREAD_SECONDS = 180  -- how long a real-world talker's chatter keeps going after one line went
local THREAD_ESCAPE = 2     -- ... unless a line scores this much on the game's side: clearly game business
local SPEAKER_SECONDS = 180 -- how long a name stays "somebody who just spoke"
local GOES_ON_SECONDS = 60  -- chatter this soon after the sender's own game line goes on from it
local GOES_ON_WORDS = 8     -- ... if it is short: a reply, not a speech
local QUESTION_SECONDS = 45 -- chatter this soon after a game question is taken for an answer
local ANSWER_SECONDS = 15   -- ... and each answer keeps the window open this much longer
local ANSWERS_MAX = 3       -- ... for at most this many answers (the first sessions: the real ones come first, then the jokes)
local ANSWER_WORDS = 4      -- an answer is a short line ("tomorrow", "press K > General") ...
local ANSWER_WORDS_TOPIC = 8 -- ... or a longer one that shares a word with the question

-- A MEME FLOOD. Now and then Trade is taken over by jokes on one word, and the word is a word of the
-- game, so every joke counted as game talk. A meme word makes a line chatter - unless the line is business
-- (trade, a group, a guild) or the world outside already; business with the word in it is still business.
-- The built-in list is Terms.MEMES; '/gtf meme add|remove' keeps the account's own (Filter.lua).
local memes, memesSet = {}, false

function Rules.SetMemes(list)
    memes, memesSet = {}, true
    for _, word in ipairs(list or ns.Terms.MEMES or {}) do
        word = string.lower(word)
        local escaped = string.gsub(word, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        -- a whole word, plural or not; a word that begins or ends with something other than a letter
        -- ("c++") gets no frontier there, since no frontier can sit between two non-letters
        local head = string.find(word, "^%a") and "%f[%a]" or ""
        local tail = string.find(word, "%a$") and "s?%f[%A]" or ""
        memes[#memes + 1] = { word = word, pattern = head .. escaped .. tail }
    end
end

-- the meme word a line jokes with, or nil
function Rules.MemeWord(text)
    if not memesSet then
        Rules.SetMemes()
    end
    local lower = string.lower(text)
    for _, meme in ipairs(memes) do
        if string.find(lower, meme.pattern) then
            return meme.word
        end
    end
    return nil
end

Rules.KINDS = { "trade", "groups", "guilds", "questions", "talk", "chatter", "world" } -- (the words of a seller for real money count as "seller" and make the line world)
Rules.PRESETS = {
    trade = { trade = true, groups = false, guilds = false, questions = false, talk = false, chatter = false },
    game = { trade = true, groups = true, guilds = true, questions = true, talk = true, chatter = false },
    chat = { trade = true, groups = true, guilds = true, questions = true, talk = true, chatter = true },
}
Rules.PRESETS.strict, Rules.PRESETS.balanced = Rules.PRESETS.game, Rules.PRESETS.chat -- (the first names)

-- word -> { weight, kind }, phrases, patterns; built once from Terms.lua, rebuilt when a word is taught
local single, phrases, patterns = {}, {}, {}

local function addWord(word, weight, kind)
    if string.find(word, " ", 1, true) then
        phrases[#phrases + 1] = { text = word, weight = weight, kind = kind }
    else
        single[word] = { weight = weight, kind = kind }
    end
end

function Rules.Rebuild(taught)
    single, phrases, patterns = {}, {}, {}
    for _, list in ipairs(ns.Terms.LISTS) do
        for _, word in ipairs(list.words) do
            addWord(word, list.weight, list.kind)
        end
    end
    -- what you taught outranks the lists: '/gtf allow raid' and '/gtf block cheese'
    for word, kind in pairs(taught or {}) do
        if kind == "game" then
            addWord(word, 2, "trade")
        elseif kind == "real" then
            addWord(word, -3, "world")
        elseif Rules.PRESETS.game[kind] ~= nil then
            addWord(word, 2, kind)
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
    line = string.gsub(line, "|cn[^:|]*:", "")                 -- the newer colour escape, |cnIQ5:
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
        if word ~= "" then
            list[#list + 1] = word
        end
    end
    return list
end

-- The score of one line: { score, hits = { {term, weight, kind} ... }, game, real, kinds = { [kind] = sum } }
function Rules.Score(text)
    if #phrases == 0 and next(single) == nil then
        Rules.Rebuild()
    end
    local hits, score, game, real, kinds = {}, 0, 0, 0, {}
    local function hit(term, weight, kind)
        hits[#hits + 1] = { term = term, weight = weight, kind = kind }
        score = score + weight
        if weight > 0 then
            game = game + weight
        else
            real = real + weight
        end
        kinds[kind] = (kinds[kind] or 0) + weight
    end
    -- "US" the country and "AH" the auction house are capital pairs; "us" and "ah" are not words to go
    -- by - and in a line SHOUTED IN CAPITALS the pairs say nothing
    if string.find(text, "%l") then
        if string.find(text, "%f[%w]US%f[%W]") or string.find(text, "%f[%w]U%.S%.") then
            hit("US", -LOUD, "world")
        end
        if string.find(text, "%f[%w]AH%f[%W]") then
            hit("AH", 2, "trade")
        end
    end
    local line = Rules.Normalize(text)
    -- what is said of the channel itself is not said of trade
    for _, neutral in ipairs(ns.Terms.NEUTRAL or {}) do
        line = string.gsub(" " .. line .. " ", " " .. neutral .. " ", " ")
        line = string.gsub(line, "^%s+", "")
        line = string.gsub(line, "%s+$", "")
    end
    local lower = string.lower(text)
    local seen = {}
    for _, word in ipairs(words(line)) do
        local entry = single[word]
        -- a listed word with an "s" on it is the same word ("pedos", "trumps"); a word ending in "ss" is not
        if not entry and #word > 4 and string.sub(word, -1) == "s" and string.sub(word, -2) ~= "ss" then
            entry = single[string.sub(word, 1, -2)] or (string.sub(word, -2) == "es" and single[string.sub(word, 1, -3)]) or nil
        end
        if entry and not seen[word] then
            seen[word] = true
            hit(word, entry.weight, entry.kind)
        end
    end
    local padded = " " .. line .. " "
    for _, phrase in ipairs(phrases) do
        if string.find(padded, " " .. phrase.text .. " ", 1, true) then
            hit(phrase.text, phrase.weight, phrase.kind)
        end
    end
    for _, entry in ipairs(patterns) do
        local found = string.match(lower, entry.pattern)
        if found then
            hit(entry.name or found, entry.weight, entry.kind)
        end
    end
    return { score = score, hits = hits, game = game, real = real, kinds = kinds }
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

------------------------------------------------------------------------
-- The conversation
------------------------------------------------------------------------
local threads = {}   -- sender -> the time their line went for the world outside
local speakers = {}  -- first name -> { sender, at, side }
local lastSaid = {}  -- sender -> the time of their last line about the game
local question = nil -- the last game question: { sender, at, until_, answers }

function Rules.ResetThreads()
    threads, speakers, lastSaid, question = {}, {}, {}, nil
end

local QUESTION_WORDS = { anyone = true, anybody = true, any = true, does = true, ["do"] = true, ["is"] = true, are = true,
    can = true, could = true, how = true, what = true, where = true, when = true, which = true, why = true, who = true,
    will = true, would = true, should = true, has = true, have = true }

-- a question, by its shape: a question mark, or a question word up front
function Rules.LooksLikeQuestion(text)
    if string.find(text, "?", 1, true) then
        return true
    end
    local first = string.match(Rules.Normalize(text), "^(%S+)")
    return first ~= nil and QUESTION_WORDS[first] == true
end

-- the line without its links - name and all
function Rules.StripLinks(text)
    local line = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    line = string.gsub(line, "|cn[^:|]*:", "")
    line = string.gsub(line, "|H[^|]*|h%[[^%]]*%]|h", " ")
    line = string.gsub(line, "|H[^|]*|h", " ")
    line = string.gsub(line, "|r", "")
    return line
end

-- a question that seeks an answer: a question word up front or a question mark at the end, and a word of
-- the game that is not just a link's name ("did someone say [Thunderfury]?" and "what would you do for a
-- [Thunderfury]" are jokes)
function Rules.SeeksAnswer(text)
    local first = string.match(Rules.Normalize(text), "^(%S+)")
    local shaped = (first ~= nil and QUESTION_WORDS[first] == true) or string.find(text, "%?%s*$") ~= nil
    if not shaped then
        return false
    end
    return Rules.Score(Rules.StripLinks(text)).game > 0
end

local function firstName(sender)
    local name = type(sender) == "string" and string.match(sender, "^(%S+)") or nil
    if name and #name >= 3 then
        return name
    end
    return nil
end

local function remember(sender, now, side)
    local name = firstName(sender)
    if name and now then
        speakers[name] = { sender = sender, at = now, side = side }
    end
end

-- somebody named in the line - written as a name, capitalised - who spoke recently: { sender, side } or nil
local function namedSpeaker(text, now)
    if not now then
        return nil
    end
    for name, speaker in pairs(speakers) do
        if now - speaker.at <= SPEAKER_SECONDS and string.find(text, "%f[%w]" .. name .. "%f[%W]") then
            return speaker
        end
    end
    return nil
end

local function wordCount(line)
    local count = 0
    for _ in string.gmatch(line, "%S+") do
        count = count + 1
    end
    return count
end

-- the words of a question worth sharing: five letters or more, so that "the" and "does" are not a topic
local function topicWords(text)
    local set = {}
    for _, word in ipairs(words(Rules.Normalize(text))) do
        if #word >= 5 then
            set[word] = true
        end
    end
    return set
end

local function sharesTopic(question, line)
    for _, word in ipairs(words(line)) do
        if question.topic[word] then
            return true
        end
    end
    return false
end

local KIND_WORDS = { trade = "trade", groups = "a group forming", guilds = "guild business", questions = "a question about the game",
    talk = "game talk", chatter = "chatter", world = "the world outside" }
Rules.KIND_WORDS = KIND_WORDS

-- Which of trade, groups and guilds the words favour: the biggest sum, a tie to guilds, then groups.
local function business(kinds)
    local best, bestSum = nil, 0
    for _, kind in ipairs({ "guilds", "groups", "trade" }) do
        local sum = kinds[kind] or 0
        if sum > bestSum then
            best, bestSum = kind, sum
        end
    end
    return best
end

-- The verdict for one line: { keep = bool, kind, reason, score, hits, work }.
--   shown   which kinds stay: a table { trade = true, ... } or a preset's name ("trade" | "game" | "chat")
--   sender  who said it (for the conversation), or nil
--   now     the time, seconds, or nil
--   sticky  whether the thread rule is on (default on)
--   answers whether chatter after a game question, or naming a game speaker, counts as one (default on)
-- `work` names every word that counted with its weight, and the score: what '/gtf test' and a click in
-- the review window show.
function Rules.Verdict(text, shown, sender, now, sticky, answers)
    if type(shown) ~= "table" then
        shown = Rules.PRESETS[shown or "game"] or Rules.PRESETS.game
    end
    local scored = Rules.Score(text)
    local score = scored.score
    local loud = scored.real <= -LOUD
    local kind, reason
    if (scored.kinds.web or 0) <= -LOUD then
        kind, reason = "world", "a web address"
    elseif (scored.kinds.seller or 0) <= -LOUD then
        kind, reason = "world", "a seller for real money: " .. named(scored.hits, -1)
    elseif (scored.kinds.crude or 0) <= -LOUD then
        kind, reason = "world", "the anal joke"
    elseif loud then
        kind, reason = "world", "real-world talk: " .. named(scored.hits, -1)
    elseif score < 0 then
        kind, reason = "world", "the world outside: " .. named(scored.hits, -1)
    elseif business(scored.kinds) then
        kind = business(scored.kinds)
        reason = KIND_WORDS[kind] .. ": " .. named(scored.hits, 1)
    elseif score > 0 and Rules.LooksLikeQuestion(text) then
        kind, reason = "questions", "a question about the game: " .. named(scored.hits, 1)
    elseif score > 0 then
        kind, reason = "talk", "game talk: " .. named(scored.hits, 1)
    else
        kind, reason = "chatter", "chatter"
        -- ... unless it is part of a conversation
        local speaker = namedSpeaker(text, now)
        if speaker and speaker.side == "world" then
            kind, reason = "world", "a reply to " .. speaker.sender .. ", who was talking about the world outside"
        elseif answers ~= false and speaker then
            kind, reason = "questions", "a reply to " .. speaker.sender
        elseif answers ~= false and question and now and now <= question.until_ and question.answers < ANSWERS_MAX
            and (wordCount(Rules.Normalize(text)) <= ANSWER_WORDS
                or (wordCount(Rules.Normalize(text)) <= ANSWER_WORDS_TOPIC and sharesTopic(question, Rules.Normalize(text)))) then
            kind, reason = "questions", "an answer after " .. question.sender .. "'s question"
            question.answers = question.answers + 1
            question.until_ = math.max(question.until_, now + ANSWER_SECONDS)
        elseif answers ~= false and sender and now and lastSaid[sender] and now - lastSaid[sender] <= GOES_ON_SECONDS
            and wordCount(Rules.Normalize(text)) <= GOES_ON_WORDS then
            -- a discussion goes on: somebody whose own last line was about the game is still talking about
            -- it - in a line the length of a reply, not a speech
            kind, reason = "talk", "goes on from their own game line"
        end
    end
    -- a meme flood: a word everybody is joking with makes a line chatter, unless the line is business or the
    -- world outside already
    local meme = Rules.MemeWord(text)
    if meme and (kind == "talk" or kind == "chatter" or kind == "questions") then
        kind, reason = "chatter", "the " .. meme .. " meme"
    end
    -- the thread rule: a real-world talker's CHATTER goes on for a while; a line with a word of the game is its own
    if sticky ~= false and sender and now and kind ~= "world" and scored.game == 0 then
        local since = threads[sender]
        if since and now - since <= THREAD_SECONDS then
            kind, reason = "world", "goes on from a real-world line (" .. reason .. ")"
        end
    end
    -- what the line means for the lines to come
    if sender and now then
        if kind == "world" then
            threads[sender] = now
            remember(sender, now, "world")
        else
            if scored.game >= THREAD_ESCAPE then
                threads[sender] = nil
            end
            remember(sender, now, "game")
            if kind ~= "chatter" then
                lastSaid[sender] = now -- a word of the game, or an answer in a discussion: part of it either way
            end
            -- a question about the game or about trade that seeks an answer opens the window ("is the AH
            -- linked?" gets its answers in chat; a group forming gets them by whisper), and an answer never
            -- opens a window of its own
            if (kind == "questions" or kind == "trade") and Rules.SeeksAnswer(text) then
                question = { sender = sender, at = now, until_ = now + QUESTION_SECONDS, answers = 0, topic = topicWords(text) }
            end
        end
    end
    local keep = kind ~= "world" and shown[kind] == true
    if not keep and kind ~= "world" then
        reason = reason .. " (" .. kind .. " off)"
    end
    -- the words with their weights, and the score
    local parts = {}
    for _, h in ipairs(scored.hits) do
        parts[#parts + 1] = h.term .. " " .. (h.weight > 0 and "+" or "") .. h.weight
    end
    local work = (#parts > 0 and table.concat(parts, ", ") or "no word of either side") .. " (score " .. score .. ")"
    return {
        keep = keep,
        kind = kind,
        reason = reason,
        score = score,
        hits = scored.hits,
        work = work,
    }
end

-- An advert, wherever it is said: a web address, a seller for real money - or the anal joke, spam of the
-- same standing. The reason and the work, or nothing. (No sender, no time: nothing is remembered of the
-- line, no conversation is touched.)
function Rules.Advert(text)
    local verdict = Rules.Verdict(text, "chat")
    if verdict.reason == "a web address" or verdict.reason == "the anal joke" or string.find(verdict.reason, "^a seller for real money", 1) then
        return verdict.reason, verdict
    end
    return nil
end

-- What '/gtf test <line>' prints
function Rules.Explain(text, shown)
    local verdict = Rules.Verdict(text, shown or "game")
    return (verdict.keep and "KEPT" or "HIDDEN") .. " (" .. verdict.reason .. "; " .. verdict.work .. ")"
end
