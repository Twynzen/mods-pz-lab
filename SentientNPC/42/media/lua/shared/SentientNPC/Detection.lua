--[[
    SentientNPC - Detection.lua
    Advanced detection system for NPCs.

    This module handles:
    - Player detection (sight and sound)
    - Zombie detection
    - NPC detection
    - Line of sight checks
    - Sound/hearing system
    - Threat assessment

    Detection is used by Programs to make decisions about behavior.
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Detection = SentientNPC.Detection or {}
local Detection = SentientNPC.Detection

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

Detection.Config = {
    -- Vision
    VISION_RANGE = 30,              -- Max sight distance (tiles)
    VISION_ANGLE = 120,             -- Field of view (degrees)
    VISION_NIGHT_PENALTY = 0.5,     -- Vision reduction at night

    -- Hearing
    HEARING_RANGE_BASE = 15,        -- Base hearing range
    HEARING_RANGE_GUNSHOT = 100,    -- Gunshot hearing range
    HEARING_RANGE_FOOTSTEP = 8,     -- Footstep hearing range

    -- Detection cooldowns
    SCAN_COOLDOWN = 500,            -- ms between full scans
    MEMORY_DURATION = 30000,        -- How long to remember detected entities

    -- Threat levels (adjusted for better zombie reaction)
    THREAT_ZOMBIE = 0.4,            -- Base zombie threat (0.4 = alert mode)
    THREAT_HOSTILE_NPC = 0.6,
    THREAT_HOSTILE_PLAYER = 0.8,
    THREAT_ARMED_PLAYER = 1.0,
}

-- =============================================================================
-- DETECTION CACHE
-- =============================================================================

-- Cache detection results to avoid repeated expensive queries
Detection.Cache = {
    players = {},           -- {npcId -> {playerId -> {player, distance, visible, lastSeen}}}
    zombies = {},           -- {npcId -> {zombieId -> {zombie, distance, lastSeen}}}
    npcs = {},              -- {npcId -> {npcId -> {brain, distance, lastSeen}}}
    threats = {},           -- {npcId -> {entity, threatLevel, distance}}
    lastScan = {},          -- {npcId -> timestamp}
}

-- =============================================================================
-- PLAYER DETECTION
-- =============================================================================

---Detect players near an NPC
---@param zombie IsoZombie The NPC zombie
---@param brain table The NPC brain
---@param range number|nil Detection range (default: Config.VISION_RANGE)
---@return table Array of detected players with metadata
function Detection.DetectPlayers(zombie, brain, range)
    if not zombie or not brain then return {} end

    range = range or Detection.Config.VISION_RANGE
    local results = {}

    local npcX, npcY = zombie:getX(), zombie:getY()
    local npcDir = zombie:getDir():toAngle()

    local players = getOnlinePlayers()
    if not players then return results end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and not player:isDead() then
            local px, py = player:getX(), player:getY()
            local distance = SentientNPC.Utils.DistTo(npcX, npcY, px, py)

            if distance <= range then
                local visible = Detection.IsInLineOfSight(zombie, player, range)
                local inFOV = Detection.IsInFieldOfView(zombie, player)

                -- Can detect if visible and in FOV, or very close (heard)
                local detected = (visible and inFOV) or (distance <= 5)

                if detected then
                    local playerId = SentientNPC.Utils.GetCharacterID(player)

                    table.insert(results, {
                        player = player,
                        playerId = playerId,
                        distance = distance,
                        visible = visible,
                        inFOV = inFOV,
                        x = px,
                        y = py,
                        z = player:getZ(),
                        armed = Detection.IsArmed(player),
                        threatening = Detection.IsThreatening(player),
                        sneaking = player:isSneaking(),
                    })

                    -- Record sighting in brain
                    SentientNPC.Brain.RecordPlayerSighting(brain, playerId, px, py, player:getZ())
                end
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.distance < b.distance end)

    return results
end

---Get closest detected player
---@param zombie IsoZombie
---@param brain table
---@param range number|nil
---@return table|nil player data, number|nil distance
function Detection.GetClosestPlayer(zombie, brain, range)
    local players = Detection.DetectPlayers(zombie, brain, range)
    if #players > 0 then
        return players[1], players[1].distance
    end
    return nil, nil
end

-- =============================================================================
-- ZOMBIE DETECTION
-- =============================================================================

---Detect zombies near an NPC
---@param zombie IsoZombie The NPC zombie
---@param brain table The NPC brain
---@param range number|nil Detection range
---@return table Array of detected zombies
function Detection.DetectZombies(zombie, brain, range)
    if not zombie or not brain then return {} end

    range = range or SentientNPC.Config.DETECT_ZOMBIE_RANGE
    local results = {}

    local npcX, npcY = zombie:getX(), zombie:getY()
    local npcPersistentId = SentientNPC.Utils.GetPersistentID(zombie)

    local cell = getCell()
    if not cell then return results end

    local zombieList = cell:getZombieList()
    if not zombieList then return results end

    for i = 0, zombieList:size() - 1 do
        local z = zombieList:get(i)
        if z and not z:isDead() then
            -- Skip self
            local zPersistentId = SentientNPC.Utils.GetPersistentID(z)
            if zPersistentId ~= npcPersistentId then
                -- Skip other NPCs (they're handled separately)
                if not SentientNPC.Possession.IsPossessed(z) then
                    local zx, zy = z:getX(), z:getY()
                    local distance = SentientNPC.Utils.DistTo(npcX, npcY, zx, zy)

                    if distance <= range then
                        table.insert(results, {
                            zombie = z,
                            persistentId = zPersistentId,
                            distance = distance,
                            x = zx,
                            y = zy,
                            z = z:getZ(),
                            crawler = z:isCrawling(),
                            targeting = z:getTarget() ~= nil,
                        })
                    end
                end
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.distance < b.distance end)

    return results
end

---Get closest zombie
---@param zombie IsoZombie
---@param brain table
---@param range number|nil
---@return table|nil zombie data, number|nil distance
function Detection.GetClosestZombie(zombie, brain, range)
    local zombies = Detection.DetectZombies(zombie, brain, range)
    if #zombies > 0 then
        return zombies[1], zombies[1].distance
    end
    return nil, nil
end

-- =============================================================================
-- NPC DETECTION
-- =============================================================================

---Detect other NPCs near this NPC
---@param zombie IsoZombie The NPC zombie
---@param brain table The NPC brain
---@param range number|nil Detection range
---@return table Array of detected NPCs
function Detection.DetectNPCs(zombie, brain, range)
    if not zombie or not brain then return {} end

    range = range or SentientNPC.Config.DETECT_NPC_RANGE
    local results = {}

    local npcX, npcY = zombie:getX(), zombie:getY()

    local possessed = SentientNPC.Possession.GetAllPossessed()

    for _, z in ipairs(possessed) do
        if z and not z:isDead() and z ~= zombie then
            local zx, zy = z:getX(), z:getY()
            local distance = SentientNPC.Utils.DistTo(npcX, npcY, zx, zy)

            if distance <= range then
                local otherBrain = SentientNPC.Brain.GetFromZombie(z)

                table.insert(results, {
                    zombie = z,
                    brain = otherBrain,
                    npcId = otherBrain and otherBrain.id or nil,
                    name = otherBrain and otherBrain.name or "Unknown",
                    distance = distance,
                    x = zx,
                    y = zy,
                    z = z:getZ(),
                    hostile = otherBrain and otherBrain.hostileToPlayers or false,
                    faction = otherBrain and otherBrain.faction or nil,
                    sameFaction = otherBrain and otherBrain.faction == brain.faction,
                })
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.distance < b.distance end)

    return results
end

-- =============================================================================
-- LINE OF SIGHT
-- =============================================================================

---Check if NPC can see a target (distance-based, like Bandits mod)
---@param zombie IsoZombie The NPC
---@param target IsoMovingObject The target
---@param maxRange number|nil Max range to check
---@return boolean
function Detection.IsInLineOfSight(zombie, target, maxRange)
    if not zombie or not target then return false end

    local npcX, npcY, npcZ = zombie:getX(), zombie:getY(), zombie:getZ()
    local targetX, targetY, targetZ = target:getX(), target:getY(), target:getZ()

    -- Different floors = can't see
    if math.floor(npcZ) ~= math.floor(targetZ) then
        return false
    end

    local distance = SentientNPC.Utils.DistTo(npcX, npcY, targetX, targetY)

    -- Simple distance check (same approach as Bandits mod)
    maxRange = maxRange or Detection.Config.VISION_RANGE
    return distance <= maxRange
end

-- =============================================================================
-- FIELD OF VIEW
-- =============================================================================

---Check if target is within NPC's field of view
---@param zombie IsoZombie The NPC
---@param target IsoMovingObject The target
---@return boolean
function Detection.IsInFieldOfView(zombie, target)
    if not zombie or not target then return false end

    local npcX, npcY = zombie:getX(), zombie:getY()
    local targetX, targetY = target:getX(), target:getY()

    -- Get NPC facing direction
    local npcDir = zombie:getDir()
    local facingAngle = Detection.DirectionToAngle(npcDir)

    -- Calculate angle to target
    local dx = targetX - npcX
    local dy = targetY - npcY
    local angleToTarget = math.atan2(dy, dx) * (180 / math.pi)

    -- Normalize angles
    facingAngle = facingAngle % 360
    angleToTarget = angleToTarget % 360

    -- Calculate angle difference
    local angleDiff = math.abs(facingAngle - angleToTarget)
    if angleDiff > 180 then
        angleDiff = 360 - angleDiff
    end

    -- Check if within FOV
    local halfFOV = Detection.Config.VISION_ANGLE / 2
    return angleDiff <= halfFOV
end

---Convert IsoDirection to angle in degrees
---@param dir IsoDirections
---@return number
function Detection.DirectionToAngle(dir)
    if not dir then return 0 end

    local dirName = tostring(dir)
    local angles = {
        ["N"] = 270,
        ["NE"] = 315,
        ["E"] = 0,
        ["SE"] = 45,
        ["S"] = 90,
        ["SW"] = 135,
        ["W"] = 180,
        ["NW"] = 225,
    }

    return angles[dirName] or 0
end

-- =============================================================================
-- THREAT ASSESSMENT
-- =============================================================================

---Check if a player is armed
---@param player IsoPlayer
---@return boolean
function Detection.IsArmed(player)
    if not player then return false end

    local primary = player:getPrimaryHandItem()
    if primary then
        -- Check if it's a weapon
        if primary:IsWeapon() then
            return true
        end
    end

    local secondary = player:getSecondaryHandItem()
    if secondary then
        if secondary:IsWeapon() then
            return true
        end
    end

    return false
end

---Check if a player is acting threatening
---@param player IsoPlayer
---@return boolean
function Detection.IsThreatening(player)
    if not player then return false end

    -- Armed and aiming
    if Detection.IsArmed(player) and player:isAiming() then
        return true
    end

    -- Recently attacked
    -- (Would need combat tracking to implement fully)

    return false
end

---Calculate threat level for a detected entity
---@param entityData table Detection data for entity
---@param brain table The NPC's brain
---@return number Threat level (0-1)
function Detection.CalculateThreatLevel(entityData, brain)
    local threat = 0

    if entityData.zombie then
        -- It's a zombie
        threat = Detection.Config.THREAT_ZOMBIE

        -- Closer = more threatening (tiered distance bonuses)
        if entityData.distance < 3 then
            threat = threat + 0.5  -- Very close = immediate flee (0.9 total)
        elseif entityData.distance < 6 then
            threat = threat + 0.3  -- Close = flee (0.7 total)
        elseif entityData.distance < 10 then
            threat = threat + 0.1  -- Nearby = alert (0.5 total)
        end

        -- Targeting the NPC = more threatening
        if entityData.targeting then
            threat = threat + 0.2
        end

    elseif entityData.player then
        -- It's a player
        if brain.hostileToPlayers then
            threat = Detection.Config.THREAT_HOSTILE_PLAYER
        else
            threat = 0.1  -- Low base threat for friendly players
        end

        -- Armed player
        if entityData.armed then
            threat = threat + 0.3
        end

        -- Threatening behavior
        if entityData.threatening then
            threat = threat + 0.4
        end

        -- Very close
        if entityData.distance < 3 then
            threat = threat + 0.2
        end

    elseif entityData.brain then
        -- It's another NPC
        if entityData.hostile and not entityData.sameFaction then
            threat = Detection.Config.THREAT_HOSTILE_NPC
        else
            threat = 0  -- Friendly NPC
        end
    end

    return math.min(1, math.max(0, threat))
end

---Get all threats sorted by threat level
---@param zombie IsoZombie
---@param brain table
---@return table Array of {entity, entityData, threatLevel, distance}
function Detection.GetThreats(zombie, brain)
    local threats = {}

    -- Detect all entities
    local players = Detection.DetectPlayers(zombie, brain)
    local zombies = Detection.DetectZombies(zombie, brain)
    local npcs = Detection.DetectNPCs(zombie, brain)

    -- Calculate threats for players
    for _, data in ipairs(players) do
        local threat = Detection.CalculateThreatLevel(data, brain)
        if threat > 0.1 then
            table.insert(threats, {
                type = "player",
                entity = data.player,
                data = data,
                threatLevel = threat,
                distance = data.distance,
            })
        end
    end

    -- Calculate threats for zombies
    for _, data in ipairs(zombies) do
        local threat = Detection.CalculateThreatLevel(data, brain)
        if threat > 0 then
            table.insert(threats, {
                type = "zombie",
                entity = data.zombie,
                data = data,
                threatLevel = threat,
                distance = data.distance,
            })
        end
    end

    -- Calculate threats for hostile NPCs
    for _, data in ipairs(npcs) do
        local threat = Detection.CalculateThreatLevel(data, brain)
        if threat > 0 then
            table.insert(threats, {
                type = "npc",
                entity = data.zombie,
                data = data,
                threatLevel = threat,
                distance = data.distance,
            })
        end
    end

    -- Sort by threat level (highest first)
    table.sort(threats, function(a, b) return a.threatLevel > b.threatLevel end)

    return threats
end

---Get the highest threat
---@param zombie IsoZombie
---@param brain table
---@return table|nil threat data
function Detection.GetHighestThreat(zombie, brain)
    local threats = Detection.GetThreats(zombie, brain)
    if #threats > 0 then
        return threats[1]
    end
    return nil
end

-- =============================================================================
-- SOUND DETECTION
-- =============================================================================

---Check if NPC can hear a sound from a location
---@param zombie IsoZombie The NPC
---@param soundX number Sound X position
---@param soundY number Sound Y position
---@param volume number Sound volume (0-1)
---@param soundType string Type of sound ("gunshot", "footstep", "voice", etc.)
---@return boolean
function Detection.CanHearSound(zombie, soundX, soundY, volume, soundType)
    if not zombie then return false end

    local npcX, npcY = zombie:getX(), zombie:getY()
    local distance = SentientNPC.Utils.DistTo(npcX, npcY, soundX, soundY)

    -- Determine hearing range based on sound type
    local hearingRange = Detection.Config.HEARING_RANGE_BASE

    if soundType == "gunshot" then
        hearingRange = Detection.Config.HEARING_RANGE_GUNSHOT
    elseif soundType == "footstep" then
        hearingRange = Detection.Config.HEARING_RANGE_FOOTSTEP
    end

    -- Adjust by volume
    hearingRange = hearingRange * volume

    return distance <= hearingRange
end

-- =============================================================================
-- ENVIRONMENTAL AWARENESS
-- =============================================================================

---Check if it's dark (affects vision)
---@return boolean
function Detection.IsDark()
    local hour = getGameTime():getHour()
    return hour < 6 or hour > 20
end

---Get current visibility modifier based on conditions
---@return number modifier (0-1)
function Detection.GetVisibilityModifier()
    local modifier = 1.0

    -- Night penalty
    if Detection.IsDark() then
        modifier = modifier * Detection.Config.VISION_NIGHT_PENALTY
    end

    -- Could add weather effects here (rain, fog)

    return modifier
end

---Get effective vision range considering conditions
---@param baseRange number|nil
---@return number
function Detection.GetEffectiveVisionRange(baseRange)
    baseRange = baseRange or Detection.Config.VISION_RANGE
    return baseRange * Detection.GetVisibilityModifier()
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Detection module loaded")

return Detection
