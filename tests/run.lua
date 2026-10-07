-- Scenario tests for AKForeverChatFilter: lua tests/run.lua  (from the addon's folder)
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
Mock.realPrint("AKForeverChatFilter scenarios")

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
    equal(verdict("lol").kind, "chatter"); equal(verdict("lol").reason, "chatter (chatter off)")
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
    v = verdict("Cheap gold! 5$ per 100g, fast delivery, whisper me")
    equal(v.kind, "world", "a gold seller is a hard pass, whatever the trade words say"); check(v.reason:find("^a seller for real money: "), v.reason)
    -- a shop's advert, as seen 2026-10-02 - with the address, with the address written with a trick, with none
    local AD = "Enjoy Forever - we cover your Leveling & Dungeons & Gearing & Professions! Order for Beta or Pre-Order for release >>> MythicStore"
    equal(verdict(AD .. ".com <<<").reason, "a web address")
    for _, tail in ipairs({ ",com <<<", " .com <<<", ". com <<<", " , com <<<", "(dot)com <<<", " dot com <<<", " [dot] com <<<", " <<<" }) do
        equal(verdict(AD .. tail).keep, false, "the advert, ending '" .. tail .. "'")
    end
    check(verdict(AD .. " <<<").reason:find("^a seller for real money: "), verdict(AD .. " <<<").reason)
    -- what must not be taken for an address or a shop
    equal(verdict("port to UC. Org is full").keep, true, "org is Orgrimmar")
    equal(verdict("lf2m sm, come on").kind, "groups", "'come' is not '.com'")
    equal(verdict("wts fishing pole. net profit 2g").kind, "trade")
    equal(verdict("WTS boost SM 10g per run").kind, "trade", "a player selling a run for gold is trade")
    equal(verdict("in order to get there take the zeppelin").kind, "chatter", "'order' alone is a word, not a shop")
    equal(verdict("wts 1000g, paypal only").kind, "world")
    v = verdict("<Forever Bound> recruiting, join discord.gg/abc123 for a spot in MC")
    equal(v.kind, "world", "a web address is a hard pass, guild ad or not"); equal(v.reason, "a web address")
    equal(verdict("check wowhead.com for the drop rate").keep, false)
    equal(verdict("Cheap gold www.bestgold.com").reason, "a web address", "the address is the first thing seen")
    equal(verdict("lf healer wc, we are 4/5").kind, "groups", "a count is no address")
    equal(verdict("asmongold said forever is dead").kind, "world", "a streamer is the world outside")
    equal(verdict("watching the stream while i fish").keep, false)
    equal(verdict("WTS " .. SWORD .. " 50g cod").kind, "trade", "gold between players is trade")
    equal(verdict("they are all pedos").kind, "world", "the plural of a listed word is the same word")
    equal(verdict("blizzard hires pedophiles").kind, "world")
    check(verdict("blizzard hires pedophiles").reason:find("pedophiles", 1, true))
    -- the anal joke, the oldest spam in Trade (the user, 2026-10-04): the link in it is no game business
    v = verdict("anal " .. SWORD)
    equal(v.kind, "world", "anal and a link"); equal(v.reason, "the anal joke"); equal(v.keep, false)
    equal(verdict("ANAL " .. SWORD .. " " .. SWORD).reason, "the anal joke", "shouted, two links")
    equal(verdict("anal").reason, "the anal joke", "the word alone")
    equal(verdict("Anal.").reason, "the anal joke")
    equal(verdict("wts " .. SWORD .. " 50g anal").kind, "world", "a trade line with the joke on it goes too")
    check(verdict("fishing in the canal by the dam").kind ~= "world", "a canal is not the joke")
    check(verdict("my analysis: horde wins av every time").kind ~= "world", "nor an analysis")
    check(verdict("such a banal quest").kind ~= "world", "nor something banal")
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

    -- the words that counted, with their weights
    check(verdict("WTS " .. SWORD .. " 50g pst").work:find("wts +2", 1, true) and verdict("WTS " .. SWORD .. " 50g pst").work:find("(score 10)", 1, true), verdict("WTS " .. SWORD .. " 50g pst").work)
    equal(verdict("lol").work, "no word of either side (score 0)")
    -- what '/gtf test' prints
    check(Rules.Explain("wts sword 50g"):find("^KEPT %(trade"), Rules.Explain("wts sword 50g"))
    equal(Rules.Explain("trump 2028"), "HIDDEN (real-world talk: trump; trump -3 (score -3))")
end)

scenario("a meme flood: lines joking with a meme word are chatter, business with the word in it is still business, and the list is the account's", function()
    local ns = start()
    local Rules = ns.Rules
    local function verdict(text, shown)
        return Rules.Verdict(text, shown or "game")
    end
    -- the murloc afternoon of 2026-10-06: titles with the word in them, 578 lines from 204 people
    local v = verdict("Jurassic Murloc")
    equal(v.kind, "chatter"); equal(v.reason, "the murloc meme (chatter off)"); equal(v.keep, false)
    equal(verdict("Murlocs of the Carribean").keep, false, "the plural too")
    equal(verdict("Real Murlocs of Elwynn Forest").keep, false, "another word of the game in the title does not save it")
    equal(verdict("Holy shit, we're still doing Murloc?").keep, false, "a joke question")
    equal(verdict("Jurassic Murloc", "chat").keep, true, "whoever keeps chatter keeps the jokes")
    -- business with the word stays business
    v = verdict("wts murloc fin soup 5g"); equal(v.kind, "trade"); equal(v.keep, true)
    v = verdict("lf2m murloc quest at the coast"); equal(v.kind, "groups"); equal(v.keep, true)
    v = verdict("<Murloc Mafia> recruiting all levels"); equal(v.kind, "guilds"); equal(v.keep, true)
    equal(verdict("trump is a murloc").kind, "world", "the world outside is still the world outside")
    -- the list: the account's own, kept by command
    SlashCmdList.AKFOREVERCHATFILTER("meme add gnome")
    check(printed("'gnome' is a meme"), "said so")
    equal(verdict("Gnome of Thrones").reason, "the gnome meme (chatter off)")
    SlashCmdList.AKFOREVERCHATFILTER("meme remove murloc")
    check(printed("'murloc' is a word of the game again"), "said so")
    equal(verdict("Jurassic Murloc").kind, "talk", "the meme over, the word is game talk again")
    equal(#ns.db.memes, 1); equal(ns.db.memes[1], "gnome")
    SlashCmdList.AKFOREVERCHATFILTER("meme")
    check(printed("meme words"), "the list is printed")
    SlashCmdList.AKFOREVERCHATFILTER("meme remove dragon")
    check(printed("'dragon' is not on the list"), "a word not on the list")
    -- a word with a character of Lua's patterns in it is matched as written
    SlashCmdList.AKFOREVERCHATFILTER("meme add c++")
    equal(verdict("the c++ of warcraft").reason, "the c++ meme (chatter off)")
    equal(#Mock.errors, 0)
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
    equal(v.keep, true, "an answer"); equal(v.kind, "questions"); equal(v.reason, "an answer after Firemoon Night's question")
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
    SlashCmdList.AKFOREVERCHATFILTER("answers on")
    Mock.chat({ text = "anyone know where the wc entrance is?", sender = "Ann Annson" })
    equal(Mock.chat({ text = "yes", sender = "Cal Calson" }), true, "... and an answer when asked for")
    equal(lastLog(ns).kind, "questions"); check(lastLog(ns).work:find("no word of either side", 1, true), lastLog(ns).work)
    SlashCmdList.AKFOREVERCHATFILTER("answers off")
    equal(Mock.chat({ text = "yes", sender = "Cal Calson" }), false)
    SlashCmdList.AKFOREVERCHATFILTER("hide questions")
    check(printed("a question about the game: hidden"))
    equal(Mock.chat({ text = "anyone know where the wc entrance is?", sender = "Ann Annson" }), false, "questions off: the question goes too")
    equal(Mock.chat({ text = "wts " .. SWORD, sender = "Ann Annson" }), true)
    SlashCmdList.AKFOREVERCHATFILTER("kinds")
    check(printed("hidden: questions, chatter"), "the kinds are listed")
    SlashCmdList.AKFOREVERCHATFILTER("hide guilds")
    equal(Mock.chat({ text = "<Forever Bound> is recruiting", sender = "Eve Evans" }), false, "guild recruitment off")
    SlashCmdList.AKFOREVERCHATFILTER("mode game")
    equal(Mock.chat({ text = "<Forever Bound> is recruiting", sender = "Eve Evans" }), true, "a preset puts every kind back")
    SlashCmdList.AKFOREVERCHATFILTER("hide world")
    check(printed("usage: /gtf hide trade | groups"), "the world outside cannot be shown")
    SlashCmdList.AKFOREVERCHATFILTER("mode trade")
    check(printed("mode: trade (trade only)"))
    equal(Mock.chat({ text = "LFM SM cath need healer", sender = "Ann Annson" }), false)
    -- the first version's setting is read as its preset
    local db = AKForeverChatFilterDB
    db.chars["Purrdee - ClassicBetaPvE"].options.kinds = nil
    db.chars["Purrdee - ClassicBetaPvE"].options.mode = "balanced"
    ns = start({ db = db })
    equal(ns.Filter.ModeName(), "chat")
end)

scenario("the words you teach outrank the lists, and are kept", function()
    local ns = start()
    equal(ns.Rules.Verdict("who wants noggenfogger", "game").keep, true, "an elixir of the game")
    SlashCmdList.AKFOREVERCHATFILTER("block noggenfogger")
    check(printed("'noggenfogger' is the world outside from now on"))
    equal(ns.Rules.Verdict("who wants noggenfogger", "game").keep, false)
    equal(ns.Rules.Verdict("spaghetti time", "game").keep, false)
    SlashCmdList.AKFOREVERCHATFILTER("allow spaghetti time")
    equal(ns.Rules.Verdict("spaghetti time", "game").keep, true, "a phrase can be taught too")
    equal(ns.db.words["spaghetti time"], "game")
    SlashCmdList.AKFOREVERCHATFILTER("words")
    check(printed("spaghetti time - game business") and printed("noggenfogger - the world outside") and printed("2 word(s) taught"))
    SlashCmdList.AKFOREVERCHATFILTER("unlearn noggenfogger")
    equal(ns.Rules.Verdict("who wants noggenfogger", "game").keep, true)
    SlashCmdList.AKFOREVERCHATFILTER("unlearn cheese")
    check(printed("usage: /gtf unlearn"))

    -- taught words come back next session
    local db = AKForeverChatFilterDB
    ns = start({ db = db })
    equal(ns.Rules.Verdict("spaghetti time", "game").keep, true, "remembered")
end)

scenario("Trade and Services are filtered out of the box; General when asked; every other channel is left alone", function()
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
    equal(#ns.db.log, 2, "and leaves no trace")

    -- ... but for adverts: a web address or a seller for real money goes from EVERY public channel
    local AD = "Enjoy Forever - we cover your Leveling & Dungeons! Order for Beta >>> MythicStore.com <<<"
    equal(Mock.chat({ text = AD, channel = "general", sender = "Shopkeeper" }), false, "seen in Orgrimmar's General, 2026-10-02")
    equal(lastLog(ns).ch, "general"); equal(lastLog(ns).why, "a web address"); equal(lastLog(ns).keep, false)
    equal(Mock.chat({ text = "cheap gold, fast delivery, whisper me", channel = "LocalDefense" }), false, "a channel of the game's own")
    equal(lastLog(ns).ch, "public"); check(lastLog(ns).why:find("^a seller for real money"), lastLog(ns).why)
    equal(Mock.chat({ text = "anal " .. SWORD, channel = "general", sender = "Joker" }), false, "the anal joke goes from General too")
    equal(lastLog(ns).why, "the anal joke")
    equal(Mock.chat({ text = AD, channel = "World" }), true, "a channel players made themselves is never touched")
    equal(Mock.chat({ text = "lol", channel = "LocalDefense" }), true, "everything else there is left alone")
    equal(ns.Filter.stats.adverts, 3); equal(#ns.db.log, 5, "only the adverts are logged")
    SlashCmdList.AKFOREVERCHATFILTER("adverts off")
    check(printed("adverts: hidden only where the whole filter runs"))
    equal(Mock.chat({ text = AD, channel = "general" }), true, "off: General is left alone altogether")
    SlashCmdList.AKFOREVERCHATFILTER("adverts on")
    SlashCmdList.AKFOREVERCHATFILTER("adverts sideways")
    check(printed("usage: /gtf adverts on | off"))
    -- (the counts below are about Trade and General)
    ns.Filter.stats.seen, ns.Filter.stats.hidden = ns.Filter.stats.seen - 3, ns.Filter.stats.hidden - 3
    table.remove(ns.db.log); table.remove(ns.db.log); table.remove(ns.db.log)
    SlashCmdList.AKFOREVERCHATFILTER("general on")
    equal(Mock.chat({ text = "trump is the best", channel = "general" }), false, "... until asked")
    equal(lastLog(ns).ch, "general")
    equal(Mock.chat({ text = "trump is the best", channel = "World" }), true, "a channel this addon does not know is never touched")
    -- the Services channel: where the shops advertise - filtered like Trade
    local seen = ns.Filter.stats.seen
    equal(Mock.chat({ text = "Order now >>> MythicStore.com <<<", channel = "Services" }), false, "a shop's advert in Services")
    equal(lastLog(ns).ch, "services"); equal(lastLog(ns).why, "a web address")
    equal(Mock.chat({ text = "wts " .. SWORD .. " 50g", channel = "Services" }), true, "a trade line there stays")
    SlashCmdList.AKFOREVERCHATFILTER("services off")
    check(printed("Services: left alone"))
    equal(Mock.chat({ text = "Order now >>> MythicStore.com <<<", channel = "Services" }), true, "off: left alone")
    SlashCmdList.AKFOREVERCHATFILTER("services on")
    SlashCmdList.AKFOREVERCHATFILTER("services sideways")
    check(printed("usage: /gtf services on | off"))
    ns.Filter.stats.seen = seen -- (the counts below are about Trade and General)
    ns.Filter.stats.hidden = ns.Filter.stats.hidden - 1; ns.Filter.stats.kept = ns.Filter.stats.kept - 1
    table.remove(ns.db.log); table.remove(ns.db.log)
    equal(ns.Filter.stats.seen, 3, "and not decided on")

    SlashCmdList.AKFOREVERCHATFILTER("off")
    equal(Mock.chat({ text = "trump is the best" }), true, "off: every line shows")
    equal(ns.Filter.stats.seen, 3, "and nothing is decided")
    SlashCmdList.AKFOREVERCHATFILTER("on")
    equal(Mock.chat({ text = "trump is the best" }), false)

    SlashCmdList.AKFOREVERCHATFILTER("mode chat")
    equal(Mock.chat({ text = "lol", sender = "Carl" }), true, "chat keeps chatter (from somebody who was not just talking politics)")
    equal(Mock.chat({ text = "lol" }), false, "Bob was: his chatter goes on from his real-world line")
    SlashCmdList.AKFOREVERCHATFILTER("mode game")
    equal(Mock.chat({ text = "lol", sender = "Carl" }), false, "game does not")
    SlashCmdList.AKFOREVERCHATFILTER("mode sideways")
    check(printed("usage: /gtf mode trade | game | chat"))

    -- unreadable: hands off, and counted
    equal(Mock.chat({ text = "trump is the best", secret = "text" }), true, "a secret line goes through untouched")
    equal(Mock.chat({ text = "trump is the best", secret = "sender" }), true)

    SlashCmdList.AKFOREVERCHATFILTER("stats")
    check(printed("hidden"), "the count is printed")
    SlashCmdList.AKFOREVERCHATFILTER("test trump 2028")
    check(printed("HIDDEN (real-world talk: trump; trump -3 (score -3))"))
end)

scenario("the channel is known by its number, or failing that by its name", function()
    local ns = start()
    equal(ns.Filter.ChannelKind(2, "Trade - City", "2. Trade - City"), "trade")
    equal(ns.Filter.ChannelKind(1, "General - Durotar"), "general")
    equal(ns.Filter.ChannelKind(0, "Trade - City"), "trade", "the name will do")
    equal(ns.Filter.ChannelKind(nil, nil, "3. General - Orgrimmar"), "general")
    equal(ns.Filter.ChannelKind(26, "LookingForGroup"), "public", "a channel of the game's own: adverts go from it")
    equal(ns.Filter.ChannelKind(0, "LookingForGroup"), nil, "without a number it is somebody's own channel")
    equal(ns.Filter.ChannelKind(0, "Services", "4. Services"), "services")
    equal(ns.Filter.ChannelKind(0, "TradeLocal", "5. TradeLocal"), "trade", "the local Trade is Trade")
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

scenario("the review window: the lines that went, with the reason; a click prints the words that counted", function()
    local ns = start()
    Mock.chat({ text = "wts " .. SWORD .. " 50g", sender = "Alice" })
    Mock.chat({ text = "trump is the best", sender = "Bob" })
    Mock.chat({ text = "lol", sender = "Carl" })
    SlashCmdList.AKFOREVERCHATFILTER("review")
    local window, list = AKForeverChatFilterWindow, AKForeverChatFilterReview
    check(window and window:IsShown(), "the window is up")
    equal(ns.Review:Describe().showing, "hidden")
    equal(#list.__messages, 2, "the two hidden lines")
    check(list.__messages[1]:find("Bob", 1, true) and list.__messages[1]:find("real-world talk: trump", 1, true), list.__messages[1])
    check(list.__messages[1]:find("|Hgtf:2|h", 1, true), "each line is a link to itself")
    check(list.__messages[1]:find("hidden|r world", 1, true), "the kind is shown: " .. list.__messages[1])
    check(list.__messages[2]:find("chatter", 1, true))
    check(ns.Review.widgets.note:GetText():find("hidden lines, 2 shown", 1, true), ns.Review.widgets.note:GetText())

    SlashCmdList.AKFOREVERCHATFILTER("review all")
    equal(#list.__messages, 3, "every line")
    check(list.__messages[1]:find("[Gloves of Old]", 1, true) and not list.__messages[1]:find("Hitem", 1, true), "an item link is shown by its name only: " .. list.__messages[1])
    check(list.__messages[1]:find("kept", 1, true))

    -- a click: the verdict, the reason and the words that counted, printed to chat
    Mock.clickLink(list, "gtf:2")
    check(printed("hidden - real-world talk: trump; trump -3 (score -3)"), "the words that counted")
    check(printed("/gtf block <word>|r teaches one"))
    Mock.clickLink(list, "gtf:999")
    Mock.clickLink(list, "item:2296")

    -- the window is dragged and remembers its place
    window.__scripts.OnDragStart(window)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
    window.__scripts.OnDragStop(window)
    equal(ns.cdb.options.window.x, 40)
    Mock.click(ns.Review.widgets.close)
    equal(window:IsShown(), false)

    SlashCmdList.AKFOREVERCHATFILTER("review")
    SlashCmdList.AKFOREVERCHATFILTER("clear")
    equal(#ns.db.log, 0)
    equal(#list.__messages, 1); check(list.__messages[1]:find("nothing hidden yet", 1, true))
end)

scenario("diagnostics and logout run; the report is SavedVariables-safe and holds no frame", function()
    local ns = start()
    Mock.chat({ text = "wts " .. SWORD .. " 50g", sender = "Alice" })
    Mock.chat({ text = "trump is the best", sender = "Bob" })
    SlashCmdList.AKFOREVERCHATFILTER("review")
    SlashCmdList.AKFOREVERCHATFILTER("diag")
    check(printed("report saved"))
    Mock.fire("PLAYER_LOGOUT")

    local report = AKForeverChatFilterDB.diag
    equal(report.asked, true); check(AKForeverChatFilterDB.diagAtLogout, "the logout's report goes beside it")
    equal(report.addonVersion, "0.1.0-test")
    equal(report.options.mode, "game"); equal(report.options.kinds.guilds, true); equal(report.filter.how, "ChatFrameUtil.AddMessageEventFilter")
    equal(report.filter.stats.seen, 2); equal(report.filter.stats.hidden, 1)
    equal(#report.log, 2); equal(report.log[2].why, "real-world talk: trump"); equal(report.log[2].work, "trump -3 (score -3)")
    check(report.terms.builtIn > 1000, "the lists are counted")
    equal(report.review.shown, true); equal(report.review.showing, "hidden")

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
    walk(AKForeverChatFilterDB, "AKForeverChatFilterDB")
end)

scenario("the log is a ring: eight hundred lines at most, and the saved state comes back", function()
    local ns = start()
    for index = 1, 810 do
        Mock.chat({ text = "trump " .. index, sender = "Bob" })
    end
    equal(#ns.db.log, 800)
    equal(ns.db.log[1].text, "trump 11", "the oldest went")
    equal(ns.db.log[800].id, 810, "numbers keep counting")
    local db = AKForeverChatFilterDB
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
-- The character's profile ------------------------------------------------------------------------------------
-- Since client build 1.60.1.70170 (Oct 1 2026) the surname sits where the realm used to be: UnitFullName("player")
-- answers "Purrdee", "Bubson" instead of "Purrdee Bubson", "ClassicBetaPvE". The profile key must not care.
scenario("one profile per character: the full name and the realm, the same on the old client and on build 70170", function()
    equal(start({ surname = "Bubson" }).characterKey, "Purrdee Bubson - ClassicBetaPvE", "the old client: the name slot full, the realm slot the realm")
    equal(start({ surname = "Bubson", freshLogin = true }).characterKey, "Purrdee Bubson - ClassicBetaPvE", "a fresh login on the old client: no realm slot yet")
    local ns = start({ surname = "Bubson", build70170 = true })
    equal(ns.characterKey, "Purrdee Bubson - ClassicBetaPvE", "build 70170: the surname in the realm slot")
    equal(ns.cdb, AKForeverChatFilterDB.chars["Purrdee Bubson - ClassicBetaPvE"], "the profile sits in the account-wide table")
    equal(start({ surname = "Bubson", build70170 = true, normalizedRealm = false }).characterKey, "Purrdee Bubson - ClassicBetaPvE", "no GetNormalizedRealmName: GetRealmName() squeezed")
    equal(start().characterKey, "Purrdee - ClassicBetaPvE", "no surname: name and realm")
end)

scenario("a cold login: no name when the addon loads; the profile is bound at PLAYER_LOGIN, never saved as Unknown, and an early write lands in it", function()
    local ns, state = Mock.install({ surname = "Bubson", build70170 = true, coldLogin = true })
    Mock.fire("ADDON_LOADED", "AKForeverChatFilter")
    equal(ns.characterKey, nil, "nothing to bind to yet")
    ns.cdb.early = { note = "written before the name was known" } -- what a module might do between the two events
    state.coldLogin = false
    Mock.fire("PLAYER_LOGIN")
    equal(ns.characterKey, "Purrdee Bubson - ClassicBetaPvE")
    local profile = AKForeverChatFilterDB.chars["Purrdee Bubson - ClassicBetaPvE"]
    equal(ns.cdb, profile, "bound to the saved table")
    equal(profile.early.note, "written before the name was known", "the stand-in's writes are folded in")
    local keys = {}
    for key in pairs(AKForeverChatFilterDB.chars) do
        keys[#keys + 1] = key
    end
    equal(#keys, 1, "one profile and no 'Unknown - ClassicBetaPvE': " .. table.concat(keys, ", "))
end)

scenario("profiles under older spellings are adopted once: this profile keeps its values, the others fill its gaps and go", function()
    local db = { chars = {
        ["Purrdee Bubson - ClassicBetaPvE"] = { options = { fromOld = "old" }, place = { x = 1 } },
        ["Purrdee - Bubson"] = { options = { fromOld = "new", fromNew = "new" }, place = { x = 2, y = 2 } },
        ["Purrdee Bubson - Classic Beta PvE"] = { options = { fromOld = "spaced", fromNew = "spaced", fromSpaced = "spaced" }, place = { w = 4 } },
        ["Unknown - ClassicBetaPvE"] = { options = { fromOld = "cold", fromNew = "cold", fromCold = "cold" }, place = { y = 3, z = 3 }, extra = { deep = true } },
    } }
    local ns = start({ surname = "Bubson", build70170 = true, db = db })
    equal(ns.characterKey, "Purrdee Bubson - ClassicBetaPvE")
    local cdb = ns.cdb
    equal(cdb, db.chars["Purrdee Bubson - ClassicBetaPvE"])
    equal(cdb.options.fromOld, "old", "the long-standing profile wins")
    equal(cdb.options.fromNew, "new", "the build-70170 profile fills gaps before the others")
    equal(cdb.options.fromSpaced, "spaced"); equal(cdb.options.fromCold, "cold")
    equal(cdb.place.x, 1); equal(cdb.place.y, 2); equal(cdb.place.w, 4); equal(cdb.place.z, 3, "filled down into nested tables")
    equal(cdb.extra.deep, true)
    equal(db.chars["Purrdee - Bubson"], nil, "the older spellings are gone")
    equal(db.chars["Purrdee Bubson - Classic Beta PvE"], nil); equal(db.chars["Unknown - ClassicBetaPvE"], nil)
    local logged
    for _, entry in ipairs(ns.sessionLog) do
        if entry.k == "profile" then
            logged = entry.d
        end
    end
    check(logged and logged.key == "Purrdee Bubson - ClassicBetaPvE", "the adoption is in the session log")
    equal(logged.adopted[1], "Purrdee - Bubson"); equal(logged.adopted[2], "Purrdee Bubson - Classic Beta PvE"); equal(logged.adopted[3], "Unknown - ClassicBetaPvE")

    -- a character first seen on build 70170 keeps that profile, under the full key
    local alt = start({ playerName = "Stabby", surname = "Bubson", build70170 = true,
        db = { chars = { ["Stabby - Bubson"] = { options = { fromNew = "new" } } } } })
    equal(alt.characterKey, "Stabby Bubson - ClassicBetaPvE")
    equal(alt.cdb.options.fromNew, "new"); equal(AKForeverChatFilterDB.chars["Stabby - Bubson"], nil)

    -- an alt logging in afterwards finds nothing to adopt and leaves the first character's profile alone
    local other = start({ playerName = "Stabby", surname = "Bubson", build70170 = true, db = db })
    equal(other.characterKey, "Stabby Bubson - ClassicBetaPvE")
    equal(next(other.cdb.options), nil, "an empty profile of its own")
    equal(db.chars["Purrdee Bubson - ClassicBetaPvE"].options.fromOld, "old")
end)

------------------------------------------------------------------------
Mock.realPrint("")
Mock.realPrint(passed .. " passed, " .. #failures .. " failed")
if #failures > 0 then
    os.exit(1)
end
