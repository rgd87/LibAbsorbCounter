# LibAbsorbCounter

Tracks Shield auras on units and sums up their current absorb values to replicate UnitGetTotalAbsorbs

Currently only works in Cataclysm.

Usage example:
-----------------

```lua
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

if isRetail then
    YourAddon:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
end

if isCataclysm then
    local LAC = LibStub("LibAbsorbCounter")
    UnitGetTotalAbsorbs = function(unit)
        return LAC:UnitGetTotalAbsorbs(unit)
    end
    LAC.RegisterCallback(self, "UNIT_ABSORB_AMOUNT_CHANGED", function(event, unit)
        self:UNIT_ABSORB_AMOUNT_CHANGED(event, unit)
    end)
end


function YouAddon:UNIT_ABSORB_AMOUNT_CHANGED(event, unit)
    local totalAbsorbs = UnitGetTotalAbsorbs(unit)
end

```
