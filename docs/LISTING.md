# Marketplace listing text (CurseForge / Wago) - Markdown

**Enjoy Trade chat the way it is supposed to be - without the drama, like you remember it. It takes the microphone away from the trolls.**

Every line of Trade is scored by the words in it: an item link, WTS/WTB/LF, a sum of gold, a profession, a dungeon, a zone or a class count for the game; a politician, a party, a country, a war, a faith, a streamer or a screen count for the world outside. The words sort each line into one of seven kinds - trade, a group forming, a guild recruiting, a question about the game, other game talk, chatter, the world outside - and every kind but the world is a setting.

- `/gtf mode trade` shows trade only; `/gtf mode game` (default) everything about the game; `/gtf mode chat` everything but the world outside. `/gtf hide guilds` takes one kind out.
- A country or a political figure named is a line gone, whatever else the line says. So is any web address (also one written with a trick: `store,com`, `store dot com`), a seller for real money - a shop taking orders, a gold seller - any talk of streamers, and the anal joke (`anal [Thunderfury]`).
- **Adverts go from every public channel**: a web address, a seller for real money or the anal joke is hidden in General, LocalDefense and LookingForGroup too, and nothing else there is touched.
- `/gtf review`: the lines that went, each with its kind and its reason. Click a line and it is printed to chat with every word that counted and its weight.
- `/gtf test <line>` shows what would happen to any line, and why. `/gtf allow <word>` / `/gtf block <word>` teach a word; taught words outrank the lists. `/gtf meme add <word>` makes a word Trade is joking with (murloc from the start) chatter while the meme lasts; `remove` ends it.

Trade and the Services channel are filtered out of the box; `/gtf general on` puts the whole filter on General (`/gtf services off` leaves Services alone, `/gtf adverts off` leaves the other public channels alone). Nothing is rewritten: the client's own message event filter hands each line over, the addon says "skip it" or nothing. A line the client keeps from addons goes through untouched.

The rest of the commands: `/gtf off` / `on` (every line again / the filter back), `/gtf show chatter` (one kind back on), `/gtf kinds` (which kinds are shown), `/gtf sticky on|off` (after a real-world line the same sender's next lines go too for a few minutes), `/gtf answers on|off` (chatter right after a game question counts as an answer), `/gtf stats`, `/gtf clear` (the session's count; forget the logged lines), `/gtf words` / `/gtf unlearn <word>` (the words you taught), `/gtf diag` (a report for bug reports, then `/reload`). `/gtf` on its own lists them.

Source and issues: https://github.com/ajkatz/AKForeverChatFilter - MIT.
