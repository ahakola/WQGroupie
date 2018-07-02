--[[
Sources:

GitHub:
	- https://github.com/robinbrisa/worldquestgroupfinder/blob/master/WorldQuestGroupFinder/WorldQuestGroupFinder.lua
	- This worked as a starting point and it has been almost complete rewrite, but there still might be be parts of code or similarities left

	robinbrisa/worldquestgroupfinder is licensed under the
	GNU General Public License v3.0

	Permissions of this strong copyleft license are conditioned on making available complete source code of licensed works and modifications, which include larger works using a licensed work, under the same license. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights.
	Permissions
	    Commercial use
	    Modification
	    Distribution
	    Patent use
	    Private use

	Conditions
	    License and copyright notice
	    State changes
	    Disclose source
	    Same License

	Limitations
	    Liability
	    Warranty

	https://github.com/robinbrisa/worldquestgroupfinder/blob/master/LICENSE - Referenced 28th April 2017
]]
local ADDON_NAME, private = ...

-- Use these to block out all Solo and Raid WQs
local blacklistedQuests = {
	[45379] = true, -- Treasure Master Iks'reeged
	--[45988] = true, -- Ancient Bones
	[43943] = true, -- Withered Army Training
	[42725] = true, -- Sharing the Wealth
	[42880] = true, -- Meeting their Quota
	[42178] = true, -- Shock Absorber
	[42173] = true, -- Electrosnack
	[44011] = true, -- Lost Wisp
	[43774] = true, -- Ley Race
	[43764] = true, -- Ley Race
	[43753] = true, -- Ley Race
	[43325] = true, -- Ley Race
	[43769] = true, -- Ley Race
	[43772] = true, -- Enigmatic
	[43767] = true, -- Enigmatic
	[43756] = true, -- Enigmatic
	[45032] = true, -- Like the Wind
	[45046] = true, -- Like the Wind
	[45047] = true, -- Like the Wind
	[45048] = true, -- Like the Wind
	[45049] = true, -- Like the Wind
	[45068] = true, -- Barrels o' fun
	[45069] = true, -- Barrels o' fun
	[45070] = true, -- Barrels o' fun
	[45071] = true, -- Barrels o' fun
	[45072] = true, -- Barrels o' fun
	[44786] = true, -- Midterm: Rune Aptitude
	[41327] = true, -- Supplies Needed: Stormscales
	[41345] = true, -- Supplies Needed: Stormscales
	[41318] = true, -- Supplies Needed: Felslate
	[41237] = true, -- Supplies Needed: Stonehide Leather
	[41339] = true, -- Supplies Needed: Stonehide Leather
	[41351] = true, -- Supplies Needed: Stonehide Leather
	[41207] = true, -- Supplies Needed: Leystone
	[41298] = true, -- Supplies Needed: Fjarnskaggl
	[41315] = true, -- Supplies Needed: Leystone
	[41316] = true, -- Supplies Needed: Leystone
	[41317] = true, -- Supplies Needed: Leystone
	[41303] = true, -- Supplies Needed: Starlight Roses
	[41288] = true, -- Supplies Needed: Aethril
	[44932] = true, -- The Nighthold: Ettin Your Foot In The Door
	[44937] = true, -- The Nighthold: Focused Power
	[44934] = true, -- The Nighthold: Creepy Crawlers
	[44935] = true, -- The Nighthold: Gilded Guardian
	[44938] = true, -- The Nighthold: Love Tap
	[44939] = true, -- The Nighthold: Seeds of Destruction
	[44936] = true, -- The Nighthold: Supply Routes
	[44933] = true, -- The Nighthold: Wailing In The Night
}
-- Not used at the moment, but save for possible later use.
local activityIDs = {
	[1015] = 419,
	[1018] = 420,
	[1024] = 421,
	[1017] = 422,
	[1033] = 423,
	[1022] = 422, -- Create Helheim WQ in Stormheim
	[1096] = 419 -- Create Eye of Azshara WQs in Aszuna
}

private.blacklistedQuests = blacklistedQuests
