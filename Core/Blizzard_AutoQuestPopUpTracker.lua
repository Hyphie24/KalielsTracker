local questItems = {};

local function AutoQuestPopupTracker_Initialize(owningModule)
	owningModule:AddBlockOffset("KT_AutoQuestPopUpBlockTemplate", -25, -4);  -- MSA
	owningModule.initializedPopUpTracker = true;
end

function KT_AutoQuestPopupTracker_OnFinishSlide(block)
	local blockContents = block.ScrollChild;
	blockContents.Shine:Show();
	blockContents.IconShine:Show();
	blockContents.Shine.Flash:Play();
	blockContents.IconShine.Flash:Play();
	-- this may have scrolled something partially offscreen
	KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_STATIC);
end

local SLIDE_DATA = { startHeight = 0, endHeight = 68, duration = 0.4, onFinishFunc = KT_AutoQuestPopupTracker_OnFinishSlide };

function KT_AutoQuestPopupTracker_OnFreeBlock(block)
	block.init = nil;
	block.questID = nil;
end

local function AutoQuestPopupTracker_ShouldDisplayQuest(questID, owningModule)
	return not C_QuestLog.IsQuestBounty(questID) and owningModule:ShouldDisplayQuest(QuestCache:Get(questID));
end

local function AutoQuestPopupTracker_UpdateExclamationIcon(itemID, popUpType, blockContents)
	local texture = itemID and select(10, C_Item.GetItemInfo(itemID));
	if texture then
		blockContents.Exclamation:SetTexCoord(0.078125, 0.921875, 0.078125, 0.921875);
		blockContents.Exclamation:SetSize(35, 35);
		SetPortraitToTexture(blockContents.Exclamation, texture);
	else
		blockContents.Exclamation:SetTexture("Interface\\QuestFrame\\AutoQuest-Parts");
		blockContents.Exclamation:SetTexCoord(0.13476563, 0.17187500, 0.01562500, 0.53125000);
		blockContents.Exclamation:SetSize(19, 33);
	end
end

local function AutoQuestPopupTracker_UpdateQuestIcon(questID, popUpType, blockContents)
	local isCampaign = QuestUtil.ShouldQuestIconsUseCampaignAppearance(questID);
	blockContents.QuestIconBadgeBorder:SetShown(not isCampaign);

	local isComplete = popUpType == "COMPLETE";
	blockContents.QuestionMark:SetShown(not isCampaign and isComplete);
	blockContents.Exclamation:SetShown(not isCampaign and not isComplete);

	if not isComplete then
		AutoQuestPopupTracker_UpdateExclamationIcon(questItems[questID], popUpType, blockContents);
	end

	if isCampaign then
		blockContents.QuestIconBg:SetTexCoord(0, 1, 0, 1);
		blockContents.QuestIconBg:SetAtlas("AutoQuest-Badge-Campaign", TextureKitConstants.UseAtlasSize);
	else
		blockContents.QuestIconBg:SetSize(60, 60);
		blockContents.QuestIconBg:SetTexture("Interface/QuestFrame/AutoQuest-Parts");
		blockContents.QuestIconBg:SetTexCoord(0.30273438, 0.41992188, 0.01562500, 0.95312500);
	end
end

local function MakeBlockKey(questID, popupType)
	return questID .. popupType;
end

function KT_AutoQuestPopupTracker_Update(owningModule)
	if( SplashFrame:IsShown() ) then
		return;
	end

	if not owningModule.initializedPopUpTracker then
		AutoQuestPopupTracker_Initialize(owningModule);
	end

	for i = 1, GetNumAutoQuestPopUps() do
		local questID, popUpType = GetAutoQuestPopUp(i);
		if AutoQuestPopupTracker_ShouldDisplayQuest(questID, owningModule) then
			local questTitle = C_QuestLog.GetTitleForQuestID(questID);
			if ( questTitle and questTitle ~= "" ) then
				local block = owningModule:GetBlock(MakeBlockKey(questID, popUpType), "ScrollFrame", "KT_AutoQuestPopUpBlockTemplate");
				-- fixed height, just add the block right away
				block.height = 68;
				block.questID = questID;
				if ( KT_ObjectiveTracker_AddBlock(block) ) then
					if ( not block.init ) then
						local blockContents = block.ScrollChild;
						AutoQuestPopupTracker_UpdateQuestIcon(questID, popUpType, blockContents);

						if popUpType == "COMPLETE" then
							if ( C_QuestLog.IsQuestTask(questID) ) then
								blockContents.TopText:SetText(QUEST_WATCH_POPUP_CLICK_TO_COMPLETE_TASK);
							else
								blockContents.TopText:SetText(QUEST_WATCH_POPUP_CLICK_TO_COMPLETE);
							end

							blockContents.BottomText:Hide();
							blockContents.TopText:SetPoint("TOP", 0, -15);
							if (blockContents.QuestName:GetStringWidth() > blockContents.QuestName:GetWidth()) then
								blockContents.QuestName:SetPoint("TOP", 0, -25);
							else
								blockContents.QuestName:SetPoint("TOP", 0, -29);
							end

							block.popUpType = "COMPLETED";
						elseif popUpType == "OFFER" then
							local blockContents = block.ScrollChild;
							blockContents.TopText:SetText(QUEST_WATCH_POPUP_QUEST_DISCOVERED);
							blockContents.BottomText:Show();
							blockContents.BottomText:SetText(QUEST_WATCH_POPUP_CLICK_TO_VIEW);
							blockContents.TopText:SetPoint("TOP", 0, -9);
							blockContents.QuestName:SetPoint("TOP", 0, -20);
							blockContents.FlashFrame:Hide();
							block.popUpType = "OFFER";
						end
						blockContents.QuestName:SetText(questTitle);
						KT_ObjectiveTracker_SlideBlock(block, SLIDE_DATA);
						block.init = true;
					end
					block:Show();
				else
					block.used = nil;
					break;
				end
			end
		end
	end
end

function KT_AutoQuestPopupTracker_AddPopUp(questID, popUpType, itemID)
	if ( AddAutoQuestPopUp(questID, popUpType) ) then
		questItems[questID] = itemID;
		KT_ObjectiveTracker_Expand();
		KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_QUEST_ADDED, questID);
		PlaySound(SOUNDKIT.UI_AUTO_QUEST_COMPLETE);
		return true;
	end
	return false;
end

function KT_AutoQuestPopupTracker_RemovePopUp(questID)
	RemoveAutoQuestPopUp(questID);
	if GetNumAutoQuestPopUps() == 0 then
		wipe(questItems);
	end
	KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_QUEST);
end

function KT_AutoQuestPopUpTracker_OnMouseUp(block, button, upInside)
	if button == "LeftButton" and upInside then
		if ( block.popUpType == "OFFER" ) then
			ShowQuestOffer(block.questID);
		else
			ShowQuestComplete(block.questID);
		end
		KT_AutoQuestPopupTracker_RemovePopUp(block.questID);
	end
end