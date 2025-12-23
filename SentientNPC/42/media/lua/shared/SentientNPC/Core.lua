--[[
    SentientNPC - Core.lua
    Main namespace and initialization for the SentientNPC mod.

    This mod creates NPCs with hybrid AI (rule-based + optional LLM).
    NPCs use zombies as containers following the Bandits mod architecture.

    Author: SentientNPC Team
    Version: 0.1.0
    Build: 42
]]

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC = SentientNPC or {}

-- Version info
SentientNPC.VERSION = "0.1.0"
SentientNPC.BUILD = 42
SentientNPC.MOD_ID = "SentientNPC"

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

SentientNPC.Config = {
    -- Debug settings
    DEBUG = true,
    DEBUG_VERBOSE = false,

    -- Update rates (in milliseconds)
    UPDATE_RATE_LIGHT = 0,          -- Every tick for position
    UPDATE_RATE_FULL = 100,         -- 100ms for full brain update
    UPDATE_RATE_AI = 1000,          -- 1s for AI decisions
    UPDATE_RATE_SYNC = 500,         -- 500ms for MP sync

    -- AI settings
    AI_ENABLED = true,
    AI_TIMEOUT = 3000,              -- Max wait for AI response
    AI_RATE_LIMIT = 5000,           -- Min interval between LLM queries per NPC

    -- Detection ranges
    DETECT_PLAYER_RANGE = 30,
    DETECT_ZOMBIE_RANGE = 20,
    DETECT_NPC_RANGE = 40,
    HEAR_RANGE_BASE = 10,

    -- Performance
    MAX_NPCS = 50,
    CULLING_DISTANCE = 100,         -- Don't process NPCs further than this

    -- Spawning
    SPAWN_MIN_DISTANCE = 30,
    SPAWN_MAX_DISTANCE = 60,
}

-- =============================================================================
-- STATE MANAGEMENT
-- =============================================================================

-- Global mod data key
SentientNPC.MOD_DATA_KEY = "SentientNPC_State"

-- Local caches (not synced, rebuilt on each client)
SentientNPC.LocalCache = {
    zombies = {},           -- onlineID -> zombie reference (temporary)
    lastUpdate = {},        -- npcId -> timestamp of last full update
    lastAIQuery = {},       -- npcId -> timestamp of last AI query
    pendingAI = {},         -- npcId -> true if waiting for AI response
}

-- =============================================================================
-- MODDATA ACCESS
-- =============================================================================

---Get or create the global mod data for SentientNPC
---@return table The global mod data table
function SentientNPC.GetModData()
    local gmd = ModData.getOrCreate(SentientNPC.MOD_DATA_KEY)

    -- Initialize structure if needed
    if not gmd.brains then gmd.brains = {} end
    if not gmd.queue then gmd.queue = {} end          -- Pending spawns
    if not gmd.stats then gmd.stats = {
        totalSpawned = 0,
        totalDied = 0,
        activeNPCs = 0,
    } end
    if not gmd.timestamp then gmd.timestamp = 0 end

    return gmd
end

---Transmit mod data to all clients (call from server/host only)
function SentientNPC.TransmitModData()
    if isClient() and not isCoopHost() then return end

    local gmd = SentientNPC.GetModData()
    gmd.timestamp = getTimestampMs()
    ModData.transmit(SentientNPC.MOD_DATA_KEY)
end

-- =============================================================================
-- LOGGING
-- =============================================================================

---Log a message with prefix
---@param level string Log level: "INFO", "WARN", "ERROR", "DEBUG"
---@param message string The message to log
---@param ... any Additional arguments for string.format
function SentientNPC.Log(level, message, ...)
    if level == "DEBUG" and not SentientNPC.Config.DEBUG then return end
    if level == "VERBOSE" and not SentientNPC.Config.DEBUG_VERBOSE then return end

    local formatted = message
    if select("#", ...) > 0 then
        formatted = string.format(message, ...)
    end

    local prefix = "[SentientNPC]"
    if level == "WARN" then
        prefix = "[SentientNPC:WARN]"
    elseif level == "ERROR" then
        prefix = "[SentientNPC:ERROR]"
    elseif level == "DEBUG" then
        prefix = "[SentientNPC:DEBUG]"
    end

    print(prefix .. " " .. formatted)
end

-- Shorthand logging functions
function SentientNPC.Info(msg, ...) SentientNPC.Log("INFO", msg, ...) end
function SentientNPC.Warn(msg, ...) SentientNPC.Log("WARN", msg, ...) end
function SentientNPC.Error(msg, ...) SentientNPC.Log("ERROR", msg, ...) end
function SentientNPC.Debug(msg, ...) SentientNPC.Log("DEBUG", msg, ...) end
function SentientNPC.Verbose(msg, ...) SentientNPC.Log("VERBOSE", msg, ...) end

-- =============================================================================
-- ENVIRONMENT DETECTION
-- =============================================================================

---Check if running on server
---@return boolean
function SentientNPC.IsServer()
    return isServer() or isCoopHost()
end

---Check if running on client (includes singleplayer)
---@return boolean
function SentientNPC.IsClient()
    return not isServer()
end

---Check if singleplayer
---@return boolean
function SentientNPC.IsSingleplayer()
    return not isClient() and not isServer()
end

---Check if we are the controller for a zombie (for MP)
---@param zombie IsoZombie The zombie to check
---@return boolean
function SentientNPC.IsController(zombie)
    if not zombie then return false end
    if SentientNPC.IsSingleplayer() then return true end
    if isClient() then
        return zombie:isLocal() or (zombie.isMovementController and zombie:isMovementController())
    end
    return true
end

-- =============================================================================
-- GAME VERSION COMPATIBILITY
-- =============================================================================

---Get the game major version
---@return number The major version (41 or 42)
function SentientNPC.GetGameVersion()
    return getCore():getGameVersion():getMajor()
end

---Check if running Build 42+
---@return boolean
function SentientNPC.IsBuild42()
    return SentientNPC.GetGameVersion() >= 42
end

-- =============================================================================
-- TIME UTILITIES
-- =============================================================================

---Get current timestamp in milliseconds
---@return number
function SentientNPC.GetTimestamp()
    return getTimestampMs()
end

---Get game world age in hours
---@return number
function SentientNPC.GetWorldHours()
    return getGameTime():getWorldAgeHours()
end

---Get current in-game hour (0-23)
---@return number
function SentientNPC.GetHour()
    return getGameTime():getHour()
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

local initialized = false

---Initialize the mod (called once on game start)
function SentientNPC.Initialize()
    if initialized then return end
    initialized = true

    SentientNPC.Info("Initializing SentientNPC v%s for Build %d",
        SentientNPC.VERSION, SentientNPC.BUILD)

    -- Get initial mod data
    local gmd = SentientNPC.GetModData()
    SentientNPC.Debug("ModData loaded. Active NPCs: %d", gmd.stats.activeNPCs)

    -- Log environment
    if SentientNPC.IsServer() then
        SentientNPC.Info("Running as SERVER")
    elseif isClient() then
        SentientNPC.Info("Running as CLIENT")
    else
        SentientNPC.Info("Running as SINGLEPLAYER")
    end

    SentientNPC.Info("Initialization complete")
end

-- =============================================================================
-- EVENT HOOKS
-- =============================================================================

-- Initialize on game start
local function onGameStart()
    SentientNPC.Initialize()
end

-- Receive synced mod data (client side)
local function onReceiveGlobalModData(key, data)
    if key ~= SentientNPC.MOD_DATA_KEY then return end
    SentientNPC.Verbose("Received ModData sync (timestamp: %d)", data.timestamp or 0)
end

-- Register events
Events.OnGameStart.Add(onGameStart)
Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)

-- =============================================================================
-- EXPORTS
-- =============================================================================

-- Module pattern - these will be loaded separately
-- SentientNPC.Utils      = require("SentientNPC/Utils")
-- SentientNPC.Brain      = require("SentientNPC/Brain")
-- SentientNPC.Possession = require("SentientNPC/PossessionManager")

SentientNPC.Info("Core module loaded")

return SentientNPC
