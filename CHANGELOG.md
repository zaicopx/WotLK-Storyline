# Changelog

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
