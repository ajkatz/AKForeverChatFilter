# AKForeverTradeFilter

## 0.1.0

For **World of Warcraft: Forever** (1.60.1, Interface 16001). The Great Trade Filter: Trade chat shows trade.

- Every Trade line is scored by its words: game business counts up (an item link, WTS/WTB/LF, gold, a
  profession, a dungeon, a zone, a class), the world outside counts down (a politician past or present,
  a party, a country, a war, a faith, a screen). The words sort a line into one of seven kinds - trade,
  groups forming, guilds, questions about the game (with their answers), other game talk, chatter, the
  world outside - and every kind but the world is a setting: `/gtf mode trade|game|chat` sets them
  together, `/gtf hide guilds` one at a time. Every verdict comes with its reason.
- A conversation about the game: chatter within a minute of a game question is taken for an answer, and a
  line naming somebody who just spoke about the game for a reply; both count as questions (`/gtf answers
  off` turns that off).
- A country named is a line gone; `US` in capitals counts, `us` the pronoun does not. A nationality only
  counts in passing, so a guild recruiting in French is still guild business.
- A thread: after a real-world line the same sender's next lines go too for three minutes, unless one is
  clearly game business.
- Trade out of the box, General on request (`/gtf general on`); nothing else is touched.
- **Training** (`/gtf train on`): every line is put to you first, then the filter's call comes up beside
  yours; the score keeps count, and when the two differ a box takes your reason (`/gtf note <text>` from
  chat does the same). **Review** (`/gtf review`): the lines that went, with reasons; a click flags a verdict
  as wrong. `/gtf test`, `/gtf allow`, `/gtf block` for arguing with it.
- The last 400 lines with their verdicts, your answers and flags live in the settings file, for tuning.
- `/gtf diag` writes a report; the one you ask for is kept, the logout's goes beside it.
