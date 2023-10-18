--[[Created By Slothpala]]--
local SetStatusBarColor = SetStatusBarColor
local UnitIsPlayer = UnitIsPlayer
local GetName = GetName
local match = match
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local pairs = pairs
local next = next
local AuraUtil_ForEachAura = AuraUtil.ForEachAura

local playerClass = select(2,UnitClass("player"))
local debuffColor = {
    Curse   = {r=0.6,g=0.0,b=1.0},
    Disease = {r=0.6,g=0.4,b=0.0},
    Magic   = {r=0.2,g=0.6,b=1.0},
    Poison  = {r=0.0,g=0.6,b=0.0},
}
local canCure = {}
local auraMap = {}
local blockColorUpdate = {}

local restoreColor = function() end
local function updateRestoreColor()
    if C_CVar.GetCVar("raidFramesDisplayClassColor") == "0" then
        restoreColor = function(frame)
            blockColorUpdate[frame] = false
            frame.healthBar:SetStatusBarColor(0,1,0)
        end
    else 
        restoreColor = function(frame)
            blockColorUpdate[frame] = false
            if not frame.unit then
                return
            end
            local class = select(2,UnitClass(frame.unit)) 
            if not RAID_CLASS_COLORS[class] then 
                return 
            end
            frame.healthBar:SetStatusBarColor(RAID_CLASS_COLORS[class].r,RAID_CLASS_COLORS[class].g,RAID_CLASS_COLORS[class].b)
        end
    end
end

local function toDebuffColor(frame, dispelName)
    blockColorUpdate[frame] = true
    frame.healthBar:SetStatusBarColor(debuffColor[dispelName].r, debuffColor[dispelName].g, debuffColor[dispelName].b)
end

local function updateColor(frame)
    for auraInstanceID, dispelName in next, auraMap[frame] do
        if auraInstanceID then
            toDebuffColor(frame, dispelName)
            return
        end
    end
    restoreColor(frame)
end

local function updateAurasFull(frame)
    auraMap[frame] = {}
    local function HandleAura(aura)
        if canCure[aura.dispelName] then
            auraMap[frame][aura.auraInstanceID] = aura.dispelName
        end
    end
    AuraUtil_ForEachAura(frame.unit, "HARMFUL", nil, HandleAura, true)  
    updateColor(frame)
end

local function updateAurasIncremental(frame, updateInfo)
    if updateInfo.addedAuras then
        for _, aura in pairs(updateInfo.addedAuras) do
            if aura.isHarmful and canCure[aura.dispelName] then
                auraMap[frame][aura.auraInstanceID] = aura.dispelName
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in pairs(updateInfo.removedAuraInstanceIDs) do
            if auraMap[frame][auraInstanceID] then
                auraMap[frame][auraInstanceID] = nil
            end
        end
    end
    updateColor(frame)
end

local hooked = {}
local function makeHooks(frame)
    auraMap[frame] = {}
    --[[
        In case you wonder why this is not in the if not hooked[frame] section:
        CompactUnitFrame_UnregisterEvents removes the event handler with frame:SetScript("OnEvent", nil) and thus our hook.
        Interface/FrameXML/CompactUnitFrame.lua
    ]]--
    frame:HookScript("OnEvent", function(frame,event,unit,updateInfo)
        if event ~= "UNIT_AURA" then
            return
        end
        if updateInfo.isFullUpdate then 
            updateAurasFull(frame)
        else
            updateAurasIncremental(frame, updateInfo)
        end
    end)
    if not hooked[frame] then
        frame:HookScript("OnAttributeChanged", function(frame, attribute, value)
            if attribute ~= "unit" then
                return
            end
            if value then
                updateAurasFull(frame)
            else
                blockColorUpdate[frame] = nil
            end
        end)
        hooked[frame] = true
    end
end

hooksecurefunc("CompactUnitFrame_RegisterEvents", function(frame)
    if frame.unit:match("na") then --this will exclude nameplates and arena
        return
    end
    if not UnitIsPlayer(frame.unit) then --exclude pet/vehicle frame
        return
    end
    makeHooks(frame)
end)    

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame) 
    --[[
        CompactUnitFrame_UpdateHealthColor checks the current healthbar color value and restores it to the designated color if it differs from it.
        If this happens while the frame has a debuff color, we will need to update it again.
    ]]--
    if blockColorUpdate[frame] then
        updateColor(frame)
    end
end)

--compact party frames
for i=1, 5 do
    local healthBar = _G["CompactPartyFrameMember" ..i .. "HealthBar"]
    if healthBar then
        local frame = healthBar:GetParent()
        makeHooks(frame)
    end
end

local function updateCurable()
    canCure = {}
    local dispelAbilities = {
        ["DRUID"] = function()
            if IsSpellKnown(2782) then --Remove Corruption
                canCure.Curse = true
                canCure.Poison = true
            end
            if IsSpellKnown(88423) then --Nature's Cure
                canCure.Magic = true
                if IsPlayerSpell(392378) then --Improved Nature's Cure
                    canCure.Curse = true
                    canCure.Poison = true
                end
            end
        end,
        ["MAGE"] = function()
            if IsSpellKnown(475) then --Remove Curse
                canCure.Curse = true
            end
        end,
        ["MONK"] = function()
            if IsSpellKnown(218164) then --Detox BM/WW
                canCure.Poison = true
                canCure.Disease = true
            end
            if IsSpellKnown(115450) then --Detox MW 
                canCure.Magic = true
                if IsPlayerSpell(388874) then --Improved Detox 
                    canCure.Poison = true
                    canCure.Disease = true
                end
            end
            if IsSpellKnown(115310) then --Revival
                canCure.Magic = true
                canCure.Poison = true
                canCure.Disease = true
            end
            if IsSpellKnown(115310) then --Restoral
                canCure.Poison = true
                canCure.Disease = true
            end
        end,
        ["PALADIN"] = function()
            if IsSpellKnown(213644) then --Cleanse Toxins
                canCure.Poison = true
                canCure.Disease = true
            end
            if IsSpellKnown(4987) then --Cleanse
                canCure.Magic = true
                if IsPlayerSpell(393024) then --Improved Cleanse
                    canCure.Poison = true
                    canCure.Disease = true
                end
            end
        end,
        ["PRIEST"] = function()
            if IsSpellKnown(527) then --Purify
                canCure.Magic = true
                if IsPlayerSpell(390632) then --Improved Purify
                    canCure.Disease = true
                end
            end
            if IsSpellKnown(213634) then --Purify Disease
                canCure.Disease = true
            end
            if IsSpellKnown(32375) then --Mass Dispel
                canCure.Magic = true
            end
        end,
        ["SHAMAN"] = function()
            if IsSpellKnown(51886) then --Cleanse Spirit
                canCure.Curse = true
            end
            if IsSpellKnown(77130) then --Purify Spirit
                canCure.Magic = true
                if IsPlayerSpell(383016) then --Improved Purify Spirit
                    canCure.Curse = true
                end
            end
            if IsSpellKnown(383013) then --Poision Cleansing Totem
                canCure.Poison = true
            end
        end,
        ["WARLOCK"] = function()
            if IsSpellKnown(89808, true) then --Singe Magic
                canCure.Magic = true
            end
        end,
        ["EVOKER"] = function()
            if IsSpellKnown(374251) then --Cauterizing Flame
                canCure.Curse = true
                canCure.Poison = true
                canCure.Disease = true
            end
            if IsSpellKnown(365585) then --Expunge 
                canCure.Poison = true
            end
            if IsSpellKnownOrOverridesKnown(360823) then --Naturalize 
                canCure.Magic = true
                canCure.Poison = true
            end
        end,
        ["DEMONHUNTER"] = function()
            if IsSpellKnown(205604) then --Reverse Magic
                canCure.Magic = true
            end
        end,
        ["HUNTER"] = function()
            if IsSpellKnown(212640) then --Mending Bandage
                canCure.Poison = true
                canCure.Disease = true
            end
        end,
    }
    if dispelAbilities[playerClass] then
        dispelAbilities[playerClass]()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    updateCurable()
    if event == "PLAYER_LOGIN" then
        updateRestoreColor()
    end
    if event == "CVAR_UPDATE" then
        local eventName = ...
        if eventName == "raidFramesDisplayClassColor" then
            updateRestoreColor()
        end
    end
end)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
if playerClass == "WARLOCK" then
    eventFrame:RegisterUnitEvent("UNIT_PET", "player")
end
