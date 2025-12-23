--[[
    SentientNPC - Commands.lua
    Client/Server command handling for NPC operations.

    Commands use PZ's sendClientCommand/sendServerCommand system
    for reliable multiplayer communication.

    Command flow:
    1. Client sends request via sendClientCommand
    2. Server validates and processes
    3. Server responds via sendServerCommand
    4. Client handles response
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"
require "SentientNPC/Brain"
require "SentientNPC/PossessionManager"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Commands = SentientNPC.Commands or {}
local Commands = SentientNPC.Commands

-- Module ID for commands
Commands.MODULE = "SentientNPC"

-- =============================================================================
-- COMMAND TYPES
-- =============================================================================

Commands.Types = {
    -- Client -> Server
    SPAWN_NPC = "SpawnNPC",
    DESPAWN_NPC = "DespawnNPC",
    INTERACT = "Interact",
    SET_PROGRAM = "SetProgram",
    REQUEST_SYNC = "RequestSync",

    -- Server -> Client
    NPC_SPAWNED = "NPCSpawned",
    NPC_DESPAWNED = "NPCDespawned",
    SYNC_STATE = "SyncState",
    ERROR = "Error",
}

-- =============================================================================
-- CLIENT -> SERVER HANDLERS
-- =============================================================================

local ServerHandlers = {}

---Handle spawn NPC request
---@param player IsoPlayer
---@param args table {x, y, z, type, name, ...}
ServerHandlers[Commands.Types.SPAWN_NPC] = function(player, args)
    -- Validate admin/permission
    if not player:isAccessLevel("Admin") then
        Commands.SendError(player, "spawn_denied", "Admin access required")
        return
    end

    -- Get spawn location
    local x = args.x or player:getX()
    local y = args.y or player:getY()
    local z = args.z or player:getZ()

    -- Build config
    local config = {
        type = args.type or SentientNPC.Brain.Types.GENERIC,
        name = args.name,
        female = args.female,
        hostile = args.hostile,
        hostileToPlayers = args.hostileToPlayers,
        program = args.program or "Idle",
        faction = args.faction,
    }

    -- Spawn NPC
    local success, result = SentientNPC.Possession.SpawnNPC(x, y, z, config)

    if success then
        -- Notify requesting player
        sendServerCommand(player, Commands.MODULE, Commands.Types.NPC_SPAWNED, {
            npcId = result,
            x = x, y = y, z = z,
            type = config.type,
            name = config.name,
        })

        SentientNPC.Info("Admin %s spawned NPC: %s at (%d,%d,%d)",
            player:getUsername(), result, x, y, z)
    else
        Commands.SendError(player, "spawn_failed", result)
    end
end

---Handle despawn NPC request
---@param player IsoPlayer
---@param args table {npcId}
ServerHandlers[Commands.Types.DESPAWN_NPC] = function(player, args)
    if not player:isAccessLevel("Admin") then
        Commands.SendError(player, "despawn_denied", "Admin access required")
        return
    end

    local npcId = args.npcId
    if not npcId then
        Commands.SendError(player, "invalid_args", "npcId required")
        return
    end

    local brain = SentientNPC.Brain.Get(npcId)
    if not brain then
        Commands.SendError(player, "not_found", "NPC not found")
        return
    end

    local zombie = SentientNPC.Possession.FindZombieByPersistentId(brain.persistentId)
    if zombie then
        SentientNPC.Possession.Release(zombie)
        zombie:Kill(nil)
    else
        -- Just remove brain if zombie not found
        SentientNPC.Brain.Remove(npcId)
    end

    sendServerCommand(player, Commands.MODULE, Commands.Types.NPC_DESPAWNED, {
        npcId = npcId,
    })

    SentientNPC.Info("Admin %s despawned NPC: %s", player:getUsername(), npcId)
end

---Handle NPC interaction
---@param player IsoPlayer
---@param args table {npcId, action, ...}
ServerHandlers[Commands.Types.INTERACT] = function(player, args)
    local npcId = args.npcId
    local action = args.action

    if not npcId or not action then
        Commands.SendError(player, "invalid_args", "npcId and action required")
        return
    end

    local brain = SentientNPC.Brain.Get(npcId)
    if not brain then
        Commands.SendError(player, "not_found", "NPC not found")
        return
    end

    SentientNPC.Debug("Player %s interacting with %s: %s",
        player:getUsername(), brain.name, action)

    -- Handle interaction based on action type
    if action == "talk" then
        -- Record interaction in memory
        local playerId = SentientNPC.Utils.GetCharacterID(player)
        SentientNPC.Brain.AddMemory(brain,
            "Player " .. player:getUsername() .. " talked to me",
            "interaction", 0.6, {playerId})

    elseif action == "recruit" then
        -- Set player as master
        if not brain.master then
            brain.master = SentientNPC.Utils.GetCharacterID(player)
            brain.program.name = "Companion"
            brain.program.stage = "Prepare"
            brain.hostileToPlayers = false

            SentientNPC.Info("NPC %s recruited by %s", brain.name, player:getUsername())
        end

    elseif action == "dismiss" then
        -- Remove master
        if brain.master == SentientNPC.Utils.GetCharacterID(player) then
            brain.master = nil
            brain.program.name = brain.programFallback or "Idle"
            brain.program.stage = "Prepare"

            SentientNPC.Info("NPC %s dismissed by %s", brain.name, player:getUsername())
        end
    end

    -- Sync changes
    SentientNPC.TransmitModData()
end

---Handle program change request
---@param player IsoPlayer
---@param args table {npcId, program, stage}
ServerHandlers[Commands.Types.SET_PROGRAM] = function(player, args)
    if not player:isAccessLevel("Admin") then
        Commands.SendError(player, "denied", "Admin access required")
        return
    end

    local npcId = args.npcId
    local program = args.program
    local stage = args.stage or "Prepare"

    if not npcId or not program then
        Commands.SendError(player, "invalid_args", "npcId and program required")
        return
    end

    local brain = SentientNPC.Brain.Get(npcId)
    if not brain then
        Commands.SendError(player, "not_found", "NPC not found")
        return
    end

    brain.program.name = program
    brain.program.stage = stage
    brain.program.data = {}

    SentientNPC.TransmitModData()

    SentientNPC.Info("Admin %s set program for %s: %s",
        player:getUsername(), brain.name, program)
end

---Handle sync request
---@param player IsoPlayer
---@param args table
ServerHandlers[Commands.Types.REQUEST_SYNC] = function(player, args)
    -- Just transmit current state
    SentientNPC.TransmitModData()
end

-- =============================================================================
-- SERVER -> CLIENT HANDLERS
-- =============================================================================

local ClientHandlers = {}

---Handle NPC spawned notification
---@param args table
ClientHandlers[Commands.Types.NPC_SPAWNED] = function(args)
    SentientNPC.Info("NPC spawned: %s (ID: %s)",
        args.name or "Unknown", args.npcId)
end

---Handle NPC despawned notification
---@param args table
ClientHandlers[Commands.Types.NPC_DESPAWNED] = function(args)
    SentientNPC.Info("NPC despawned: %s", args.npcId)
end

---Handle error from server
---@param args table
ClientHandlers[Commands.Types.ERROR] = function(args)
    SentientNPC.Error("Server error [%s]: %s", args.code or "unknown", args.message or "")
end

-- =============================================================================
-- COMMAND ROUTING
-- =============================================================================

---Process client command (server-side)
---@param module string
---@param command string
---@param player IsoPlayer
---@param args table
local function onClientCommand(module, command, player, args)
    if module ~= Commands.MODULE then return end

    local handler = ServerHandlers[command]
    if handler then
        SentientNPC.Debug("Processing client command: %s from %s",
            command, player:getUsername())

        local success, err = pcall(handler, player, args or {})
        if not success then
            SentientNPC.Error("Error handling command %s: %s", command, err)
            Commands.SendError(player, "internal_error", tostring(err))
        end
    else
        SentientNPC.Warn("Unknown command from client: %s", command)
    end
end

---Process server command (client-side)
---@param module string
---@param command string
---@param args table
local function onServerCommand(module, command, args)
    if module ~= Commands.MODULE then return end

    local handler = ClientHandlers[command]
    if handler then
        SentientNPC.Debug("Processing server command: %s", command)

        local success, err = pcall(handler, args or {})
        if not success then
            SentientNPC.Error("Error handling server command %s: %s", command, err)
        end
    else
        SentientNPC.Verbose("Unhandled server command: %s", command)
    end
end

-- =============================================================================
-- CLIENT SEND FUNCTIONS
-- =============================================================================

---Request to spawn an NPC (client -> server)
---@param config table {x, y, z, type, name, ...}
function Commands.RequestSpawn(config)
    sendClientCommand(Commands.MODULE, Commands.Types.SPAWN_NPC, config or {})
end

---Request to despawn an NPC (client -> server)
---@param npcId string
function Commands.RequestDespawn(npcId)
    sendClientCommand(Commands.MODULE, Commands.Types.DESPAWN_NPC, {npcId = npcId})
end

---Request to interact with NPC (client -> server)
---@param npcId string
---@param action string
---@param data table|nil Additional data
function Commands.RequestInteract(npcId, action, data)
    local args = data or {}
    args.npcId = npcId
    args.action = action
    sendClientCommand(Commands.MODULE, Commands.Types.INTERACT, args)
end

---Request to change NPC program (client -> server, admin only)
---@param npcId string
---@param program string
---@param stage string|nil
function Commands.RequestSetProgram(npcId, program, stage)
    sendClientCommand(Commands.MODULE, Commands.Types.SET_PROGRAM, {
        npcId = npcId,
        program = program,
        stage = stage,
    })
end

---Request state sync (client -> server)
function Commands.RequestSync()
    sendClientCommand(Commands.MODULE, Commands.Types.REQUEST_SYNC, {})
end

-- =============================================================================
-- SERVER SEND FUNCTIONS
-- =============================================================================

---Send error to client
---@param player IsoPlayer
---@param code string
---@param message string
function Commands.SendError(player, code, message)
    sendServerCommand(player, Commands.MODULE, Commands.Types.ERROR, {
        code = code,
        message = message,
    })
end

-- =============================================================================
-- EVENT REGISTRATION
-- =============================================================================

Events.OnClientCommand.Add(onClientCommand)
Events.OnServerCommand.Add(onServerCommand)

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Commands module loaded")

return Commands
