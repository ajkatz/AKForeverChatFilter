# AKForeverChatFilter

## 0.1.3

- **A meme flood is chatter.** Trade spent an afternoon on murloc jokes - "Jurassic Murloc", "Murloc Gump",
  578 lines from 204 people - and every one of them counted as game talk, because a murloc is a creature
  of the game. A line joking with a meme word is chatter now, hidden unless you keep chatter; business
  with the word in it (a murloc fin soup for sale, a group for the murloc quest) stays business. `murloc`
  is on the list from the start; `/gtf meme add <word>` puts the next one on, `/gtf meme remove <word>`
  takes it off when the joke is over, `/gtf meme` lists them.

## 0.1.2

- **The anal joke is a line gone**: `anal [Thunderfury]`, `anal` and a link or two - the oldest spam in
  Trade, and the link in it used to count as game business. The word on its own only: a canal, an analysis
  and something banal are left alone. It goes from every public channel, like a web address
  (`/gtf adverts off` keeps that to Trade and Services).

## 0.1.1

- **Renamed to AKForeverChatFilter** - it was AKForeverTradeFilter, and it stopped being about Trade alone.
  The folder is new: delete the old `AKForeverTradeFilter` folder in `Interface\AddOns`. Settings start
  afresh (`/gtf allow` and `/gtf block` teach the words again); `/gtf` stays, `/acf` is new.
- **Settings follow the character.** Client build 1.60.1.70170 (Oct 1 2026) moved a character's surname
  into the realm slot of `UnitName`, which gave the per-character settings a key without the realm. The
  profile is now keyed by the full name and the realm (`Purrdee Bubson - ClassicBetaPvE`) and bound at
  PLAYER_LOGIN, when the client knows the name for sure, so a cold login no longer lands in an `Unknown`
  profile. Profiles saved under the other spellings are folded into it the first time each character logs
  in: the long-standing profile keeps its values, the others fill its gaps, and `/gtf diag` says what was
  adopted.
- **The Services channel is filtered too**, like Trade (`/gtf services off` leaves it alone): that is
  where the shops advertise.
- **A web address written with a trick is still a web address**: `store,com`, `store . com`,
  `store(dot)com`, `store dot com`.
- **A shop's advert is a line gone even without an address**: taking orders and pre-orders, "we cover
  your leveling", a professional team, piloted or self-play. A player selling a dungeon run for gold is
  still trade.
- **Adverts go from every public channel**: a web address or a seller for real money is hidden in
  General, LocalDefense and LookingForGroup too - and nothing else there is touched (`/gtf adverts off`
  turns that off; `/gtf general on` still puts the whole filter on General). A channel players made
  themselves is never touched.

## 0.1.0

For **World of Warcraft: Forever** (1.60.1, Interface 16001). Trade chat shows trade.

- Every Trade line is scored by its words: game business counts up (an item link, WTS/WTB/LF, gold, a
  profession, a dungeon, a zone, a class), the world outside counts down (a politician past or present,
  a party, a country, a war, a faith, a screen). The words sort a line into one of seven kinds - trade,
  groups forming, guilds, questions about the game (with their answers), other game talk, chatter, the
  world outside - and every kind but the world is a setting: `/gtf mode trade|game|chat` sets them
  together, `/gtf hide guilds` one at a time. Every verdict comes with its reason.
- A web address, a gold seller (real money, a delivery, a price in dollars) and any talk of streamers are
  a line gone, no other consideration.
- A country or a political figure named is a line gone, whatever else the line says; `US` in capitals
  counts, `us` the pronoun does not. A nationality only counts in passing, so a guild recruiting in French
  is still guild business.
- A thread: after a real-world line the same sender's next lines go too for three minutes, unless one is
  clearly game business.
- A conversation about the game, off by default (`/gtf answers on`): chatter right after a game question
  taken for an answer, a line naming somebody who just spoke about the game for a reply, chatter from
  somebody whose own last line was about the game for the discussion going on. Off, because the useful
  answers come by whisper and what follows a question in the channel is mostly noise.
- Trade out of the box, General on request (`/gtf general on`); nothing else is touched.
- **Review** (`/gtf review`): the lines that went, each with its kind and its reason; a click prints the
  line with every word that counted and its weight. `/gtf test <line>` does the same for any line you
  type; `/gtf allow <word>` and `/gtf block <word>` teach a word, and taught words outrank the lists.
- The last 800 lines with their verdicts live in the settings file; `/gtf diag` writes a report beside
  them - the one you ask for is kept, the logout's goes beside it.
