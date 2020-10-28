--[[ 
	Action Bar Saver, Shadowed
]]
ActionBarSaver = select(2, ...)

local ABS = ActionBarSaver
local L = ABS.L

local restoreErrors, macroCache, macroNameCache, mountCache = {}, {}, {}, {}
local playerClass

local MAX_MACROS = 54
local MAX_CHAR_MACROS = 18
local MAX_GLOBAL_MACROS = 36
local MAX_ACTION_BUTTONS = 144
local POSSESSION_START = 121
local POSSESSION_END = 132

local MAX_CHAR_MACROS = MAX_CHARACTER_MACROS
local MAX_GLOBAL_MACROS = MAX_ACCOUNT_MACROS
local MAX_MACROS = MAX_CHAR_MACROS + MAX_GLOBAL_MACROS

function ABS:OnInitialize()
	local defaults = {
		macro = false,
		softRestore = false,
		spellSubs = {},
		sets = {}
	}
	
	ActionBarSaverDB = ActionBarSaverDB or {}
		
	-- Load defaults in
	for key, value in pairs(defaults) do
		if( ActionBarSaverDB[key] == nil ) then
			ActionBarSaverDB[key] = value
		end
	end
	
	for classToken in pairs(RAID_CLASS_COLORS) do
		ActionBarSaverDB.sets[classToken] = ActionBarSaverDB.sets[classToken] or {}
	end
	
	self.db = ActionBarSaverDB
	
	playerClass = select(2, UnitClass("player"))
end

-- Text "compression" so it can be stored in our format fine
function ABS:CompressText(text)
	text = string.gsub(text, "\n", "/n")
	text = string.gsub(text, "/n$", "")
	text = string.gsub(text, "||", "/124")
	
	return string.trim(text)
end

function ABS:UncompressText(text)
	text = string.gsub(text, "/n", "\n")
	text = string.gsub(text, "/124", "|")
	
	return string.trim(text)
end

-- Restore a saved profile
function ABS:SaveProfile(name)
	self.db.sets[playerClass][name] = self.db.sets[playerClass][name] or {}
	local set = self.db.sets[playerClass][name]
	
	for actionID=1, MAX_ACTION_BUTTONS do
		set[actionID] = nil
		
		local type, id, subType = GetActionInfo(actionID)
		if( type and id and ( actionID < POSSESSION_START or actionID > POSSESSION_END ) ) then
			-- DB Format: <type>|<id>|<binding>|<name>|<extra ...>
			-- Save a companion
			if( type == "companion" ) then
				set[actionID] = string.format("%s|%s|%s|%s|%s|%s", type, id, "", "", subType, "")
			-- Save an equipment set or pet
			elseif( type == "equipmentset" or type == "summonpet" ) then
				set[actionID] = string.format("%s|%s|%s", type, id, "")
			-- Save a mount
			elseif( type == "summonmount" ) then
				local creatureName = C_MountJournal.GetMountInfoByID(id);
				set[actionID] = string.format("%s|%s|%s", type, creatureName, "")
			-- Save an item
			elseif( type == "item" ) then
				set[actionID] = string.format("%s|%d|%s|%s", type, id, "", (GetItemInfo(id)) or "")
			-- Save a spell
			elseif( type == "spell" and id > 0 ) then
				set[actionID] = string.format("%s|%d|%s", type, id, "")
			-- Save a macro
			elseif( type == "macro" ) then
				local name, icon, macro = GetMacroInfo(id)
				if( name and icon and macro ) then
					set[actionID] = string.format("%s|%d|%s|%s|%s|%s", type, actionID, "", self:CompressText(name), icon, self:CompressText(macro))
				end
			-- Flyout mnenu
		    elseif( type == "flyout" ) then
		        set[actionID] = string.format("%s|%d|%s|%s|%s", type, id, "", (GetFlyoutInfo(id)), "")
			end
		end
	end
	
	self:Print(string.format(L["Saved profile %s!"], name))
end

-- Finds the macroID in case it's changed
function ABS:FindMacro(id, name, data)
	if( macroCache[id] == data ) then
		return id
	end
	
	-- No such luck, check name
	if( macroNameCache[name] ) then
		if( macroCache[macroNameCache[name]] == data ) then
			return id
		end
	end

	-- Still no luck, let us try data
	for id, currentMacro in pairs(macroCache) do
		if( currentMacro == data ) then
			return id
		end
	end
	
	return nil
end

-- Restore any macros that don't exist
function ABS:RestoreMacros(set)
	local perCharacter = true
	for id, data in pairs(set) do
		local type, id, binding, macroName, macroIcon, macroData = string.split("|", data)
		if( type == "macro" ) then
			-- Do we already have a macro?
			local macroID = self:FindMacro(id, macroName, macroData)
			if( not macroID ) then
				local globalNum, charNum = GetNumMacros()
				-- Make sure we aren't at the limit
				if( globalNum == MAX_GLOBAL_MACROS and charNum == MAX_CHAR_MACROS ) then
					table.insert(restoreErrors, L["Unable to restore macros, you already have 36 global and 18 per character ones created."])
					break

				-- We ran out of space for per character, so use global
				elseif( charNum == MAX_CHAR_MACROS ) then
					perCharacter = false
				end
				
				macroName = self:UncompressText(macroName)

				-- GetMacroInfo still returns the full path while CreateMacro needs the relative
				-- can also return INTERFACE\ICONS\ aswell, apparently.
				macroIcon = macroIcon and string.gsub(macroIcon, "[iI][nN][tT][eE][rR][fF][aA][cC][eE]\\[iI][cC][oO][nN][sS]\\", "")
				
				-- No macro name means a space has to be used or else it won't be created and saved
				CreateMacro(macroName == "" and " " or macroName, macroIcon or "INV_Misc_QuestionMark", self:UncompressText(macroData), perCharacter)
			end
		end
	end
	
	-- Recache macros due to any additions
	local blacklist = {}
	for i=1, MAX_MACROS do
		local name, icon, macro = GetMacroInfo(i)
		
		if( name ) then
			-- If there are macros with the same name, then blacklist and don't look by name
			if( macroNameCache[name] ) then
				blacklist[name] = true
				macroNameCache[name] = nil
			elseif( not blacklist[name] ) then
				macroNameCache[name] = i
			end
		end
		macroCache[i] = macro and self:CompressText(macro) or nil
	end
end

-- Restore a saved profile
function ABS:RestoreProfile(name, overrideClass)
	local set = self.db.sets[overrideClass or playerClass][name]
	if( not set ) then
		self:Print(string.format(L["No profile with the name \"%s\" exists."], set))
		return
	elseif( InCombatLockdown() ) then
		self:Print(String.format(L["Unable to restore profile \"%s\", you are in combat."], set))
		return
	end
	
	table.wipe(mountCache)
	table.wipe(macroCache)
	table.wipe(macroNameCache)

	-- Cache mounts
	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		local creatureName = C_MountJournal.GetDisplayedMountInfo(i);
		mountCache[creatureName] = i
 	end		
	
	-- Cache macros
	local blacklist = {}
	for i=1, MAX_MACROS do
		local name, icon, macro = GetMacroInfo(i)
		
		if( name ) then
			-- If there are macros with the same name, then blacklist and don't look by name
			if( macroNameCache[name] ) then
				blacklist[name] = true
				macroNameCache[name] = nil
			elseif( not blacklist[name] ) then
				macroNameCache[name] = i
			end
		end
		macroCache[i] = macro and self:CompressText(macro) or nil
	end
	
	-- Check if we need to restore any missing macros
	if( self.db.macro ) then
		self:RestoreMacros(set)
	end
	
	-- Start fresh with nothing on the cursor
	ClearCursor()
	
	-- Save current sound setting
	local soundToggle = GetCVar("Sound_EnableAllSound")
	-- Turn sound off
	SetCVar("Sound_EnableAllSound", 0)

	for i=1, MAX_ACTION_BUTTONS do
		if( i < POSSESSION_START or i > POSSESSION_END ) then
			local type, id = GetActionInfo(i)
		
			-- Clear the current spot
			if( (id or type) and not self.db.softRestore ) then
				PickupAction(i)
				ClearCursor()
			end
		
			-- Restore this spot
			if( set[i] ) then
				self:RestoreAction(i, string.split("|", set[i]))
			end
		end
	end
	
	-- Restore old sound setting
	SetCVar("Sound_EnableAllSound", soundToggle)
	
	-- Done!
	if( #(restoreErrors) == 0 ) then
		self:Print(string.format(L["Restored profile %s!"], name))
	else
		self:Print(string.format(L["Restored profile %s, failed to restore %d buttons type /abs errors for more information."], name, #(restoreErrors)))
	end
end

function ABS:RestoreAction(i, type, actionID, binding, ...)

	-- Restore a spell, flyout or companion
	if( type == "spell" or type == "companion" ) then
		PickupSpell(actionID)
		if( GetCursorInfo() ~= type ) then
			local linkedSet = self:IsSpellLinked(actionID)
			if (linkedSet) then
				for index,value in ipairs(self.db.spellSubs[linkedSet]) do 
					if(IsSpellKnown(value)) then
						PickupSpell(value)
						break
					end
				end
			end
		end
		if( GetCursorInfo() ~= type ) then
			spellName = GetSpellInfo(actionID)
			table.insert(restoreErrors, string.format(L["Unable to restore spell \"%s\" to slot #%d, it does not appear to have been learned yet."], spellName, i))
			ClearCursor()
			return
		end		
		PlaceAction(i)
		
	-- Restore flyout
	elseif( type == "flyout" ) then
		PickupSpell(actionID)
		if( GetCursorInfo() ~= type ) then
			table.insert(restoreErrors, string.format(L["Unable to restore flyout spell \"%s\" to slot #%d, it does not appear to exist anymore."], actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)
		
	-- Restore mount
	elseif( type == "summonmount" ) then
		if (mountCache[actionID]) then
			C_MountJournal.Pickup(mountCache[actionID])
			if( GetCursorInfo() ~= "mount" ) then
				table.insert(restoreErrors, string.format(L["Unable to restore mount \"%s\" to slot #%d, it does not appear to exist anymore."], actionID, i))
				ClearCursor()
				return
			end
			PlaceAction(i)
		end
		
	-- Restore pet
	elseif( type == "summonpet" ) then
		C_PetJournal.PickupPet(actionID)
		if( GetCursorInfo() ~= "battlepet" ) then
			table.insert(restoreErrors, string.format(L["Unable to restore pet \"%s\" to slot #%d, it does not appear to exist anymore."], actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)
        
	-- Restore an equipment set button
	elseif( type == "equipmentset" ) then
		local slotID = -1
		for i=1, C_EquipmentSet.GetNumEquipmentSets() do
			if( C_EquipmentSet.GetEquipmentSetInfo(i) == actionID ) then
				slotID = i
				break
			end
		end
		C_EquipmentSet.PickupEquipmentSet(slotID)
		if( GetCursorInfo() ~= "equipmentset" ) then
			table.insert(restoreErrors, string.format(L["Unable to restore equipment set \"%s\" to slot #%d, it does not appear to exist anymore."], actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)
			
	-- Restore an item
	elseif( type == "item" ) then
		PickupItem(actionID)
		if( GetCursorInfo() ~= type ) then
			local itemName = select(i, ...)
			table.insert(restoreErrors, string.format(L["Unable to restore item \"%s\" to slot #%d, cannot be found in inventory."], itemName and itemName ~= "" and itemName or actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)

	-- Restore a macro
	elseif( type == "macro" ) then
		local name, _, content = ...
		PickupMacro(self:FindMacro(actionID, name, content or -1))
		if( GetCursorInfo() ~= type ) then
			table.insert(restoreErrors, string.format(L["Unable to restore macro id #%d to slot #%d, it appears to have been deleted."], actionID, i))
			ClearCursor()
			return
		end	
		PlaceAction(i)
	end
end

function ABS:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ABS|r: " .. msg)
end

function ABS:IsSpellLinked(spellID)
	spellID = tonumber(spellID)
	if (#(self.db.spellSubs) > 0) then
		for index,value in ipairs(self.db.spellSubs) do 
			if(tContains(value, spellID)) then
				return index
			end
		end
	end
	return false
end

SLASH_ACTIONBARSAVER1 = nil
SlashCmdList["ACTIONBARSAVER"] = nil

SLASH_ABS1 = "/abs"
SLASH_ABS2 = "/actionbarsaver"
SlashCmdList["ABS"] = function(msg)
	msg = msg or ""
	
	local cmd, arg = string.split(" ", msg, 2)
	cmd = string.lower(cmd or "")
	arg = string.lower(arg or "")
	
	local self = ABS
	
	-- Profile saving
	if( cmd == "save" and arg ~= "" ) then
		self:SaveProfile(arg)
	
	-- Spell sub
	elseif( cmd == "linknew" and arg ~= "" ) then
		local first = string.match(arg, "\"(.+)\"")
		
		if( not first ) then
			self:Print(L["Invalid parameters passed, remember that you must put quotes around the spell name."])
			return
		end
		spellID = select(7, GetSpellInfo(first))
		if( not spellID ) then
			self:Print(L["Invalid spell passed, remember that the spell's name must match exactly and you must know the spell."])
			return
		end
		local linkedSet = self:IsSpellLinked(spellID)
		if (linkedSet) then
			self:Print(string.format(L["The spell \"%s\" already exists in linked set #%d."], first, linkedSet))
			return
		end
		tinsert(self.db.spellSubs, {spellID})
		self:Print(string.format(L["The spell \"%s\" has been added to a new linked set."], first))
	
	-- Spell sub
	elseif( cmd == "linkadd" and arg ~= "" ) then
		local first, second = string.match(arg, "(%d+) \"(.+)\"")
		
		if( not first or not second ) then
			self:Print(L["Invalid parameters passed, remember to use a number for the linked set and to put quotes around the spell name."])
			return
		end
		first = tonumber(first)
		if( not self.db.spellSubs[first] ) then
			self:Print(string.format(L["The linked set #%d does not exist."], first))
			return
		end
		spellID = select(7, GetSpellInfo(second))
		if( not spellID ) then
			self:Print(L["Invalid spell passed, remember that the spell's name must match exactly and you must know the spell."])
			return
		end
		local linkedSet = self:IsSpellLinked(spellID)
		if (linkedSet) then
			self:Print(string.format(L["The spell \"%s\" already exists in linked set #%d."], second, linkedSet))
			return
		end
		tinsert(self.db.spellSubs[first], spellID)
		self:Print(string.format(L["The spell \"%s\" has been added to the linked set #%d."], second, first))
	
	-- Spell sub
	elseif( cmd == "linklist" ) then
		if( #(self.db.spellSubs) == 0 ) then
			self:Print(L["No linked sets currently exist."])
			return
		end
		for index,value in ipairs(self.db.spellSubs) do 
			local spells = {}
			for index2,value2 in ipairs(value) do 
				spellName = GetSpellInfo(value2)
				tinsert(spells, "#" .. index2 .. " " .. spellName)
			end
			local spellList = table.concat(spells, ", ")
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["Linked set #%d contains: %s"], index, spellList))
		end
	
	-- Spell sub
	elseif( cmd == "linkdelete" and arg ~= "" ) then
		local first, second = string.match(arg, "(%d+) ?(%d*)")
		
		if( not first ) then
			self:Print(L["Please specify the set or the set and the spell which you wish to delete."])
			return
		elseif( first and #(second) == 0 ) then
			first = tonumber(first)
			if (not self.db.spellSubs[first]) then
				self:Print(L["The specified linked set does not exist."])
				return
			end
			tremove(self.db.spellSubs, first)
			self:Print(string.format(L["Linked set #%d has been deleted."], first))
		elseif( first and second ) then
			first = tonumber(first)
			second = tonumber(second)
			if (not self.db.spellSubs[first] or not self.db.spellSubs[first][second]) then
				self:Print(L["The specified linked set or spell does not exist."])
				return
			end
			tremove(self.db.spellSubs[first], second)
			if(#(self.db.spellSubs[first]) == 0) then
				tremove(self.db.spellSubs, first)
			end
			self:Print(string.format(L["Spell #%d from linked set #%d has been deleted."], second, first))
		end
		
	-- Profile restoring
	elseif( cmd == "restore" and arg ~= "" ) then
		for i=#(restoreErrors), 1, -1 do table.remove(restoreErrors, i) end
				
		if( not self.db.sets[playerClass][arg] ) then
			self:Print(string.format(L["Cannot restore profile \"%s\", you can only restore profiles saved to your class."], arg))
			return
		end
		self.db.softRestore = false
		self:RestoreProfile(arg, playerClass)
		
	-- Profile restoring
	elseif( cmd == "softrestore" and arg ~= "" ) then
		for i=#(restoreErrors), 1, -1 do table.remove(restoreErrors, i) end
				
		if( not self.db.sets[playerClass][arg] ) then
			self:Print(string.format(L["Cannot restore profile \"%s\", you can only restore profiles saved to your class."], arg))
			return
		end
		self.db.softRestore = true
		self:RestoreProfile(arg, playerClass)
		
	-- Profile renaming
	elseif( cmd == "rename" and arg ~= "" ) then
		local old, new = string.split(" ", arg, 2)
		new = string.trim(new or "")
		old = string.trim(old or "")
		
		if( new == old ) then
			self:Print(string.format(L["You cannot rename \"%s\" to \"%s\" they are the same profile names."], old, new))
			return
		elseif( new == "" ) then
			self:Print(string.format(L["No name specified to rename \"%s\" to."], old))
			return
		elseif( self.db.sets[playerClass][new] ) then
			self:Print(string.format(L["Cannot rename \"%s\" to \"%s\" a profile already exists for %s."], old, new, (UnitClass("player"))))
			return
		elseif( not self.db.sets[playerClass][old] ) then
			self:Print(string.format(L["No profile with the name \"%s\" exists."], old))
			return
		end
		
		self.db.sets[playerClass][new] = CopyTable(self.db.sets[playerClass][old])
		self.db.sets[playerClass][old] = nil
		
		self:Print(string.format(L["Renamed \"%s\" to \"%s\""], old, new))
		
	-- Restore errors
	elseif( cmd == "errors" ) then
		if( #(restoreErrors) == 0 ) then
			self:Print(L["No errors found!"])
			return
		end

		self:Print(string.format(L["Errors found: %d"], #(restoreErrors)))
		for _, text in pairs(restoreErrors) do
			DEFAULT_CHAT_FRAME:AddMessage(text)
		end

	-- Delete profile
	elseif( cmd == "delete" ) then
		self.db.sets[playerClass][arg] = nil
		self:Print(string.format(L["Deleted saved profile %s."], arg))
	
	-- List profiles
	elseif( cmd == "list" ) then
		local classes = {}
		local setList = {}
		
		for class, sets in pairs(self.db.sets) do
			table.insert(classes, class)
		end
		
		table.sort(classes, function(a, b)
			return a < b
		end)
		
		for _, class in pairs(classes) do
			for i=#(setList), 1, -1 do table.remove(setList, i) end
			for setName in pairs(self.db.sets[class]) do
				table.insert(setList, setName)
			end
			
			if( #(setList) > 0 ) then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99%s|r: %s", L[class] or "???", table.concat(setList, ", ")))
			end
		end
		
	-- Macro restoring
	elseif( cmd == "macro" ) then
		self.db.macro = not self.db.macro

		if( self.db.macro ) then
			self:Print(L["Auto macro restoration is now enabled!"])
		else
			self:Print(L["Auto macro restoration is now disabled!"])
		end
		
	-- Halp
	else
		self:Print(L["Slash commands"])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99==" .. L["SAVED PROFILES"] .. "==|r")
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs save <" .. L["profile"] .. ">|r - " .. L["Saves your current action bar setup under the given profile."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs restore <" .. L["profile"] .. ">|r - " .. L["Changes your action bars to the passed profile."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs softrestore <" .. L["profile"] .. ">|r - " .. L["Changes your action bars to the passed profile. Soft restore will only add saved buttons, not empty buttons that have no value saved to them."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs delete <" .. L["profile"] .. ">|r - " .. L["Deletes the saved profile."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs rename <" .. L["oldProfile"] .. "> <" .. L["newProfile"] .. ">|r - " .. L["Renames a saved profile from oldProfile to newProfile."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs macro|r - " .. L["Attempts to restore macros that have been deleted for a profile."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs list|r - " .. L["Lists all saved profiles."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99==" .. L["LINKED SETS"] .. "==|r")
		DEFAULT_CHAT_FRAME:AddMessage(L["Linked sets allow you to add several abilities to an array of linked abilities, and if one of those abilities is listed in a profile but not available to your character, it will try to find another one from that array."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs linknew \"<" .. L["spell"] .. ">\"|r - " .. L["Creates a new linked set with the specified spell, INCLUDE QUOTES, e.g \"War Stomp\"."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs linkadd <" .. L["linked set"] .. "> \"<" .. L["spell"] .. ">\"|r - " .. L["Adds spell to a linked set, by specifiying the linked set with an integer and the spell within quotes; e.g to add War Stomp to set 1, write /linkadd 1 \"War Stomp\"."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs linklist|r - " .. L["Lists all linked spells."])
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99/abs linkdelete|r - " .. L["Deletes either a linked set, or an item from a linked set. To delete the first set write /linkdelete 1, to delete the first item from the first set, write /linkdelete 1 1."])
	end
end

-- Check if we need to load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( addon == "ActionBarSaver" ) then
		ABS:OnInitialize()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
