--[[
    SentientNPC - Update.lua (Client)
    Main update loop for NPC behavior.

    This module hooks into OnZombieUpdate to process possessed zombies.
    It handles:
    - Rate-limited brain updates
    - Task execution
    - State synchronization
    - AI decision polling

    IMPORTANT: OnZombieUpdate is called VERY frequently (every tick).
    All expensive operations must be rate-limited.
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"
require "SentientNPC/Brain"
require "SentientNPC/PossessionManager"
require "SentientNPC/Detection"
-- UI se carga en OnGameStart, no aquí

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Update = SentientNPC.Update or {}
local Update = SentientNPC.Update

-- =============================================================================
-- UPDATE STATE
-- =============================================================================

Update.enabled = true
Update.lastFullUpdate = {}         -- npcId -> timestamp
Update.lastSyncUpdate = 0          -- Global sync timestamp
Update.processedThisTick = 0       -- Counter for this tick
Update.maxPerTick = 10             -- Max NPCs to fully process per tick

-- =============================================================================
-- MAIN UPDATE LOOP
-- =============================================================================

---Main update function called for every zombie every tick
---@param zombie IsoZombie The zombie being updated
function Update.OnZombieUpdate(zombie)
    if not Update.enabled then return end
    if not zombie then return end

    -- Quick check: is this a possessed NPC?
    if not SentientNPC.Possession.IsPossessed(zombie) then
        return
    end

    -- Get brain
    local brain = SentientNPC.Brain.GetFromZombie(zombie)
    if not brain then
        -- Orphaned possession state - clean it up
        SentientNPC.Warn("Orphaned NPC found, releasing")
        SentientNPC.Possession.Release(zombie)
        return
    end

    local now = SentientNPC.GetTimestamp()

    -- ==========================================================================
    -- LIGHT UPDATE (every tick)
    -- ==========================================================================
    Update.LightUpdate(zombie, brain, now)

    -- ==========================================================================
    -- FULL UPDATE (rate limited)
    -- ==========================================================================
    local lastFull = Update.lastFullUpdate[brain.id] or 0
    if (now - lastFull) >= SentientNPC.Config.UPDATE_RATE_FULL then
        -- Limit how many NPCs we fully process per tick
        if Update.processedThisTick < Update.maxPerTick then
            Update.FullUpdate(zombie, brain, now)
            Update.lastFullUpdate[brain.id] = now
            Update.processedThisTick = Update.processedThisTick + 1
        end
    end
end

---Light update - runs every tick, must be fast
---@param zombie IsoZombie
---@param brain table
---@param now number Current timestamp
function Update.LightUpdate(zombie, brain, now)
    -- Update position in brain
    brain.lastX = zombie:getX()
    brain.lastY = zombie:getY()
    brain.lastZ = zombie:getZ()

    -- Update movement state
    brain.moving = zombie:isMoving()

    -- CRITICAL: Prevent zombie AI from targeting players
    -- The native zombie AI continuously tries to acquire targets
    -- We must clear it every tick unless the NPC is hostile
    if not brain.hostileToPlayers then
        local currentTarget = zombie:getTarget()
        if currentTarget and instanceof(currentTarget, "IsoPlayer") then
            zombie:setTarget(nil)
        end
    end
end

---Full update - runs rate-limited, can do heavier processing
---@param zombie IsoZombie
---@param brain table
---@param now number Current timestamp
function Update.FullUpdate(zombie, brain, now)
    -- Sync brain from zombie
    SentientNPC.Brain.SyncFromZombie(brain, zombie)

    -- Check if we're the controller for this zombie
    local isController = SentientNPC.IsController(zombie)

    -- ==========================================================================
    -- MANAGE STATE
    -- ==========================================================================
    Update.ManageHealth(zombie, brain)
    Update.ManageSpeech(zombie, brain, now)

    -- Only controller runs AI logic
    if isController then
        -- ==========================================================================
        -- EXECUTE CURRENT TASK
        -- ==========================================================================
        Update.ExecuteTask(zombie, brain, now)

        -- ==========================================================================
        -- RUN PROGRAM (if no task active)
        -- ==========================================================================
        if not brain.currentTask or brain.currentTask.state == "complete" then
            Update.RunProgram(zombie, brain, now)
        end
    end

    -- Update brain last update time
    brain.lastUpdate = now
end

-- =============================================================================
-- STATE MANAGEMENT
-- =============================================================================

---Manage NPC health state
---@param zombie IsoZombie
---@param brain table
function Update.ManageHealth(zombie, brain)
    local health = zombie:getHealth()

    -- Update brain health
    brain.stats.health = health * brain.stats.healthMax

    -- Check for death
    if health <= 0 then
        SentientNPC.Debug("NPC health depleted: %s", brain.name)
        -- Death is handled by OnZombieDead event
    end
end

---Manage speech cooldown
---@param zombie IsoZombie
---@param brain table
---@param now number
function Update.ManageSpeech(zombie, brain, now)
    if brain.speechCooldown > 0 then
        brain.speechCooldown = math.max(0, brain.speechCooldown - 100)
    end
end

-- =============================================================================
-- TASK EXECUTION
-- =============================================================================

---Execute current task
---@param zombie IsoZombie
---@param brain table
---@param now number
function Update.ExecuteTask(zombie, brain, now)
    local task = SentientNPC.Brain.GetCurrentTask(brain)
    if not task then return end

    local action = task.action or "idle"
    local actionModule = SentientNPC.Actions and SentientNPC.Actions[action]

    -- If no action module, mark complete
    if not actionModule then
        task.state = "complete"
        SentientNPC.Verbose("No action handler for: %s", action)
        return
    end

    -- State machine
    if task.state == "starting" then
        -- Initialize task
        local success = true
        if actionModule.onStart then
            success = actionModule.onStart(zombie, brain, task)
        end

        if success then
            task.state = "working"
            task.startTime = now
        else
            task.state = "complete"
            SentientNPC.Verbose("Task failed to start: %s", action)
        end

    elseif task.state == "working" then
        -- Execute task
        local complete = false
        if actionModule.onWorking then
            complete = actionModule.onWorking(zombie, brain, task)
        end

        -- Check timeout
        local timeout = task.timeout or 10000
        if (now - (task.startTime or now)) > timeout then
            complete = true
            SentientNPC.Verbose("Task timeout: %s", action)
        end

        if complete then
            -- Finish task
            if actionModule.onComplete then
                actionModule.onComplete(zombie, brain, task)
            end
            task.state = "complete"
        end
    end
end

-- =============================================================================
-- PROGRAM EXECUTION
-- =============================================================================

---Run the current program stage
---@param zombie IsoZombie
---@param brain table
---@param now number
function Update.RunProgram(zombie, brain, now)
    local programName = brain.program.name
    local stage = brain.program.stage

    -- Get program module
    local program = SentientNPC.Programs and SentientNPC.Programs[programName]
    if not program then
        -- Fall back to Idle
        programName = "Idle"
        program = SentientNPC.Programs and SentientNPC.Programs.Idle
    end

    if not program then
        SentientNPC.Warn("No program found: %s", programName)
        return
    end

    -- Get stage function
    local stageFunc = program[stage]
    if not stageFunc then
        SentientNPC.Warn("No stage %s in program %s", stage, programName)
        brain.program.stage = "Prepare"
        return
    end

    -- Execute stage
    local result = stageFunc(zombie, brain)

    if result then
        -- Update stage
        if result.next then
            brain.program.stage = result.next
        end

        -- Add returned tasks
        if result.tasks then
            for _, task in ipairs(result.tasks) do
                SentientNPC.Brain.AddTask(brain, task)
            end
        end

        -- Handle program change
        if result.program then
            brain.program.name = result.program
            brain.program.stage = "Prepare"
            brain.program.data = result.programData or {}
        end
    end
end

-- =============================================================================
-- TICK MANAGEMENT
-- =============================================================================

---Reset per-tick counters (called at start of each game tick)
function Update.OnTick()
    Update.processedThisTick = 0

    -- Global sync (less frequent)
    local now = SentientNPC.GetTimestamp()
    if (now - Update.lastSyncUpdate) > SentientNPC.Config.UPDATE_RATE_SYNC then
        Update.lastSyncUpdate = now
        -- Any global sync operations here
    end
end

-- =============================================================================
-- CULLING
-- =============================================================================

---Check if zombie is within processing range of any player
---@param zombie IsoZombie
---@return boolean
function Update.ShouldProcess(zombie)
    if not zombie then return false end

    local zx, zy = zombie:getX(), zombie:getY()
    local cullDist = SentientNPC.Config.CULLING_DISTANCE

    local players = getOnlinePlayers()
    if not players then return true end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local dist = SentientNPC.Utils.DistTo(zx, zy, player:getX(), player:getY())
            if dist <= cullDist then
                return true
            end
        end
    end

    return false
end

-- =============================================================================
-- ENABLE/DISABLE
-- =============================================================================

---Enable NPC updates
function Update.Enable()
    Update.enabled = true
    SentientNPC.Info("NPC updates enabled")
end

---Disable NPC updates
function Update.Disable()
    Update.enabled = false
    SentientNPC.Info("NPC updates disabled")
end

-- =============================================================================
-- CONSOLE COMMANDS (for testing without UI)
-- =============================================================================

local function registerConsoleCommands()
    -- Quick spawn
    _G.snpcSpawn = function(name, program)
        local player = getPlayer()
        if not player then
            print("[SentientNPC] No player found")
            return
        end

        -- Build config
        local config = {
            name = name or "NPC_" .. ZombRand(1000, 9999),
            program = program or "Idle",
        }

        -- If Follow program, set master to player's onlineID (Bandits pattern)
        if program == "Follow" or program == "Companion" then
            config.master = player:getOnlineID()
        end

        local success, result = SentientNPC.Possession.SpawnNearPlayer(player, 5, config)

        if success then
            print("[SentientNPC] Spawned: " .. (name or "NPC") .. " with ID: " .. tostring(result))
        else
            print("[SentientNPC] Error: " .. tostring(result))
        end
    end

    -- Quick delete all
    _G.snpcClear = function()
        local zombies = SentientNPC.Possession.GetAllPossessed()
        local count = #zombies
        for _, zombie in ipairs(zombies) do
            SentientNPC.Possession.Release(zombie)
            zombie:removeFromWorld()
        end
        print("[SentientNPC] Deleted " .. count .. " NPCs")
    end

    -- List NPCs
    _G.snpcList = function()
        local brains = SentientNPC.Brain.GetAll()
        local count = 0
        for id, brain in pairs(brains) do
            print(string.format("  [%s] %s - %s (%s)",
                id, brain.name, brain.program.name, brain.program.stage))
            count = count + 1
        end
        print("[SentientNPC] Total: " .. count .. " NPCs")
    end

    -- Change program for all NPCs
    _G.snpcProgram = function(programName)
        local brains = SentientNPC.Brain.GetAll()
        local count = 0
        for id, brain in pairs(brains) do
            brain.program.name = programName or "Idle"
            brain.program.stage = "Prepare"
            brain.program.data = {}
            if programName == "Follow" then
                local player = getPlayer()
                if player then
                    -- Use onlineID for multiplayer compatibility (Bandits pattern)
                    brain.master = player:getOnlineID()
                end
            end
            count = count + 1
        end
        print("[SentientNPC] Changed " .. count .. " NPCs to " .. (programName or "Idle"))
    end

    -- Make NPC come to player
    _G.snpcCome = function()
        local player = getPlayer()
        if not player then return end

        local brains = SentientNPC.Brain.GetAll()
        for id, brain in pairs(brains) do
            brain.tasks = {}
            SentientNPC.Brain.AddTask(brain, {
                action = "move",
                x = player:getX() + 2,
                y = player:getY() + 2,
                z = player:getZ(),
                walkType = "Run",
                tolerance = 1.5,
                timeout = 30000,
            })
        end
        print("[SentientNPC] NPCs coming to you")
    end

    SentientNPC.Debug("Console commands registered: snpcSpawn(), snpcClear(), snpcList(), snpcProgram(), snpcCome()")
end

-- =============================================================================
-- EVENT REGISTRATION
-- =============================================================================

-- Main zombie update hook
Events.OnZombieUpdate.Add(Update.OnZombieUpdate)

-- Per-tick reset
Events.OnTick.Add(Update.OnTick)

-- Register console commands on game start
Events.OnGameStart.Add(registerConsoleCommands)

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Update module (client) loaded")

return Update
