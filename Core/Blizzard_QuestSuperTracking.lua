local PENDING_QUEST_ID;
local SuperTrackEventFrame = nil;

local SuperTrackEventMixin = {};
function SuperTrackEventMixin:OnEvent(event, ...)
	if event == "QUEST_LOG_UPDATE" then
		self:CheckUpdateSuperTracked();
	elseif event == "SUPER_TRACKING_CHANGED" then
		self:CacheCurrentSuperTrackInfo();
	end
end

function SuperTrackEventMixin:CheckUpdateSuperTracked()
	local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID();
	if superTrackedQuestID and superTrackedQuestID == self.superTrackedQuestID then
		if C_QuestLog.ReadyForTurnIn(superTrackedQuestID) and not self.isComplete then
			KT_QuestSuperTracking_ChooseClosestQuest();
		end
	end
end

function SuperTrackEventMixin:CacheCurrentSuperTrackInfo()
	self.isComplete = nil;
	self.uiMapID = nil;
	self.worldQuests = nil;
	self.worldQuestsElite = nil;
	self.dungeons = nil;
	self.treasures = nil;

	local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID();
	self.superTrackedQuestID = superTrackedQuestID;
	self.superTrackedMapPinType, self.superTrackedMapPinTypeID = C_SuperTrack.GetSuperTrackedMapPin();
	self.superTrackedVignetteGUID = C_SuperTrack.GetSuperTrackedVignette();
	self.superTrackedContentType, self.superTrackedContentID = C_SuperTrack.GetSuperTrackedContent();

	if superTrackedQuestID then
		self.isComplete = C_QuestLog.ReadyForTurnIn(superTrackedQuestID);
		self.uiMapID, self.worldQuests, self.worldQuestsElite, self.dungeons, self.treasures = C_QuestLog.GetQuestAdditionalHighlights(superTrackedQuestID);
	end

	EventRegistry:TriggerEvent("Supertracking.OnChanged", self);
end

function SuperTrackEventMixin:GetSuperTrackedMapPin()
	return self.superTrackedMapPinType, self.superTrackedMapPinTypeID;
end

function SuperTrackEventMixin:GetSuperTrackedQuestID()
	return self.superTrackedQuestID;
end

function SuperTrackEventMixin:GetSuperTrackedVignette()
	return self.superTrackedVignetteGUID;
end

function SuperTrackEventMixin:GetSuperTrackedContent()
	return self.superTrackedContentType, self.superTrackedContentID;
end

function KT_QuestSuperTracking_ShouldHighlightWorldQuests(uiMapID)  -- 1
	return SuperTrackEventFrame.uiMapID == uiMapID and SuperTrackEventFrame.worldQuests;
end

function KT_QuestSuperTracking_ShouldHighlightWorldQuestsElite(uiMapID)  -- 1
	return SuperTrackEventFrame.uiMapID == uiMapID and SuperTrackEventFrame.worldQuestsElite;
end

function KT_QuestSuperTracking_ShouldHighlightDungeons(uiMapID)  -- 1
	return SuperTrackEventFrame.uiMapID == uiMapID and SuperTrackEventFrame.dungeons;
end

function KT_QuestSuperTracking_ShouldHighlightTreasures(uiMapID)  -- 1
	return SuperTrackEventFrame.uiMapID == uiMapID and SuperTrackEventFrame.treasures;
end

function KT_QuestSuperTracking_Initialize()
	assert(SuperTrackEventFrame == nil);
	SuperTrackEventFrame = Mixin(CreateFrame("FRAME"), SuperTrackEventMixin);
	SuperTrackEventFrame:SetScript("OnEvent", SuperTrackEventMixin.OnEvent);
	SuperTrackEventFrame:RegisterEvent("QUEST_LOG_UPDATE");
	SuperTrackEventFrame:RegisterEvent("SUPER_TRACKING_CHANGED");

	SuperTrackEventFrame:CacheCurrentSuperTrackInfo();
end

KT_QuestSuperTracking_Initialize(); -- TODO: Rewrite, use EventRegistry

function KT_QuestSuperTracking_OnQuestTracked(questID)
	-- We should supertrack quest if it got added to the top of the tracker
	-- First check if we have POI info. Could be missing if 1) we didn't know about this quest before, 2) just doesn't have POIs
	if QuestHasPOIInfo(questID) then
		-- now check if quest is at the top of the tracker
		if C_QuestLog.GetQuestIDForQuestWatchIndex(1) == questID then
			C_SuperTrack.SetSuperTrackedQuestID(questID);
		end
		PENDING_QUEST_ID = nil;
	else
		-- no POI info, could be arriving later
		PENDING_QUEST_ID = questID;
	end
end

function KT_QuestSuperTracking_OnQuestCompleted()  -- 1
	KT_QuestSuperTracking_ChooseClosestQuest();
end

function KT_QuestSuperTracking_OnQuestUntracked()
	KT_QuestSuperTracking_ChooseClosestQuest();
end

function KT_QuestSuperTracking_OnPOIUpdate()
	-- if we were waiting on data for an added quest, we should supertrack it if it has POI data and it's at the top of the tracker
	if PENDING_QUEST_ID and QuestHasPOIInfo(PENDING_QUEST_ID) then
		-- check top of tracker
		if C_QuestLog.GetQuestIDForQuestWatchIndex(1) == PENDING_QUEST_ID then
			C_SuperTrack.SetSuperTrackedQuestID(PENDING_QUEST_ID);
		end
	elseif not C_SuperTrack.GetSuperTrackedQuestID() then
		-- otherwise pick something if we're not supertrack anything
		KT_QuestSuperTracking_ChooseClosestQuest();
	end

	PENDING_QUEST_ID = nil;
end

function KT_QuestSuperTracking_ChooseClosestQuest()
	local closestQuestID;

	local minDistSqr = math.huge;
	for i = 1, C_QuestLog.GetNumWorldQuestWatches() do
		local watchedWorldQuestID = C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i);
		if watchedWorldQuestID then
			local distanceSq = C_QuestLog.GetDistanceSqToQuest(watchedWorldQuestID);
			if distanceSq and distanceSq <= minDistSqr then
				minDistSqr = distanceSq;
				closestQuestID = watchedWorldQuestID;
			end
		end
	end

	if not closestQuestID then
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i);
			if ( questID and QuestHasPOIInfo(questID) ) then
				local distSqr, onContinent = C_QuestLog.GetDistanceSqToQuest(questID);
				if onContinent and distSqr <= minDistSqr then
					minDistSqr = distSqr;
					closestQuestID = questID;
				end
			end
		end
	end

	-- If nothing with POI data is being tracked expand search to quest log
	if not closestQuestID then
		for questLogIndex = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(questLogIndex);
			if info and not info.isHeader and not info.isHidden and QuestHasPOIInfo(info.questID) then
				local distSqr, onContinent = C_QuestLog.GetDistanceSqToQuest(info.questID);
				if onContinent and distSqr <= minDistSqr then
					minDistSqr = distSqr;
					closestQuestID = questID;
				end
			end
		end
	end

	-- Supertrack if we have a valid quest
	if ( closestQuestID ) then
		C_SuperTrack.SetSuperTrackedQuestID(closestQuestID, true);  -- MSA
	else
		C_SuperTrack.SetSuperTrackedQuestID(0);
	end
end

function KT_QuestSuperTracking_IsSuperTrackedQuestValid()
	local trackedQuestID = C_SuperTrack.GetSuperTrackedQuestID();
	if not trackedQuestID then
		return false;
	end

	if not C_QuestLog.GetLogIndexForQuestID(trackedQuestID) then
		-- Might be a tracked world quest that isn't in our log yet
		if QuestUtils_IsQuestWorldQuest(trackedQuestID) and QuestUtils_IsQuestWatched(trackedQuestID) then
			return C_TaskQuest.IsActive(trackedQuestID);
		end
		return false;
	end

	return true;
end

function KT_QuestSuperTracking_CheckSelection()
	if C_SuperTrack.IsSuperTrackingQuest() or not C_SuperTrack.IsSuperTrackingAnything() then
		if not KT_QuestSuperTracking_IsSuperTrackedQuestValid() then
			KT_QuestSuperTracking_ChooseClosestQuest();
		end
	end
end