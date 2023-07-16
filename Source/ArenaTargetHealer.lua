local f = CreateFrame("Frame")
f:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("RAID_ROSTER_UPDATE")

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

local function updateFriendly(command, unitID)
    local global, char = GetNumMacros()
    for i = 1, (char + 120) do
        if (i <= global) or (i > 119) then
            local name, icon, body = GetMacroInfo(i)
            if body and body:find(command) then
                body = body:gsub("/tar [^%s]+", "/tar "..unitID)
                body = body:gsub("/target [^%s]+", "/tar "..unitID)
                body = body:gsub("/focus [^%s]+", "/focus "..unitID)
                body = body:gsub("/cast %[([^@%]]*)@[^,%]]+([^@%]]*)%]", "/cast [%1@"..unitID.."%2]")
                EditMacro(name, name, icon, body)
            end
        end
    end
end

local function updateFriendlyHealer(unitID)
    updateFriendly("#RTH", unitID)
end

local function updateFriendlyTank(unitID)
    updateFriendly("#RTT", unitID)
end

local function updateFriendlyDPS(unitID)
    updateFriendly("#RTD", unitID)
end

f:SetScript("OnEvent", function()
    if InCombatLockdown() then return end
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
    
    healerIndex, tankIndex, dpsIndex = nil, nil, nil
    local prefix = "raid"
    
    if IsInRaid() then
        for index = 1, MAX_RAID_MEMBERS do
            local _, _, _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(index)
            if (not healerIndex) and (role == "HEALER") then
                healerIndex = index
            elseif (not tankIndex) and (role == "TANK") then
                tankIndex = index
            elseif (not dpsIndex) and (role == "DAMAGER") then
                dpsIndex = index
            end
        end
    elseif IsInGroup() then
        prefix = "party"
        for index = 1, GetNumSubgroupMembers() do
            local role = UnitGroupRolesAssigned(prefix..index)
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
        updateFriendlyHealer(prefix..healerIndex)
    else
        updateFriendlyHealer("player")
    end
    
    if tankIndex then
        updateFriendlyTank(prefix..tankIndex)
    else
        updateFriendlyTank("player")
    end
    
    if dpsIndex then
        updateFriendlyDPS(prefix..dpsIndex)
    else
        updateFriendlyDPS("player")
    end
end)

--[[
function testATH(index)
    updateFriendlyHealer(index)
end
]]
