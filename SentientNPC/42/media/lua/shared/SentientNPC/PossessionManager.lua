--[[
    SentientNPC - PossessionManager.lua
    System for "possessing" zombies to convert them into NPCs.

    Core concept: We use vanilla zombies as containers for NPCs.
    This leverages the game's existing:
    - Pathfinding system
    - Animation system
    - Collision detection
    - Multiplayer synchronization

    A "possessed" zombie:
    - Cannot bite (setNoTeeth(true))
    - Has custom variables identifying it as NPC
    - Is controlled by our Brain/Program system
    - Maintains a linked "brain" in ModData
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"
require "SentientNPC/Brain"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Possession = SentientNPC.Possession or {}
local Possession = SentientNPC.Possession

-- =============================================================================
-- ZOMBIE VARIABLES (set on possessed zombies)
-- =============================================================================

-- Variable names used to mark possessed zombies
Possession.VAR_POSSESSED = "Possessed"          -- boolean: true if NPC
Possession.VAR_NPC_ID = "NPCId"                 -- string: unique NPC ID
Possession.VAR_NPC_TYPE = "NPCType"             -- string: NPC type
Possession.VAR_NPC_NAME = "NPCName"             -- string: display name
Possession.VAR_BRAIN_ID = "NPCBrainId"          -- string: brain ID
Possession.VAR_HOSTILE = "NPCHostile"           -- boolean: hostile to players
Possession.VAR_WALK_TYPE = "NPCWalkType"        -- string: current walk animation

-- =============================================================================
-- POSSESSION QUEUE
-- =============================================================================

-- Queue of pending possessions (server creates brain, client applies it)
-- Structure: persistentId -> brain config
local possessionQueue = {}

---Add to possession queue (server-side)
---@param persistentId number Zombie's persistent ID
---@param brainConfig table Brain configuration
function Possession.QueuePossession(persistentId, brainConfig)
    local gmd = SentientNPC.GetModData()
    gmd.queue[persistentId] = brainConfig

    SentientNPC.Debug("Queued possession for zombie %d", persistentId)
end

---Check if zombie has pending possession
---@param zombie IsoZombie The zombie
---@return table|nil Brain config if pending
function Possession.CheckQueue(zombie)
    if not zombie then return nil end

    local persistentId = SentientNPC.Utils.GetPersistentID(zombie)
    if not persistentId then return nil end

    local gmd = SentientNPC.GetModData()
    local config = gmd.queue[persistentId]

    if config then
        gmd.queue[persistentId] = nil
        return config
    end

    return nil
end

-- =============================================================================
-- CORE POSSESSION FUNCTIONS
-- =============================================================================

---Possess a zombie, converting it to an NPC
---@param zombie IsoZombie The zombie to possess
---@param config table|nil Configuration for the NPC
---@return boolean success
---@return string|table brainIdOrError
function Possession.Possess(zombie, config)
    -- Validate zombie
    if not zombie then
        return false, "invalid_zombie"
    end

    if zombie:isDead() then
        return false, "zombie_is_dead"
    end

    -- Check if already possessed
    if Possession.IsPossessed(zombie) then
        return false, "already_possessed"
    end

    -- Check NPC limit
    local gmd = SentientNPC.GetModData()
    if SentientNPC.Brain.Count() >= SentientNPC.Config.MAX_NPCS then
        return false, "npc_limit_reached"
    end

    config = config or {}

    -- Get persistent ID (survives object pooling)
    local persistentId = SentientNPC.Utils.GetPersistentID(zombie)
    local onlineId = SentientNPC.Utils.GetZombieOnlineID(zombie)

    -- Create brain
    local brainConfig = {
        id = config.id or SentientNPC.Utils.GenerateUUID(),
        persistentId = persistentId,
        onlineId = onlineId,
        name = config.name,
        type = config.type or SentientNPC.Brain.Types.GENERIC,
        female = config.female or zombie:isFemale(),
        bornCoords = {
            x = zombie:getX(),
            y = zombie:getY(),
            z = zombie:getZ(),
        },
        hostile = config.hostile or false,
        hostileToPlayers = config.hostileToPlayers or false,
        faction = config.faction,
        program = config.program or "Idle",
        master = config.master,
        personality = config.personality or SentientNPC.Brain.GeneratePersonality(),
        aiEnabled = config.aiEnabled,
        stats = config.stats,
    }

    local brain = SentientNPC.Brain.Create(brainConfig)

    -- Apply zombie modifications
    Possession.ApplyToZombie(zombie, brain)

    -- Store brain
    SentientNPC.Brain.Store(brain)

    -- Update stats
    gmd.stats.totalSpawned = (gmd.stats.totalSpawned or 0) + 1
    gmd.stats.activeNPCs = SentientNPC.Brain.Count()

    -- Sync in multiplayer
    if SentientNPC.IsServer() then
        SentientNPC.TransmitModData()
    end

    SentientNPC.Info("Possessed zombie as NPC: %s (ID: %s, Type: %s)",
        brain.name, brain.id, brain.type)

    return true, brain.id
end

---Apply NPC state to a zombie
---@param zombie IsoZombie The zombie
---@param brain table The brain
function Possession.ApplyToZombie(zombie, brain)
    if not zombie or not brain then return end

    -- Mark as possessed
    zombie:setVariable(Possession.VAR_POSSESSED, true)
    zombie:setVariable(Possession.VAR_NPC_ID, brain.id)
    zombie:setVariable(Possession.VAR_NPC_TYPE, brain.type)
    zombie:setVariable(Possession.VAR_NPC_NAME, brain.name)
    zombie:setVariable(Possession.VAR_BRAIN_ID, brain.id)
    zombie:setVariable(Possession.VAR_HOSTILE, brain.hostileToPlayers)

    -- Disable zombie attack behavior
    zombie:setNoTeeth(true)

    -- CRITICAL: Clear zombie's target to stop it from chasing players
    -- Without this, the zombie AI will still pursue targets even with setNoTeeth
    zombie:setTarget(nil)

    -- Reset pathfinding to stop current chase
    local pathBehavior = zombie:getPathFindBehavior2()
    if pathBehavior then
        pathBehavior:cancel()
    end

    -- Store reference in local cache
    SentientNPC.LocalCache.zombies[brain.persistentId] = zombie

    -- Apply brain state
    SentientNPC.Brain.ApplyToZombie(brain, zombie)

    SentientNPC.Debug("Applied NPC state to zombie: %s", brain.name)
end

---Release a possessed zombie, returning it to normal
---@param zombie IsoZombie The zombie to release
---@return boolean success
function Possession.Release(zombie)
    if not zombie then return false end

    if not Possession.IsPossessed(zombie) then
        return false
    end

    local brain = SentientNPC.Brain.GetFromZombie(zombie)
    local npcName = brain and brain.name or "Unknown"

    -- Clear variables
    zombie:setVariable(Possession.VAR_POSSESSED, false)
    zombie:clearVariable(Possession.VAR_NPC_ID)
    zombie:clearVariable(Possession.VAR_NPC_TYPE)
    zombie:clearVariable(Possession.VAR_NPC_NAME)
    zombie:clearVariable(Possession.VAR_BRAIN_ID)
    zombie:clearVariable(Possession.VAR_HOSTILE)
    zombie:clearVariable(Possession.VAR_WALK_TYPE)

    -- Restore zombie behavior
    zombie:setNoTeeth(false)

    -- Remove brain
    if brain then
        local persistentId = brain.persistentId
        SentientNPC.Brain.Remove(brain.id)

        -- Clear from local cache
        SentientNPC.LocalCache.zombies[persistentId] = nil
    end

    -- Sync
    if SentientNPC.IsServer() then
        SentientNPC.TransmitModData()
    end

    SentientNPC.Info("Released NPC: %s", npcName)

    return true
end

-- =============================================================================
-- STATE CHECKING
-- =============================================================================

---Check if a zombie is possessed (is an NPC)
---@param zombie IsoZombie The zombie
---@return boolean
function Possession.IsPossessed(zombie)
    if not zombie then return false end
    return zombie:getVariableBoolean(Possession.VAR_POSSESSED)
end

---Get NPC ID from zombie
---@param zombie IsoZombie The zombie
---@return string|nil NPC ID
function Possession.GetNPCId(zombie)
    if not zombie then return nil end
    local id = zombie:getVariableString(Possession.VAR_NPC_ID)
    return (id and id ~= "") and id or nil
end

---Get NPC type from zombie
---@param zombie IsoZombie The zombie
---@return string|nil NPC type
function Possession.GetNPCType(zombie)
    if not zombie then return nil end
    local npcType = zombie:getVariableString(Possession.VAR_NPC_TYPE)
    return (npcType and npcType ~= "") and npcType or nil
end

---Get NPC name from zombie
---@param zombie IsoZombie The zombie
---@return string|nil NPC name
function Possession.GetNPCName(zombie)
    if not zombie then return nil end
    local name = zombie:getVariableString(Possession.VAR_NPC_NAME)
    return (name and name ~= "") and name or nil
end

---Check if NPC is hostile to players
---@param zombie IsoZombie The zombie
---@return boolean
function Possession.IsHostile(zombie)
    if not zombie then return false end
    return zombie:getVariableBoolean(Possession.VAR_HOSTILE)
end

-- =============================================================================
-- ZOMBIE FINDING
-- =============================================================================

---Find zombie by persistent ID
---@param persistentId number The persistent ID
---@return IsoZombie|nil
function Possession.FindZombieByPersistentId(persistentId)
    if not persistentId then return nil end

    -- Check cache first
    local cached = SentientNPC.LocalCache.zombies[persistentId]
    if cached and not cached:isDead() then
        -- Verify it's still the right zombie
        if SentientNPC.Utils.GetPersistentID(cached) == persistentId then
            return cached
        end
    end

    -- Search all zombies
    local cell = getCell()
    if not cell then return nil end

    local zombieList = cell:getZombieList()
    if not zombieList then return nil end

    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if zombie and SentientNPC.Utils.GetPersistentID(zombie) == persistentId then
            -- Update cache
            SentientNPC.LocalCache.zombies[persistentId] = zombie
            return zombie
        end
    end

    return nil
end

---Get zombie instance for a brain
---@param brain table The brain
---@return IsoZombie|nil
function Possession.GetZombieForBrain(brain)
    if not brain then return nil end
    return Possession.FindZombieByPersistentId(brain.persistentId)
end

---Get all possessed zombies
---@return table Array of zombies
function Possession.GetAllPossessed()
    local result = {}

    local cell = getCell()
    if not cell then return result end

    local zombieList = cell:getZombieList()
    if not zombieList then return result end

    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if zombie and Possession.IsPossessed(zombie) then
            table.insert(result, zombie)
        end
    end

    return result
end

-- =============================================================================
-- OBJECT POOLING HANDLING
-- =============================================================================

-- When zombies are recycled (object pooling), we need to re-possess them
-- This is called from OnZombieCreate event

---Handle zombie creation (object pooling)
---@param zombie IsoZombie The newly created/recycled zombie
function Possession.OnZombieCreate(zombie)
    if not zombie then return end

    local persistentId = SentientNPC.Utils.GetPersistentID(zombie)

    -- Check if this zombie should be an NPC (from queue)
    local queuedConfig = Possession.CheckQueue(zombie)
    if queuedConfig then
        -- Apply possession from queue
        Possession.Possess(zombie, queuedConfig)
        return
    end

    -- Check if there's an orphaned brain for this persistent ID
    local brain = SentientNPC.Brain.GetByPersistentId(persistentId)
    if brain then
        -- Re-apply possession (zombie was recycled)
        SentientNPC.Debug("Re-possessing recycled zombie: %s", brain.name)
        Possession.ApplyToZombie(zombie, brain)

        -- Update brain with new online ID
        brain.onlineId = SentientNPC.Utils.GetZombieOnlineID(zombie)
    else
        -- Clean up any stale possession state
        if zombie:getVariableBoolean(Possession.VAR_POSSESSED) then
            SentientNPC.Warn("Cleaning orphaned possession state from zombie")
            zombie:setVariable(Possession.VAR_POSSESSED, false)
            zombie:clearVariable(Possession.VAR_NPC_ID)
            zombie:setNoTeeth(false)
        end
    end
end

---Handle zombie death
---@param zombie IsoZombie The dead zombie
function Possession.OnZombieDead(zombie)
    if not zombie then return end

    if not Possession.IsPossessed(zombie) then return end

    local brain = SentientNPC.Brain.GetFromZombie(zombie)
    if brain then
        SentientNPC.Info("NPC died: %s", brain.name)

        -- Update stats
        local gmd = SentientNPC.GetModData()
        gmd.stats.totalDied = (gmd.stats.totalDied or 0) + 1

        -- Remove brain
        SentientNPC.Brain.Remove(brain.id)

        -- Clean cache
        SentientNPC.LocalCache.zombies[brain.persistentId] = nil

        -- Sync
        if SentientNPC.IsServer() then
            SentientNPC.TransmitModData()
        end
    end
end

-- =============================================================================
-- SPAWNING
-- =============================================================================

---Spawn a new NPC at a location
---@param x number X coordinate
---@param y number Y coordinate
---@param z number Z coordinate
---@param config table|nil NPC configuration
---@return boolean success
---@return string|nil npcIdOrError
function Possession.SpawnNPC(x, y, z, config)
    config = config or {}

    -- Verify location
    local square = SentientNPC.Utils.GetSquare(x, y, z)
    if not square then
        return false, "invalid_location"
    end

    if not SentientNPC.Utils.IsWalkable(square) then
        -- Try to find nearby walkable square
        square = SentientNPC.Utils.FindWalkableSquare(x, y, z, 3)
        if not square then
            return false, "no_walkable_square"
        end
        x, y, z = square:getX(), square:getY(), square:getZ()
    end

    -- Determine outfit
    local outfit = config.outfit or "Naked"
    local female = config.female and 1 or 0

    -- Spawn zombie using game API
    local zombieList
    if SentientNPC.IsBuild42() then
        -- Build 42 API (has sitting parameter)
        zombieList = addZombiesInOutfit(x, y, z, 1, outfit, female,
            false,  -- crawler
            false,  -- fallOnFront
            false,  -- fakeDead
            false,  -- knockedDown
            false,  -- invulnerable
            false,  -- sitting
            1.0)    -- health
    else
        -- Build 41 API
        zombieList = addZombiesInOutfit(x, y, z, 1, outfit, female,
            false, false, false, false, 1.0)
    end

    if not zombieList or zombieList:size() == 0 then
        return false, "spawn_failed"
    end

    local zombie = zombieList:get(0)
    if not zombie then
        return false, "spawn_failed"
    end

    -- Possess the zombie
    config.female = config.female or zombie:isFemale()
    local success, result = Possession.Possess(zombie, config)

    if success then
        SentientNPC.Info("Spawned NPC at (%d, %d, %d): %s",
            x, y, z, config.name or result)
    end

    return success, result
end

---Spawn NPC near a player
---@param player IsoPlayer The player
---@param distance number Distance from player
---@param config table|nil NPC configuration
---@return boolean success
---@return string|nil npcIdOrError
function Possession.SpawnNearPlayer(player, distance, config)
    if not player then return false, "invalid_player" end

    local px, py, pz = player:getX(), player:getY(), player:getZ()

    -- Random angle
    local angle = SentientNPC.Utils.RandFloat(0, math.pi * 2)
    local x = px + math.cos(angle) * distance
    local y = py + math.sin(angle) * distance

    return Possession.SpawnNPC(math.floor(x), math.floor(y), pz, config)
end

-- =============================================================================
-- EVENT REGISTRATION
-- =============================================================================

-- Register for zombie events
Events.OnZombieCreate.Add(Possession.OnZombieCreate)
Events.OnZombieDead.Add(Possession.OnZombieDead)

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("PossessionManager module loaded")

return Possession
