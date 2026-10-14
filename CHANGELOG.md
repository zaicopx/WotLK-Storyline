# Changelog

## 3.5.1
- Fix: the cinematic zoom of 3.5.0 was far too strong: a human NPC filled the window and its head was cut off.
  The zoom distances are about 2.5 times smaller now and the default strength is 40 %.
- New: **Cinematic zoom** slider (0-100 %) in the options panel. Moving it switches the cinematic mode on and
  updates a dialog that is open. Same value as `/storyline cine <0-100>`.
- A strength of 50 % that 3.5.0 had saved (its default) is reset to the new default of 40 %.

## 3.5.0
- New: **cinematic mode**. The camera slowly zooms in on the model that is talking (the other one steps back a
  little); when the dialog asks something of you (choices, objectives, rewards) the focus moves to your character
  and goes back to the NPC with the next line. Only the two models are moved with `SetPosition`, from an
  `OnUpdate`. Models drawn with a model camera (creatures) are left alone.
  Option "Cinematic mode" (on by default), `/storyline cine`, `/storyline cine <0-100>` (strength, default 50),
  `/storyline cine flip` (reverse the direction).
- New: **NPC emotes play animations**. A text like `<Thrall bows.>` plays the bow animation (also wave, laugh,
  cry, salute). Only played on player race models (an unknown sequence can crash the client); other models stand.
  Option "NPC emotes play animations" (on by default), `/storyline emote`. English verbs only.
- New: **tint of the location picture by game time**: dark blue at night, warm at dawn and dusk, untouched during
  the day. Option "Tint background by game time" (on by default), `/storyline tint`.
- New file `effects.lua`; `UI.PlayAnimation` takes an optional duration and a "trusted" flag.

## 3.4.1
- New: location pictures for **The Burning Crusade** zones: Hellfire Peninsula, Zangarmarsh, Terokkar Forest,
  Nagrand, Blade's Edge Mountains, Netherstorm, Shadowmoon Valley, Shattrath City, Eversong Woods, Ghostlands,
  Silvermoon City, Isle of Quel'Danas, Azuremyst Isle, Bloodmyst Isle and The Exodar (16 pictures).
- Sub zones can have a picture of their own: **Area 52** (inside Netherstorm) shows its own picture.
- Outland dungeons / raids use the picture of their zone (e.g. Mana-Tombs and Sethekk Halls: Terokkar Forest,
  Black Temple: Shadowmoon Valley, Sunwell Plateau and Magisters' Terrace: Isle of Quel'Danas); Karazhan uses
  the Deadwind Pass picture.
- The new zone names are matched in English only (German / French translations are not included yet).

## 3.4.0
- New: **location background**. While a dialog is open, a picture of the zone you are in is shown behind the
  models (vanilla zones only for now: 36 pictures, plus instances / battlegrounds that belong to one of them,
  e.g. Blackrock Depths, Alterac Valley). Zones without a picture keep the normal faction-coloured background.
- New option "Location background" (on by default) and `/storyline bg` to turn it on / off.
- The picture is cut to the shape of the window instead of being stretched, and follows window resizing.
- Zone names are matched in English, German and French (translations from Babble-Zone 2.2); other languages
  fall back to the English names.
- New command `/storyline zone`: prints the zone name the game returns, the sub zone and the picture chosen.
- The pictures are in `Artwork/Locations/` (taken from VanillaStoryline, see `Sources.txt`). When that folder and
  `Artwork/Locations/Installed.lua` are removed, the addon keeps working with the plain background.

## 3.3.1
- Fix: accepting a quest with the green check mark did nothing. In 3.3.5a `Button:IsEnabled()` returns
  1 or 0 and 0 counts as "true" in Lua, so a DISABLED original Accept button was treated as usable;
  it was "clicked" (ignored by the game) and `AcceptQuest()` was never called. A disabled button now
  means the quest is accepted directly (PvP-quest confirmation and auto-accept quests included).
- The result is checked: if the quest window is still open and the quest is not in the quest log 0.3 s
  later, the quest is accepted directly; if that fails too, a diagnostic line is printed in the chat.
- The same 1/0 mistake in the dialog's "next" button (it was never really disabled while a reward
  had to be picked) is fixed.
- `/storyline debug` also prints the state of the original Accept button.

## 3.3.0
- Fix: the dialog could not be closed after a quest had been chosen. Closing by the player (X button,
  ESC, `/storyline close`) now never depends on the original Blizzard window or on a server answer:
  the Storyline window is hidden at once, the original quest / gossip window is closed too, and
  events that still arrive for the dialog that was just closed can no longer open it again.
- Fix: after accepting / declining a quest the window could stay open when the original quest window
  was not reported as closed. If it is still the same dialog 0.7 s later it is closed anyway (the next
  quest of a chain is a different dialog and is left alone).
- Fix: a faded-out window that never finished fading is hidden by a watchdog.
- The X / lock / settings / resize buttons are on a higher frame strata, so no panel inside the window
  or frame of another addon can swallow their clicks.
- The mouse wheel no longer resizes the NPC / your character by default. It is now an option
  ("Mouse wheel resizes the NPC", `/storyline wheel`), off by default. Models already resized by an
  accidental scroll: `/storyline scale reset`.
- New: "Dim strength" slider (0-100 %) in the options panel and `/storyline dim <0-100>`. Moving the
  slider switches dimming on, shows a short preview when no dialog is open, and updates live while a
  dialog is open.
- New diagnostics: `/storyline close` (emergency close), `/storyline debug` (state of the windows),
  `/storyline focus` (prints which frame is under the mouse after 4 s).

## 3.2.0
- Fix: the original quest window appeared after taking / turning in a quest. A late
  QUEST_FINISHED (sent while closing the previous quest of a chain) closed the next Storyline
  dialog. Closing now only happens when the original dialog is really closed, and if an original
  dialog is still open after Storyline ended, it is shown through Storyline again.
- Errors in the addon are now also printed in the chat (most players have Lua error popups off).
- Models turning towards each other: a model camera is attached to the model, so rotating the model
  with a camera selected had no visible effect. Characters now use the free camera (rotation is
  applied last); creatures keep camera 0. `/storyline camera all auto` restores the old behaviour.

## 3.1.0
- Camera is chosen per model: character models (humans, elves, dwarves...) use camera 1, creatures
  (treants, bears, giants...) use camera 0, so big NPCs show full body and normal NPCs stay normal.
  The NPC is hidden for a split second until its model is known. Overrides per model with
  `/storyline camera 0|1|2|auto`, global with `/storyline camera all ...`.
- Models turn towards each other: rotation is now set with SetRotation (as Blizzard's own model
  frames do) as well as SetFacing; new "Model angle" slider and `/storyline angle`.
- New: text size slider, "Dim the world behind the window" option, options panel in two columns.

## 3.0.2
- Models turn towards each other again (facing/camera are set before the model is loaded and
  applied again right after it has loaded - the client reset them).
- Giant / big NPCs: size hints by model family and creature type, wider mouse-wheel range
  (-190..190) saved per pair of models; `/storyline info`, `/storyline scale`, `/storyline camera`.
- Dialog choices: small box as wide as its longest line, no title, placed between the models
  (like the original Storyline).

## 3.0.1
- Fix client crash (ERROR #132 ACCESS_VIOLATION) when a dialog / the preview opened:
  models are now set up only after the window is shown, no more reading-book model or
  hard-coded animation numbers; an animation is only played if it is listed for that exact model.
- New option / command "Show 3D models" (`/storyline models`) as a safety switch.

## 3.0.0
- New Retail-style window: parchment frame, banner, player model left / NPC model right,
  chat bubble with faded-in text, objectives and rewards medallions, gossip choices panel.
- Dialog flow like Retail Storyline (last paragraph turns the "next" line into the action).
- Same saved variable as before (`Storyline_Data`), same per-model scaling data.
- Fix #8 Questie, #7 layer order, #5 deDE, #4 spell reward error.
- Options: text speed, auto-equip, force gossip, hide original frames, lock, disable in instances,
  tinted background, keyboard shortcuts, model animations, flip facing.

## 2.0.0 (internal)
- First Lua-only rewrite (superseded by 3.0.0).
