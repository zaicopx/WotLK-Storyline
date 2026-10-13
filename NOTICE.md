# Credits and licence

Storyline was created by Sylvain "Telkostrasz" Cossement and Morgane "Ellypse" Parize (Total RP 3).
The WotLK 3.3.5a backport is by Lanrutcon, centurijon and shadovvs. The source files of the original
carry the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0).

This version reuses artwork (`Artwork/`), animation / scaling / position data (`structures.lua`) and
the layout of the original, and is distributed under the same Apache License 2.0. Blizzard Entertainment
owns the game assets referenced by name; the Artwork files are Blizzard textures bundled by the original
addon for 3.3.5a clients. Check the licences of upstream projects before redistributing.


## Location pictures (Artwork/Locations)

The zone pictures in `Artwork/Locations/*.blp` come from **VanillaStoryline** by Renew @ nostalrius.org. They are
paintings, concept art and screenshots by third-party artists; the original sources are listed in
`Artwork/Locations/Sources.txt`. No licence is stated for them, so their redistribution rights are unclear.
Before publishing or redistributing this addon, get permission, replace the pictures, or remove the folder
`Artwork/Locations/` together with the `Artwork\Locations\Installed.lua` line in `Storyline.toc` (the addon works
without it, with the plain background). `locations.lua` (zone matching) is original code; the German / French zone
name translations come from Babble-Zone 2.2 via VanillaStoryline.
