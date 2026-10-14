-- locations.lua
-- Picture of the zone behind the models ("location background").
--
-- Pictures: Artwork\Locations\<Name>.blp (512x256). Vanilla pictures come from VanillaStoryline (see
-- Artwork\Locations\Sources.txt); the Burning Crusade (Outland, Quel'Thalas, Azuremyst / Bloodmyst) pictures were
-- added in 3.4.1. Every zone without a picture keeps the plain (faction-tinted) background. The feature switches
-- itself off when the pictures are not installed (Artwork\Locations\Installed.lua missing), so the addon also
-- works without them.
--
-- Zone names are matched by English name. Other client languages: German and French are translated below
-- (names from Babble-Zone 2.2, as used by VanillaStoryline); other languages fall back to the English names.

local S = _G.Storyline
local UI = S.UI

local LOCATION_PATH = "Interface\\AddOns\\Storyline\\Artwork\\Locations\\"
local ART_ALPHA = 0.9

-- English zone name -> picture
local ZONE_FILE = {
	["Dun Morogh"] = "DunMorogh",
	["Durotar"] = "Durotar",
	["Elwynn Forest"] = "ElwynnForest",
	["Mulgore"] = "Mulgore",
	["Teldrassil"] = "Teldrassil",
	["Loch Modan"] = "LochModan",
	["Silverpine Forest"] = "SilverpineForest",
	["Westfall"] = "Westfall",
	["The Barrens"] = "TheBarrens",
	["Redridge Mountains"] = "RedridgeMountains",
	["Stonetalon Mountains"] = "StonetalonMountains",
	["Ashenvale"] = "Ashenvale",
	["Duskwood"] = "Duskwood",
	["Hillsbrad Foothills"] = "HillsbradFoothills",
	["Wetlands"] = "Wetlands",
	["Alterac Mountains"] = "AlteracMountains",
	["Arathi Highlands"] = "ArathiHighlands",
	["Stranglethorn Vale"] = "StranglethornVale",
	["Dustwallow Marsh"] = "DustwallowMarsh",
	["Feralas"] = "Feralas",
	["The Hinterlands"] = "TheHinterlands",
	["Tanaris"] = "Tanaris",
	["Searing Gorge"] = "SearingGorge",
	["Un'Goro Crater"] = "UngoroCrater",
	["Felwood"] = "Felwood",
	["Burning Steppes"] = "BurningSteppes",
	["Western Plaguelands"] = "WesternPlaguelands",
	["Deadwind Pass"] = "DeadwindPass",
	["Eastern Plaguelands"] = "EasternPlaguelands",
	["Winterspring"] = "Winterspring",
	["Moonglade"] = "Moonglade",
	["Silithus"] = "Silithus",
	["Blackrock Mountain"] = "BlackrockMountain",
	["Ironforge"] = "Ironforge",
	["City of Ironforge"] = "Ironforge",
	["Stormwind City"] = "StormwindCity",
	["Undercity"] = "Undercity",
	["Alterac Valley"] = "AlteracMountains",
	["Blackrock Depths"] = "BlackrockMountain",
	["Blackrock Spire"] = "BlackrockMountain",
	["Lower Blackrock Spire"] = "BlackrockMountain",
	["Upper Blackrock Spire"] = "BlackrockMountain",
	["Molten Core"] = "BlackrockMountain",
	["Blackwing Lair"] = "BlackrockMountain",
	["Hellfire Peninsula"] = "HellfirePeninsula",
	["Zangarmarsh"] = "Zangarmarsh",
	["Terokkar Forest"] = "TerokkarForest",
	["Nagrand"] = "Nagrand",
	["Blade's Edge Mountains"] = "BladesEdgeMountains",
	["Netherstorm"] = "Netherstorm",
	["Shadowmoon Valley"] = "ShadowmoonValley",
	["Shattrath City"] = "ShattrathCity",
	["Eversong Woods"] = "EversongWoods",
	["Ghostlands"] = "Ghostlands",
	["Silvermoon City"] = "SilvermoonCity",
	["Isle of Quel'Danas"] = "IsleOfQuelDanas",
	["Azuremyst Isle"] = "AzuremystIsle",
	["Bloodmyst Isle"] = "BloodmystIsle",
	["The Exodar"] = "TheExodar",
	["Hellfire Ramparts"] = "HellfirePeninsula",
	["The Blood Furnace"] = "HellfirePeninsula",
	["The Shattered Halls"] = "HellfirePeninsula",
	["Magtheridon's Lair"] = "HellfirePeninsula",
	["The Slave Pens"] = "Zangarmarsh",
	["The Underbog"] = "Zangarmarsh",
	["The Steamvault"] = "Zangarmarsh",
	["Serpentshrine Cavern"] = "Zangarmarsh",
	["Mana-Tombs"] = "TerokkarForest",
	["Auchenai Crypts"] = "TerokkarForest",
	["Sethekk Halls"] = "TerokkarForest",
	["Shadow Labyrinth"] = "TerokkarForest",
	["Gruul's Lair"] = "BladesEdgeMountains",
	["The Mechanar"] = "Netherstorm",
	["The Botanica"] = "Netherstorm",
	["The Arcatraz"] = "Netherstorm",
	["Tempest Keep"] = "Netherstorm",
	["The Eye"] = "Netherstorm",
	["Black Temple"] = "ShadowmoonValley",
	["Magisters' Terrace"] = "IsleOfQuelDanas",
	["Sunwell Plateau"] = "IsleOfQuelDanas",
	["Zul'Aman"] = "Ghostlands",
	["Karazhan"] = "DeadwindPass",
}

-- sub zones that have a picture of their own (checked before the zone)
local SUBZONE_FILE = {
	["Area 52"] = "Area52",
}

-- localized zone name -> English zone name (only needed where the name differs)
local LOCALIZED = {
	deDE = {
		["Wald von Elwynn"] = "Elwynn Forest",
		["Tirisfal"] = "Tirisfal Glades",
		["Dunkelk\195\188ste"] = "Darkshore",
		["Silberwald"] = "Silverpine Forest",
		["Brachland"] = "The Barrens",
		["Rotkammgebirge"] = "Redridge Mountains",
		["Steinkrallengebirge"] = "Stonetalon Mountains",
		["D\195\164mmerwald"] = "Duskwood",
		["Vorgebirge von Hillsbrad"] = "Hillsbrad Foothills",
		["Sumpfland"] = "Wetlands",
		["Tausend Nadeln"] = "Thousand Needles",
		["Alteracgebirge"] = "Alterac Mountains",
		["Arathihochland"] = "Arathi Highlands",
		["Schlingendorntal"] = "Stranglethorn Vale",
		["Marschen von Dustwallow"] = "Dustwallow Marsh",
		["\195\150dland"] = "Badlands",
		["S\195\188mpfe des Elends"] = "Swamp of Sorrows",
		["Hinterland"] = "The Hinterlands",
		["Sengende Schlucht"] = "Searing Gorge",
		["Verw\195\188stete Lande"] = "Blasted Lands",
		["Un'Goro-Krater"] = "Un'Goro Crater",
		["Teufelswald"] = "Felwood",
		["Brennende Steppe"] = "Burning Steppes",
		["Westliche Pestl\195\164nder"] = "Western Plaguelands",
		["Gebirgspass der Totenwinde"] = "Deadwind Pass",
		["\195\150stliche Pestl\195\164nder"] = "Eastern Plaguelands",
		["Stormwind"] = "Stormwind City",
	},
	frFR = {
		["For\195\170t d'Elwynn"] = "Elwynn Forest",
		["Clairi\195\168res de Tirisfal"] = "Tirisfal Glades",
		["Sombrivage (Darkshore)"] = "Darkshore",
		["For\195\170t des Pins argent\195\169s (Silverpine Forest)"] = "Silverpine Forest",
		["Marche de l'Ouest (Westfall)"] = "Westfall",
		["Les Tarides (the Barrens)"] = "The Barrens",
		["Les Carmines (Redridge Mts)"] = "Redridge Mountains",
		["Les Serres-Rocheuses (Stonetalon Mts)"] = "Stonetalon Mountains",
		["Bois de la P\195\169nombre (Duskwood)"] = "Duskwood",
		["Contreforts d'Hillsbrad"] = "Hillsbrad Foothills",
		["Les Paluns (Wetlands)"] = "Wetlands",
		["Mille pointes (Thousand Needles)"] = "Thousand Needles",
		["Montagnes d'Alterac"] = "Alterac Mountains",
		["Bassin d'Arathi"] = "Arathi Highlands",
		["D\195\169solace"] = "Desolace",
		["Vall\195\169e de Strangleronce (Stranglethorn Vale)"] = "Stranglethorn Vale",
		["Mar\195\169cage d'\195\130prefange (Dustwallow Marsh)"] = "Dustwallow Marsh",
		["Terres ingrates (Badlands)"] = "Badlands",
		["Marais des Chagrins (Swamp of Sorrows)"] = "Swamp of Sorrows",
		["Les Hinterlands"] = "The Hinterlands",
		["Gorge des Vents br\195\187lants (Searing Gorge)"] = "Searing Gorge",
		["Terres foudroy\195\169es (Blasted Lands)"] = "Blasted Lands",
		["Crat\195\168re d'Un'Goro"] = "Un'Goro Crater",
		["Gangrebois (Felwood)"] = "Felwood",
		["Steppes ardentes"] = "Burning Steppes",
		["Maleterres de l'ouest (Western Plaguelands)"] = "Western Plaguelands",
		["D\195\169fil\195\169 de Deuillevent (Deadwind Pass)"] = "Deadwind Pass",
		["Maleterres de l'est (Eastern Plaguelands)"] = "Eastern Plaguelands",
		["Berceau-de-l'Hiver (Winterspring)"] = "Winterspring",
		["Reflet-de-lune"] = "Moonglade",
		["Cit\195\169 de Stormwind"] = "Stormwind City",
	},
}

-- A few names in the source table carry the English name in brackets, e.g. "Name (Dustwallow Marsh)":
-- the client only returns the part before the brackets, so add that form as well.
for _, names in pairs(LOCALIZED) do
	local extra = {}
	for name, english in pairs(names) do
		local plain = name:gsub("%s*%b()%s*$", "")
		if plain ~= name and plain ~= "" then extra[plain] = english end
	end
	for name, english in pairs(extra) do names[name] = english end
end

local function currentZone()
	local zone = GetRealZoneText and GetRealZoneText()
	if not zone or zone == "" then zone = GetZoneText() end
	return zone
end

-- Returns the picture name for a zone (default: the zone the player is in), or nil.
-- Without arguments a sub zone with a picture of its own (e.g. Area 52) wins over the zone.
function S.GetLocationArt(zone)
	if not zone then
		local sub = GetSubZoneText and GetSubZoneText()
		if sub and SUBZONE_FILE[sub] then return SUBZONE_FILE[sub] end
		zone = currentZone()
	end
	if not zone or zone == "" then return nil end
	local names = LOCALIZED[GetLocale()]
	local english = (names and names[zone]) or zone
	return ZONE_FILE[english]
end

-- The picture is cut (not stretched) to the shape of the window.
function UI.CropLocationArt()
	local art, f = UI.locArt, UI.frame
	if not art or not f or not UI.currentLocationArt then return end
	local w, h = f:GetWidth() - 40, f:GetHeight() - 40
	if not w or not h or w <= 0 or h <= 0 then return end
	local imageAspect, windowAspect = 2, w / h   -- the pictures are 512 x 256
	local left, right, top, bottom = 0, 1, 0, 1
	if windowAspect > imageAspect then
		local visible = imageAspect / windowAspect
		top = (1 - visible) / 2; bottom = 1 - top
	else
		local visible = windowAspect / imageAspect
		left = (1 - visible) / 2; right = 1 - left
	end
	art:SetTexCoord(left, right, top, bottom)
end

-- Shows the picture of the current zone (when the option is on and a picture exists), otherwise the
-- normal background.
function UI.UpdateLocationBackground()
	local art = UI.locArt
	if not art then return end
	local file = S.db.locationBackground and S.LocationArtInstalled and S.GetLocationArt() or nil
	if file then
		art:SetTexture(LOCATION_PATH .. file)
		art:SetAlpha(ART_ALPHA)
		art:Show()
		UI.bgArt:Hide()
		UI.currentLocationArt = file
		UI.CropLocationArt()
		if UI.UpdateLocationTint then UI.UpdateLocationTint() end
	else
		art:Hide()
		UI.bgArt:Show()
		UI.currentLocationArt = nil
	end
end
