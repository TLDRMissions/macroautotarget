local addonName, addon = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
f:RegisterEvent("ARENA_OPPONENT_UPDATE")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("UPDATE_MACROS")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

-- supported commands:
-- #ATH
-- target first enemy arena healer
-- #ATT
-- target first enemy arena tank
-- #ATD
-- target first enemy arena dps
-- #ATC
-- target first enemy arena caster (not hunters)
-- #ATM
-- target first enemy arena melee
-- #ATR
-- target first enemy arena hunter or caster
-- #RTH
-- target first friendly party/raid healer
-- #RTT
-- target first friendly party/raid tank
-- #RTD
-- target first friendly party/raid dps
-- optional numbers such as:
-- #RTH2
-- #RTH12
-- targets the 2nd or 12th DPS in the party/raid

local macroCache = nil
-- Lets cut down on the number of calls to GetMacroInfo by storing the entire list once per cycle instead
-- The function seems to be costly to repeat unnecessarily
local function cacheMacros()
    macroCache = {}
    for macroIndex = 1, 138 do
        local name, icon, body = GetMacroInfo(macroIndex)
        if name and body then
            macroCache[macroIndex] = {name, icon, body}
        end
    end
end

local function updateArena(command, index, numRole)
    for macroIndex = 1, 138 do
        if macroCache[macroIndex] then
            local name, icon, body = macroCache[macroIndex][1], macroCache[macroIndex][2], macroCache[macroIndex][3]
            local cache = body
            if body:find(command) then
                local secondaryMatch = body:match(command..numRole.."[0-9]?")
                if secondaryMatch ~= command..numRole then secondaryMatch = nil end
                local alternateMatch = body:match(command.."[0-9]+")
                local primaryMatch = body:match(command)
            
                if secondaryMatch or ((numRole == 1) and (not alternateMatch) and primaryMatch) then
                    body = body:gsub("/tar arena%d", "/tar arena"..index)
                    body = body:gsub("/target arena%d", "/tar arena"..index)
                    body = body:gsub("/focus arena%d", "/focus arena"..index)
                    body = body:gsub("/cast %[([^@%]]*)@arena%d([^@%]]*)%]", "/cast [%1@arena"..index.."%2]")
                    if body ~= cache then
                        EditMacro(macroIndex, name, icon, body)
                    end
                end
            end
        end
    end
end

local function updateArenaHealer(healerIndex, numRole)
    if (not healerIndex) or (type(healerIndex) ~= "number") or (healerIndex < 1) or (healerIndex > 3) then return end
    updateArena("#ATH", healerIndex, numRole)
end

local function updateArenaTank(tankIndex, numRole)
    if (not tankIndex) or (type(tankIndex) ~= "number") or (tankIndex < 1) or (tankIndex > 3) then return end
    updateArena("#ATT", tankIndex, numRole)
end

local function updateArenaDPS(dpsIndex, numRole)
    if (not dpsIndex) or (type(dpsIndex) ~= "number") or (dpsIndex < 1) or (dpsIndex > 3) then return end
    updateArena("#ATD", dpsIndex, numRole)
end

local function updateArenaCaster(index, numRole)
    if (not index) or (type(index) ~= "number") or (index < 1) or (index > 3) then return end
    updateArena("#ATC", index, numRole)
end

local function updateArenaMelee(index, numRole)
    if (not index) or (type(index) ~= "number") or (index < 1) or (index > 3) then return end
    updateArena("#ATM", index, numRole)
end

local function updateArenaRanged(index, numRole)
    if (not index) or (type(index) ~= "number") or (index < 1) or (index > 3) then return end
    updateArena("#ATR", index, numRole)
end

local function updateFriendly(command, unitID, rosterIndex)
    for macroIndex = 1, 138 do
        if macroCache[macroIndex] then
            local name, icon, body = macroCache[macroIndex][1], macroCache[macroIndex][2], macroCache[macroIndex][3]
            local cache = body
            
            -- explanation of this logic
            -- we want to capture #RTT but not #RTT2 or #RTT32
            -- or maybe we want to capture #RTT3 but have to exclude #RTT and #RTT31
            local secondaryMatch = body:match(command..rosterIndex.."[0-9]?")
            if secondaryMatch ~= command..rosterIndex then secondaryMatch = nil end
            local alternateMatch = body:match(command.."[0-9]+")
            local primaryMatch = body:match(command)
            
            if secondaryMatch or ((rosterIndex == 1) and (not alternateMatch) and primaryMatch) then
                body = body:gsub("/tar [^%s]+", "/tar "..unitID)
                body = body:gsub("/target [^%s]+", "/tar "..unitID)
                body = body:gsub("/focus [^%s]+", "/focus "..unitID)
                body = body:gsub("@player", "@"..unitID)
                body = body:gsub("@party[%d]+", "@"..unitID)
                body = body:gsub("@raid[%d]+", "@"..unitID)
                if body ~= cache then
                    EditMacro(name, name, icon, body)
                end
            end
        end
    end
end

local function updateFriendlyHealer(unitID, rosterIndex)
    updateFriendly("#RTH", unitID, rosterIndex)
end

local function updateFriendlyTank(unitID, rosterIndex)
    updateFriendly("#RTT", unitID, rosterIndex)
end

local function updateFriendlyDPS(unitID, rosterIndex)
    updateFriendly("#RTD", unitID, rosterIndex)
end

local checkAfterCombat, updateMacrosPending, busy
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        cacheMacros()
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        return
    end

    if (event ~= "PLAYER_REGEN_ENABLED") and InCombatLockdown() then
        checkAfterCombat = true
        return
    end
    
    if not macroCache then return end
    
    if (event == "PLAYER_REGEN_ENABLED") and (not checkAfterCombat) then
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        checkAfterCombat = false
    end
    
    if busy then return end
    
    if event == "UPDATE_MACROS" then
        if updateMacrosPending then return end
        updateMacrosPending = true
        C_Timer.After(5, function()
            cacheMacros()
            updateMacrosPending = false
            f:GetScript("OnEvent")(self, "MANUAL")
        end)
        return
    end
    
    if updateMacrosPending then return end
    
    busy = true
    
    C_Timer.After(0.2, function()
        if InCombatLockdown() then
            busy = false
            return
        end
        
        local healerIndex, tankIndex, dpsIndex, casterIndex, meleeIndex, rangedIndex = {}, {}, {}, {}, {}, {}
        for index = 1, 5 do
            local specID = GetArenaOpponentSpec(index)
            if (specID and specID > 0) then
                local _, _, _, _, role = GetSpecializationInfoByID(specID)
                if role == "HEALER" then
                    table.insert(healerIndex, index)
                elseif role == "TANK" then
                    table.insert(tankIndex, index)
                elseif role == "DAMAGER" then
                    table.insert(dpsIndex, index)
                    
                    local roleType = addon.SpecIDToRole[specID]
                    if roleType == "CASTER" then
                        table.insert(casterIndex, index)
                        table.insert(rangedIndex, index)
                    elseif roleType == "MELEE" then
                        table.insert(meleeIndex, index)
                    elseif roleType == "RANGED" then
                        table.insert(rangedIndex, index)
                    end
                end
            end
        end

        C_Timer.After(0.2, function()
            if InCombatLockdown() then
                busy = false
                return
            end
            for numHealer, index in pairs(healerIndex) do
                updateArenaHealer(index, numHealer)
            end
            
            C_Timer.After(0.2, function()
                if InCombatLockdown() then
                    busy = false
                    return
                end
                for numTank, index in pairs(tankIndex) do
                    updateArenaTank(index, numTank)
                end
                
                C_Timer.After(0.2, function()
                    if InCombatLockdown() then
                        busy = false
                        return
                    end
                    
                    C_Timer.After(0.2, function()
                        if InCombatLockdown() then
                            busy = false
                            return
                        end
                        for numDPS, index in pairs(dpsIndex) do
                            updateArenaDPS(index, numDPS)
                        end
                        
                        C_Timer.After(0.2, function()
                            if InCombatLockdown() then
                                busy = false
                                return
                            end
                            for numCaster, index in pairs(casterIndex) do
                                updateArenaCaster(index, numCaster)
                            end
                            
                            C_Timer.After(0.2, function()
                                if InCombatLockdown() then
                                    busy = false
                                    return
                                end
                                for numMelee, index in pairs(meleeIndex) do
                                    updateArenaMelee(index, numMelee)
                                end
                                
                                C_Timer.After(0.2, function()
                                    if InCombatLockdown() then
                                        busy = false
                                        return
                                    end
                                    for numRanged, index in pairs(rangedIndex) do
                                        updateArenaRanged(index, numRanged)
                                    end
                                    
                                    --
                                    -- ARENA / FRIENDLY SEPARATOR
                                    --
                                    
                                    C_Timer.After(0.2, function()
                                        if InCombatLockdown() then
                                            busy = false
                                            return
                                        end
                                        healerIndex, tankIndex, dpsIndex = nil, nil, nil
                                        local numHealer, numTank, numDPS = 0, 0, 0
                                        local prefix = "raid"
                                        
                                        if IsInRaid() then
                                            for index = 1, MAX_RAID_MEMBERS do
                                                local name, _, _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(index)
                                                if name ~= UnitName("player") then
                                                    if (role == "HEALER") then
                                                        numHealer = numHealer + 1
                                                        updateFriendlyHealer(prefix..index, numHealer)
                                                    elseif (not tankIndex) and (role == "TANK") then
                                                        numTank = numTank + 1
                                                        updateFriendlyTank(prefix..index, numTank)
                                                    elseif (not dpsIndex) and (role == "DAMAGER") then
                                                        numDPS = numDPS + 1
                                                        updateFriendlyDPS(prefix..index, numDPS)
                                                    end
                                                end
                                            end
                                        elseif IsInGroup() then
                                            prefix = "party"
                                            for index = 1, GetNumSubgroupMembers() do
                                                local role = UnitGroupRolesAssigned(prefix..index)
                                                if (role == "HEALER") then
                                                    numHealer = numHealer + 1
                                                    updateFriendlyHealer(prefix..index, numHealer)
                                                elseif (not tankIndex) and (role == "TANK") then
                                                    numTank = numTank + 1
                                                    updateFriendlyTank(prefix..index, numTank)
                                                elseif (not dpsIndex) and (role == "DAMAGER") then
                                                    numDPS = numDPS + 1
                                                    updateFriendlyDPS(prefix..index, numDPS)
                                                end
                                            end
                                        end
                                        
                                        C_Timer.After(0.2, function()
                                            if InCombatLockdown() then
                                                busy = false
                                                return
                                            end
                                            for i = (numHealer+1), MAX_RAID_MEMBERS do
                                                updateFriendlyHealer("player", i)
                                            end
                                            
                                            C_Timer.After(0.2, function()
                                                if InCombatLockdown() then
                                                    busy = false
                                                    return
                                                end
                                                for i = (numTank+1), MAX_RAID_MEMBERS do
                                                    updateFriendlyTank("player", i)
                                                end
                                                
                                                C_Timer.After(0.2, function()
                                                    if InCombatLockdown() then
                                                        busy = false
                                                        return
                                                    end
                                                    for i = (numDPS+1), MAX_RAID_MEMBERS do
                                                        updateFriendlyDPS("player", i)
                                                    end
                                                    busy = false
                                                end)
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)