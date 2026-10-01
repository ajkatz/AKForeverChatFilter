# AKForeverTradeFilter

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
