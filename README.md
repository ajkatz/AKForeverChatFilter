# AKForeverChatFilter

(AKForeverTradeFilter until 0.1.1 - the name changed when it stopped being about Trade alone.)

For **World of Warcraft: Forever** (1.60.1, Interface 16001). Trade chat shows trade.

Status: **v0.1.0 (2026-09-30)**, proven in the game on its first day: the word lists were tuned against five
hundred lines of live Trade, each called by its owner first and by the filter second, until the two agreed on
94% of them.

Install: CurseForge, Wago, or the zip from the GitHub release into `Interface\AddOns\AKForeverChatFilter`.

## What it does

Every line of Trade is scored by the words in it. Game business counts up - an item link, `WTS`/`WTB`/`LF`,
a sum of gold, a profession, a dungeon, a zone, a class - and the world outside counts down: a politician,
a party, a country, a war, a faith, a screen. The words sort the line into one of seven kinds:

| kind | what it is | for instance |
|---|---|---|
| **trade** | selling, buying, a price, a service for a tip | `WTS [Gloves] 50g`, `lf enchanter, tipping`, `ports to org 5g` |
| **groups** | a group forming for a dungeon, a raid, a quest | `LFM SM cath need healer`, `lf2m brd` |
| **guilds** | a guild recruiting, or somebody looking for one | `<Forever Bound> is recruiting`, `lf guild` |
| **questions** | a question about the game - and its answers | `where is the RFD entrance`, `yes tomorrow` |
| **talk** | anything else about the game | `gnome is fun on the other side`, `server just died` |
| **chatter** | nothing of the game in it | `lol`, `thanks man` |
| **world** | the world outside | a politician, a country, a war, a faith, a screen |

The world outside never stays, and a loud word of it - a politician, a country, a war, a faith, a
streamer - is a hard pass whatever else the line says (`WTS [Sulfuras] 50g made in china` goes). So is a
web address of any kind, a Discord invite included - also when it is written with a trick (`store,com`,
`store dot com`) - and so is a seller for real money: a delivery, a price in dollars, a shop taking orders. Which of the other kinds stay is a setting per kind:

- `/gtf mode trade`: trade only.
- `/gtf mode game` (the default): everything about the game - trade, groups, guilds, questions, talk.
- `/gtf mode chat`: everything but the world outside.
- `/gtf hide guilds`, `/gtf show chatter`: one kind at a time; `/gtf kinds` says where things stand.

**A conversation about the game, off by default.** The useful answers to a question in Trade come by
whisper, and what follows one in the channel is mostly noise, so out of the box a line counts by its own
words only. `/gtf answers on` turns the conversation rules on: short chatter within three quarters of a
minute of a game question is taken for an answer (three at most, each buying fifteen seconds; a longer
line only if it shares a word with the question), a line naming somebody who just spoke about the game
for a reply, and short chatter from somebody whose own last line, within a minute, was about the game for
the discussion going on. Sarcasm is beyond it either way.

A country named is a line gone (`canada`, `israel`, `the US` - in capitals; `us` the pronoun is not a
country), and so is any politician past or present. A nationality or a language only counts in passing:
`french speaking guild recruiting` is guild business, `any canadians here` is not.

**A thread:** somebody whose line went for real-world talk usually goes on (`lol no he didn't`). For three
minutes their chatter goes too, and so does a reply naming them, unless a line is clearly game business.
`/gtf sticky off` turns that off.

Trade and the Services channel are filtered out of the box (`/gtf services off` leaves Services alone);
`/gtf general on` adds General. **Adverts go from every public channel** - a web address or a seller for
real money is hidden in General, LocalDefense and LookingForGroup too, and nothing else there is touched
(`/gtf adverts off`). A channel players made themselves is never touched. Nothing is
rewritten: the client's own message event filter (`ChatFrameUtil.AddMessageEventFilter`) hands the line
over, the addon says "skip it" or nothing, and the chat window does the rest. A line the client keeps from
addons (a secret value) goes through untouched.

## Verifying, and teaching

| | |
|---|---|
| `/gtf review` | a window with the lines that went, newest last, each with its kind and its reason. `/gtf review all` shows the kept ones too. **Click a line** and it is printed to chat with every word that counted and its weight (`trump -3 (score -3)`), so the word to teach is in plain sight |
| `/gtf test <line>` | what the filter would do with that line, why, and every word that counted with its weight |
| `/gtf allow <word>` / `/gtf block <word>` | teach a word (or a phrase): game business, or the world outside. Taught words outrank the built-in lists. `/gtf words` lists them, `/gtf unlearn <word>` forgets one |
| `/gtf stats` | this session's count: seen, hidden, kept |
| `/gtf diag` | a report into the settings file, then `/reload`: options, counts, the last lines with their verdicts, every error |

The last 800 lines the filter decided on are kept in the settings file with their verdicts; `/gtf clear`
forgets them.

## Commands

`/gtf` lists them: `on`, `off`, `mode trade|game|chat`, `show <kind>`, `hide <kind>`, `kinds`, `answers on|off`, `services on|off`, `general on|off`, `adverts on|off`, `sticky on|off`, `test`,
`allow`, `block`, `unlearn`, `words`, `review [all]`, `clear`, `stats`, `diag`.
`/acf` and `/akforeverchatfilter` are the other spellings.

## How it stays out of Blizzard's way

- The one way in is the client's own message event filter; no chat frame is hooked, no message is
  rewritten, nothing of Blizzard's is touched. The window is ours alone.
- Every value the client hands over is checked for secrecy before it is looked at; unreadable means hands
  off. The registry itself skips the callback for a secret line, and the addon counts how often.
- Nothing runs on a timer. Every entry point goes through a safe call, and every error is kept for the report.

## Tests

`lua tests/run.lua` from the addon's folder (Lua 5.4; the addon's files run in a 5.1-shaped environment).
The mock models this build's filter registry, three chat windows, and secret values.

