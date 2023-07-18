local f = CreateFrame("Frame")
f:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

-- supported commands:
-- #ATH
-- target first enemy arena healer
-- #ATT
-- target first enemy arena tank
-- #ATD
-- target first enemy arena dps
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

local function updateArena(command, index)
    local global, char = GetNumMacros()
    for i = 1, (char + 120) do
        if (i <= global) or (i > 119) then
            local name, icon, body = GetMacroInfo(i)
            if body and body:find(command) then
                body = body:gsub("/tar arena%d", "/tar arena"..index)
                body = body:gsub("/target arena%d", "/tar arena"..index)
                body = body:gsub("/focus arena%d", "/focus arena"..index)
                body = body:gsub("/cast %[([^@%]]*)@arena%d([^@%]]*)%]", "/cast [%1@arena"..index.."%2]")
                EditMacro(name, name, icon, body)
            end
        end
    end
end

local function updateArenaHealer(healerIndex)
    if (not healerIndex) or (type(healerIndex) ~= "number") or (healerIndex < 1) or (healerIndex > 3) then return end
    updateArena("#ATH", healerIndex)
end

local function updateArenaTank(tankIndex)
    if (not tankIndex) or (type(tankIndex) ~= "number") or (tankIndex < 1) or (tankIndex > 3) then return end
    updateArena("#ATT", tankIndex)
end

local function updateArenaDPS(dpsIndex)
    if (not dpsIndex) or (type(dpsIndex) ~= "number") or (dpsIndex < 1) or (dpsIndex > 3) then return end
    updateArena("#ATD", dpsIndex)
end

local function updateFriendly(command, unitID, rosterIndex)
    local global, char = GetNumMacros()
    for i = 1, (char + 120) do
        if (i <= global) or (i > 119) then
            local name, icon, body = GetMacroInfo(i)
            if body then
                local secondaryMatch = body:match(command..rosterIndex)
                local alternateMatch = body:match(command.."[0-9]")
                local primaryMatch = body:match(command)
                
                if secondaryMatch or ((rosterIndex == 1) and (not alternateMatch) and primaryMatch) then
                    body = body:gsub("/tar [^%s]+", "/tar "..unitID)
                    body = body:gsub("/target [^%s]+", "/tar "..unitID)
                    body = body:gsub("/focus [^%s]+", "/focus "..unitID)
                    body = body:gsub("/cast %[([^@%]]*)@[^,%]]+([^@%]]*)%]", "/cast [%1@"..unitID.."%2]")
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

local checkAfterCombat
f:SetScript("OnEvent", function(self, event)
    if (event ~= "PLAYER_REGEN_ENABLED") and InCombatLockdown() then
        checkAfterCombat = true
        return
    end
    if (event == "PLAYER_REGEN_ENABLED") and (not checkAfterCombat) then
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        checkAfterCombat = false
    end
    
    local healerIndex, tankIndex, dpsIndex
    for index = 1, 3 do
        local specID = GetArenaOpponentSpec(index)
        if (specID and specID > 0) then
            local _, _, _, _, role = GetSpecializationInfoByID(specID)
            if (not healerIndex) and (role == "HEALER") then
                healerIndex = index
            elseif (not tankIndex) and (role == "TANK") then
                tankIndex = index
            elseif (not dpsIndex) and (role == "DAMAGER") then
                dpsIndex = index
            end
        end
    end
    
    if healerIndex then
        updateArenaHealer(healerIndex)
    end
    if tankIndex then
        updateArenaTank(tankIndex)
    end
    if dpsIndex then
        updateArenaDPS(dpsIndex)
    end
    
    --
    -- ARENA / FRIENDLY SEPARATOR
    --
    
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
    
    for i = (numHealer+1), MAX_RAID_MEMBERS do
        updateFriendlyHealer("player", i)
    end
    
    for i = (numTank+1), MAX_RAID_MEMBERS do
        updateFriendlyTank("player", i)
    end
    
    for i = (numDPS+1), MAX_RAID_MEMBERS do
        updateFriendlyDPS("player", i)
    end
end)

--function testATH(index)
--    updateFriendlyHealer(index)
--end
