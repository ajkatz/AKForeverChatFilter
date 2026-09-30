# AKForeverTradeFilter

## 0.1.0

For **World of Warcraft: Forever** (1.60.1, Interface 16001). Trade chat shows trade.

- Every Trade line is scored by its words: game business counts up (an item link, WTS/WTB/LF, gold, a
  profession, a dungeon, a zone, a class), the world outside counts down (a politician past or present,
  a party, a country, a war, a faith, a screen). The words sort a line into one of seven kinds - trade,
  groups forming, guilds, questions about the game (with their answers), other game talk, chatter, the
  world outside - and every kind but the world is a setting: `/gtf mode trade|game|chat` sets them
  together, `/gtf hide guilds` one at a time. Every verdict comes with its reason.
- A conversation about the game, off by default (`/gtf answers on`): chatter right after a game question
  taken for an answer, a line naming somebody who just spoke about the game for a reply, chatter from
  somebody whose own last line was about the game for the discussion going on. Off, because the useful
  answers come by whisper and what follows a question in the channel is mostly noise.
- Every verdict says how sure it is - certain, sure, fairly sure, leaning on one word, nothing to go by, a
  guess from the conversation - and shows every word that counted with its weight, in the training window,
  the review window and `/gtf test`.
- More to teach on a guess: when the filter was not sure, or when you differ, the line stays up with seven
  buttons for which kind it really is, its words as tokens to click (left: game business, right: the world
  outside - taught on the spot) and the box for your reason.
- A country or a political figure named is a line gone, whatever else the line says; `US` in capitals
  counts, `us` the pronoun does not. A nationality only counts in passing, so a guild recruiting in French
  is still guild business.
- A thread: after a real-world line the same sender's next lines go too for three minutes, unless one is
  clearly game business.
- Trade out of the box, General on request (`/gtf general on`); nothing else is touched.
- **Training** (`/gtf train on`): every line is put to you first, then the filter's call comes up beside
  yours; the score keeps count - starting over whenever the word lists change - and when the two differ a
  box takes your reason (`/gtf note <text>` from chat does the same). **Review** (`/gtf review`): the lines that went, with reasons; a click flags a verdict
  as wrong. `/gtf test`, `/gtf allow`, `/gtf block` for arguing with it.
- The last 800 lines with their verdicts, your answers and flags live in the settings file, for tuning.
- `/gtf diag` writes a report; the one you ask for is kept, the logout's goes beside it.
