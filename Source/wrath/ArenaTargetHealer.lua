local f = CreateFrame("Frame")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

-- supported commands:
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
                    body = body:gsub("@player", "@"..unitID)
                    body = body:gsub("@party[%d]+", "@"..unitID)
                    body = body:gsub("@raid[%d]+", "@"..unitID)
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
    
    local healerIndex, tankIndex, dpsIndex = nil, nil, nil
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
