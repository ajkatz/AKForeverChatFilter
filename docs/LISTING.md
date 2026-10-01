# Marketplace listing text (CurseForge / Wago) - Markdown

**Enjoy Trade chat the way it is supposed to be - without the drama, like you remember it. It takes the microphone away from the trolls.**

Every line of Trade is scored by the words in it: an item link, WTS/WTB/LF, a sum of gold, a profession, a dungeon, a zone or a class count for the game; a politician, a party, a country, a war, a faith, a streamer or a screen count for the world outside. The words sort each line into one of seven kinds - trade, a group forming, a guild recruiting, a question about the game, other game talk, chatter, the world outside - and every kind but the world is a setting.

- `/gtf mode trade` shows trade only; `/gtf mode game` (default) everything about the game; `/gtf mode chat` everything but the world outside. `/gtf hide guilds` takes one kind out.
- A country or a political figure named is a line gone, whatever else the line says. So is any web address, a gold seller, and any talk of streamers.
- `/gtf review`: the lines that went, each with its kind and its reason. Click a line and it is printed to chat with every word that counted and its weight.
- `/gtf test <line>` shows what would happen to any line, and why. `/gtf allow <word>` / `/gtf block <word>` teach a word; taught words outrank the lists.

Trade is filtered out of the box; `/gtf general on` adds General. Nothing is rewritten: the client's own message event filter hands each line over, the addon says "skip it" or nothing. A line the client keeps from addons goes through untouched.

Source and issues: https://github.com/ajkatz/AKForeverTradeFilter - MIT.
