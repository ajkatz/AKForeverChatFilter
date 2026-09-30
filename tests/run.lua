-- Scenario tests for AKForeverTradeFilter: lua tests/run.lua  (from the addon's folder)
package.path = "tests/?.lua;" .. package.path
local Mock = require("wowmock")

local passed, failures = 0, {}

local function check(condition, message)
    if not condition then
        error(message or "check failed", 2)
    end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message and (message .. ": ") or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function scenario(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok and #Mock.errors > 0 then
        ok, err = false, "the addon raised an error: " .. tostring(Mock.errors[1])
    end
    if ok then
        passed = passed + 1
        Mock.realPrint("  ok    " .. name)
    else
        failures[#failures + 1] = name
        Mock.realPrint("  FAIL  " .. name .. "\n          " .. tostring(err):gsub("\n", "\n          "))
    end
end

local function start(options)
    local ns, state = Mock.install(options)
    Mock.login()
    return ns, state
end

local function printed(text)
    for _, line in ipairs(Mock.printed) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

local function lastLog(ns)
    local log = ns.db.log
    return log[#log]
end

local SWORD = "|cff0070dd|Hitem:2296:0:0:0:0:0:0:0:60|h[Gloves of Old]|h|r"

------------------------------------------------------------------------
Mock.realPrint("AKForeverTradeFilter scenarios")

scenario("the rules: seven kinds of line, and every verdict says why", function()
    local ns = start()
    local Rules = ns.Rules
    local function verdict(text, shown)
        return Rules.Verdict(text, shown or "game")
    end
    local v = verdict("WTS " .. SWORD .. " 50g pst")
    equal(v.keep, true); equal(v.kind, "trade"); check(v.reason:find("^trade: "), v.reason)
    check(v.reason:find("wts", 1, true) and v.reason:find("50g", 1, true), "the trade words are named: " .. v.reason)
    equal(v.score, 3 + 2 + 2 + 2 + 1, "a link, wts, a sum of gold, pst, and the gloves")
    equal(verdict("LFM SM cath need healer and 1 dps").kind, "groups")
    equal(verdict("lf healer for wc").kind, "groups")
    equal(verdict("lf lock for summons at brd, will tip").kind, "trade", "a service for a tip, though it starts with lf")
    equal(verdict("<Forever Bound> is recruiting all classes for MC, pst").kind, "guilds")
    check(verdict("<Forever Bound> is recruiting all classes for MC, pst").reason:find("a <guild>", 1, true))
    equal(verdict("lf guild, 60 rogue").kind, "guilds", "looking for one is guild business too")
    equal(verdict("how do i get to booty bay").kind, "questions")
    check(verdict("how do i get to booty bay").reason:find("^a question about the game"), verdict("how do i get to booty bay").reason)
    equal(verdict("anyone know if they are gonna up the level?").kind, "questions")
    equal(verdict("gnome is fun on the other side").kind, "talk")
    equal(verdict("did someone say " .. SWORD .. "?").kind, "questions", "a link alone is not trade")
    equal(verdict("anyone else think trump is doing great").kind, "world")
    equal(verdict("anyone else think trump is doing great").reason, "real-world talk: trump")
    equal(verdict("lol").kind, "chatter"); equal(verdict("lol").reason, "chatter (chatter off)"); equal(verdict("lol").sure, false, "nothing to go by")
    equal(verdict("anyone else lagging?").kind, "questions", "lag is the game's")

    -- the presets
    equal(verdict("WTS " .. SWORD .. " 50g", "trade").keep, true)
    equal(verdict("LFM SM cath need healer", "trade").keep, false, "mode trade: trade only")
    check(verdict("LFM SM cath need healer", "trade").reason:find("(groups off)", 1, true))
    equal(verdict("how do i get to booty bay", "trade").keep, false)
    equal(verdict("how do i get to booty bay", "game").keep, true)
    equal(verdict("lol", "game").keep, false); equal(verdict("lol", "chat").keep, true)
    equal(verdict("lol", "balanced").keep, true, "the first version's names still work"); equal(verdict("lol", "strict").keep, false)
    equal(verdict("trump 2028", "chat").keep, false, "the world outside never stays")
    -- one kind at a time
    local noGuilds = { trade = true, groups = true, guilds = false, questions = true, talk = true, chatter = false }
    equal(verdict("<Forever Bound> is recruiting", noGuilds).keep, false)
    equal(verdict("LFM SM", noGuilds).keep, true)

    -- the world outweighs the game, but not a trade line with a link and a price
    equal(verdict("biden is a warlock lol").keep, false, "a loud word of the world outweighs a word of the game")
    equal(verdict("wts " .. SWORD .. " 50g made in china").keep, false, "a country named is a line gone, trade or not: the user's rule")
    equal(verdict("Trump offering $5k to voters, imagine how much gold that can get YOU").kind, "world", "a politician named is a line gone, gold or not")
    equal(verdict("alex jones was right about everything").kind, "world", "heard in Trade, 2026-09-30")
    equal(verdict("when is FRESH?").kind, "questions", "a fresh realm is the game's")
    equal(verdict("anyone else super laggy first time loggin in this week").kind, "questions")
    equal(verdict("+2 trillion debt, WINNING").keep, false)
    equal(verdict("LF bottom/twink/trans/ in nc pm me").keep, false, "the slang of this chat")
    equal(verdict("whats a woman").keep, false, "people, as the world talks about them"); equal(verdict("whats a woman").kind, "world")
    equal(verdict("any girl gamers here? im a hunter").keep, false, "a word of the game and a word of the world: nothing to go by")
    equal(verdict("fembois in orgrimmar").keep, false, "a word of the game and a word of the world: nothing to go by")
    equal(verdict("any femboy guild?").kind, "guilds", "in passing does not undo guild business - the user's own call on that line")
    equal(verdict("yeah horde is mostly betas, shame").keep, false, "troll bait with a word of the game in it")
    equal(verdict("Furries are bestiality enthusiasts and should be catapulted into an active volcano.").kind, "world")
    equal(verdict("trade channel is for trading ragebait").kind, "world")
    equal(verdict("Damage Per Second looking for Ruins of Lordaeron Please Send Tell!").kind, "groups", "Forever's own dungeon, and the long form of LF")
    equal(verdict("EVERYONE REPORT A BUG").keep, true, "bug reports are the beta's business")
    equal(verdict("Yeah therapy is literally indoctrination camps you pay for").kind, "world")
    equal(verdict("go to therapy").keep, false)
    equal(verdict("they are all pedos").kind, "world", "the plural of a listed word is the same word")
    equal(verdict("blizzard hires pedophiles").kind, "world")
    check(verdict("blizzard hires pedophiles").reason:find("pedophiles", 1, true))
    equal(verdict("the trumps are at it again").kind, "world")
    equal(verdict("wts mageweaves cheap").kind, "trade", "and on the game's side too")
    equal(verdict("the middle east is a mess again").kind, "world", "a region of the world is the world")
    equal(verdict("<Fellowship of Divas> is a new guild for making friends of every gender, pst").kind, "guilds", "a word in passing does not undo a guild ad")
    equal(verdict("imagine still playing horde in 2026").kind, "world", "a line that opens with 'imagine' is bait")
    check(verdict("imagine still playing horde in 2026").reason:find("imagine", 1, true), verdict("imagine still playing horde in 2026").reason)
    equal(verdict("lol imagine being a mage").kind, "world")
    equal(verdict("wts " .. SWORD .. " 50g, imagine the dps").kind, "trade", "'imagine' in the middle of a line is just a word")
    equal(verdict("wts boots man 5g").kind, "trade", "'man' in passing does not undo a trade line")
    equal(verdict("i heard she strangled her kids with a " .. SWORD).keep, false, "a crime story is the world's, link or not")
    equal(verdict("no one changes how they think through someone spergin in trade chat").kind, "chatter", "'trade chat' is the channel, not trade")
    equal(verdict("wts boots, whisper me in trade chat").kind, "trade", "but a trade line is still trade")
    equal(verdict("damn AH is fucked, bronze is the same price as tin").kind, "trade", "AH in capitals is the auction house")
    equal(verdict("ah ok thanks").kind, "chatter", "'ah' in lower case is a sigh")
    equal(verdict("need 9 more guild sigs").kind, "guilds", "signatures are guild business")
    equal(verdict("trade war is killing the economy").keep, false, "'trade war' is a phrase of the world, whatever 'trade' is")
    equal(verdict("Trump's a joke").reason, "real-world talk: trump", "a possessive is the same word")
    equal(verdict("the alt-right is at it again").keep, false, "a hyphen is a space")
    check(verdict("the alt-right is at it again").reason:find("alt right", 1, true))

    -- countries are a hard pass; nationalities in passing
    equal(verdict("the US is falling apart").keep, false)
    equal(verdict("the US is falling apart").reason, "real-world talk: US")
    equal(verdict("us on the way to brd").keep, true, "'us' the pronoun is nobody's country")
    equal(verdict("JOIN US FOR MC TONIGHT").keep, true, "shouted in capitals, the pair says nothing")
    equal(verdict("canada is nice this time of year").keep, false)
    equal(verdict("any canadians here?").keep, false, "in passing counts against a line with nothing else")
    equal(verdict("any canadians here?").reason, "the world outside: canadians")
    equal(verdict("french speaking guild recruiting").keep, true, "guild business in another language is guild business")
    equal(verdict("french speaking guild recruiting").kind, "guilds")
    equal(verdict("israel and iran again").keep, false)
    equal(verdict("what did obama ever do").keep, false, "a former president is an easy one")
    equal(verdict("reagan would have hated this").keep, false)
    equal(verdict("nice weather today", "chat").keep, false, "in passing is enough with nothing on the game's side")
    -- a tank that holds gas (heard in Trade, 2026-09-30)
    equal(verdict("my gas tank is empty").keep, false, "a tank that holds gas is the world's")
    check(verdict("my gas tank is empty").reason:find("gas tank", 1, true), verdict("my gas tank is empty").reason)
    equal(verdict("need a tank for brd").kind, "groups")
    equal(verdict("fish tank cleaning day").keep, false)
    equal(verdict("raid this weekend?").keep, true, "the weekend is when raids happen: not a word of the world")
    equal(verdict("gg everyone", "chat").keep, true)

    -- how sure, and on what
    equal(verdict("WTS " .. SWORD .. " 50g pst").confidence, "sure")
    check(verdict("WTS " .. SWORD .. " 50g pst").work:find("wts +2", 1, true) and verdict("WTS " .. SWORD .. " 50g pst").work:find("(score 10)", 1, true), verdict("WTS " .. SWORD .. " 50g pst").work)
    equal(verdict("trump 2028").confidence, "certain: a loud word of the world outside is a hard pass")
    equal(verdict("lf healer").confidence, "fairly sure")
    equal(verdict("gnome is fun").confidence, "leaning, on one word")
    equal(verdict("lol").confidence, "nothing to go by"); equal(verdict("lol").work, "no word of either side (score 0)")
    -- what '/gtf test' prints
    check(Rules.Explain("wts sword 50g"):find("^KEPT %(trade"), Rules.Explain("wts sword 50g"))
    check(Rules.Explain("trump 2028"):find("^HIDDEN %(real%-world talk: trump; certain: a loud word of the world outside is a hard pass; trump %-3 %(score %-3%)%)"), Rules.Explain("trump 2028"))
end)

scenario("a thread: after a real-world line the same sender's chatter goes too, and a reply naming them, unless clearly game business", function()
    local ns = start()
    local Rules = ns.Rules
    Rules.ResetThreads()
    local now = 1000
    equal(Rules.Verdict("trump 2028", "chat", "Bob Bobson", now, true).keep, false)
    local v = Rules.Verdict("lol no way", "chat", "Bob Bobson", now + 30, true)
    equal(v.keep, false, "chatter that follows a real-world line is the same thread")
    check(v.reason:find("^goes on from a real%-world line"), v.reason)
    equal(Rules.Verdict("lol no way", "chat", "Alice Aly", now + 30, true).keep, true, "somebody else's chatter is not")
    v = Rules.Verdict("Bob you are so right", "chat", "Carl Carlson", now + 40, true)
    equal(v.keep, false, "... unless it names him"); check(v.reason:find("^a reply to Bob Bobson, who was talking about the world outside"), v.reason)
    v = Rules.Verdict("then why do i get stormwind mail", "chat", "Bob Bobson", now + 50, true)
    equal(v.keep, true, "a line with a word of the game is its own, thread or no thread"); equal(v.kind, "talk")
    equal(Rules.Verdict("trump 2028", "chat", "Bob Bobson", now + 55, true).keep, false)
    equal(Rules.Verdict("wts " .. SWORD, "chat", "Bob Bobson", now + 60, true).keep, true, "clearly game business escapes the thread")
    equal(Rules.Verdict("lol no way", "chat", "Bob Bobson", now + 90, true).keep, true, "and ends it")
    equal(Rules.Verdict("trump 2028", "chat", "Bob Bobson", now + 100, true).keep, false)
    equal(Rules.Verdict("lol no way", "chat", "Bob Bobson", now + 100 + 181, true).keep, true, "a thread is three minutes long")
    equal(Rules.Verdict("trump 2028", "chat", "Bob Bobson", now + 400, false).keep, false)
    equal(Rules.Verdict("lol no way", "chat", "Bob Bobson", now + 410, false).keep, true, "sticky off: every line on its own")
end)

scenario("a conversation about the game: the answers to a game question count as questions, and so does a reply naming somebody who just spoke", function()
    local ns = start()
    local Rules = ns.Rules
    Rules.ResetThreads()
    local now = 2000
    local function verdict(text, sender, at, shown)
        return Rules.Verdict(text, shown or "game", sender, now + at, true, true)
    end
    -- the first real session, as it went
    equal(verdict("anyone know if they are gonna up the level?", "Firemoon Night", 0).kind, "questions")
    local v = verdict("yes tomorrow", "Shadow Seer", 5)
    equal(v.keep, true, "an answer"); equal(v.kind, "questions"); equal(v.reason, "an answer after Firemoon Night's question"); equal(v.sure, false, "a guess, for the trainer")
    equal(verdict("i think tomorrow no?", "Gaga Prime", 8).keep, true)
    equal(verdict("yes", "Perdition Eversorrow", 12).keep, true)
    equal(verdict("my mandated union break is over, gotta go back to work now", "Lightbringer Nictalope", 13).keep, false, "a speech is no answer")
    equal(verdict("Link please head from Leatherworking please", "Holly Boy", 20).kind, "talk")
    v = verdict("which one Holly", "Inyanis Ninyomae", 25)
    equal(v.keep, true); equal(v.reason, "a reply to Holly Boy", "named, whatever the timing")
    -- the window: three quarters of a minute, each answer buying fifteen seconds more, three answers at most
    equal(verdict("lol", "Someone Else", 26).keep, false, "three answers is enough: the fourth is chatter")
    equal(verdict("ok", "Another One", 26 + 16).keep, false, "and the window is closed anyway (for somebody who said nothing before)")
    equal(verdict("Does anyone want to do Wailing Caverns?", "Cbiscuit Lancer", 95).kind, "groups")
    equal(verdict("RIP Man City hahaha", "Maelor Cadarn", 97).keep, false, "a group forming gets its answers by whisper: no window")
    equal(verdict("holly which one", "Stranger Sam", 100).keep, false, "a name is written as a name: Forever's first names are common words")
    -- an answer that ends in a question mark opens no window of its own; a joke question opens none at all
    equal(verdict("where is the wc entrance", "Asker Askerson", 120).kind, "questions")
    equal(verdict("?", "Puzzled Pete", 150).keep, true, "an answer, of sorts")
    equal(verdict("nothing", "Someone Else", 166).keep, false, "the answer bought fifteen seconds, not a window of its own")
    equal(verdict("did someone say " .. SWORD .. "?", "Meme Lord", 250).kind, "questions")
    equal(verdict("lol", "Someone Else", 252).keep, false, "a joke question seeks no answer: no window")
    equal(verdict("What would ya do for a " .. SWORD, "Meme Lord", 260).kind, "questions")
    equal(verdict("anything", "Someone Else", 262).keep, false, "a question with nothing but a link's name in it: no window either")
    equal(verdict("where is the rfd entrance", "Asker Askerson", 300).kind, "questions")
    for index = 1, 3 do
        equal(verdict("answer " .. index, "Helper " .. index, 300 + index).keep, true, "answer " .. index)
    end
    equal(verdict("answer 4", "Helper 4", 304).keep, false, "three answers is enough")
    -- an answer is short, or shares a word with the question
    equal(verdict("anyone know when the level cap goes up?", "Asker Askerson", 350).kind, "questions")
    v = verdict("anyone who says tomorrow is guessing", "Helper Hal", 352)
    equal(v.keep, true, "six words, but 'anyone' is the question's"); equal(v.reason, "an answer after Asker Askerson's question")
    equal(verdict("what is love tell me more", "Joker Joe", 353).keep, false, "six words of something else")
    equal(verdict("cannibalistic humanoid underground dweller", "Joker Joe", 354).keep, true, "four words: short enough to be an answer, right or wrong")
    -- not with answers off, nor with questions hidden
    equal(verdict("where is the rfd entrance", "Asker Askerson", 400).kind, "questions")
    equal(Rules.Verdict("yes tomorrow", "game", "Shadow Seer", now + 402, true, false).keep, false, "answers off: chatter is chatter")
    equal(verdict("yes tomorrow", "Shadow Seer", 403, "trade").keep, false, "mode trade: no questions, no answers")
    -- a question about the world outside opens no window
    equal(verdict("who is voting for trump?", "Bob Bobson", 500).kind, "world")
    equal(verdict("me", "Carl Carlson", 502).keep, false)
    -- a name shorter than three letters is no name to go by
    equal(verdict("wts " .. SWORD, "Al Alson", 600).kind, "trade")
    equal(verdict("Al is here", "Dan Danson", 601).keep, false)
    -- a discussion goes on: chatter from somebody whose own last line was about the game (the AH-linking
    -- discussion of 2026-09-30: "correct, it is not", "they are connected", "back in the very old days...")
    v = verdict("Just noticed, the auction house doesn't appear to be linked between ally and horde?", "Asker Askerson", 700)
    equal(v.kind, "trade", "'auction house' makes it trade - and a question mark at the end makes it seek an answer")
    equal(verdict("correct, it is not", "Helper Hal", 705).reason, "an answer after Asker Askerson's question")
    equal(verdict("then why do i get stormwind mail", "Asker Askerson", 740).kind, "talk")
    v = verdict("because it never has and never will", "Helper Hal", 760)
    equal(v.keep, true); equal(v.kind, "talk"); equal(v.reason, "goes on from their own game line", "Hal answered 55 seconds ago: part of the discussion")
    equal(v.confidence, "a guess: the conversation, not the words")
    equal(verdict("back in the very old days, cities had their own individual auction houses, it is connected now", "Helper Hal", 800).kind, "trade", "an auction house in it: trade, and kept either way")
    equal(verdict("thank the stars!", "Asker Askerson", 795).keep, true, "the asker goes on too")
    equal(verdict("outrage man, anger is the only language they know so it just oozes out of every one of them", "Asker Askerson", 810).keep, false,
        "a speech is not a reply: eleven words or more stand on their own")
    equal(verdict("lol", "Bystander Bill", 806).keep, false, "somebody who said nothing about the game does not")
    equal(verdict("what da hell", "Helper Hal", 800 + 61).keep, false, "a minute on, it is chatter again")
    equal(Rules.Verdict("what da hell", "game", "Helper Hal", now + 810, true, false).keep, false, "answers off: chatter is chatter")
    -- the same through the filter, with the real settings: answers are OFF out of the box - they come by whisper
    Mock.chat({ text = "anyone know where the wc entrance is?", sender = "Ann Annson" })
    equal(Mock.chat({ text = "south of the crossroads, in the mountain", sender = "Ben Benson" }), true, "kept by its words")
    equal(Mock.chat({ text = "yes", sender = "Cal Calson" }), false, "the bare answer is chatter out of the box")
    SlashCmdList.AKFOREVERTRADEFILTER("answers on")
    Mock.chat({ text = "anyone know where the wc entrance is?", sender = "Ann Annson" })
    equal(Mock.chat({ text = "yes", sender = "Cal Calson" }), true, "... and an answer when asked for")
    equal(lastLog(ns).kind, "questions")
    equal(lastLog(ns).conf, "a guess: the conversation, not the words"); check(lastLog(ns).work:find("no word of either side", 1, true), lastLog(ns).work)
    SlashCmdList.AKFOREVERTRADEFILTER("answers off")
    equal(Mock.chat({ text = "yes", sender = "Cal Calson" }), false)
    SlashCmdList.AKFOREVERTRADEFILTER("hide questions")
    check(printed("a question about the game: hidden"))
    equal(Mock.chat({ text = "anyone know where the wc entrance is?", sender = "Ann Annson" }), false, "questions off: the question goes too")
    equal(Mock.chat({ text = "wts " .. SWORD, sender = "Ann Annson" }), true)
    SlashCmdList.AKFOREVERTRADEFILTER("kinds")
    check(printed("hidden: questions, chatter"), "the kinds are listed")
    SlashCmdList.AKFOREVERTRADEFILTER("hide guilds")
    equal(Mock.chat({ text = "<Forever Bound> is recruiting", sender = "Eve Evans" }), false, "guild recruitment off")
    SlashCmdList.AKFOREVERTRADEFILTER("mode game")
    equal(Mock.chat({ text = "<Forever Bound> is recruiting", sender = "Eve Evans" }), true, "a preset puts every kind back")
    SlashCmdList.AKFOREVERTRADEFILTER("hide world")
    check(printed("usage: /gtf hide trade | groups"), "the world outside cannot be shown")
    SlashCmdList.AKFOREVERTRADEFILTER("mode trade")
    check(printed("mode: trade (trade only)"))
    equal(Mock.chat({ text = "LFM SM cath need healer", sender = "Ann Annson" }), false)
    -- the first version's setting is read as its preset
    local db = AKForeverTradeFilterDB
    db.chars["Purrdee - ClassicBetaPvE"].options.kinds = nil
    db.chars["Purrdee - ClassicBetaPvE"].options.mode = "balanced"
    ns = start({ db = db })
    equal(ns.Filter.ModeName(), "chat")
end)

scenario("the words you teach outrank the lists, and are kept", function()
    local ns = start()
    equal(ns.Rules.Verdict("who wants noggenfogger", "game").keep, true, "an elixir of the game")
    SlashCmdList.AKFOREVERTRADEFILTER("block noggenfogger")
    check(printed("'noggenfogger' is the world outside from now on"))
    equal(ns.Rules.Verdict("who wants noggenfogger", "game").keep, false)
    equal(ns.Rules.Verdict("spaghetti time", "game").keep, false)
    SlashCmdList.AKFOREVERTRADEFILTER("allow spaghetti time")
    equal(ns.Rules.Verdict("spaghetti time", "game").keep, true, "a phrase can be taught too")
    equal(ns.db.words["spaghetti time"], "game")
    SlashCmdList.AKFOREVERTRADEFILTER("words")
    check(printed("spaghetti time - game business") and printed("noggenfogger - the world outside") and printed("2 word(s) taught"))
    SlashCmdList.AKFOREVERTRADEFILTER("unlearn noggenfogger")
    equal(ns.Rules.Verdict("who wants noggenfogger", "game").keep, true)
    SlashCmdList.AKFOREVERTRADEFILTER("unlearn cheese")
    check(printed("usage: /gtf unlearn"))

    -- taught words come back next session
    local db = AKForeverTradeFilterDB
    ns = start({ db = db })
    equal(ns.Rules.Verdict("spaghetti time", "game").keep, true, "remembered")
end)

scenario("only Trade is filtered out of the box; General when asked; every other channel is left alone", function()
    local ns = start()
    equal(ns.Filter.how, "ChatFrameUtil.AddMessageEventFilter")
    equal(Mock.chat({ text = "wts " .. SWORD .. " 50g" }), true, "trade shows")
    equal(Mock.chat({ text = "trump is the best" }), false, "politics does not")
    equal(#Mock.shownIn("ChatFrame1"), 1); equal(#Mock.shownIn("ChatFrame2"), 1, "both windows that show Trade")
    equal(ns.Filter.stats.seen, 2, "one line, two windows: decided once")
    equal(ns.Filter.stats.hidden, 1); equal(#ns.db.log, 2, "and logged once")
    equal(lastLog(ns).keep, false); equal(lastLog(ns).why, "real-world talk: trump"); equal(lastLog(ns).who, "Bob"); equal(lastLog(ns).ch, "trade")
    equal(lastLog(ns).id, 2, "every logged line has its number")

    equal(Mock.chat({ text = "trump is the best", channel = "general" }), true, "General is left alone out of the box")
    SlashCmdList.AKFOREVERTRADEFILTER("general on")
    equal(Mock.chat({ text = "trump is the best", channel = "general" }), false, "... until asked")
    equal(lastLog(ns).ch, "general")
    equal(Mock.chat({ text = "trump is the best", channel = "World" }), true, "a channel this addon does not know is never touched")
    equal(ns.Filter.stats.seen, 3, "and not decided on")

    SlashCmdList.AKFOREVERTRADEFILTER("off")
    equal(Mock.chat({ text = "trump is the best" }), true, "off: every line shows")
    equal(ns.Filter.stats.seen, 3, "and nothing is decided")
    SlashCmdList.AKFOREVERTRADEFILTER("on")
    equal(Mock.chat({ text = "trump is the best" }), false)

    SlashCmdList.AKFOREVERTRADEFILTER("mode chat")
    equal(Mock.chat({ text = "lol", sender = "Carl" }), true, "chat keeps chatter (from somebody who was not just talking politics)")
    equal(Mock.chat({ text = "lol" }), false, "Bob was: his chatter goes on from his real-world line")
    SlashCmdList.AKFOREVERTRADEFILTER("mode game")
    equal(Mock.chat({ text = "lol", sender = "Carl" }), false, "game does not")
    SlashCmdList.AKFOREVERTRADEFILTER("mode sideways")
    check(printed("usage: /gtf mode trade | game | chat"))

    -- unreadable: hands off, and counted
    equal(Mock.chat({ text = "trump is the best", secret = "text" }), true, "a secret line goes through untouched")
    equal(ns.Filter.stats.secretEvents, 1, "the event saw it")
    equal(Mock.chat({ text = "trump is the best", secret = "sender" }), true)

    SlashCmdList.AKFOREVERTRADEFILTER("stats")
    check(printed("hidden"), "the count is printed")
    SlashCmdList.AKFOREVERTRADEFILTER("test trump 2028")
    check(printed("HIDDEN (real-world talk: trump; certain"))
end)

scenario("the channel is known by its number, or failing that by its name", function()
    local ns = start()
    equal(ns.Filter.ChannelKind(2, "Trade - City", "2. Trade - City"), "trade")
    equal(ns.Filter.ChannelKind(1, "General - Durotar"), "general")
    equal(ns.Filter.ChannelKind(0, "Trade - City"), "trade", "the name will do")
    equal(ns.Filter.ChannelKind(nil, nil, "3. General - Orgrimmar"), "general")
    equal(ns.Filter.ChannelKind(26, "LookingForGroup"), nil)
    equal(ns.Filter.ChannelKind(0, "World"), nil)
    equal(ns.Filter.ChannelKind(Mock.SECRET, Mock.SECRET, Mock.SECRET), nil, "secrets are nobody's channel")
end)

scenario("a client with the older filter API, and one with none at all", function()
    local ns = start({ legacyFilterApi = true })
    equal(ns.Filter.how, "ChatFrame_AddMessageEventFilter")
    equal(Mock.chat({ text = "trump is the best" }), false, "filtered all the same")

    ns = start({ noFilterApi = true })
    equal(ns.Filter.how, "this client has no message event filter", "says so, no error")
    equal(Mock.chat({ text = "trump is the best" }), true, "and every line shows")
end)

scenario("the review window: the lines that went, with the reason; a click flags a verdict as wrong", function()
    local ns = start()
    Mock.chat({ text = "wts " .. SWORD .. " 50g", sender = "Alice" })
    Mock.chat({ text = "trump is the best", sender = "Bob" })
    Mock.chat({ text = "lol", sender = "Carl" })
    SlashCmdList.AKFOREVERTRADEFILTER("review")
    local window, list = AKForeverTradeFilterWindow, AKForeverTradeFilterReview
    check(window and window:IsShown(), "the window is up")
    equal(ns.Trainer:Describe().page, "review")
    equal(#list.__messages, 2, "the two hidden lines")
    check(list.__messages[1]:find("Bob", 1, true) and list.__messages[1]:find("real-world talk: trump", 1, true), list.__messages[1])
    check(list.__messages[1]:find("|Hgtf:2|h", 1, true), "each line is a link to itself")
    check(list.__messages[1]:find("hidden|r world", 1, true), "the kind is shown: " .. list.__messages[1])
    check(list.__messages[1]:find("[certain]", 1, true), "and how sure: " .. list.__messages[1])
    check(list.__messages[2]:find("chatter", 1, true))
    check(ns.Trainer.widgets.note:GetText():find("hidden lines, 2 shown", 1, true), ns.Trainer.widgets.note:GetText())

    SlashCmdList.AKFOREVERTRADEFILTER("review all")
    equal(#list.__messages, 3, "every line")
    check(list.__messages[1]:find("[Gloves of Old]", 1, true) and not list.__messages[1]:find("Hitem", 1, true), "an item link is shown by its name only: " .. list.__messages[1])
    check(list.__messages[1]:find("kept", 1, true))

    Mock.clickLink(list, "gtf:2")
    equal(ns.Filter.EntryById(2).flag, "wrong", "flagged")
    check(list.__messages[2]:find("[flagged wrong]", 1, true), "and shown as such")
    Mock.clickLink(list, "gtf:2")
    equal(ns.Filter.EntryById(2).flag, nil, "a second click takes it back")
    Mock.clickLink(list, "gtf:999")
    Mock.clickLink(list, "item:2296")

    -- the window is dragged and remembers its place
    window.__scripts.OnDragStart(window)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
    window.__scripts.OnDragStop(window)
    equal(ns.cdb.options.window.x, 40)
    SlashCmdList.AKFOREVERTRADEFILTER("reset")
    equal(ns.cdb.options.window, nil)

    SlashCmdList.AKFOREVERTRADEFILTER("clear")
    equal(#ns.db.log, 0)
    equal(#list.__messages, 1); check(list.__messages[1]:find("nothing seen yet", 1, true))
end)

scenario("training: every line is put to you first, then the filter's call comes up beside yours, and the score keeps count", function()
    local ns = start()
    SlashCmdList.AKFOREVERTRADEFILTER("train on")
    equal(ns:GetOption("training"), "all")
    local w = ns.Trainer.widgets
    equal(ns.Trainer:Describe().page, "train")
    check(w.message:GetText():find("waiting for the next line", 1, true))
    equal(w.trade:IsEnabled(), false, "nothing to answer yet")

    Mock.chat({ text = "wts " .. SWORD .. " 50g", sender = "Alice" })
    Mock.chat({ text = "trump is the best", sender = "Bob" })
    Mock.chat({ text = "lol", sender = "Carl" })
    check(w.message:GetText():find("[Gloves of Old]", 1, true), "the first line is up, links by their name: " .. w.message:GetText())
    check(w.meta:GetText():find("Alice", 1, true) and w.meta:GetText():find("Trade", 1, true), w.meta:GetText())
    check(w.note:GetText():find("2 waiting", 1, true), w.note:GetText())
    equal(w.trade:IsEnabled(), true)
    check(not w.feedback:GetText() or w.feedback:GetText() == "", "nothing said yet")

    Mock.click(w.trade)
    check(w.feedback:GetText():find("Agreed", 1, true) and w.feedback:GetText():find("kept it", 1, true), w.feedback:GetText())
    check(w.feedback:GetText():find("sure - ", 1, true) and w.feedback:GetText():find("wts +2", 1, true), "how sure, and on what: " .. w.feedback:GetText())
    equal(#ns.db.labels, 1); equal(ns.db.labels[1].label, "trade"); equal(ns.db.labels[1].agree, true)
    equal(ns.db.trainStats.asked, 1); equal(ns.db.trainStats.agreed, 1)
    check(w.message:GetText():find("trump", 1, true), "the next line is up")

    Mock.click(w.trade) -- you would have kept the politics: a disagreement
    check(w.feedback:GetText():find("Not what the filter did", 1, true) and w.feedback:GetText():find("hid it", 1, true), w.feedback:GetText())
    equal(ns.db.labels[2].agree, false)
    check(w.tally:GetText():find("1 of 2", 1, true), w.tally:GetText())
    equal(ns.db.trainStats.stamp, ns.Terms.Stamp(), "the tally belongs to this set of rules")
    -- the line stays up and the box asks why; nothing else can be answered meanwhile
    check(w.message:GetText():find("trump", 1, true), "the line stays up for your reason")
    equal(w.why:IsShown(), true); equal(w.next:IsShown(), true)
    equal(w.trade:IsEnabled(), false); equal(w.skip:IsEnabled(), false)
    equal(ns.Trainer:Describe().awaiting, "trump is the best")
    Mock.click(w.trade)
    equal(#ns.db.labels, 2, "no second answer while the box is up")
    Mock.enter(w.why, "  he is a politician, but it was a joke about the game  ")
    equal(ns.db.labels[2].note, "he is a politician, but it was a joke about the game", "your reason, tidied, on your answer")
    equal(ns.db.log[2].note, ns.db.labels[2].note, "and on the line")
    equal(w.why:IsShown(), false, "the box goes")
    check(w.feedback:GetText():find("Noted", 1, true), w.feedback:GetText())
    check(w.message:GetText():find("lol", 1, true), "and the next line is up")
    equal(w.why:GetText(), "", "the box is empty for the next time")

    Mock.click(w.skip)
    check(w.feedback:GetText():find("Skipped", 1, true))
    equal(#ns.db.labels, 2, "a skip is no answer")
    check(w.message:GetText():find("waiting for the next line", 1, true))

    -- a mismatch with no reason: Next moves on; '/gtf note' from chat lands on the last answer
    Mock.chat({ text = "putin did nothing wrong", sender = "Fred" })
    Mock.click(w.trade)
    equal(ns.Trainer:Describe().awaiting, "putin did nothing wrong")
    Mock.click(w.next)
    equal(ns.Trainer:Describe().awaiting, nil); equal(ns.db.labels[3].note, nil, "no reason given")
    SlashCmdList.AKFOREVERTRADEFILTER("note sarcasm, it was mocking him")
    equal(ns.db.labels[3].note, "sarcasm, it was mocking him", "from chat, onto the last answer")
    check(printed("noted, on your last answer"))
    Mock.chat({ text = "obama was better", sender = "Fred" })
    Mock.click(w.trade)
    SlashCmdList.AKFOREVERTRADEFILTER("note same joke")
    equal(ns.db.labels[4].note, "same joke", "from chat, onto the line waiting for a reason")
    equal(ns.Trainer:Describe().awaiting, nil)

    -- your answer sits on the log entry too, for the review page
    equal(ns.db.log[2].label, "trade")

    -- 'unsure': only the lines the filter had nothing to go by
    SlashCmdList.AKFOREVERTRADEFILTER("train unsure")
    Mock.chat({ text = "wts " .. SWORD, sender = "Alice" })
    check(w.message:GetText():find("waiting", 1, true), "a sure line is not asked about")
    Mock.chat({ text = "hmm", sender = "Dan" })
    check(w.message:GetText():find("hmm", 1, true), "an unsure one is")
    Mock.click(w.notTrade)
    local last = ns.db.labels[#ns.db.labels]; equal(last.label, "not"); equal(last.agree, true)

    -- more than fit in the queue: the oldest are let go
    SlashCmdList.AKFOREVERTRADEFILTER("train on")
    for index = 1, 40 do
        Mock.chat({ text = "line " .. index, sender = "Eve" })
    end
    check(w.note:GetText():find("30 waiting", 1, true) and w.note:GetText():find("let go", 1, true), w.note:GetText())

    -- closing the window ends the training
    Mock.click(w.close)
    equal(ns:GetOption("training"), "off")
    equal(AKForeverTradeFilterWindow:IsShown(), false)
    check(printed("training off"))
    Mock.chat({ text = "line 41", sender = "Eve" })
    equal(#ns.db.log > 0, true, "the filter goes on")

    -- training comes back next session
    SlashCmdList.AKFOREVERTRADEFILTER("train on")
    local db = AKForeverTradeFilterDB
    ns = start({ db = db })
    equal(ns.Trainer:Describe().shown, true, "the window is up again")
    equal(ns.Trainer:Describe().page, "train")
    SlashCmdList.AKFOREVERTRADEFILTER("train off")
    check(printed("we agreed on"))

    -- the rules change: the tally so far is put aside and a new one starts
    local asked = ns.db.trainStats.asked
    check(asked > 0)
    ns.db.trainStats.stamp = ns.db.trainStats.stamp + 1 -- (as a changed Terms.lua would)
    SlashCmdList.AKFOREVERTRADEFILTER("train on")
    equal(ns.db.trainStats.asked, 0, "a fresh count"); equal(ns.db.trainStats.stamp, ns.Terms.Stamp())
    equal(ns.db.trainHistory[1].asked, asked, "the old count is kept aside")
    check(ns.Trainer.widgets.tally:GetText():find("since the last tuning", 1, true), ns.Trainer.widgets.tally:GetText())
end)

scenario("diagnostics and logout run; the report is SavedVariables-safe and holds no frame", function()
    local ns = start()
    Mock.chat({ text = "wts " .. SWORD .. " 50g", sender = "Alice" })
    Mock.chat({ text = "trump is the best", sender = "Bob" })
    SlashCmdList.AKFOREVERTRADEFILTER("train on")
    Mock.chat({ text = "hmm", sender = "Dan" })
    Mock.click(ns.Trainer.widgets.notTrade)
    SlashCmdList.AKFOREVERTRADEFILTER("diag")
    check(printed("report saved"))
    Mock.fire("PLAYER_LOGOUT")

    local report = AKForeverTradeFilterDB.diag
    equal(report.asked, true); check(AKForeverTradeFilterDB.diagAtLogout, "the logout's report goes beside it")
    equal(report.addonVersion, "0.1.0-test")
    equal(report.options.mode, "game"); equal(report.options.kinds.guilds, true); equal(report.filter.how, "ChatFrameUtil.AddMessageEventFilter")
    equal(report.filter.stats.seen, 3); equal(report.filter.stats.hidden, 2)
    equal(#report.log, 3); equal(report.log[2].why, "real-world talk: trump")
    equal(#report.labels, 1); equal(report.labels[1].label, "not"); equal(report.labels[1].id, 3, "an answer knows its line")
    check(report.terms.builtIn > 1000, "the lists are counted")
    equal(report.trainer.training, "all")

    local function walk(value, path)
        local kind = type(value)
        check(kind == "table" or kind == "string" or kind == "number" or kind == "boolean", path .. " holds a " .. kind)
        if kind == "table" then
            check(rawget(value, "__kind") == nil, path .. " is a frame")
            for k, v in pairs(value) do
                walk(v, path .. "." .. tostring(k))
            end
        end
    end
    walk(AKForeverTradeFilterDB, "AKForeverTradeFilterDB")
end)

scenario("the log is a ring: eight hundred lines at most, and the saved state comes back", function()
    local ns = start()
    for index = 1, 810 do
        Mock.chat({ text = "trump " .. index, sender = "Bob" })
    end
    equal(#ns.db.log, 800)
    equal(ns.db.log[1].text, "trump 11", "the oldest went")
    equal(ns.db.log[800].id, 810, "numbers keep counting")
    local db = AKForeverTradeFilterDB
    ns = start({ db = db })
    equal(#ns.db.log, 800, "back next session")
    equal(ns.savedStateSource, "client")
end)

scenario("the version: the packager's stamp, a working copy, a release tag", function()
    local ns = start({ version = "@project-version@" })
    equal(ns.version, "dev")
    ns = start({ version = "v0.1.0" })
    equal(ns.version, "0.1.0")
end)

------------------------------------------------------------------------
Mock.realPrint("")
Mock.realPrint(passed .. " passed, " .. #failures .. " failed")
if #failures > 0 then
    os.exit(1)
end
