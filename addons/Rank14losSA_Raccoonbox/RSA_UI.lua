--[[
RSA_UI.lua - Alert Frame and Portrait Icon Systems
Part of Rank14losSA addon
]]

RSA_AlertFrame = nil
RSA_MoveMode = false
RSA_IconCache = {}

--[[===========================================================================
	Alert Frame System
=============================================================================]]

function RSA_CreateAlertFrame()
	if RSA_AlertFrame then return end
	
	RSA_AlertFrame = CreateFrame("Frame", "RSAAlertFrame", UIParent)
	RSA_AlertFrame:SetWidth(250)
	RSA_AlertFrame:SetHeight(28)
	RSA_AlertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	RSA_AlertFrame:SetMovable(true)
	RSA_AlertFrame:EnableMouse(false)
	RSA_AlertFrame:SetClampedToScreen(true)
	RSA_AlertFrame:RegisterForDrag("LeftButton")
	RSA_AlertFrame:SetFrameStrata("HIGH")
	RSA_AlertFrame:SetHitRectInsets(10000, 10000, 10000, 10000)
	
	-- Icon (links)
	RSA_AlertFrame.icon = RSA_AlertFrame:CreateTexture(nil, "ARTWORK")
	RSA_AlertFrame.icon:SetWidth(28)
	RSA_AlertFrame.icon:SetHeight(28)
	RSA_AlertFrame.icon:SetPoint("LEFT", RSA_AlertFrame, "LEFT", 0, 0)
	RSA_AlertFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	
	-- Bar (startet NACH dem Icon, nicht darunter)
	RSA_AlertFrame.bar = RSA_AlertFrame:CreateTexture(nil, "BACKGROUND")
	RSA_AlertFrame.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	local alpha = RSA_AlertFrameBgAlpha or 0.7
	RSA_AlertFrame.bar:SetVertexColor(1.0, 0.7, 0.0, alpha)
	RSA_AlertFrame.bar:SetPoint("LEFT", RSA_AlertFrame.icon, "RIGHT", 0, 0)  -- Startet rechts vom Icon
	RSA_AlertFrame.bar:SetHeight(28)
	RSA_AlertFrame.bar:SetWidth(0)
	
	-- Text
	RSA_AlertFrame.text = RSA_AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	RSA_AlertFrame.text:SetPoint("LEFT", RSA_AlertFrame.icon, "RIGHT", 8, 0)
	RSA_AlertFrame.text:SetText("")
	RSA_AlertFrame.text:SetTextColor(1, 1, 1)
	RSA_AlertFrame.text:SetShadowOffset(1, -1)
	RSA_AlertFrame.text:SetShadowColor(0, 0, 0, 1)
	
	-- Timer
	RSA_AlertFrame.timerText = RSA_AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	RSA_AlertFrame.timerText:SetPoint("RIGHT", RSA_AlertFrame, "RIGHT", -8, 0)
	RSA_AlertFrame.timerText:SetText("")
	RSA_AlertFrame.timerText:SetTextColor(1, 1, 1)
	RSA_AlertFrame.timerText:SetShadowOffset(1, -1)
	RSA_AlertFrame.timerText:SetShadowColor(0, 0, 0, 1)
	
	-- Drag
	RSA_AlertFrame:SetScript("OnDragStart", function()
		if RSA_MoveMode then this:StartMoving() end
	end)
	
	RSA_AlertFrame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		local ux, uy = UIParent:GetCenter()
		RSA_AlertFrameX = x - ux
		RSA_AlertFrameY = y - uy
	end)
	
	RSA_AlertFrame:Hide()
	RSA_AlertFrame.fadeTime = 0
	RSA_AlertFrame.castTime = 0
	RSA_AlertFrame.castElapsed = 0
	RSA_AlertFrame.isCasting = false
	RSA_AlertFrame.isBuffTimer = false
	RSA_AlertFrame.buffDuration = 0
	RSA_AlertFrame.buffElapsed = 0
	RSA_AlertFrame.buffEndTime = nil
	RSA_AlertFrame.activeBuffs = {}
	
	-- OnUpdate
	RSA_AlertFrame:SetScript("OnUpdate", function()
		if not this:IsVisible() then return end
		local elapsed = arg1
		
		if this.isCasting and this.castTime > 0 then
			-- CAST: Bar fills up
			this.castElapsed = this.castElapsed + elapsed
			local progress = this.castElapsed / this.castTime
			this.timerText:SetText(string.format("%.1f / %.1f", this.castElapsed, this.castTime))
			
			if progress >= 1 then
				this.bar:SetWidth(this:GetWidth())
				this.isCasting = false
				this.timerText:SetText("")
				-- After cast ends, check for active buffs
				if this.hadActiveBuffs or (this.activeBuffs and next(this.activeBuffs) ~= nil) then
					-- We have buffs to show
					RSA_ShowNextBuff()
				elseif RSA_MoveMode then
					-- Im Move-Mode: Zurück zum Platzhalter
					this.text:SetText(">> DRAG TO MOVE <<")
					this.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					local textWidth = this.text:GetStringWidth()
					local frameWidth = math.max(180, textWidth + 80)
					this:SetWidth(frameWidth)
					this.bar:SetWidth(frameWidth)
					this.bar:SetVertexColor(0.5, 0.5, 0.5, RSA_AlertFrameBgAlpha or 0.7)
					this.timerText:SetText("")
				else
					-- No buffs - start normal fade
					this.fadeTime = 0
				end
				this.hadActiveBuffs = nil
			else
				this.bar:SetWidth(this:GetWidth() * progress)
			end
		elseif this.isBuffTimer and this.buffEndTime then
			-- BUFF: Use absolute end time for accuracy
			local now = GetTime()
			local remaining = this.buffEndTime - now
			
			if remaining <= 0 then
				-- Buff expired - remove from tracking and show next
				if this.currentBuffKey then
					this.activeBuffs[this.currentBuffKey] = nil
				end
				this.isBuffTimer = false
				this.bar:SetWidth(0)
				this.timerText:SetText("")
				-- Show next buff or fade out
				RSA_ShowNextBuff()
				if not this.isBuffTimer then
					this.fadeTime = 0
				end
			else
				local progress = remaining / this.buffDuration
				this.bar:SetWidth(this:GetWidth() * progress)
				-- Only show timer if not hidden
				if not this.hideTimer then
					this.timerText:SetText(string.format("%.1f", remaining))
				end
			end
		else
			-- Normal fade out (nur wenn nicht im Move-Mode)
			if not RSA_MoveMode then
				this.fadeTime = this.fadeTime + elapsed
				if this.fadeTime > 2 then
					local alpha = 1 - ((this.fadeTime - 2) / 0.5)
					if alpha <= 0 then
						this:Hide()
						this:SetAlpha(1)
						this.bar:SetWidth(0)
					else
						this:SetAlpha(alpha)
					end
				end
			end
		end
	end)
	
	-- Restore position
	if RSA_AlertFrameX and RSA_AlertFrameY then
		RSA_AlertFrame:ClearAllPoints()
		RSA_AlertFrame:SetPoint("CENTER", UIParent, "CENTER", RSA_AlertFrameX, RSA_AlertFrameY)
	end
end

function RSA_ShowAlert(spellName, playerName, casterGUID, castDuration, spellID, itemID)
	if not RSA_AlertFrame then return end
	if not RSA_AlertFrameEnabled then return end
	
	-- Initialize active buffs tracking
	if not RSA_AlertFrame.activeBuffs then
		RSA_AlertFrame.activeBuffs = {}
	end
	
	local isTarget = false
	if casterGUID then
		local targetExists, targetGUID = UnitExists("target")
		if targetExists and targetGUID == casterGUID then
			isTarget = true
		end
	end
	
	local isFadeCheck = spellName and string.sub(spellName, -4) == "down"
	local isNewCast = castDuration and tonumber(castDuration) and tonumber(castDuration) > 0 and not isFadeCheck
	
	local displayName = spellName
	local isFade = false
	if string.sub(displayName, -4) == "down" then
		displayName = string.sub(displayName, 1, -5)
		isFade = true
	end
	
	local buffKey = (casterGUID or "unknown") .. "_" .. displayName
	
	if isFade then
		RSA_AlertFrame.activeBuffs[buffKey] = nil
		RSA_DisplayAlert(spellName, playerName, casterGUID, nil, spellID, true, itemID)
		RSA_ShowNextBuff()
		return
	end
	
	if isNewCast then
		RSA_AlertFrame.isBuffTimer = false
		RSA_AlertFrame.currentBuffKey = nil
		RSA_DisplayAlert(spellName, playerName, casterGUID, castDuration, spellID, isTarget, itemID)
		return
	end
	
	local buffDuration = nil
	local hideTimer = false
	
	if spellID and RSA_USE_SPELL_IDS[spellID] then
		buffDuration = 3
		hideTimer = true
	elseif RSA_NO_TIMER_BUFFS and RSA_NO_TIMER_BUFFS[displayName] then
		buffDuration = 3
		hideTimer = true
	elseif spellID and RSA_SPELLID_DURATIONS[spellID] then
		buffDuration = RSA_SPELLID_DURATIONS[spellID]
	elseif RSA_BUFF_DURATIONS[displayName] then
		buffDuration = RSA_BUFF_DURATIONS[displayName]
	end
	
	if not buffDuration then
		buffDuration = 3
		hideTimer = true
	end
	
	RSA_AlertFrame.activeBuffs[buffKey] = {
		spellName = spellName,
		displayName = displayName,
		playerName = playerName,
		casterGUID = casterGUID,
		spellID = spellID,
		itemID = itemID,
		duration = buffDuration,
		endTime = GetTime() + buffDuration,
		isTarget = isTarget,
		hideTimer = hideTimer,
	}
	
	-- Show the buff with shortest remaining time
	RSA_ShowNextBuff()
end

function RSA_ShowNextBuff()
	if not RSA_AlertFrame or not RSA_AlertFrame.activeBuffs then return end
	
	-- Clean up expired buffs
	local now = GetTime()
	for key, buff in pairs(RSA_AlertFrame.activeBuffs) do
		if buff.endTime and buff.endTime <= now then
			RSA_AlertFrame.activeBuffs[key] = nil
		end
	end
	
	-- Find buff with shortest remaining time
	local bestBuff = nil
	local bestKey = nil
	local shortestTime = nil
	
	for key, buff in pairs(RSA_AlertFrame.activeBuffs) do
		if buff.endTime then
			local remaining = buff.endTime - now
			if remaining > 0 and (not shortestTime or remaining < shortestTime) then
				shortestTime = remaining
				bestBuff = buff
				bestKey = key
			end
		end
	end
	
	if bestBuff then
		-- Show this buff with remaining time
		local remaining = bestBuff.endTime - now
		RSA_DisplayBuffAlert(bestBuff, remaining)
		RSA_AlertFrame.currentBuffKey = bestKey
	else
		-- No active buffs - only hide if not currently casting AND not in move mode
		RSA_AlertFrame.currentBuffKey = nil
		if not RSA_AlertFrame.isCasting and not RSA_MoveMode then
			RSA_AlertFrame.isBuffTimer = false
			RSA_AlertFrame:Hide()
			RSA_AlertFrame.bar:SetWidth(0)
			RSA_AlertFrame.timerText:SetText("")
		elseif RSA_MoveMode then
			-- Im Move-Mode: Zurück zum Platzhalter
			RSA_AlertFrame.isBuffTimer = false
			RSA_AlertFrame.text:SetText(">> DRAG TO MOVE <<")
			RSA_AlertFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			local textWidth = RSA_AlertFrame.text:GetStringWidth()
			local frameWidth = math.max(180, textWidth + 80)
			RSA_AlertFrame:SetWidth(frameWidth)
			RSA_AlertFrame.bar:SetWidth(frameWidth)
			RSA_AlertFrame.bar:SetVertexColor(0.5, 0.5, 0.5, RSA_AlertFrameBgAlpha or 0.7)
			RSA_AlertFrame.timerText:SetText("")
		end
	end
end

function RSA_DisplayBuffAlert(buff, remaining)
	if not RSA_AlertFrame then return end
	
	-- Icon
	local iconPath = RSA_GetIcon(buff.spellID and tonumber(buff.spellID), buff.itemID)
	RSA_IconCache[buff.displayName] = iconPath
	RSA_AlertFrame.icon:SetTexture(iconPath)
	
	-- Text
	local alertText
	if buff.playerName and buff.playerName ~= "" and buff.playerName ~= "Unknown" then
		alertText = buff.playerName .. " - " .. buff.displayName
	else
		alertText = buff.displayName
	end
	RSA_AlertFrame.text:SetText(alertText)
	
	-- Resize
	local textWidth = RSA_AlertFrame.text:GetStringWidth()
	local frameWidth = math.max(100, textWidth + 80)
	RSA_AlertFrame:SetWidth(frameWidth)
	
	RSA_AlertFrame.trackingGUID = buff.casterGUID
	local sliderAlpha = RSA_AlertFrameBgAlpha or 0.7
	
	-- BUFF WITH DURATION: Bar empties from current progress to 0%
	RSA_AlertFrame.buffDuration = buff.duration
	RSA_AlertFrame.buffEndTime = buff.endTime
	RSA_AlertFrame.isCasting = false
	RSA_AlertFrame.isBuffTimer = true
	RSA_AlertFrame.hideTimer = buff.hideTimer
	
	local progress = remaining / buff.duration
	RSA_AlertFrame.bar:SetWidth(RSA_AlertFrame:GetWidth() * progress)
	RSA_AlertFrame.bar:SetVertexColor(1.0, 0.7, 0.0, sliderAlpha)
	RSA_AlertFrame.bar:SetAlpha(1)
	RSA_AlertFrame.bar:Show()
	
	-- Show timer only if not hidden (for "use" abilities like Kick)
	if buff.hideTimer then
		RSA_AlertFrame.timerText:SetText("")
	else
		RSA_AlertFrame.timerText:SetText(string.format("%.1f", remaining))
	end
	
	RSA_AlertFrame:SetAlpha(1)
	RSA_AlertFrame:Show()
	RSA_AlertFrame.fadeTime = 0
	RSA_AlertFrame.isTargetAlert = buff.isTarget
end

function RSA_DisplayAlert(spellName, playerName, casterGUID, castDuration, spellID, isTarget, itemID)
	if not RSA_AlertFrame then return end
	
	-- DEBUG
	if castDuration and tonumber(castDuration) and tonumber(castDuration) > 0 then
	end
	
	local displayName = spellName
	local isFade = false
	if string.sub(displayName, -4) == "down" then
		displayName = string.sub(displayName, 1, -5)
		isFade = true
	end
	
	-- Icon
	local iconPath = "Interface\\Icons\\INV_Misc_QuestionMark"
	if isFade and RSA_IconCache[displayName] then
		iconPath = RSA_IconCache[displayName]
	elseif spellID then
		iconPath = RSA_GetIcon(tonumber(spellID), itemID)
		if not isFade then
			RSA_IconCache[displayName] = iconPath
		end
	end
	RSA_AlertFrame.icon:SetTexture(iconPath)
	
	-- Text
	local alertText
	if isFade then
		if playerName and playerName ~= "" and playerName ~= "Unknown" then
			alertText = playerName .. "'s " .. displayName .. " fades"
		else
			alertText = displayName .. " fades"
		end
	elseif playerName and playerName ~= "" and playerName ~= "Unknown" then
		alertText = playerName .. " - " .. displayName
	else
		alertText = displayName
	end
	RSA_AlertFrame.text:SetText(alertText)
	
	-- Resize
	local textWidth = RSA_AlertFrame.text:GetStringWidth()
	local frameWidth = math.max(180, textWidth + 80)
	RSA_AlertFrame:SetWidth(frameWidth)
	
	RSA_AlertFrame.trackingGUID = casterGUID
	RSA_AlertFrame.castSpellName = (castDuration and tonumber(castDuration) and tonumber(castDuration) > 0 and not isFade) and displayName or nil
	local sliderAlpha = RSA_AlertFrameBgAlpha or 0.7
	
	if castDuration and tonumber(castDuration) and tonumber(castDuration) > 0 and not isFade then
		-- CAST: Bar fills from 0 to 100% (red)
		-- Store current buff state to restore after cast
		RSA_AlertFrame.hadActiveBuffs = (RSA_AlertFrame.activeBuffs and next(RSA_AlertFrame.activeBuffs) ~= nil)
		RSA_AlertFrame.castTime = tonumber(castDuration) / 1000
		RSA_AlertFrame.castElapsed = 0
		RSA_AlertFrame.isCasting = true
		RSA_AlertFrame.isBuffTimer = false
		RSA_AlertFrame.buffEndTime = nil  -- Clear buff timer
		RSA_AlertFrame.bar:SetWidth(0)
		RSA_AlertFrame.bar:SetVertexColor(1.0, 0.7, 0.0, sliderAlpha)
		RSA_AlertFrame.bar:SetAlpha(0.7)
		RSA_AlertFrame.bar:Show()
		RSA_AlertFrame.timerText:SetText("")
		RSA_AlertFrame:SetAlpha(1)  -- Ensure frame is visible
		RSA_AlertFrame:Show()  -- Show the frame!
		RSA_AlertFrame.fadeTime = 0  -- Reset fade timer
	else
		-- INSTANT or FADE: Full bar
		RSA_AlertFrame.castTime = 0
		RSA_AlertFrame.castElapsed = 0
		RSA_AlertFrame.isCasting = false
		RSA_AlertFrame.isBuffTimer = false
		RSA_AlertFrame.timerText:SetText("")
		RSA_AlertFrame.bar:SetWidth(RSA_AlertFrame:GetWidth())
		RSA_AlertFrame.bar:SetAlpha(1)
		if isFade then
			-- Fade alerts: green bar, no fade time - disappear immediately
			RSA_AlertFrame.bar:SetVertexColor(0.3, 0.8, 0.3, sliderAlpha)
			RSA_AlertFrame.fadeTime = 2.5  -- Start fade immediately (2.5 = instant fade)
		else
			-- Instant casts: normal 2s display then fade
			RSA_AlertFrame.bar:SetVertexColor(1.0, 0.7, 0.0, sliderAlpha)
			RSA_AlertFrame.fadeTime = 0
		end
		RSA_AlertFrame.bar:Show()
	end
	RSA_AlertFrame.isTargetAlert = isTarget
end

function RSA_CancelCast(casterGUID)
  if not RSA_AlertFrame then return end
  if not RSA_AlertFrame.isCasting then return end
  if RSA_AlertFrame.trackingGUID ~= casterGUID then return end
  RSA_AlertFrame.isCasting = false
  RSA_AlertFrame.bar:SetWidth(0)
  RSA_AlertFrame.timerText:SetText("")
  -- Clear portrait icon for this cast
  if RSA_AlertFrame.castSpellName and RSA_TrackedBuffs and RSA_TrackedBuffs[casterGUID] then
    RSA_TrackedBuffs[casterGUID][RSA_AlertFrame.castSpellName] = nil
    RSA_RefreshTargetPortrait()
  end
  -- If we have active buffs, show them instead of hiding
  if RSA_AlertFrame.activeBuffs and next(RSA_AlertFrame.activeBuffs) then
    RSA_ShowNextBuff()
  elseif not RSA_MoveMode then
    RSA_AlertFrame:Hide()
  end
end

function RSA_ToggleMoveMode()
	RSA_MoveMode = not RSA_MoveMode
	
	if RSA_MoveMode then
		if not RSA_AlertFrame then RSA_CreateAlertFrame() end
		RSA_AlertFrame:EnableMouse(true)
		RSA_AlertFrame:SetHitRectInsets(0, 0, 0, 0)
		
		-- Nur Platzhalter anzeigen wenn KEIN aktiver Alert läuft
		if not RSA_AlertFrame:IsVisible() or (not RSA_AlertFrame.isCasting and not RSA_AlertFrame.isBuffTimer) then
			RSA_AlertFrame.text:SetText(">> DRAG TO MOVE <<")
			RSA_AlertFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			
			-- Dynamische Größe wie bei normalen Alerts
			local textWidth = RSA_AlertFrame.text:GetStringWidth()
			local frameWidth = math.max(180, textWidth + 80)
			RSA_AlertFrame:SetWidth(frameWidth)
			RSA_AlertFrame.bar:SetWidth(frameWidth)
			RSA_AlertFrame.bar:SetAlpha(1)
			RSA_AlertFrame.bar:SetVertexColor(0.5, 0.5, 0.5, RSA_AlertFrameBgAlpha or 0.7)
			RSA_AlertFrame.isCasting = false
			RSA_AlertFrame.isBuffTimer = false
			RSA_AlertFrame.timerText:SetText("")
			RSA_AlertFrame:SetAlpha(1)
			RSA_AlertFrame:Show()
		end
		-- Wenn Timer aktiv ist, bleibt alles sichtbar und läuft weiter
		
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert Frame move mode |cff00ff00ENABLED|r")
	else
		RSA_AlertFrame:EnableMouse(false)
		RSA_AlertFrame:SetHitRectInsets(10000, 10000, 10000, 10000)
		
		-- Nur verstecken wenn KEIN aktiver Alert läuft
		if not RSA_AlertFrame.isCasting and not RSA_AlertFrame.isBuffTimer then
			RSA_AlertFrame:Hide()
			RSA_AlertFrame.bar:SetWidth(0)
			RSA_AlertFrame.timerText:SetText("")
		end
		-- OnUpdate Script läuft bereits weiter von RSA_CreateAlertFrame()
		
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert Frame move mode |cffff0000DISABLED|r")
	end
end

--[[===========================================================================
	Portrait Icon Tracking System
=============================================================================]]

RSA_TrackedBuffs = {}

function RSA_UpdatePortraitIcon(spell, playerName, casterGUID, spellID, itemID)
	if not casterGUID then return end
	
	local displayName = spell
	local isFade = false
	if string.sub(spell, -4) == "down" then
		displayName = string.sub(spell, 1, -5)
		isFade = true
	end
	
	if not RSA_TrackedBuffs[casterGUID] then
		RSA_TrackedBuffs[casterGUID] = {}
	end
	
	if isFade then
		RSA_TrackedBuffs[casterGUID][displayName] = nil
	else
		local iconPath = RSA_GetIcon(spellID and tonumber(spellID), itemID)
		
		local duration = nil
		local hideTimer = false
		
		-- "Use" abilities (Kick, FlashBomb, etc.) get 3s display without timer
		if spellID and RSA_USE_SPELL_IDS[spellID] then
			duration = 3
			hideTimer = true
		-- Buffs without known duration get 3s display without timer
		elseif RSA_NO_TIMER_BUFFS and RSA_NO_TIMER_BUFFS[displayName] then
			duration = 3
			hideTimer = true
		elseif spellID and RSA_SPELLID_DURATIONS[spellID] then
			duration = RSA_SPELLID_DURATIONS[spellID]
		elseif RSA_BUFF_DURATIONS[displayName] then
			duration = RSA_BUFF_DURATIONS[displayName]
		end
		
		-- For abilities without duration, use 3s default to ensure cleanup
		if not duration then
			duration = 3
			hideTimer = true
		end
		
		local endTime = GetTime() + duration
		RSA_TrackedBuffs[casterGUID][displayName] = {
			icon = iconPath,
			endTime = endTime,
			spellID = spellID,
			hideTimer = hideTimer,
		}
	end
	
	RSA_RefreshTargetPortrait()
end

function RSA_RefreshTargetPortrait()
	local targetExists, targetGUID = UnitExists("target")
	if not targetExists or not targetGUID then
		RSA_HidePlayerFrameIcon()
		return
	end
	
	local buffs = RSA_TrackedBuffs[targetGUID]
	if not buffs then
		RSA_HidePlayerFrameIcon()
		return
	end
	
	local bestBuff = nil
	local bestName = nil
	local now = GetTime()
	
	for name, data in pairs(buffs) do
		if data.endTime and data.endTime < now then
			buffs[name] = nil
		else
			if not bestBuff then
				bestBuff = data
				bestName = name
			elseif data.endTime and bestBuff.endTime then
				if data.endTime < bestBuff.endTime then
					bestBuff = data
					bestName = name
				end
			elseif data.endTime then
				bestBuff = data
				bestName = name
			end
		end
	end
	
	if bestBuff then
		local remaining = bestBuff.endTime and (bestBuff.endTime - now) or nil
		RSA_ShowPlayerFrameIcon(bestBuff.icon, bestName, remaining, bestBuff.hideTimer)
	else
		RSA_HidePlayerFrameIcon()
	end
end

-- Target change hook and periodic cleanup
local RSA_TargetChangeFrame = CreateFrame("Frame")
RSA_TargetChangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
local cleanupTimer = 0
RSA_TargetChangeFrame:SetScript("OnEvent", function()
	RSA_RefreshTargetPortrait()
end)
RSA_TargetChangeFrame:SetScript("OnUpdate", function()
	cleanupTimer = cleanupTimer + arg1
	if cleanupTimer >= 0.1 then
		cleanupTimer = 0
		RSA_RefreshTargetPortrait()
	end
end)

--[[===========================================================================
	Portrait Icon Frame
=============================================================================]]

RSA_PlayerIcon = nil

function RSA_SetPlayerIconShape(frame)
	if not frame then return end

	local shape = RSA_PortraitIconShape or "square"
	local size = frame.baseSize or frame:GetWidth() or 52
	frame:SetWidth(size)
	frame:SetHeight(size)

	if shape == "circle" then
		-- Match ModernFocusFrame/DragonflightUI's approach: place the icon
		-- under the unitframe art and let the existing circular portrait frame
		-- hide the square corners. Do not draw our own minimap border.
		if frame.parentFrame and frame.parentFrame.GetFrameLevel then
			frame:SetFrameLevel(frame.parentFrame:GetFrameLevel())
		end
	else
		if frame.parentFrame and frame.parentFrame.GetFrameLevel then
			frame:SetFrameLevel(frame.parentFrame:GetFrameLevel() + 5)
		end
	end

	if frame.icon then
		frame.icon:ClearAllPoints()
		frame.icon:SetAllPoints(frame)
		if shape == "circle" then
			frame.icon:SetDrawLayer("BORDER")
		else
			frame.icon:SetDrawLayer("OVERLAY")
		end
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	if frame.border then
		frame.border:Hide()
	end
end

function RSA_CreatePlayerFrameIcon()
	if RSA_PlayerIcon then return end
	
	local parentFrame, anchorFrame, iconSize
	
	if pfUI and pfUI.uf and pfUI.uf.target and pfUI.uf.target.portrait then
		parentFrame = pfUI.uf.target
		anchorFrame = pfUI.uf.target.portrait
		iconSize = pfUI.uf.target.portrait:GetWidth() or 40
	else
		parentFrame = TargetFrame
		anchorFrame = TargetPortrait
		iconSize = 52
	end
	
	local frame = CreateFrame("Frame", "RSA_PlayerFrameIcon", parentFrame)
	frame.parentFrame = parentFrame
	frame.baseSize = iconSize
	frame:SetWidth(iconSize)
	frame:SetHeight(iconSize)
	frame:SetFrameLevel(parentFrame:GetFrameLevel() + 5)
	frame:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
	
	frame.icon = frame:CreateTexture(nil, "OVERLAY")
	frame.icon:SetAllPoints(frame)
	frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	RSA_SetPlayerIconShape(frame)

	frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.timer:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.timer:SetTextColor(0, 1, 0)
	frame.timer:SetShadowOffset(2, -2)
	frame.timer:SetShadowColor(0, 0, 0, 1)
	frame.timer:SetText("")
	
	frame.endTime = 0
	frame.hasTimer = false
	frame.spellName = nil
	
	frame:SetScript("OnUpdate", function()
		if not this:IsVisible() then return end
		if this.hasTimer and this.endTime > 0 then
			local remaining = this.endTime - GetTime()
			if remaining > 0 then
				this.timer:SetText(string.format("%.1f", remaining))
			else
				-- Time expired - hide immediately
				this:Hide()
				this.timer:SetText("")
				this.spellName = nil
			end
		end
	end)
	
	frame:Hide()
	RSA_PlayerIcon = frame
end

function RSA_ShowPlayerFrameIcon(iconPath, spellName, remainingTime, hideTimer)
	if not RSA_PlayerIcon then RSA_CreatePlayerFrameIcon() end
	if not RSA_PlayerIcon then return end
	
	RSA_PlayerIcon.icon:SetTexture(iconPath)
	RSA_PlayerIcon.spellName = spellName
	
	if remainingTime and remainingTime > 0 then
		RSA_PlayerIcon.endTime = GetTime() + remainingTime
		RSA_PlayerIcon.hasTimer = not hideTimer
		if hideTimer then
			RSA_PlayerIcon.timer:SetText("")
		end
	else
		RSA_PlayerIcon.endTime = 0
		RSA_PlayerIcon.hasTimer = false
		RSA_PlayerIcon.timer:SetText("")
	end
	
	RSA_PlayerIcon:SetAlpha(1)
	RSA_PlayerIcon:Show()
end

function RSA_HidePlayerFrameIcon()
	if not RSA_PlayerIcon then return end
	RSA_PlayerIcon:Hide()
	RSA_PlayerIcon.timer:SetText("")
	RSA_PlayerIcon.spellName = nil
end