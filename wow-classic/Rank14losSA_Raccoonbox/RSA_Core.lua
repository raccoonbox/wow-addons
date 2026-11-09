--[[
RSA_Core.lua - Core Functions, Config, Menu System
Part of Rank14losSA addon
]]

local RSA_VERSION = "1.0-Nampower"

-- detect current addon folder
RSA_PATH = "Interface\\AddOns\\Rank14losSA"
for _, name in pairs({ "Rank14losSA_Raccoonbox", "Rank14losSA" }) do
	local _, title = GetAddOnInfo(name)
	if title then
		RSA_PATH = "Interface\\AddOns\\" .. name
		break
	end
end

--[[===========================================================================
	Core Functions
=============================================================================]]

function RSA_SlashCmdHandler(msg)
	if msg and string.lower(msg) == "save" then
		if RSA_AlertFrameX and RSA_AlertFrameY then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Position saved: X=" .. math.floor(RSA_AlertFrameX) .. ", Y=" .. math.floor(RSA_AlertFrameY))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r No position to save")
		end
		return
	end
	local _, _, yards = string.find(string.lower(msg or ""), "^range%s*(%d*)")
	if yards then
		if yards ~= "" then RSAConfig.range = tonumber(yards) end
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert range: " .. RSA_GetMaxRange() .. " yards")
		return
	end
	RSAMenuFrame_Toggle()
end

function RSA_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("PLAYER_LOGOUT")
end

function RSA_OnEvent(event)
	if event == "PLAYER_LOGOUT" then return end
	
	if event == "PLAYER_ENTERING_WORLD" then
		this:UnregisterEvent("PLAYER_ENTERING_WORLD")
		
		local hasNamepower = (GetNampowerVersion ~= nil)

		if not hasNamepower then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000============================================|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA] CRITICAL ERROR: Nampower NOT DETECTED!|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00This addon REQUIRES Nampower to function.|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00https://gitea.com/avitasia/nampower|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000RSA addon has been DISABLED.|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000============================================|r")

			SLASH_RSA1 = "/rsa"
			SlashCmdList["RSA"] = function()
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r Nampower not detected!")
			end
			RSAMenuFrame:UnregisterAllEvents()
			if RSAConfig then RSAConfig.enabled = false end
			return
		end
		
		-- Initialize config
		if not RSAConfig or not RSAConfig.version or RSAConfig.version ~= RSA_VERSION then
			RSAConfig = {
				["enabled"] = true,
				["outside"] = true,
				["version"] = RSA_VERSION,
				["buffs"] = {
					["enabled"] = true,
					["AdrenalineRush"] = true, ["ArcanePower"] = true, ["Barkskin"] = true,
					["BattleStance"] = false, ["BerserkerRage"] = true, ["BerserkerStance"] = false,
					["BestialWrath"] = true, ["BladeFlurry"] = true, ["BlessingofFreedom"] = true,
					["BlessingofProtection"] = true, ["Cannibalize"] = true, ["ColdBlood"] = true,
					["Combustion"] = true, ["Dash"] = true, ["DeathWish"] = true,
					["DefensiveStance"] = false, ["Deterrence"] = true,
					["DivineFavor"] = true, ["DivineShield"] = true,
					["ElementalMastery"] = true, ["Evasion"] = true,
					["FearWard"] = true, ["FrenziedRegeneration"] = true,
					["IceBlock"] = true, ["InnerFocus"] = true, ["Innervate"] = true,
					["LastStand"] = true, ["Nature'sGrasp"] = true,
					["Nature'sSwiftness"] = true, ["PowerInfusion"] = true, ["PresenceofMind"] = true,
					["RapidFire"] = true, ["Recklessness"] = true, ["Reflector"] = true,
					["Retaliation"] = true, ["Sacrifice"] = true, ["ShieldWall"] = true,
					["Sprint"] = true, ["Stoneform"] = true, ["SweepingStrikes"] = true,
					["WilloftheForsaken"] = true, ["FreeAction"] = true,
				},
				["casts"] = {
					["enabled"] = true,
					["EntanglingRoots"] = true, ["EscapeArtist"] = true, ["Fear"] = true,
					["Hearthstone"] = true, ["Hibernate"] = true, ["HowlofTerror"] = true,
					["MindControl"] = true, ["Polymorph"] = true, ["RevivePet"] = true,
					["ScareBeast"] = true, ["WarStomp"] = true,
				},
				["debuffs"] = {
					["enabled"] = true,
					["Blind"] = true, ["ConcussionBlow"] = true, ["Counterspell-Silenced"] = true,
					["DeathCoil"] = true, ["Disarm"] = true, ["HammerofJustice"] = true,
					["IntimidatingShout"] = true, ["PsychicScream"] = true, ["Repetance"] = true,
					["ScatterShot"] = true, ["Seduction"] = true, ["Silence"] = true,
					["SpellLock"] = true, ["WyvernSting"] = true,
				},
				["fadingBuffs"] = {
					["enabled"] = true,
					["AdrenalineRush"] = true, ["ArcanePower"] = true, ["Barkskin"] = true,
					["BerserkerRage"] = true, ["BestialWrath"] = true, ["BladeFlurry"] = true,
					["BlessingofFreedom"] = true, ["BlessingofProtection"] = true, ["Combustion"] = true,
					["Dash"] = true, ["DeathWish"] = true, ["Deterrence"] = true,
					["DivineShield"] = true, ["Evasion"] = true, ["FrenziedRegeneration"] = true,
					["IceBlock"] = true, ["Innervate"] = true, ["LastStand"] = true,
					["Nature'sGrasp"] = true, ["RapidFire"] = true, ["Recklessness"] = true,
					["Retaliation"] = true, ["ShieldWall"] = true, ["Sprint"] = true,
					["Stoneform"] = true, ["WilloftheForsaken"] = true, ["FreeAction"] = true,
				},
				["use"] = {
					["enabled"] = true,
					["Kick"] = true, ["FlashBomb"] = true,
					["DesperatePrayer"] = true, ["EarthbindTotem"] = true,
					["Evocation"] = true, ["FreezingTrap"] = true,
					["GroundingTotem"] = true, ["Intimidation"] = true,
					["ManaTideTotem"] = true, ["Tranquility"] = true,
					["TremorTotem"] = true, ["Trinket"] = true,
					["EarthShock"] = true,
				},
			}
		end
		
		-- Migrate existing configs: add new buff entries
		if RSAConfig.buffs then
			local newBuffs = {
				"FreeAction",
			}
			for _, buff in ipairs(newBuffs) do
				if RSAConfig.buffs[buff] == nil then
					RSAConfig.buffs[buff] = true
				end
			end
		end
		
		-- Migrate existing configs: add new use entries
		if RSAConfig.use then
			local newUseAbilities = {
				"DesperatePrayer", "EarthbindTotem", "Evocation", "FreezingTrap",
				"GroundingTotem", "Intimidation", "ManaTideTotem", "Tranquility",
				"TremorTotem", "Trinket", "EarthShock",
			}
			for _, ability in ipairs(newUseAbilities) do
				if RSAConfig.use[ability] == nil then
					RSAConfig.use[ability] = true
				end
			end
		end

		-- Migrate existing configs: add new fadingBuffs entries
		if RSAConfig.fadingBuffs then
			local newFadingBuffs = {
				"AdrenalineRush", "ArcanePower", "BerserkerRage", "BestialWrath",
				"BladeFlurry", "BlessingofFreedom", "Combustion", "Dash", "DeathWish",
				"FrenziedRegeneration", "Innervate", "LastStand", "Nature'sGrasp",
				"RapidFire", "Recklessness", "Retaliation", "Sprint", "Stoneform",
				"WilloftheForsaken", "FreeAction",
			}
			for _, buff in ipairs(newFadingBuffs) do
				if RSAConfig.fadingBuffs[buff] == nil then
					RSAConfig.fadingBuffs[buff] = true
				end
			end
		end
		
		RSA_NP:Initialize()
		InitializeDistanceCheck()
		
		if RSAConfig.alertFrame == nil then
			if RSA_AlertFrameEnabled ~= nil then
				RSAConfig.alertFrame = RSA_AlertFrameEnabled and true or false
			else
				RSAConfig.alertFrame = true
			end
		end
		RSA_AlertFrameEnabled = RSAConfig.alertFrame and true or false
		if RSA_AlertFrameBgAlpha == nil then RSA_AlertFrameBgAlpha = 0.7 end
		if RSA_PortraitIconShape == nil then RSA_PortraitIconShape = "square" end

		RSA_CreateAlertFrame()
		
		if RSAConfig.enabled then
			if not RSAConfig.outside then
				this:RegisterEvent("ZONE_CHANGED_NEW_AREA")
				RSA_UpdateState()
			else
				RSA_Enable()
			end
		end
		
		SlashCmdList["RSA"] = RSA_SlashCmdHandler
		SLASH_RSA1 = "/rsa"
		
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		RSA_UpdateState()
	end
end

function RSA_UpdateState()
	local zone = GetRealZoneText()
	if zone == "Alterac Valley" or zone == "Arathi Basin" or zone == "Warsong Gulch" then
		RSA_Enable()
	else
		RSA_Disable()
	end
end

function RSA_Disable()
	RSA_NP:Disable()
end

function RSA_Enable()
	RSA_NP:Enable()
end

function RSA_PlaySoundFile(spell, playerName, casterGUID, castDuration, spellID, itemID)
	RSA_ShowAlert(spell, playerName, casterGUID, castDuration, spellID, itemID)
	RSA_UpdatePortraitIcon(spell, playerName, casterGUID, spellID, itemID)
	
	-- DEBUG OUTPUT
	if RSA_NP and RSA_NP.debugMode then
		local isFade = string.sub(spell, -4) == "down"
		local displayName = isFade and string.sub(spell, 1, -5) or spell
		local eventType = "BUFF"
		
		if castDuration and tonumber(castDuration) and tonumber(castDuration) > 0 then
			eventType = "CAST"
		elseif isFade then
			eventType = "FADE"
		elseif spellID and RSA_USE_SPELL_IDS[spellID] then
			eventType = "USE"
		end
		
	-- Get spell name with rank from SpellInfo/Nampower
	local spellNameWithRank = displayName
	if spellID then
		local name = SpellInfo and SpellInfo(spellID)
		if not name and GetSpellRecField then
			name = GetSpellRecField(spellID, "spellName")
		end
		if name then spellNameWithRank = name end
	end
		
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff========== R14 Debug ==========|r")
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ffEvent Type:|r " .. eventType)
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ffCaster:|r " .. (playerName or "Unknown"))
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ffSpell:|r " .. spellNameWithRank)
		
		-- Spell ID nur anzeigen wenn nicht Fade
		if not isFade then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ffSpell ID:|r " .. tostring(spellID or "N/A"))
		end
		
		if castDuration and tonumber(castDuration) and tonumber(castDuration) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff00ffCast Time:|r %.2fs", tonumber(castDuration) / 1000))
		elseif not isFade then
			-- Zeige Duration für Buffs
			local duration = nil
			if spellID and RSA_SPELLID_DURATIONS[spellID] then
				duration = RSA_SPELLID_DURATIONS[spellID]
			elseif RSA_BUFF_DURATIONS[displayName] then
				duration = RSA_BUFF_DURATIONS[displayName]
			end
			if duration then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff00ffDuration:|r %ds", duration))
			end
		end
		
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ffSound:|r " .. spell .. ".mp3")
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff================================|r")
	end
	
	local mp3Path = RSA_PATH .. "\\Voice\\"..spell..".mp3"
	PlaySoundFile(mp3Path, "Master")
end

function RSA_Subtable(index)
	if index < RSA_BUFF then return "buffs"
	elseif index < RSA_CAST then return "casts"
	elseif index < RSA_DEBUFF then return "debuffs"
	elseif index < RSA_FADING then return "fadingBuffs"
	else return "use"
	end
end

function RSA_SoundText(index)
	if RSA_SOUND_OPTION_WHITE[index] then
		return "enabled"
	else
		local text = RSA_SOUND_OPTION_TEXT[index]
		if not text then return nil end
		return string.gsub(text, " ", "")
	end
end

function RSA_EnableCheckBox(button)
	if OptionsFrame_EnableCheckBox then
		OptionsFrame_EnableCheckBox(button)
		return
	end
	button:Enable()
	local fontString = _G[button:GetName().."Text"]
	if fontString then fontString:SetTextColor(1, 1, 1) end
end

function RSA_DisableCheckBox(button)
	if OptionsFrame_DisableCheckBox then
		OptionsFrame_DisableCheckBox(button)
		return
	end
	button:Disable()
	local fontString = _G[button:GetName().."Text"]
	if fontString then fontString:SetTextColor(0.5, 0.5, 0.5) end
end

--[[===========================================================================
	Menu System
=============================================================================]]

function RSACheckButton_OnClick()
	if this.variable then
		if this:GetChecked() then
			RSAConfig[this.variable] = true
		else
			RSAConfig[this.variable] = false
		end
		if this.index == 1 then
			RSAMenuFrame_UpdateDependencies()
			if RSAConfig.outside and this:GetChecked() then
				RSA_Enable()
			else
				RSA_Disable()
			end
		elseif this.index == 2 then
			if this:GetChecked() then
				RSAMenuFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
				RSA_Enable()
			else
				RSAMenuFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
				RSA_UpdateState()
			end
		elseif this.index == 3 then
			RSAConfig.alertFrame = this:GetChecked() and true or false
			RSA_AlertFrameEnabled = RSAConfig.alertFrame
		elseif this.index == 4 then
			RSA_ToggleMoveMode()
			this:SetChecked(RSA_MoveMode)
		elseif this.index == 5 then
			RSA_PortraitIconShape = this:GetChecked() and "circle" or "square"
			RSA_SetPlayerIconShape(RSA_PlayerIcon)
		end
	else
		local subtable = RSA_Subtable(this.index)
		local soundText = RSA_SoundText(this.index)
		if RSAConfig[subtable] and soundText then
			RSAConfig[subtable][soundText] = this:GetChecked()
		end
		if RSA_SOUND_OPTION_WHITE[this.index] then
			RSASoundOptionFrame_Update()
		end
	end
end

function RSAMenuFrame_Toggle()
	if RSAMenuFrame:IsVisible() then
		RSAMenuFrame:Hide()
	else
		RSAMenuFrame:Show()
	end
end

function RSAMenuFrame_Update()
	local button, fontString
	for i=1,5 do
		fontString = _G["RSAMenuFrameButton"..i.."Text"]
		fontString:SetText(RSA_MENU_TEXT[i])
		button = _G["RSAMenuFrameButton"..i]
		button.variable = RSA_MENU_SETS[i]
		button.index = i
		
		if i == 1 or i == 2 then
			button:SetChecked(RSAConfig[button.variable])
		elseif i == 3 then
			button:SetChecked(RSA_AlertFrameEnabled)
		elseif i == 4 then
			button:SetChecked(RSA_MoveMode)
		elseif i == 5 then
			button:SetChecked(RSA_PortraitIconShape == "circle")
		end
		
		if RSA_MENU_WHITE[i] then
			fontString:SetTextColor(1,1,1)
		end
	end
	
	if not RSAMenuFrame.alphaSlider then
		local slider = CreateFrame("Slider", "RSAAlphaSlider", RSAMenuFrame, "OptionsSliderTemplate")
		slider:SetWidth(180)
		slider:SetHeight(16)
		slider:SetPoint("TOPLEFT", RSAMenuFrameButton5, "BOTTOMLEFT", 0, -15)
		slider:SetMinMaxValues(0, 100)
		slider:SetValueStep(1)
		
		local displayValue = (RSA_AlertFrameBgAlpha / 0.7) * 100
		slider:SetValue(displayValue)
		
		_G[slider:GetName().."Low"]:SetText("0%")
		_G[slider:GetName().."High"]:SetText("100%")
		_G[slider:GetName().."Text"]:SetText("Background: " .. math.floor(displayValue) .. "%")
		
		slider:SetScript("OnValueChanged", function()
			local displayVal = this:GetValue()
			RSA_AlertFrameBgAlpha = (displayVal / 100) * 0.7
			_G[this:GetName().."Text"]:SetText("Bar Opacity: " .. math.floor(displayVal) .. "%")
			if RSA_AlertFrame and RSA_AlertFrame:IsVisible() then
				RSA_AlertFrame.bar:SetVertexColor(0.5, 0.5, 0.5, RSA_AlertFrameBgAlpha)
			end
		end)
		
		RSAMenuFrame.alphaSlider = slider
	else
		local displayValue = (RSA_AlertFrameBgAlpha / 0.7) * 100
		RSAMenuFrame.alphaSlider:SetValue(displayValue)
		_G[RSAMenuFrame.alphaSlider:GetName().."Text"]:SetText("Bar Opacity: " .. math.floor(displayValue) .. "%")
	end

	if not RSAMenuFrame.rangeSlider then
		local slider = CreateFrame("Slider", "RSARangeSlider", RSAMenuFrame, "OptionsSliderTemplate")
		slider:SetWidth(180)
		slider:SetHeight(16)
		slider:SetPoint("TOPLEFT", RSAMenuFrame.alphaSlider, "BOTTOMLEFT", 0, -25)
		slider:SetMinMaxValues(10, 100)
		slider:SetValueStep(5)

		_G[slider:GetName().."Low"]:SetText("10yd")
		_G[slider:GetName().."High"]:SetText("100yd")

		slider:SetScript("OnValueChanged", function()
			RSAConfig.range = math.floor(this:GetValue())
			_G[this:GetName().."Text"]:SetText("Alert Range: " .. RSAConfig.range .. " yd")
		end)

		RSAMenuFrame.rangeSlider = slider
	end
	RSAMenuFrame.rangeSlider:SetValue(RSA_GetMaxRange())
	_G[RSAMenuFrame.rangeSlider:GetName().."Text"]:SetText("Alert Range: " .. RSA_GetMaxRange() .. " yd")

	RSAMenuFrame_UpdateDependencies()
end

function RSAMenuFrame_UpdateDependencies()
	if RSAConfig.enabled then
		RSA_EnableCheckBox(RSAMenuFrameButton2)
	else
		RSA_DisableCheckBox(RSAMenuFrameButton2)
	end
end

function RSASoundOptionFrame_Toggle()
	if RSASoundOptionFrame:IsVisible() then
		RSASoundOptionFrame:Hide()
	else
		RSASoundOptionFrame:Show()
	end
end

function RSASoundOptionFrame_Update()
	local button, fontString
	local offset = FauxScrollFrame_GetOffset(RSASoundOptionFrameScrollFrame)
	for i=1,17 do
		local index = offset + i
		fontString = _G["RSASoundOptionFrameButton"..i.."Text"]
		fontString:SetText(RSA_SOUND_OPTION_TEXT[index] or "")
		
		button = _G["RSASoundOptionFrameButton"..i]
		button.index = index
		
		local subtable = RSA_Subtable(index)
		local config = RSAConfig[subtable]
		local soundText = RSA_SoundText(index)

		if RSA_SOUND_OPTION_NOBUTTON[index] or not config or not soundText then
			button:Hide()
		else
			button:Show()
			button:SetChecked(config[soundText])
		end

		if RSA_SOUND_OPTION_WHITE[index] then
			RSA_EnableCheckBox(button)
			fontString:SetTextColor(1,1,1)
		else
			if config and config["enabled"] then
				RSA_EnableCheckBox(button)
			else
				RSA_DisableCheckBox(button)
			end
		end
	end
	
	FauxScrollFrame_Update(RSASoundOptionFrameScrollFrame, table.getn(RSA_SOUND_OPTION_TEXT), 17, 16)
end

--[[===========================================================================
	Debug Commands
=============================================================================]]

SLASH_RSASTATUS1 = "/rsastatus"
SlashCmdList["RSASTATUS"] = function()
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00========== RSA Status ==========|r")
	if GetNampowerVersion then
		local a, b, c = GetNampowerVersion()
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00Nampower:|r v%d.%d.%d", a, b, c))
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Mode:|r " .. (pfUI and pfUI.libdebuff_spell_go_other_hooks and "pfUI hooks" or "Standalone"))
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Scanner:|r " .. (RSA_NP.enabled and "|cff00ff00ACTIVE|r" or "|cffff0000INACTIVE|r"))
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Nampower:|r |cffff0000NOT AVAILABLE|r")
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00RSA Enabled:|r " .. tostring(RSAConfig and RSAConfig.enabled))
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Debug Mode:|r " .. (RSA_NP.debugMode and "|cffff00ffENABLED|r" or "DISABLED"))
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00================================|r")
end

SLASH_R14DEBUG1 = "/r14debug"
SlashCmdList["R14DEBUG"] = function()
	RSA_NP.debugMode = not RSA_NP.debugMode
	if RSA_NP.debugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 Debug]|r Debug mode |cff00ff00ENABLED|r")
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 Debug]|r Debug mode |cffff0000DISABLED|r")
	end
end
