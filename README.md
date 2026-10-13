# Storyline for WotLK 3.3.5a — v3.4.0

Retail-style quest and gossip dialogs for the **World of Warcraft 3.3.5a (Wrath of the Lich King)** client.
Instead of the old stone quest window you get a parchment dialog with **your character on the left and the
NPC on the right**, a chat bubble with text that fades in letter by letter, and glowing medallions for the
quest objectives and rewards, like the Retail version of Storyline.

This is a fork of [shadovvs/WotLK-Storyline](https://github.com/shadovvs/WotLK-Storyline), which is a
backport of [Total-RP/Storyline](https://github.com/Total-RP/Storyline). The addon was rewritten in Lua and then
improved in several rounds (3.0 → 3.4.0) after testing in the game. Everything that was changed, and why, is
described below.

> Tested in-game on a 3.3.5a client together with [DragonUI](https://github.com/NeticSoul/DragonUI). If something
> looks wrong on your setup, please open an issue (see [Troubleshooting](#troubleshooting) for the information
> that helps most).

---

## Table of contents

1. [Features](#features)
2. [Install](#install)
3. [Using it](#using-it)
4. [Options](#options)
5. [Slash commands](#slash-commands)
6. [Compatibility](#compatibility)
7. [Troubleshooting](#troubleshooting)
8. [What was changed in this fork](#what-was-changed-in-this-fork)
9. [Problems fixed (summary table)](#problems-fixed-summary-table)
10. [Technical notes for addon developers](#technical-notes-for-addon-developers)
11. [Files](#files)
12. [Not included](#not-included)
13. [Credits and licence](#credits-and-licence)

---

## Features

- **Parchment window** with the quest title on a banner. Your character is on the left, the NPC on the right,
  and the two models **face each other** (adjustable angle, can be flipped).
- **Chat bubble** with the NPC name and the text typed out one paragraph at a time. NPC emotes (`<...>`) use the
  emote colour. The NPC plays talk / exclaim / question animations that follow the punctuation of the text.
- **The "next" line becomes the action** on the last paragraph: *Check objectives* → *I accept.*, *Complete quest*,
  *Get reward*, or the first dialog choice.
- **Objectives medallion** with accept ✔ and decline ✘ buttons, required items and a reward preview.
- **Rewards medallion** where you click the reward you want.
- **Gossip options and quests** in a small panel with the usual icons, a **rewind** button, and number keys.
- **Resizable, movable and lockable** window, faction-tinted background (blue for Alliance, red for Horde).
- **Dim the world** behind the window, with an adjustable strength (0–100 %).
- **Location background**: a picture of the zone you are in is shown behind the models (vanilla zones for now,
  can be switched off). See [Location background](#location-background).
- Per-model **scale data** from the original backport, so giants and tiny NPCs are framed sensibly.
- **Keyboard**: `SPACE` continues, `1`–`9` pick a dialog option, `ESC` closes.
- English and German (deDE) translations; any other client language falls back to English.
- Every event handler is protected: if the addon ever errors, the **original Blizzard windows come back** so you
  can still talk to the NPC.

## Install

1. Download the latest zip (or the `Storyline` folder from this repository).
2. Copy the **`Storyline`** folder to `World of Warcraft\Interface\AddOns\`. The folder name must stay `Storyline`.
3. Start the game and make sure *Storyline* is enabled in the AddOns list.

Settings use the same saved variable as the old versions (`Storyline_Data`), so existing settings carry over.
Type `/storyline test` for a preview without having to talk to an NPC.

## Using it

| Action | What it does |
|---|---|
| Click the chat bubble or press `SPACE` | Next paragraph; on the last one, run the action shown on the "next" line |
| Right-click the chat bubble, or the rewind button | Start the dialog again |
| `1`–`9` | Pick a gossip option / quest from the list |
| Green ✔ / red ✘ on the objectives medallion | Accept / decline the quest |
| `X` button, `ESC`, or `/storyline close` | Close the dialog |
| Drag the window | Move it (unless locked) |
| Drag the bottom-right grip | Resize it |
| Key icon (top right) | Lock / unlock the window position |
| Gear icon (bottom left) | Open the options |
| Mouse wheel over the models | Make the NPC bigger / smaller — **off by default**, see [Options](#options) |

## Location background

While a dialog is open, a picture of the zone you are standing in is drawn behind the two models, inside the
parchment frame. The picture is cut (not stretched) to the shape of the window and follows window resizing.

- **Vanilla zones for now** (36 pictures: Elwynn Forest, Westfall, Durotar, The Barrens, Stormwind City,
  Ironforge, Undercity, Winterspring, Silithus… and instances / battlegrounds that belong to one of them, e.g.
  Blackrock Depths and Alterac Valley). Every other zone (Orgrimmar, Darnassus, Thunder Bluff, Outland,
  Northrend…) keeps the normal faction-coloured background.
- **On / off**: *Location background* in the options, or `/storyline bg`. It is on by default.
- Zone names are matched in English, and in German and French (names from Babble-Zone 2.2). Other client languages
  fall back to the English names; `/storyline zone` shows what is detected.
- The pictures live in `Artwork/Locations/` (512×256 BLP). If that folder (and `Artwork/Locations/Installed.lua`) is
  removed, the addon simply keeps the plain background — see [Credits and licence](#credits-and-licence) for why
  that matters.

## Options

Open them with `/storyline`, the gear icon in the window, or *Esc → Interface → AddOns → Storyline*.

**Sliders**

- **Text animation speed** — from instant to fast.
- **Text size** — 11 to 24.
- **Model angle** — how far the two models turn towards each other.
- **Dim strength** — how dark the 3D world gets behind the window (0–100 %). Moving the slider switches dimming
  on, shows a short preview when no dialog is open, and updates live while a dialog is open.

**Check boxes**

- Hide the original Blizzard frames
- Also take over vendors / flight masters / other gossip windows
- Auto-equip reward (experimental)
- Keyboard shortcuts
- Disable in instances (keep the original windows inside dungeons and raids)
- Lock the window
- Show 3D models (safety switch)
- Animate 3D models
- Flip model direction
- Faction-coloured background
- Location background
- Dim the world behind the window
- Mouse wheel resizes the NPC

## Slash commands

`/storyline` and `/stl` are the same command.

| Command | Action |
|---|---|
| `/storyline` | Open the options |
| `/storyline test` | Preview the window without an NPC |
| `/storyline close` | **Emergency close**: closes the window and the original dialog no matter what state they are in |
| `/storyline bg` | Turn the location background on / off |
| `/storyline zone` | Print the zone the addon sees and which picture it picked (for bug reports) |
| `/storyline dim <0-100>` | Strength of the world dimming (`0` = off) |
| `/storyline wheel` | Turn "mouse wheel resizes the NPC" on / off |
| `/storyline flip` | Swap the facing direction of the models |
| `/storyline angle <0..1.3>` | How far the models turn towards each other |
| `/storyline camera free\|0\|1\|2\|auto` | Camera for the NPC model you are talking to (add `all` for every NPC) |
| `/storyline scale <n>` / `reset` | Size of the NPC relative to your character for this pair of models |
| `/storyline models` | Turn the 3D models on / off (safety switch) |
| `/storyline lock` / `unlock` | Lock / unlock the window |
| `/storyline reset` | Reset window position and size |
| `/storyline info` | Print model information (useful for bug reports) |
| `/storyline debug` | Print the state of the Storyline window, the original quest / gossip windows and the original Accept button |
| `/storyline focus` | Hold the mouse over a button for 4 seconds; the name of the frame under the mouse is printed (finds frames that block clicks) |

## Compatibility

- **DragonUI** — tested together with DragonUI. DragonUI restyles the original quest and gossip windows; Storyline
  keeps those windows open but invisible, so nothing is lost. The "quest not accepted" bug that showed up while
  testing with it was a mistake in Storyline's own code and is fixed in 3.3.1 (see below).
- **Questie** — turn-ins go through the original *Complete Quest* button and the global `GetQuestReward`, so
  Questie's hooks run, and Questie is asked to redraw its tracker and map icons afterwards.
- **Other UI addons** — the control buttons (close, lock, settings, resize) sit on a higher frame strata so frames
  of other addons cannot swallow their clicks.
- Dungeons and raids can be left to the original windows with the *Disable in instances* option.

## Troubleshooting

| Problem | What to do |
|---|---|
| The window is stuck / will not close | Click `X`, press `ESC`, or type `/storyline close` |
| The two models face away from each other | `/storyline flip` |
| No picture in a vanilla zone | `/storyline zone` prints the zone name the game returns and the picture chosen. Send that line in an issue. Other client languages than English / German / French fall back to English zone names |
| A giant NPC is far too big or too small | Turn on *Mouse wheel resizes the NPC* (or `/storyline wheel`) and scroll over the models. `/storyline scale reset` undoes it |
| The models were resized by accident | `/storyline scale reset` |
| The game crashes when a dialog opens | `/storyline models` turns the 3D models off |
| Accepting a quest does nothing | Update to 3.3.1. If it still happens, send the red chat line "the quest was not accepted" and the result of `/storyline debug` |
| A button does not react | `/storyline focus`, hold the mouse over the button for 4 seconds, and send the printed frame names |
| Lua errors | Errors are also printed in the chat. Please include them in the issue |

When reporting a bug, please include: the output of `/storyline info` and `/storyline debug`, the NPC and quest name,
and the other UI addons you use.

## What was changed in this fork

This is the history from the first rewrite to the current release. The full list is in
`CHANGELOG.md`.

### 3.0.0 — new Retail-style window (full rewrite in Lua)

- New window: parchment frame, banner with the quest title, player model left / NPC model right, chat bubble with
  faded-in text, objectives and rewards medallions, gossip choices panel.
- Dialog flow like Retail Storyline (the last paragraph turns the "next" line into the action).
- Same saved variable (`Storyline_Data`) and same per-model scaling data as before.
- Fixed the open GitHub issues: **#8** Questie, **#7** layer order, **#5** deDE, **#4** spell reward error.
- Options: text speed, auto-equip, force gossip, hide original frames, lock, disable in instances, tinted
  background, keyboard shortcuts, model animations, flip facing.

### 3.0.1 — client crash fix

- Fixed a client crash (`ERROR #132 ACCESS_VIOLATION`) when a dialog or the preview opened. Models are now set
  up only after the window is shown; no more reading-book model or hard-coded animation numbers; an animation is
  only played if it is listed for that exact model.
- New option / command *Show 3D models* (`/storyline models`) as a safety switch.

### 3.0.2 — facing and giant NPCs

- Models turn towards each other again (facing and camera are set before the model loads and applied again right
  after it has loaded, because the client reset them).
- Giant / big NPCs: size hints by model family and creature type, wider mouse-wheel range, saved per pair of models;
  `/storyline info`, `/storyline scale`, `/storyline camera`.
- Dialog choices: small box as wide as its longest line, no title, placed between the models (like the original).

### 3.1.0 — cameras, rotation, text size and dimming

- The camera is chosen **per model**: character models (humans, elves, dwarves…) use camera 1, creatures (treants,
  bears, giants…) use camera 0, so big NPCs show their full body and normal NPCs stay normal.
- Models turn towards each other with `SetRotation` (as Blizzard's own model frames do) as well as `SetFacing`;
  new *Model angle* slider and `/storyline angle`.
- New: text size slider, *Dim the world behind the window* option, options panel in two columns.

### 3.2.0 — chains, errors and real turning

- Fixed: the original quest window appeared after taking / turning in a quest. A late `QUEST_FINISHED` (sent while
  closing the previous quest of a chain) closed the next Storyline dialog. Closing now only happens when the
  original dialog is really closed, and if an original dialog is still open after Storyline ended, it is shown
  through Storyline again.
- Errors in the addon are now also printed in the chat (most players have Lua error popups turned off).
- **Models really turn towards each other now.** A model camera is attached to the model, so rotating the model
  with a camera selected had no visible effect. Characters now use the free camera (rotation is applied last);
  creatures keep camera 0. `/storyline camera all auto` restores the old behaviour.

### 3.3.0 — closing, mouse wheel and dim slider

- **The dialog could not be closed after a quest had been chosen.** Closing by the player (`X` button, `ESC`,
  `/storyline close`) no longer depends on the original Blizzard window or on a server answer: the Storyline window
  is hidden at once, the original quest / gossip window is closed too, and events that still arrive for the
  dialog that was just closed can no longer open it again.
- After accepting / declining a quest, the window could stay open when the original quest window was not reported
  as closed. If it is still the same dialog shortly afterwards, it is closed anyway (the next quest of a chain is a
  different dialog and is left alone).
- A faded-out window that never finished fading is hidden by a watchdog.
- The `X` / lock / settings / resize buttons are on a higher frame strata.
- **The mouse wheel no longer resizes the NPC and your character by default.** It is now an option
  (*Mouse wheel resizes the NPC*, `/storyline wheel`), off by default.
- **New: *Dim strength* slider** (0–100 %) and `/storyline dim <0-100>`.
- New diagnostics: `/storyline close`, `/storyline debug`, `/storyline focus`.

### 3.3.1 — accepting quests

- **Fixed: accepting a quest with the green check mark did nothing.** In 3.3.5a `Button:IsEnabled()` returns `1`
  or `0`, and `0` counts as "true" in Lua, so a **disabled** original Accept button was treated as usable. It was
  "clicked" (the game ignores clicks on disabled buttons) and `AcceptQuest()` was never called. A disabled button
  now means the quest is accepted directly, including the PvP-quest confirmation and auto-accept quests.
- The result is **checked**: if the quest window is still open and the quest is not in the quest log shortly
  afterwards, the quest is accepted directly; if that fails too, a diagnostic line is printed in the chat.
- The same `1`/`0` mistake in the dialog's "next" button (it was never really disabled while a reward had to be
  picked) is fixed.
- `/storyline debug` also prints the state of the original Accept button.

### 3.4.0 — location backgrounds

- **New: location background.** A picture of the current zone behind the models, with an option (and
  `/storyline bg`) to turn it on / off. Pictures come from
  VanillaStoryline (Renew @ nostalrius.org); only vanilla zones have a picture so far.
- The picture is cut to the shape of the window instead of being stretched, and is updated on every dialog.
- Zones without a picture, other languages without a translation, and installs without the pictures keep the
  normal background.
- New command `/storyline zone` (prints the detected zone and picture).

## Problems fixed (summary table)

| Problem | Cause | Fix | Version |
|---|---|---|---|
| Questie keeps handed-in quests in the tracker / map (#8) | `GetQuestReward` was cached in a local at load time and the original button was never used, so Questie's hooks never ran | Turn-in goes through the original *Complete Quest* button (global `GetQuestReward`); direct call as fallback after 1.2 s; Questie is asked to redraw tracker and map icons | 3.0.0 |
| Choices drawn under the dialog text (#7) | Frame levels were left to chance | Explicit frame levels: models < borders < chat < medallions < choices / objectives / rewards | 3.0.0 |
| No German translation (#5) | — | Complete deDE translation | 3.0.0 |
| Lua error on class quests that teach a spell (#4) | `Content.SpellFrame.Icon` did not exist | Reward buttons are built in code with their own `Icon`; spell data read defensively | 3.0.0 |
| Client crash when a dialog opened | Models were set up on a hidden frame; animations that the model does not have | Set up models only after the window is shown; only play listed animations; *Show 3D models* switch | 3.0.1 |
| Models do not turn towards each other | Facing / camera reset by the client after loading | Set facing and camera before and after loading | 3.0.2 |
| Models still do not turn | A model camera is attached to the model, so rotation has no visible effect | Characters use the free camera, rotation is applied last | 3.2.0 |
| Original quest window appears after turning in a quest | A late `QUEST_FINISHED` closed the next Storyline dialog | Close only when the original dialog is really closed; re-show a still-open original dialog through Storyline | 3.2.0 |
| Dialog cannot be closed after choosing a quest | Closing depended on the original window / server answer; stray events reopened the window | Force-close independent of both; ignore events of the dialog that was just closed; watchdog | 3.3.0 |
| Mouse wheel zooms the NPC / character by accident | Wheel over the models always resized them | Off by default, option + `/storyline wheel` | 3.3.0 |
| No control over the dimming | Fixed 50 % | *Dim strength* slider, `/storyline dim` | 3.3.0 |
| Quest not accepted with the green check mark | `IsEnabled()` returns `1`/`0`; a disabled Accept button was "clicked" and `AcceptQuest()` never called | Treat `0` as disabled, accept directly, verify the result | 3.3.1 |

## Technical notes for addon developers

Things that were learnt the hard way while making this work on the 3.3.5a client:

- **`Button:IsEnabled()` returns `1` or `0`, not a boolean.** `if button:IsEnabled() then` is always true. Use
  `S.IsOn(button)` (in `utils.lua`) or compare against `0`. A disabled button also ignores `:Click()`.
- **There is no `C_Timer`**; timers and fades are built on `OnUpdate` (`core.lua`).
- **There is no `SetAnimation()` on models**; a sequence is played by feeding `SetSequenceTime` every frame.
  Calling it with a sequence the model does not have can crash the client, so only sequences listed for that
  exact model are played.
- **Model frames must be set up after they are shown.** Setting up models on a hidden frame can crash the client.
- **A model camera is attached to the model.** While a camera is selected, `SetFacing` / `SetRotation` have no
  visible effect; use the free camera for characters that have to turn.
- **The original `QuestFrame` must stay "shown".** Hiding it closes the quest dialog on the server side. It is made
  invisible (alpha 0) and tiny (scale 0.001) instead.
- **`QUEST_FINISHED` and `GOSSIP_CLOSED` often arrive back to back with the next dialog's open event**, and
  sometimes late. Closing from those events is debounced and checks that the original dialog is really closed.
  Closing by the player does not depend on them.
- Call API functions that other addons hook (`AcceptQuest`, `GetQuestReward`…) **by name at call time**, not through
  a local copy cached at load time, or hooks installed later (Questie…) never run.

## Files

`Storyline/` contains:

| File | Purpose |
|---|---|
| `Storyline.toc` | Addon manifest (Interface 30300) |
| `core.lua` | Namespace, saved variables and defaults, timers, fades |
| `locales.lua` | All user-facing strings (enUS fallback, deDE) |
| `structures.lua` | Animation, scale and position data from the original addon |
| `utils.lua` | Text cleaning, paragraph splitting, small helpers (`S.IsOn`) |
| `frames.xml` | Parchment artwork (tiled textures) |
| `layout.lua` | Window, models, chat bubble, medallions, dim layer, control buttons |
| `locations.lua` | Location background: zone name → picture, cropping to the window, English / German / French names |
| `rewards.lua` | Reward grid, tooltips, auto-equip |
| `logic.lua` | Dialog flow, quest actions, closing logic |
| `compat.lua` | Original Blizzard frames, accepting / turning in quests, Questie |
| `options.lua` | Interface options panel and slash commands |
| `events.lua` | Event registration (every handler runs protected) |
| `Artwork/` | Textures |
| `Artwork/Locations/` | Zone pictures (`*.blp`), `Installed.lua` (switches the feature on) and `Sources.txt` (where the pictures come from) |
| `CHANGELOG.md`, `README.md`, `NOTICE.md` | Documentation |

## Not included

- Location pictures for non-vanilla zones (Outland, Northrend, the other capital cities) — planned. Until then those
  zones use the faction-tinted background.
- The friendship / reputation bar of Retail (it relies on Retail-only game data).
- Blacklist button, dyslexia font, custom text fonts.

## Credits and licence

- **Storyline** was created by Sylvain "Telkostrasz" Cossement and Morgane "Ellypse" Parize (Total RP 3).
- The **WotLK 3.3.5a backport** is by Lanrutcon, centurijon and shadovvs.
- The Lua rewrite (3.x) and the later fixes described above build on that work.
- The **location pictures** (`Artwork/Locations/`) are taken from
  **VanillaStoryline** by Renew @ nostalrius.org. They are paintings, concept art and screenshots by a number of
  third-party artists; the list of original sources is in `Artwork/Locations/Sources.txt`. **That project does not
  state a licence for the pictures, so their redistribution rights are unclear.** If you publish or fork this
  repository, either get permission from the artists, replace the pictures with your own, or leave the
  `Artwork/Locations/` folder out (delete it together with the `Artwork\Locations\Installed.lua` line in
  `Storyline.toc`; the addon then works without the location background).

The source files of the original carry the Apache License, Version 2.0
(<http://www.apache.org/licenses/LICENSE-2.0>). This version reuses the artwork (`Artwork/`), the animation /
scaling / position data (`structures.lua`) and the layout of the original and is distributed under the same
Apache License 2.0. Blizzard Entertainment owns the game assets referenced by name; the Artwork files are
Blizzard textures bundled by the original addon for 3.3.5a clients. Check the licences of upstream projects before
redistributing. See `NOTICE.md`.
