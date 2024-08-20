--[[
Sources used to create this addon:

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

DefaultUI FrameXML:
	- At least following files (there might have been others, but mostly these) have been used:
		QuestUtils.lua
		LFGList.lua
		Blizzard_BonusObjectiveTracker.lua


My previous addons:
	Some parts of code has been recycled from my other addons, but I can't recall all anymore what and from where.

]]

--[[ Reminder so I don't have to look these up all the time
LFGListUtil_GetQuestCategoryData(questID);
	return activityID, categoryID, filters, questName;

GetQuestTagInfo(questID);
	return tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, displayTimeLeft;

LFGListEntryCreation_GetAutoCreateDataQuest(self)
	return activityID, name, itemLevel, honorLevel, voiceChatInfo, description, autoAccept, privateGroup, questID;
]]


--[[ TODO
- Slashhandler
	- Toggle
	- Settings
- Real settings?
]]

local ADDON_NAME, private = ...

local db = { debug = false }
local function Debug(text, ...)
	if not db.debug then return end
	if text then
		if text:match("%%[dfqsx%d%.]") then
			(DEBUG_CHAT_FRAME or ChatFrame1):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. format(text, ...))
		else
			(DEBUG_CHAT_FRAME or ChatFrame1):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

local function Print(text, ...)
	if text then
		if text:match("%%[dfqs%d%.]") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. ADDON_NAME ..":|r " .. format(text, ...))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. ADDON_NAME ..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

local WQGroupie = CreateFrame("Frame")
local panel = LFGListFrame
local questTable = {}
local leaveDelay = 15
local blacklistedQuests = private.blacklistedQuests or {}

-- Icons
local iconCreateGroup = 236352
local iconDelist = 236372
local iconError = 134400
local iconGroupUp = 136054
local iconIdle = 132156
local iconSearch = 463888 -- 134442
local iconWaitForInvite = 134376 -- 237538
local iconAcceptDecline = 1391676

local LMB = "|TInterface\\HELPFRAME\\NewPlayerExperienceParts:24:24:0:0:1024:512:981:1013:66:98|t"
local RMB = "|TInterface\\HELPFRAME\\NewPlayerExperienceParts:24:24:0:0:1024:512:981:1013:132:164|t"
local iconLMB = "|TInterface\\HELPFRAME\\NewPlayerExperienceParts:24:24:0:3:1024:512:981:1013:66:98|t"
local iconRMB = "|TInterface\\HELPFRAME\\NewPlayerExperienceParts:24:24:0:3:1024:512:981:1013:132:164|t"

-- Tooltips
local tooltipHeader = NORMAL_FONT_COLOR_CODE..ADDON_NAME..FONT_COLOR_CODE_CLOSE.."\n"

local tooltipAcceptDecline = tooltipHeader..LMB.."Accept invitation to this group.\n"..RMB.."Decline invitation to this group."
local tooltipCreated = tooltipHeader.."Created and listed your own group for others to join.\n"..RMB.." Cancel listing."
local tooltipDelist = tooltipHeader.."Your group is still listed in the Finder-tool.\n"..LMB.." Delist your group."
local tooltipGroupedUp = tooltipHeader.."You are in questing group now. Be awesome to others!"
local tooltipIdle = tooltipHeader.."Idling, go to active world quest area to make the magic happen.\n"..BATTLENET_FONT_COLOR_CODE.."ALT"..FONT_COLOR_CODE_CLOSE.." +"..LMB.." Reposition by dragging."
local tooltipNoResultsFound = tooltipHeader.."No results found. I have no idea what happened, but something went wrong."
local tooltipResults = tooltipHeader.."Found %d groups fitting your requirements.\n"..LMB.."Apply to one group per click, up to %d groups at once.\n"..RMB.."Create and list your own group."
local tooltipSearch = tooltipHeader..LMB.."Seach for questing groups.\n"..RMB.."Create and list your own group."
local tooltipSearchFailed = tooltipHeader.."Search Failed. You probably searched too many times in too short timeperiod. Try again after few seconds."
local tooltipZeroResults = tooltipHeader.."Found 0 groups fitting you requirements.\n"..LMB.."Seach again for questing groups.\n"..RMB.."Create and list your own group."

local function _createClick(button)
	private.CreateListing(private.questID, private.activityID)

	Debug("Create CLICK", button)
	PlaySound("igCharacterInfoOpen");
end

local function _getTasks()
	local tasks = GetTasksTable();

	for i = #tasks, 1, -1 do
		local questID = tasks[i]
		local isInArea, isOnMap, numObjectives, taskName, displayAsObjective = GetTaskInfo(questID);

		if isInArea and isOnMap then
			if not questTable[questID] and questID ~= private.questID then
				questTable[questID] = taskName

				private.processQuest(questID)
				break
			elseif questID ~= private.questID then
				private.processQuest(questID)
				break
			else
				table.remove(tasks, i)
				wipe(questTable)
			end
		elseif not isOnMap then
			table.remove(tasks, i)
		end
	end

	Debug("_getTasks", #tasks)
end

local function noopClick(this, button)
	if button == "MiddleButton" then
		_getTasks()
	end

	if private.created then
		private.RemoveListing()
	end

	Debug("noop CLICK", button)
	PlaySound("igMainMenuOptionCheckBoxOn");
end

local function _setIdle()
	WQGroupie.Button.Ctext:SetText("Idle")
	WQGroupie.Button.Ltext:SetText("")
	WQGroupie.Button.Rtext:SetText("")
	WQGroupie.Button.tooltip = tooltipIdle
	WQGroupie.Button:SetScript("OnClick", noopClick)
	WQGroupie.Button.bg:SetTexture(iconIdle)
end

local function delistClick(this, button)
	if private.created then
		private.RemoveListing()
	end

	_setIdle()

	Debug("delist CLICK", button)
	PlaySound("igMainMenuOptionCheckBoxOn");
end

local function cancelClick(this, button)
	if button == "RightButton" then
		if not private.groupUp then
			private.RemoveListing()
		end

		_setIdle()
	end

	Debug("cancel CLICK", button)
	PlaySound("igMainMenuOptionCheckBoxOn");
end

local function searchAndCreate(this, button)
	if button == "LeftButton" then
		private.Search(private.questID)

		WQGroupie.Button:Disable()
		Debug("Search CLICK", button)
		PlaySound("igMainMenuOptionCheckBoxOn");
	elseif button == "RightButton" then
		_createClick(button)
	elseif button == "MiddleButton" then
		_getTasks()
	end
end

local function _setSearch(noResults)
	if noResults then
		WQGroupie.Button.Ctext:SetText("0 results\nTry again in a second.")
		WQGroupie.Button.tooltip = tooltipZeroResults
	else
		WQGroupie.Button.Ctext:SetText(questTable[private.questID])
		WQGroupie.Button.tooltip = tooltipSearch
	end
	WQGroupie.Button.Ltext:SetText("Seach\n"..iconLMB)
	WQGroupie.Button.Rtext:SetText("Create\n"..iconRMB)
	WQGroupie.Button:SetScript("OnClick", searchAndCreate)
	WQGroupie.Button.bg:SetTexture(iconSearch)
end

local function applyAndCreate(this, button)
	if button == "LeftButton" then
		local numApplications, numActiveApplications = C_LFGList.GetNumApplications();
		if numActiveApplications < MAX_LFG_LIST_APPLICATIONS then
			local resultID = tremove(private.applications)
			if resultID then
				private.ApplyToGroup(resultID, private.questID, private.spec)

				WQGroupie.Button.Ctext:SetText(string.format("%d/%d applied", numActiveApplications, math.min(private.applyMax, MAX_LFG_LIST_APPLICATIONS)))
				WQGroupie.Button.Ltext:SetText("Apply\n"..iconLMB)
				WQGroupie.Button.Rtext:SetText("Create\n"..iconRMB)
				PlaySound("PVPEnterQueue");
			else
				Debug("!resultID ???")

				Print("Something went wrong... Taking few steps back")
				_setSearch()
				PlaySound("igMainMenuOptionCheckBoxOn");
			end
		else
			Print(LFG_LIST_HIT_MAX_APPLICATIONS, MAX_LFG_LIST_APPLICATIONS)
			PlaySound("igMainMenuOptionCheckBoxOn");
		end
		Debug("Apply CLICK", button)
	elseif button == "RightButton" then
		_createClick(button)
	end
end

local function acceptOrDecline(this, button)
	if private.applicationID then
		if button == "LeftButton" then
			C_LFGList.AcceptInvite(private.applicationID);
		elseif button == "RightButton" then
			C_LFGList.DeclineInvite(private.applicationID);
		end
	end

	Debug("accept/decline CLICK", button, private.applicationID)
	PlaySound("igMainMenuOptionCheckBoxOn");
	private.applicationID = nil
end

local function _setApply()
	local numApplications, numActiveApplications = C_LFGList.GetNumApplications();
	WQGroupie.Button.Ctext:SetText(string.format("%d/%d applied", numActiveApplications, math.min(private.applyMax, MAX_LFG_LIST_APPLICATIONS)))
	WQGroupie.Button.Ltext:SetText("Apply\n"..iconLMB)
	WQGroupie.Button.Rtext:SetText("Create\n"..iconRMB)
	WQGroupie.Button.tooltip = string.format(tooltipResults, private.applyMax, MAX_LFG_LIST_APPLICATIONS)
	WQGroupie.Button:SetScript("OnClick", applyAndCreate)
	WQGroupie.Button.bg:SetTexture(iconWaitForInvite)
end

do
	WQGroupie.Button = CreateFrame("Button", ADDON_NAME.."_Button", UIParent)
	WQGroupie.Button:SetPoint("CENTER", 250, 250)
	--WQGroupie.Button:SetSize(64, 64)
	WQGroupie.Button:SetSize(75, 75)
	WQGroupie.Button:SetScript("OnClick", noopClick)
	WQGroupie.Button:RegisterForClicks("AnyUp")

	WQGroupie.Button:SetScript("OnEnter", function(self)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			--GameTooltip:SetText(self.tooltip, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true);
			GameTooltip:SetText(self.tooltip, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1, true);
			GameTooltip:Show();
		end
	end)
	WQGroupie.Button:SetScript("OnLeave", GameTooltip_Hide)
	WQGroupie.Button.tooltip = tooltipIdle

	WQGroupie.Button:SetMovable(true)
	WQGroupie.Button:SetClampedToScreen(true)
	WQGroupie.Button:RegisterForDrag("LeftButton")
	WQGroupie.Button:SetScript("OnDragStart", function()
		if (IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then
			WQGroupie.Button:StartMoving()
		end
	end)
	WQGroupie.Button:SetScript("OnDragStop", WQGroupie.Button.StopMovingOrSizing)

	WQGroupie.Button:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = true,
		tileSize = 8,
		edgeSize = 2,
	})
	WQGroupie.Button:SetBackdropColor(0, 0, 0, .5)
	WQGroupie.Button:SetBackdropBorderColor(0, 0, 0, 1)

	WQGroupie.Button.bg = WQGroupie.Button:CreateTexture(nil, "BACKGROUND")
	WQGroupie.Button.bg:ClearAllPoints()
	WQGroupie.Button.bg:SetAllPoints()
	WQGroupie.Button.bg:SetTexCoord(.08, .92, .08, .92) -- Strip the "borders"
	WQGroupie.Button.bg:SetTexture(iconIdle)
	--WQGroupie.Button.bg:SetColorTexture(0, 0, 0, .5)

	--[[WQGroupie.Button.title = WQGroupie.Button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall") --"GameFontHighlightSmall")
	WQGroupie.Button.title:SetPoint("TOP", 0, 3)
	WQGroupie.Button.title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	WQGroupie.Button.title:SetText(ADDON_NAME)]]

	WQGroupie.Button.Ctext = WQGroupie.Button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall") --"GameFontHighlightSmall")
	--WQGroupie.Button.Ctext:SetPoint("CENTER")
	WQGroupie.Button.Ctext:SetPoint("TOP", WQGroupie.Button, "CENTER")
	WQGroupie.Button.Ctext:SetTextColor(1, 1, 1)
	WQGroupie.Button.Ctext:SetText("Idle")

	WQGroupie.Button.Ltext = WQGroupie.Button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall") --"GameFontHighlightSmall")
	--WQGroupie.Button.Ltext:SetPoint("TOPLEFT", 1, -8)
	WQGroupie.Button.Ltext:SetPoint("TOPLEFT", 2, -3)
	WQGroupie.Button.Ltext:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	--WQGroupie.Button.Ltext:SetTextColor(1, 1, 1)
	--WQGroupie.Button.Ltext:SetTextColor(.5, .5, .5)
	--WQGroupie.Button.Ltext:SetText("Left")

	WQGroupie.Button.Rtext = WQGroupie.Button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall") --"GameFontHighlightSmall")
	--WQGroupie.Button.Rtext:SetPoint("TOPRIGHT", 0, -8)
	WQGroupie.Button.Rtext:SetPoint("TOPRIGHT", 1, -3)
	WQGroupie.Button.Rtext:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	--WQGroupie.Button.Rtext:SetTextColor(1, 1, 1)
	--WQGroupie.Button.Rtext:SetTextColor(.5, .5, .5)
	--WQGroupie.Button.Rtext:SetText("Right")

	--WQGroupie.Button.Ltext:SetText("Search\n"..iconLMB)
	--WQGroupie.Button.Rtext:SetText("Create\n"..iconRMB)
end

WQGroupie:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, event, ...)
end)
WQGroupie:RegisterEvent("ADDON_LOADED")

function WQGroupie:ADDON_LOADED(event, addon, ...)
	if addon ~= ADDON_NAME then return end

	self:UnregisterEvent(event)
	self:RegisterEvent("PLAYER_LOGIN")

	private.applications = {}
	private.applicants = {}
	private.groupUp = false
end

function WQGroupie:PLAYER_LOGIN(event)
	self:UnregisterEvent(event)
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
	self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
	self:RegisterEvent("LFG_LIST_NO_RESULTS_FOUND")
	self:RegisterEvent("LFG_LIST_SEARCH_FAILED")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("QUEST_REMOVED")
	self:RegisterEvent("QUEST_TURNED_IN")

	_getTasks()
end

function WQGroupie:PLAYER_ENTERING_WORLD(event)
	local inInstance, instanceType = IsInInstance()
	if inInstance then
		WQGroupie.Button:Hide()
	else
		WQGroupie.Button:Show()
	end
end

do -- GROUP_ROSTER_UPDATE
	local throttling

	local function DelayedUpdate()
		throttling = nil

		if private.questID and private.groupUp then
			WQGroupie.Button.Ctext:SetText("Grouped up!")
			WQGroupie.Button.Ltext:SetText("")
			WQGroupie.Button.Rtext:SetText("")
			WQGroupie.Button.tooltip = tooltipGroupedUp
			WQGroupie.Button:SetScript("OnClick", noopClick)
			WQGroupie.Button.bg:SetTexture(iconGroupUp)
		end

		if private.questID and QuestUtils_IsQuestWorldQuest(private.questID) and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) > 0 then
			local _, _, _, rarity = GetQuestTagInfo(private.questID);
			if not IsInRaid() and UnitIsGroupLeader("player") and rarity == LE_WORLD_QUEST_QUALITY_EPIC then
				C_PartyInfo.ConvertToRaid() -- ConvertToRaid()
			end
		end
	end

	local function ThrottleUpdate(self, event, questID)
		if not throttling then
			throttling = true
			C_Timer.After(0.5, DelayedUpdate)
		end
	end

	WQGroupie.GROUP_ROSTER_UPDATE = ThrottleUpdate -- Throttle
end

do -- QUEST_REMOVED / QUEST_TURNED_IN
	local throttling
	local carryID

	local function DelayedUpdate()
		throttling = nil

		if private.questID and private.questID == carryID and
		QuestUtils_IsQuestWorldQuest(private.questID) then
			if private.created then
				WQGroupie.Button.Ctext:SetText("Delist group")
				WQGroupie.Button.Ltext:SetText("Delist\n"..iconLMB)
				WQGroupie.Button.Rtext:SetText("")
				WQGroupie.Button.tooltip = tooltipDelist
				WQGroupie.Button:SetScript("OnClick", delistClick)
				WQGroupie.Button.bg:SetTexture(iconDelist)
			else
				_setIdle()
			end

			if private.groupUp then
				if GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) > 1 then
					if questTable[private.questID] then
						Print("WorldQuest \"%s\" completed, leaving group in %d seconds.", questTable[private.questID], leaveDelay)
					else
						Print("WorldQuest completed, leaving group in %d seconds.", leaveDelay)
					end
					C_Timer.After(leaveDelay, function()
						C_PartyInfo.LeaveParty() -- LeaveParty()
					end)
				else
					Print("WorldQuest completed.")
					C_PartyInfo.LeaveParty() -- LeaveParty()
				end

				PlaySound("ReadyCheck");
			else
				Print("WorldQuest completed.")
			end

			wipe(private.applications)
			wipe(private.applicants)
			private.questID = nil
			private.groupUp = false
		end
	end

	local function ThrottleUpdate(self, event, questID)
		if not throttling then
			throttling = true
			carryID = questID
			C_Timer.After(0.5, DelayedUpdate)
		end
	end

	WQGroupie.QUEST_REMOVED = ThrottleUpdate -- Throttle
	WQGroupie.QUEST_TURNED_IN = ThrottleUpdate -- Throttle
end

function WQGroupie:LFG_LIST_SEARCH_RESULTS_RECEIVED(event)
	WQGroupie.Button:Enable()

	if not private.questID then return end -- Stop if you are doing something else

	wipe(private.applications)
	local totalResults, results = C_LFGList.GetSearchResults();
	local myNumMembers = math.max(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME), 1);

	Debug("Results:", totalResults, results and #results or 0, myNumMembers)

	for _, resultID in ipairs(results) do
		local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID);
		Debug("GetApplicationInfo", tostring(appStatus), tostring(pendingStatus), tostring(appDuration))
		local id, activityID, name, comment, voiceChat, iLvl, honorLevel, age, numBNetFriends, numCharFriends, numGuildMates, isDelisted, leaderName, numMembers, isAutoAccept = C_LFGList.GetSearchResultInfo(resultID);
		if appStatus and appStatus == "none" and not pendingStatus and not isDelisted then
			local _, _, _, rarity = GetQuestTagInfo(private.questID);
			if (not IsInRaid(LE_PARTY_CATEGORY_HOME) and myNumMembers + numMembers < (MAX_PARTY_MEMBERS + 1)) or
				(IsInRaid() and rarity == LE_WORLD_QUEST_QUALITY_EPIC and myNumMembers + numMembers < MAX_RAID_MEMBERS) then
				private.applications[#private.applications + 1] = resultID
			end
		end
	end

	if #private.applications == 0 then
		Print("None of the results matched requirements, try creating your own group or search again.")

		_setSearch(true)
	else
		Print("Found %d groups matching requirements, click to apply for them.", #private.applications)
		private.spec = GetSpecializationRole(GetSpecialization())
		private.applyMax = #private.applications

		_setApply()
	end

end

function WQGroupie:LFG_LIST_SEARCH_FAILED(event)
	WQGroupie.Button:Enable()
	WQGroupie.Button.Ctext:SetText("Search failed.")
	WQGroupie.Button.tooltip = tooltipSearchFailed
	WQGroupie.Button.bg:SetTexture(iconError)

	Print("Search failed.")
end

function WQGroupie:LFG_LIST_NO_RESULTS_FOUND(event)
	WQGroupie.Button:Enable()
	WQGroupie.Button.Ctext:SetText("No results found.")
	WQGroupie.Button.tooltip = tooltipNoResultsFound
	WQGroupie.Button.bg:SetTexture(iconError)

	Print("No results found.")
end

local function reduceApplicationCount()
	private.applyMax = math.max(private.applyMax - 1, #private.applications)

	_setApply()
end

function WQGroupie:LFG_LIST_APPLICATION_STATUS_UPDATED(event, applicationID, newStatus, oldStatus)
	if private.questID then
		if newStatus == "invited" then
			--PlaySound("ReadyCheck");
			private.applicationID = applicationID
			WQGroupie.Button.Ctext:SetText("Invited to group")
			WQGroupie.Button.Ltext:SetText("Accept\n"..iconLMB)
			WQGroupie.Button.Rtext:SetText("Decline\n"..iconRMB)
			WQGroupie.Button.tooltip = tooltipAcceptDecline
			WQGroupie.Button:SetScript("OnClick", acceptOrDecline)
			WQGroupie.Button.bg:SetTexture(iconAcceptDecline)

		elseif newStatus == "declined" or newStatus == "failed" or newStatus == "timedout" or
		newStatus == "declined_full" or newStatus == "declined_delisted" or newStatus == "invitedeclined" then
			reduceApplicationCount()
		elseif newStatus == "inviteaccepted" then
			--WQGroupie.Button:SetScript("OnClick", applyAndCreate)
			Debug(">", event, newStatus, oldStatus)

			private.groupUp = true
			self:GROUP_ROSTER_UPDATE()
		end
	end
end

function WQGroupie:LFG_LIST_APPLICANT_UPDATED(event, applicantID)
	if private.questID then
		local id, status, pendingStatus, numMembers, isNew, comment = C_LFGList.GetApplicantInfo(applicantID);
		if status == "inviteaccepted" then
			private.groupUp = true
			private.created = false
			self:GROUP_ROSTER_UPDATE()

			if not private.applicants[applicantID] then
				private.applicants[applicantID] = true

				if (numMembers > 1) then
					Print("Got %d new group members!", numMembers)
				else
					Print("Got new group member!")
				end
			end
		end
	end
end

function private.ApplyToGroup(resultID, questID, spec) -- C_LFGList.ApplyToGroup(resultID, comment, tankOK, healerOK, damageOK)
	local myNumMembers = math.max(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME), 1);
	local _, _, _, _, _, _, _, _, _, _, _, isDelisted, _, numMembers = C_LFGList.GetSearchResultInfo(resultID);

	local _, _, _, rarity = GetQuestTagInfo(private.questID);
	if not isDelisted and (not IsInRaid(LE_PARTY_CATEGORY_HOME) and myNumMembers + numMembers < (MAX_PARTY_MEMBERS + 1)) or
	(IsInRaid() and rarity == LE_WORLD_QUEST_QUALITY_EPIC and myNumMembers + numMembers < MAX_RAID_MEMBERS) then
		C_LFGList.ApplyToGroup(resultID, string.format("%s-%d", ADDON_NAME, questID or 0), spec == "TANK", spec == "HEALER", spec == "DAMAGER")
		Debug("ApplyToGroup")
	else
		reduceApplicationCount()
		Debug("!ApplyToGroup ???")
	end
end

function private.ClearSearchResults() -- C_LFGList.ClearSearchResults
	C_LFGList.ClearSearchResults()
	Debug("ClearSearchResults")
end

function private.CreateListing(questID, activityID) -- C_LFGList.CreateListing(activityID, name, itemLevel, honorLevel, voiceChatInfo, description, autoAccept, privateGroup, questID)
	local activityID, name, itemLevel, honorLevel, voiceChatInfo, description, autoAccept, privateGroup, questID = LFGListEntryCreation_GetAutoCreateDataQuest({ autoCreateContextID = questID, autoCreateActivityID = activityID })

	if (C_LFGList.CreateListing(activityID, name, itemLevel, honorLevel, voiceChatInfo, description, autoAccept, privateGroup, questID)) then
		LFGListFrame.displayedAutoAcceptConvert = true

		WQGroupie.Button.Ctext:SetText("Listing created!")
		WQGroupie.Button.Ltext:SetText("")
		WQGroupie.Button.Rtext:SetText("Cancel\n"..iconRMB)
		WQGroupie.Button.tooltip = tooltipCreated
		WQGroupie.Button:SetScript("OnClick", cancelClick)

		Print("Created grouplisting for quest \"%s\".", questTable[questID])
		WQGroupie.Button.bg:SetTexture(iconCreateGroup)

		private.created = true
	else
		Print("Creating grouplisting failed.")
		WQGroupie.Button.bg:SetTexture(iconError)
	end

	Debug("CreateListing")
end

function private.RemoveListing() -- C_LFGList.RemoveListing()
	C_LFGList.RemoveListing()
	private.created = false

	Debug("RemoveListing")
end

function private.Search(questID) -- C_LFGList.Search(categoryID, questName, filters, baseFilters, languages)
	local languages = C_LFGList.GetLanguageSearchFilter();
	local _, categoryID, filters, questName = LFGListUtil_GetQuestCategoryData(questID);

	C_LFGList.Search(categoryID, questName, filters, panel.baseFilters, languages);
	Debug("Search")
end

function private.processQuest(questID)
	if blacklistedQuests[questID] or questID == private.questID then return end -- Solo/Raid WQs or we are already doing this

	local activityID, _, _, questName = LFGListUtil_GetQuestCategoryData(questID);

	local _, worldQuestType
	if QuestUtils_IsQuestWorldQuest(questID) then
		_, _, worldQuestType = GetQuestTagInfo(questID)
	end

	if not activityID or worldQuestType == LE_QUEST_TAG_TYPE_PET_BATTLE or
	worldQuestType == LE_QUEST_TAG_TYPE_DUNGEON or worldQuestType == LE_QUEST_TAG_TYPE_PROFESSION then
		return;
	end

	private.questID = questID
	private.activityID = activityID
	questTable[questID] = questName

	_setSearch(false)

	Debug("processQuest", questID)
end

hooksecurefunc("ObjectiveTracker_Update", function(reason, questID)
	--if reason ~= OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED or GetCurrentMapAreaID() == 978 then -- not in Ashran
	if reason ~= OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED or (WorldMapFrame and WorldMapFrame:GetMapID() == 978) then -- not in Ashran
		return
	end

	private.processQuest(questID)
end)
