--[[
    SentientNPC - Brain.lua
    Brain system for NPC state management.

    The "brain" is a Lua table that stores ALL state for an NPC:
    - Identity (id, name, type)
    - Stats (health, endurance, mood)
    - Program state (current behavior)
    - Memory (past experiences)
    - Personality (traits that affect decisions)
    - Task queue (pending actions)

    This follows the Bandits mod architecture where brain data
    is stored separately from the zombie instance to survive
    object pooling.
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Brain = SentientNPC.Brain or {}
local Brain = SentientNPC.Brain

-- =============================================================================
-- NPC TYPES
-- =============================================================================

Brain.Types = {
    GENERIC = "generic",
    GUARD = "guard",
    MERCHANT = "merchant",
    WANDERER = "wanderer",
    SURVIVOR = "survivor",
    COMPANION = "companion",
}

-- =============================================================================
-- MOODS
-- =============================================================================

Brain.Moods = {
    HOSTILE = "hostile",
    ALERT = "alert",
    NEUTRAL = "neutral",
    FRIENDLY = "friendly",
    AFRAID = "afraid",
}

-- =============================================================================
-- ACTIONS (for task queue)
-- =============================================================================

Brain.Actions = {
    IDLE = "idle",
    MOVE = "move",
    PATROL = "patrol",
    ATTACK = "attack",
    FLEE = "flee",
    TRADE = "trade",
    DIALOGUE = "dialogue",
    ALERT = "alert",
    GUARD = "guard",
    FOLLOW = "follow",
    WAIT = "wait",
}

-- =============================================================================
-- DEFAULT VALUES
-- =============================================================================

local DEFAULT_PERSONALITY = {
    aggression = 0.5,       -- 0=passive, 1=aggressive
    bravery = 0.5,          -- 0=coward, 1=brave
    sociability = 0.5,      -- 0=loner, 1=social
    greed = 0.5,            -- 0=generous, 1=greedy
    loyalty = 0.5,          -- 0=disloyal, 1=loyal
    intelligence = 0.5,     -- affects decision quality
}

local DEFAULT_STATS = {
    healthMax = 100,
    health = 100,
    enduranceMax = 100,
    endurance = 100,
    hunger = 0,
    thirst = 0,
    tiredness = 0,
}

-- =============================================================================
-- BRAIN CREATION
-- =============================================================================

---Create a new brain for an NPC
---@param config table Configuration for the NPC
---@return table The new brain
function Brain.Create(config)
    config = config or {}

    local brain = {
        -- =====================================================================
        -- IDENTIFICATION
        -- =====================================================================
        id = config.id or SentientNPC.Utils.GenerateUUID(),
        persistentId = config.persistentId,     -- Zombie's persistent outfit ID
        onlineId = config.onlineId,             -- Zombie's online ID (volatile)

        name = config.name or Brain.GenerateName(config.female),
        type = config.type or Brain.Types.GENERIC,
        female = config.female or false,

        -- =====================================================================
        -- SPAWN INFO
        -- =====================================================================
        bornCoords = config.bornCoords or {x = 0, y = 0, z = 0},
        bornTime = SentientNPC.GetWorldHours(),
        createdTimestamp = SentientNPC.GetTimestamp(),

        -- =====================================================================
        -- AFFILIATION
        -- =====================================================================
        faction = config.faction or "neutral",
        group = config.group,                   -- Group ID if part of a group
        master = config.master,                 -- Player ID if companion

        -- =====================================================================
        -- HOSTILITY
        -- =====================================================================
        hostile = config.hostile or false,      -- Hostile to other NPCs
        hostileToPlayers = config.hostileToPlayers or false,

        -- =====================================================================
        -- CURRENT STATE
        -- =====================================================================
        mood = config.mood or Brain.Moods.NEUTRAL,
        state = "idle",                         -- Current high-level state

        sleeping = false,
        stationary = false,                     -- Forced to stay in place
        aiming = false,
        moving = false,
        inCombat = false,

        -- =====================================================================
        -- STATS
        -- =====================================================================
        stats = SentientNPC.Utils.DeepCopy(config.stats or DEFAULT_STATS),

        -- Multipliers (1.0 = normal)
        healthMult = config.healthMult or 1.0,
        damageMult = config.damageMult or 1.0,
        speedMult = config.speedMult or 1.0,
        accuracyMult = config.accuracyMult or 1.0,

        -- =====================================================================
        -- PROGRAM (Behavior Control)
        -- =====================================================================
        program = {
            name = config.program or "Idle",
            stage = "Prepare",
            data = {},                          -- Program-specific data
        },
        programFallback = config.program or "Idle",

        -- =====================================================================
        -- TASK QUEUE
        -- =====================================================================
        tasks = {},                             -- Queue of pending tasks
        currentTask = nil,                      -- Currently executing task
        taskState = "idle",                     -- idle, working, complete

        -- =====================================================================
        -- MEMORY SYSTEM
        -- =====================================================================
        memories = {},                          -- List of memory entries
        memoryLimit = config.memoryLimit or 50, -- Max memories to keep

        -- Short-term tracking
        lastSeenPlayers = {},                   -- playerId -> {x, y, z, timestamp}
        lastSeenThreats = {},                   -- threatId -> {x, y, z, timestamp, type}
        visitedLocations = {},                  -- List of visited coordinates

        -- =====================================================================
        -- PERSONALITY
        -- =====================================================================
        personality = SentientNPC.Utils.DeepCopy(config.personality or DEFAULT_PERSONALITY),

        -- =====================================================================
        -- APPEARANCE (for visual identification)
        -- =====================================================================
        skin = config.skin or SentientNPC.Utils.RandInt(1, 5),
        hairType = config.hairType or SentientNPC.Utils.RandInt(1, 10),
        hairColor = config.hairColor or SentientNPC.Utils.RandInt(1, 8),
        beardType = config.beardType or 0,
        clothing = config.clothing or {},

        -- =====================================================================
        -- VOICE AND DIALOGUE
        -- =====================================================================
        voice = config.voice or (config.female and "Female" or "Male"),
        speechCooldown = 0,                     -- Cooldown until can speak again
        lastDialogue = nil,                     -- Last thing said

        -- =====================================================================
        -- AI INTEGRATION
        -- =====================================================================
        ai = {
            enabled = config.aiEnabled ~= false,
            lastQuery = 0,                      -- Timestamp of last AI query
            pendingQuery = false,               -- Waiting for AI response
            lastDecision = nil,                 -- Last AI decision
            decisionCache = {},                 -- Cached decisions by context
        },

        -- =====================================================================
        -- RANDOM SEEDS (for consistent behavior variation)
        -- =====================================================================
        rnd = {
            ZombRand(100),
            ZombRand(100),
            ZombRand(100),
            ZombRand(100),
            ZombRand(100),
        },

        -- =====================================================================
        -- METADATA
        -- =====================================================================
        version = SentientNPC.VERSION,
        lastUpdate = SentientNPC.GetTimestamp(),
    }

    SentientNPC.Debug("Brain created: %s (type: %s)", brain.name, brain.type)

    return brain
end

-- =============================================================================
-- BRAIN STORAGE
-- =============================================================================

---Store a brain in ModData
---@param brain table The brain to store
function Brain.Store(brain)
    if not brain or not brain.id then
        SentientNPC.Error("Cannot store brain: invalid brain")
        return
    end

    local gmd = SentientNPC.GetModData()
    gmd.brains[brain.id] = brain
    brain.lastUpdate = SentientNPC.GetTimestamp()

    SentientNPC.Verbose("Brain stored: %s", brain.id)
end

---Get a brain by ID
---@param brainId string The brain ID
---@return table|nil The brain or nil
function Brain.Get(brainId)
    if not brainId then return nil end

    local gmd = SentientNPC.GetModData()
    return gmd.brains[brainId]
end

---Get brain by zombie's persistent ID
---@param persistentId number The zombie's persistent outfit ID
---@return table|nil The brain or nil
function Brain.GetByPersistentId(persistentId)
    if not persistentId then return nil end

    local gmd = SentientNPC.GetModData()
    for _, brain in pairs(gmd.brains) do
        if brain.persistentId == persistentId then
            return brain
        end
    end
    return nil
end

---Get brain from a zombie instance
---@param zombie IsoZombie The zombie
---@return table|nil The brain or nil
function Brain.GetFromZombie(zombie)
    if not zombie then return nil end

    -- First check variable
    local brainId = zombie:getVariableString("NPCBrainId")
    if brainId and brainId ~= "" then
        local brain = Brain.Get(brainId)
        if brain then return brain end
    end

    -- Fallback to persistent ID lookup
    local persistentId = SentientNPC.Utils.GetPersistentID(zombie)
    return Brain.GetByPersistentId(persistentId)
end

---Remove a brain
---@param brainId string The brain ID to remove
function Brain.Remove(brainId)
    if not brainId then return end

    local gmd = SentientNPC.GetModData()
    local brain = gmd.brains[brainId]

    if brain then
        SentientNPC.Debug("Brain removed: %s (%s)", brain.name, brainId)
        gmd.brains[brainId] = nil
        gmd.stats.activeNPCs = math.max(0, (gmd.stats.activeNPCs or 0) - 1)
    end
end

---Get all active brains
---@return table Dictionary of brainId -> brain
function Brain.GetAll()
    local gmd = SentientNPC.GetModData()
    return gmd.brains or {}
end

---Count active brains
---@return number Count
function Brain.Count()
    return SentientNPC.Utils.TableCount(Brain.GetAll())
end

-- =============================================================================
-- BRAIN UPDATES
-- =============================================================================

---Update brain from zombie state
---@param brain table The brain
---@param zombie IsoZombie The zombie instance
function Brain.SyncFromZombie(brain, zombie)
    if not brain or not zombie then return end

    -- Update volatile IDs
    brain.onlineId = SentientNPC.Utils.GetZombieOnlineID(zombie)

    -- Update position tracking
    brain.lastX = zombie:getX()
    brain.lastY = zombie:getY()
    brain.lastZ = zombie:getZ()

    -- Update movement state
    brain.moving = zombie:isMoving()

    brain.lastUpdate = SentientNPC.GetTimestamp()
end

---Apply brain state to zombie
---@param brain table The brain
---@param zombie IsoZombie The zombie
function Brain.ApplyToZombie(brain, zombie)
    if not brain or not zombie then return end

    -- Set the brain ID variable
    zombie:setVariable("NPCBrainId", brain.id)

    -- Apply movement state
    if brain.stationary then
        zombie:setMoving(false)
    end
end

-- =============================================================================
-- TASK MANAGEMENT
-- =============================================================================

---Add a task to the queue
---@param brain table The brain
---@param task table The task to add
function Brain.AddTask(brain, task)
    if not brain or not task then return end

    task.id = task.id or SentientNPC.Utils.GenerateUUID()
    task.addedAt = SentientNPC.GetTimestamp()
    task.state = "pending"

    table.insert(brain.tasks, task)

    SentientNPC.Verbose("Task added to %s: %s", brain.name, task.action or "unknown")
end

---Get the current/next task
---@param brain table The brain
---@return table|nil The current task
function Brain.GetCurrentTask(brain)
    if not brain then return nil end

    if brain.currentTask and brain.currentTask.state ~= "complete" then
        return brain.currentTask
    end

    -- Get next pending task
    if #brain.tasks > 0 then
        brain.currentTask = table.remove(brain.tasks, 1)
        brain.currentTask.state = "starting"
        return brain.currentTask
    end

    return nil
end

---Clear all tasks
---@param brain table The brain
function Brain.ClearTasks(brain)
    if not brain then return end
    brain.tasks = {}
    brain.currentTask = nil
    brain.taskState = "idle"
end

---Check if brain has tasks of a specific type
---@param brain table The brain
---@param actionType string The action type to check
---@return boolean
function Brain.HasTaskType(brain, actionType)
    if not brain then return false end

    if brain.currentTask and brain.currentTask.action == actionType then
        return true
    end

    for _, task in ipairs(brain.tasks) do
        if task.action == actionType then
            return true
        end
    end

    return false
end

-- =============================================================================
-- MEMORY SYSTEM
-- =============================================================================

---Add a memory to the NPC
---@param brain table The brain
---@param content string The memory content
---@param memoryType string|nil Type: "interaction", "observation", "emotion"
---@param importance number|nil Importance 0.0-1.0 (default 0.5)
---@param relatedEntities table|nil List of related entity IDs
function Brain.AddMemory(brain, content, memoryType, importance, relatedEntities)
    if not brain or not content then return end

    local memory = {
        id = SentientNPC.Utils.GenerateUUID(),
        content = content,
        type = memoryType or "observation",
        importance = importance or 0.5,
        timestamp = SentientNPC.GetTimestamp(),
        gameHours = SentientNPC.GetWorldHours(),
        accessCount = 0,
        relatedEntities = relatedEntities or {},
    }

    table.insert(brain.memories, memory)

    -- Trim old memories if over limit
    while #brain.memories > brain.memoryLimit do
        -- Remove least important old memory
        local minIdx = 1
        local minScore = 999

        for i, mem in ipairs(brain.memories) do
            local age = (SentientNPC.GetTimestamp() - mem.timestamp) / 3600000  -- hours
            local score = mem.importance - (age * 0.1)
            if score < minScore then
                minScore = score
                minIdx = i
            end
        end

        table.remove(brain.memories, minIdx)
    end

    SentientNPC.Verbose("Memory added to %s: %s", brain.name, content:sub(1, 50))
end

---Get relevant memories based on context
---@param brain table The brain
---@param context string Context to match against
---@param limit number|nil Maximum memories to return
---@return table List of memory strings
function Brain.GetRelevantMemories(brain, context, limit)
    limit = limit or 5

    if not brain or #brain.memories == 0 then
        return {}
    end

    -- Score memories by relevance (simplified - real version would use embeddings)
    local scored = {}
    local now = SentientNPC.GetTimestamp()

    for _, mem in ipairs(brain.memories) do
        local age = (now - mem.timestamp) / 3600000  -- Age in hours
        local recencyScore = math.exp(-age / 24)     -- Decay over 24 hours
        local importanceScore = mem.importance
        local accessBonus = math.min(0.2, mem.accessCount * 0.02)

        local score = (recencyScore * 0.3) + (importanceScore * 0.5) + accessBonus

        table.insert(scored, {memory = mem, score = score})
    end

    -- Sort by score descending
    table.sort(scored, function(a, b) return a.score > b.score end)

    -- Return top memories
    local result = {}
    for i = 1, math.min(limit, #scored) do
        scored[i].memory.accessCount = scored[i].memory.accessCount + 1
        table.insert(result, scored[i].memory.content)
    end

    return result
end

---Record seeing a player
---@param brain table The brain
---@param playerId number Player ID
---@param x number X position
---@param y number Y position
---@param z number Z position
function Brain.RecordPlayerSighting(brain, playerId, x, y, z)
    if not brain then return end

    brain.lastSeenPlayers[playerId] = {
        x = x,
        y = y,
        z = z,
        timestamp = SentientNPC.GetTimestamp(),
    }
end

---Record a threat sighting
---@param brain table The brain
---@param threatId number Threat ID
---@param threatType string Type of threat
---@param x number X position
---@param y number Y position
---@param z number Z position
function Brain.RecordThreatSighting(brain, threatId, threatType, x, y, z)
    if not brain then return end

    brain.lastSeenThreats[threatId] = {
        type = threatType,
        x = x,
        y = y,
        z = z,
        timestamp = SentientNPC.GetTimestamp(),
    }
end

-- =============================================================================
-- PERSONALITY
-- =============================================================================

---Generate random personality traits
---@return table Personality traits
function Brain.GeneratePersonality()
    local personality = {}

    for trait, _ in pairs(DEFAULT_PERSONALITY) do
        -- Generate with slight bias toward middle values
        local value = (SentientNPC.Utils.RandFloat(0, 1) + SentientNPC.Utils.RandFloat(0, 1)) / 2
        personality[trait] = SentientNPC.Utils.Round(value, 2)
    end

    return personality
end

---Get personality modifier for a decision
---@param brain table The brain
---@param trait string The trait name
---@param baseValue number Base value to modify
---@return number Modified value
function Brain.ApplyPersonalityModifier(brain, trait, baseValue)
    if not brain or not brain.personality then return baseValue end

    local traitValue = brain.personality[trait] or 0.5
    local modifier = (traitValue - 0.5) * 0.4  -- -0.2 to +0.2

    return baseValue + modifier
end

-- =============================================================================
-- NAME GENERATION
-- =============================================================================

local MALE_NAMES = {
    "John", "Michael", "David", "James", "Robert", "William", "Thomas",
    "Daniel", "Richard", "Charles", "Joseph", "Mark", "Steven", "Paul",
    "Andrew", "Joshua", "Kenneth", "Kevin", "Brian", "George", "Edward",
    "Ronald", "Timothy", "Jason", "Jeffrey", "Ryan", "Jacob", "Gary",
    "Nicholas", "Eric", "Jonathan", "Stephen", "Larry", "Justin", "Scott",
}

local FEMALE_NAMES = {
    "Mary", "Patricia", "Jennifer", "Linda", "Elizabeth", "Barbara", "Susan",
    "Jessica", "Sarah", "Karen", "Nancy", "Lisa", "Betty", "Margaret",
    "Sandra", "Ashley", "Dorothy", "Kimberly", "Emily", "Donna", "Michelle",
    "Carol", "Amanda", "Melissa", "Deborah", "Stephanie", "Rebecca", "Sharon",
    "Laura", "Cynthia", "Kathleen", "Amy", "Angela", "Shirley", "Anna",
}

local LAST_NAMES = {
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
    "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
    "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
    "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
    "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
}

---Generate a random name
---@param female boolean|nil Generate female name
---@return string Full name
function Brain.GenerateName(female)
    local firstName = female
        and SentientNPC.Utils.Choice(FEMALE_NAMES)
        or SentientNPC.Utils.Choice(MALE_NAMES)
    local lastName = SentientNPC.Utils.Choice(LAST_NAMES)
    return firstName .. " " .. lastName
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Brain module loaded")

return Brain
