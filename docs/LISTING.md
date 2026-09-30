# Marketplace listing text (CurseForge / Wago) - Markdown

**Trade chat shows trade.** Every line of Trade is scored by the words in it: an item link, WTS/WTB/LF, a sum of gold, a profession, a dungeon, a zone or a class count for the game; a politician, a party, a country, a war, a faith or a screen count for the world outside. The words sort each line into one of seven kinds - trade, a group forming, a guild recruiting, a question about the game, other game talk, chatter, the world outside - and every kind but the world is a setting.

- `/gtf mode trade` shows trade only; `/gtf mode game` (default) everything about the game; `/gtf mode chat` everything but the world outside. `/gtf hide guilds` takes one kind out.
- A country or a political figure named is a line gone, whatever else the line says.
- `/gtf review`: the lines that went, each with its reason and how sure the filter was. Click a line to flag its verdict as wrong.
- `/gtf train on`: every line is put to you first - Trade or not? - then the filter's call comes up beside yours with its confidence and every word that counted; the score keeps count. When it was only guessing, teach it: which kind the line really is, and which word should have decided.
- `/gtf test <line>` shows what would happen to any line, and why. `/gtf allow <word>` / `/gtf block <word>` teach a word.

Trade is filtered out of the box; `/gtf general on` adds General. Nothing is rewritten: the client's own message event filter hands each line over, the addon says "skip it" or nothing. A line the client keeps from addons goes through untouched.

Client note: the Forever beta may write saved settings on logout and not read them back; the addon's options, log and taught words live in one account-wide table.

Source and issues: https://github.com/ajkatz/AKForeverTradeFilter - MIT.
