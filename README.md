# AKForeverTradeFilter - The Great Trade Filter

For **World of Warcraft: Forever** (1.60.1, Interface 16001). Trade chat shows trade.

Status: **v0.1.0, unproven in the game** - built 2026-09-30 for the first outing. The learning loop is the
point of the first weeks: the training mode and the review window are how the word lists get tuned.

## What it does

Every line of Trade is scored by the words in it. Game business counts up - an item link, `WTS`/`WTB`/`LF`,
a sum of gold, a profession, a dungeon, a zone, a class - and the world outside counts down: a politician,
a party, a country, a war, a faith, a screen. The sum decides:

- **strict** (the default): a line stays only when it is game business. Real-world talk goes, and so does
  plain chatter (`lol`, `thanks man`). A question about the game is game business (`where is the RFD
  entrance`).
- **balanced** (`/gtf mode balanced`): real-world talk goes, chatter stays.

A country named is a line gone (`canada`, `israel`, `the US` - in capitals; `us` the pronoun is not a
country), and so is any politician past or present. A nationality or a language only counts in passing:
`french speaking guild recruiting` is guild business, `any canadians here` is not. A loud word of the world
outweighs two words of the game (`biden is a warlock` goes), but not a trade line with a link and a price
(`WTS [Sulfuras] 50g made in china` stays).

**A thread:** somebody whose line went for real-world talk usually goes on (`lol no he didn't`). For three
minutes their lines go too, unless one is clearly game business. `/gtf sticky off` turns that off.

Trade is filtered out of the box; `/gtf general on` adds General. No other channel is touched. Nothing is
rewritten: the client's own message event filter (`ChatFrameUtil.AddMessageEventFilter`) hands the line
over, the addon says "skip it" or nothing, and the chat window does the rest. A line the client keeps from
addons (a secret value) goes through untouched.

## Verifying, and teaching

| | |
|---|---|
| `/gtf review` | a window with the lines that went, newest last, each with its reason. `/gtf review all` shows the kept ones too. **Click a line to flag its verdict as wrong** (click again to take it back); the flag is saved with the line |
| `/gtf train on` | **training**: every Trade line is put to you first - *Trade* or *Not trade*? - and only then the filter's own call and reason come up beside yours. The score keeps count of how often the two agree. When the two differ, a box asks for your reason: click it, type, Enter saves it with the line; *Next* moves on without one (`/gtf note <text>` from chat does the same). `/gtf train unsure` asks only about the lines the filter had nothing to go by; `/gtf train off`, or close the window |
| `/gtf test <line>` | what the filter would do with that line, and every word that counted |
| `/gtf allow <word>` / `/gtf block <word>` | teach a word (or a phrase): game business, or the world outside. Taught words outrank the built-in lists. `/gtf words` lists them, `/gtf unlearn <word>` forgets one |
| `/gtf stats` | this session's count: seen, hidden, kept |
| `/gtf diag` | a report into the settings file, then `/reload`: options, counts, the last lines with their verdicts, your training answers, every error |

Everything the filter decides on is kept in the settings file (the last 400 lines with verdicts), and so are
your training answers and flags. That file is what the next round of tuning is made from: what got through
that should not have, what went that should have stayed, and the words that decided it.

## Commands

`/gtf` lists them: `on`, `off`, `mode strict|balanced`, `general on|off`, `sticky on|off`, `test`,
`allow`, `block`, `unlearn`, `words`, `train on|unsure|off`, `review [all]`, `clear`, `reset`, `stats`, `diag`.
`/akforevertradefilter` is the long form.

## How it stays out of Blizzard's way

- The one way in is the client's own message event filter; no chat frame is hooked, no message is
  rewritten, nothing of Blizzard's is touched. The window is ours alone.
- Every value the client hands over is checked for secrecy before it is looked at; unreadable means hands
  off. The registry itself skips the callback for a secret line, and the addon counts how often.
- Nothing runs on a timer. Every entry point goes through a safe call, and every error is kept for the report.

## Tests

`lua tests/run.lua` from the addon's folder (Lua 5.4; the addon's files run in a 5.1-shaped environment).
The mock models this build's filter registry, three chat windows, and secret values.

## Open questions to test in the game

1. Does the client hand Trade lines to the filter at all, or are they secret? `/gtf stats` counts both
   (`N channel event(s), M unreadable`); the filter's registration is named there too.
2. Is Trade's zone channel id 2 on this client, as on every other? The name is the fallback.
3. What gets through that should not, what goes that should stay: `/gtf train on` for a while, then the
   review window and `/gtf diag`.

## Saved settings on the Forever beta

`AKForeverTradeFilterDB` is one account-wide table (the log, the answers and the taught words are shared;
the options are per character). Should the client write it and not read it back, `tools/Install-SavedStateBridge.ps1`
installs the companion addon that feeds it back in.
