--[================[
LibAbsorbCounter
Author: d87
--]================]


local MAJOR, MINOR = "LibAbsorbCounter", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end


lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

lib.frame = lib.frame or CreateFrame("Frame")

local f = lib.frame
local callbacks = lib.callbacks

lib.absorbAuras = lib.absorbAuras or setmetatable({}, { __mode = "v" })
local absorbAuras = lib.absorbAuras

lib.absorbCache = lib.absorbCache or {}
local absorbCache = lib.absorbCache

local GetAuraDataByIndex = C_UnitAuras.GetAuraDataByIndex
local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID


local apiLevel = math.floor(select(4,GetBuildInfo())/10000)
f:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)


-- local IsGroupUnit = function(unit)
--     return UnitExists(unit) and (UnitIsUnit(unit, "player") or UnitPlayerOrPetInParty(unit) or UnitPlayerOrPetInRaid(unit))
-- end

-- local function UnitIsHostile(unit)
--     local reaction = UnitReaction(unit, 'player') or 1
--     return reaction <= 4
-- end


local function FireCallback(event, unit, ...)
    callbacks:Fire(event, unit, ...)
end



local shieldSpells = {
	[11426] = 1, -- Ice Barrier (Mage)
	[17]    = 1, -- Power Word: Shield (Priest)
	[47753] = 1, -- Divine Aegis (Priest)
	[86273] = 1, -- Iluminated Healing (Paladin)
    [77535] = 1, -- Blood Shield (DK)
}


local function InvalidateCache(unit)
    absorbCache[unit] = nil
    FireCallback("UNIT_ABSORB_AMOUNT_CHANGED", unit)
end


local function FullUnitUpdate(unit)
    absorbAuras[unit] = {}
    local unitAbsorbAuras = absorbAuras[unit]
    for i=1, 100 do
        local aura = GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then return end

        local aIID = aura.auraInstanceID
        if shieldSpells[aura.spellId] then
            unitAbsorbAuras[aIID] = aura.points[1] or 0
        end
    end
end

function f:UNIT_AURA(event, unit, info)

	if info.isFullUpdate or absorbAuras[unit] == nil then
        FullUnitUpdate(unit)
        InvalidateCache(unit)
        -- print("full update")
		return
	end

    local shouldInvalidateCache = false

	if info.addedAuras then
        for _, aura in pairs(info.addedAuras) do
            local unitAbsorbAuras = absorbAuras[unit]

            if shieldSpells[aura.spellId] then
                local aIID = aura.auraInstanceID
                unitAbsorbAuras[aIID] = aura.points[1] or 0
                shouldInvalidateCache = true
                -- print('added shield, clearing cache')
            end
        end
	end
	if info.updatedAuraInstanceIDs then
        local unitAbsorbAuras = absorbAuras[unit]
        for _, aIID in pairs(info.updatedAuraInstanceIDs) do
			local aura = GetAuraDataByAuraInstanceID(unit, aIID)
            if aura then -- apparently it can be nil
                if shieldSpells[aura.spellId] then
                    unitAbsorbAuras[aIID] = aura.points[1] or 0
                    shouldInvalidateCache = true
                    -- print('updated shield', aIID, aura.name, aura.points[1])
                end
            else -- try to remove in that case
                if unitAbsorbAuras[aIID] then
                    unitAbsorbAuras[aIID] = nil
                    shouldInvalidateCache = true
                end
            end
        end
	end
	if info.removedAuraInstanceIDs then
        local unitAbsorbAuras = absorbAuras[unit]
        for _, aIID in pairs(info.removedAuraInstanceIDs) do
            if unitAbsorbAuras[aIID] then
                unitAbsorbAuras[aIID] = nil
                shouldInvalidateCache = true
                -- print('removed shield, clearing cache')
            end
        end
	end

    if shouldInvalidateCache then
        InvalidateCache(unit)
    end
end


local function RecalculateCache(unit)
    local unitAbsorbAuras = absorbAuras[unit]
    if not unitAbsorbAuras then return 0 end

    local totalAbsorb = 0
    for aIID, absorb in pairs(unitAbsorbAuras) do
        totalAbsorb = totalAbsorb + absorb
    end
    return totalAbsorb
end




local CACHE_EXPIRATION_TIME = 40
function lib:UnitGetTotalAbsorbs(unit)
    local cached = absorbCache[unit]
    local now = GetTime()
    if cached then
        local cacheExpirationTime = cached[2]
        if now > cacheExpirationTime then
            if UnitExists(unit) then
                FullUnitUpdate(unit)
                local total = RecalculateCache(unit)
                absorbCache[unit] = {total, now}
                return total
            else
                return 0
            end
        end
        return cached[1]
    else
        local total = RecalculateCache(unit)
        absorbCache[unit] = {total, now+CACHE_EXPIRATION_TIME}
        return total
    end
end

function f:PLAYER_ENTERING_WORLD()
    local unit = next(absorbAuras)
    while unit do
        absorbAuras[unit] = nil
        InvalidateCache(unit)
        unit = next(absorbAuras)
    end
end

function callbacks.OnUsed()
    f:RegisterEvent("UNIT_AURA")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function callbacks.OnUnused()
    f:UnregisterAllEvents()
end