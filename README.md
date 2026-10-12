# Storyline (WotLK 3.3.5a) – 3.3.1

Retail-style quest and gossip dialogs for the 3.3.5a client, modelled on the current
**Total-RP/Storyline** and built on the artwork and model data of the original 3.3.5a
backport. Rewritten from scratch in Lua; fixes the open GitHub issues.

## What it looks like (as in the Retail version)
- Parchment window with the quest title on a banner, **your character on the left, the NPC
  on the right**, facing each other, with the same per-model scaling data as the backport.
- A chat bubble with the NPC name and the text **faded in letter by letter**, one paragraph
  at a time; NPC emotes (`<...>`) in emote colour; talk / exclaim / question animations that
  follow the punctuation.
- On the last paragraph the "next" line becomes the action: *Check objectives* → *I accept.*,
  *Complete quest*, *Get reward*, or the first dialog choice.
- Glowing **objectives medallion** (accept ✔ / decline ✘ buttons, required items, rewards
  preview) and **rewards medallion** (click the reward you want).
- Gossip options and quests in a panel with their usual icons, **rewind** button, resizable
  and lockable window, faction-tinted background, SPACE / 1-9 / ESC keys.

## Install
Copy the `Storyline` folder to `World of Warcraft\Interface\AddOns\` (folder name must stay
`Storyline`). Settings use the same saved variable as the old version (`Storyline_Data`), so
existing settings carry over. Type `/storyline test` for a preview without an NPC.

## Slash commands
`/storyline` options · `/storyline test` preview · `/storyline flip` swap model facing ·
`/storyline reset` reset window · `/storyline info` print model info · `/storyline scale <n>|reset` · `/storyline camera free|0|1|2|auto` (add `all` for every NPC) · `/storyline angle <0..1.3>` · `/storyline lock|unlock` · `/storyline models` turn 3D models on/off (safety switch) ·
`/storyline dim <0-100>` strength of the world dimming · `/storyline wheel` mouse-wheel model resizing on/off ·
`/storyline close` emergency close · `/storyline debug` · `/storyline focus` (which frame is under the mouse)

Tips: drag the window to move it, drag the bottom-right grip to resize, **mouse wheel over
the models** can make the NPC bigger / smaller relative to your character (off by default, turn it on in the options or with `/storyline wheel`; saved per pair of models, `/storyline scale reset` undoes it), right click
on the bubble rewinds, **1-9** pick a dialog choice, **SPACE** continues.

## Issues fixed
| # | Problem | Cause found in the old code | Fix |
|---|---|---|---|
| 8 | Questie keeps handed-in quests in tracker / map | `events.lua` cached `GetQuestReward` in a local at load time and never used the original button, so hooks installed by Questie never ran | Turn-in goes through the original *Complete Quest* button, which calls the **global** `GetQuestReward`; direct call as fallback after 1.2 s; afterwards Questie is asked to redraw tracker + map icons (`compat.lua`) |
| 7 | Choices drawn under the dialog text | frame levels were left to chance | explicit frame levels: models < borders < chat < medallions < choices / objectives / rewards panels (`layout.lua`) |
| 5 | deDE locale | – | complete German translation (`locales.lua`), including all new strings |
| 4 | Lua error on class quests that teach a spell | `Content.SpellFrame.Icon` did not exist | reward buttons are built in code with their own `Icon`; spell data read defensively (`rewards.lua`) |

## Files
`frames.xml` (parchment art) · `layout.lua` (window, models, chat, medallions) · `logic.lua`
(dialog flow) · `rewards.lua` (reward grid, auto-equip) · `compat.lua` (original frames,
Questie) · `options.lua` · `events.lua` · `core.lua` · `utils.lua` · `locales.lua` ·
`structures.lua` (animation / scale / position data from the original) · `Artwork/`.
Every event handler is protected: if the addon errors, the original Blizzard windows come back.

## Not included
- Per-zone background pictures and the friendship / reputation bar of Retail (they rely on
  Retail-only game data); the background is faction-tinted instead.
- Blacklist button, dyslexia font, custom text fonts.
- Untested in-game by the author of this rework: please report anything odd.
  If the models face away from each other use `/storyline flip`.

See `NOTICE.md` for credits and licence.
