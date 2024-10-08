local _, KT = ...

KT_PROFESSION_RECIPE_TRACKER_MODULE = KT_ObjectiveTracker_GetModuleInfoTable("KT_PROFESSION_RECIPE_TRACKER_MODULE");
KT_PROFESSION_RECIPE_TRACKER_MODULE.updateReasonModule = KT_OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE;
KT_PROFESSION_RECIPE_TRACKER_MODULE:SetHeader(KT_ObjectiveTrackerFrame.BlocksFrame.ProfessionHeader, PROFESSIONS_TRACKER_HEADER_PROFESSION);

local IsRecrafting = true;

-- *****************************************************************************************************
-- ***** BLOCK DROPDOWN FUNCTIONS
-- *****************************************************************************************************

function KT.GetRecipeID(block)  -- MSA
	return math.abs(block.id);
end

function KT.IsRecraftBlock(block)  -- MSA
	return block.id < 0;
end

local function RecipeObjectiveTracker_OnOpenDropDown(self)
	--[[local block = self.activeFrame;

	info = UIDropDownMenu_CreateInfo();
	info.notCheckable = 1;

	if not KT.IsRecraftBlock(block) and IsSpellKnown(KT.GetRecipeID(block)) then
		info.text = PROFESSIONS_TRACKING_VIEW_RECIPE;
		info.func = function()
			C_TradeSkillUI.OpenRecipe(recipeID);
		end;
		info.arg1 = block.id;
		info.checked = false;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	end

	info.text = PROFESSIONS_UNTRACK_RECIPE;
	info.func = function()
		local track = false;
		C_TradeSkillUI.SetRecipeTracked(KT.GetRecipeID(block), track, KT.IsRecraftBlock(block));
	end;
	info.arg1 = block.id;
	info.checked = false;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);]]
end

function KT_PROFESSION_RECIPE_TRACKER_MODULE:OnBlockHeaderClick(block, mouseButton)
	if ( IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() ) then
		local link = C_TradeSkillUI.GetRecipeLink(KT.GetRecipeID(block));
		if ( link ) then
			ChatEdit_InsertLink(link);
		end
	elseif ( mouseButton ~= "RightButton" ) then
		--CloseDropDownMenus();
		if ( not ProfessionsFrame ) then
			ProfessionsFrame_LoadUI();
		end
		if ( IsModifiedClick("RECIPEWATCHTOGGLE") ) then
			local track = false;
			C_TradeSkillUI.SetRecipeTracked(KT.GetRecipeID(block), track, KT.IsRecraftBlock(block));
		else
			if not KT.IsRecraftBlock(block) then
				local recipeID = KT.GetRecipeID(block);
				if C_TradeSkillUI.IsRecipeProfessionLearned(recipeID) then
					C_TradeSkillUI.OpenRecipe(recipeID);
				else
					Professions.InspectRecipe(recipeID);
				end
			end
		end
	else
		KT_ObjectiveTracker_ToggleDropDown(block, RecipeObjectiveTracker_OnOpenDropDown);
	end
end

-- *****************************************************************************************************
-- ***** UPDATE FUNCTIONS
-- *****************************************************************************************************
local LINE_TYPE_ANIM = { template = "KT_QuestObjectiveAnimLineTemplate", freeLines = { } };

function KT_PROFESSION_RECIPE_TRACKER_MODULE:Update()
	self:BeginLayout();

	if self.continuableContainer then
		self.continuableContainer:Cancel();
	end

	self.continuableContainer = ContinuableContainer:Create();
	local function LoadItems(recipes)
		for _, recipeID in ipairs(recipes) do
			local reagents = ProfessionsUtil.CreateRecipeReagentsForAllBasicReagents(recipeID);
			for reagentIndex, reagent in ipairs(reagents) do
				if reagent.itemID then
					self.continuableContainer:AddContinuable(Item:CreateFromItemID(reagent.itemID));
				end
			end
		end
	end

	-- Load regular and recraft recipe items.
	LoadItems(C_TradeSkillUI.GetRecipesTracked(IsRecrafting));
	LoadItems(C_TradeSkillUI.GetRecipesTracked(not IsRecrafting));

	local function Layout()
		local colorStyle = KT_OBJECTIVE_TRACKER_COLOR["Normal"];

		local function AddObjectives(isRecraft)
			for _, recipeID in ipairs(C_TradeSkillUI.GetRecipesTracked(isRecraft)) do
				local recipeSchematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft);
				local blockID = NegateIf(recipeID, isRecraft);
				local block = self:GetBlock(blockID);
				local blockName = isRecraft and PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(recipeSchematic.name) or recipeSchematic.name;
				self:SetBlockHeader(block, blockName);

				local eligibleSlots = {};
				for slotIndex, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics) do
					if ProfessionsUtil.IsReagentSlotRequired(reagentSlotSchematic) then
						if ProfessionsUtil.IsReagentSlotModifyingRequired(reagentSlotSchematic) then
							table.insert(eligibleSlots, 1, {slotIndex = slotIndex, reagentSlotSchematic = reagentSlotSchematic});
						else
							table.insert(eligibleSlots, {slotIndex = slotIndex, reagentSlotSchematic = reagentSlotSchematic});
						end
					end
				end

				for idx, tbl in ipairs(eligibleSlots) do
					local slotIndex = tbl.slotIndex;
					local reagentSlotSchematic = tbl.reagentSlotSchematic;
					if ProfessionsUtil.IsReagentSlotRequired(reagentSlotSchematic) then
						local reagent = reagentSlotSchematic.reagents[1];
						local quantityRequired = reagentSlotSchematic.quantityRequired;
						local quantity = ProfessionsUtil.AccumulateReagentsInPossession(reagentSlotSchematic.reagents);
						local name = nil;

						if ProfessionsUtil.IsReagentSlotBasicRequired(reagentSlotSchematic) then
							if reagent.itemID then
								local item = Item:CreateFromItemID(reagent.itemID);
								name = item:GetItemName();
							elseif reagent.currencyID then
								local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID);
								if currencyInfo then
									name = currencyInfo.name;
								end
							end
						elseif ProfessionsUtil.IsReagentSlotModifyingRequired(reagentSlotSchematic) then
							if reagentSlotSchematic.slotInfo then
								name = reagentSlotSchematic.slotInfo.slotText;
							end
						end

						if name then
							local text = PROFESSIONS_TRACKER_REAGENT_FORMAT:format(PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityRequired), name)
							local metQuantity = quantity >= quantityRequired;
							local dashStyle = metQuantity and KT_OBJECTIVE_DASH_STYLE_HIDE or KT_OBJECTIVE_DASH_STYLE_SHOW;
							local colorStyle = KT_OBJECTIVE_TRACKER_COLOR[metQuantity and "Complete" or "Normal"];
							line = self:AddObjective(block, slotIndex, text, LINE_TYPE_ANIM, nil, dashStyle, colorStyle);
							line.Check:SetShown(metQuantity);
						end
					end
				end

				block:SetHeight(block.height);

				if ( KT_ObjectiveTracker_AddBlock(block) ) then
					block:Show();
					self:FreeUnusedLines(block);
				else
					block.used = false;
					break;
				end
			end
		end

		AddObjectives(IsRecrafting);
		AddObjectives(not IsRecrafting);
	end

	-- We can continue to layout each of the blocks if every item is loaded, otherwise
	-- we need to wait until the items load, then notify the objective tracker to try again.
	local allLoaded = true;
	local function OnItemsLoaded()
		if allLoaded then
			Layout();
		else
			KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE);
		end
	end
	-- The assignment of allLoaded is only meaningful if false. If and when the callback
	-- is invoked later, it will force an update. If the value was true, the callback would have
	-- already been invoked prior to returning.
	allLoaded = self.continuableContainer:ContinueOnLoad(OnItemsLoaded);

	self:EndLayout();
end

function KT_ProfessionsRecipeTracking_Initialize()
	local function OnCurrencyChanged(o, currencyID)
		KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE);
	end
	EventRegistry:RegisterFrameEvent("CURRENCY_DISPLAY_UPDATE");
	EventRegistry:RegisterCallback("CURRENCY_DISPLAY_UPDATE", OnCurrencyChanged, KT_PROFESSION_RECIPE_TRACKER_MODULE);

	local function OnTrackedRecipeUpdate(o, recipeID, tracked)
		KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE);
	end
	EventRegistry:RegisterFrameEvent("TRACKED_RECIPE_UPDATE");
	EventRegistry:RegisterCallback("TRACKED_RECIPE_UPDATE", OnTrackedRecipeUpdate, KT_PROFESSION_RECIPE_TRACKER_MODULE);

	local function OnBagUpdateDelayed(o)
		KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE);
	end
	EventRegistry:RegisterFrameEvent("BAG_UPDATE_DELAYED");
	EventRegistry:RegisterCallback("BAG_UPDATE_DELAYED", OnBagUpdateDelayed, KT_PROFESSION_RECIPE_TRACKER_MODULE);
end