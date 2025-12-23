--[[
    SentientNPC - Sync.lua (Server)
    Multiplayer synchronization for NPC state.

    Handles:
    - State transmission to clients
    - Client state reconciliation
    - Periodic sync broadcasts
    - Join/leave handling
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"
require "SentientNPC/Brain"

-- Only load on server
if isClient() and not isCoopHost() then
    return
end

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Sync = SentientNPC.Sync or {}
local Sync = SentientNPC.Sync

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

Sync.SYNC_INTERVAL = 2000           -- ms between full syncs
Sync.PARTIAL_SYNC_INTERVAL = 500    -- ms between partial syncs

-- =============================================================================
-- STATE
-- =============================================================================

Sync.lastFullSync = 0
Sync.lastPartialSync = 0
Sync.pendingUpdates = {}            -- brainIds that need sync

-- =============================================================================
-- SYNC FUNCTIONS
-- =============================================================================

---Broadcast full state to all clients
function Sync.BroadcastFullState()
    local gmd = SentientNPC.GetModData()
    gmd.timestamp = SentientNPC.GetTimestamp()

    ModData.transmit(SentientNPC.MOD_DATA_KEY)

    Sync.lastFullSync = SentientNPC.GetTimestamp()
    SentientNPC.Verbose("Full state broadcast complete")
end

---Mark a brain as needing sync
---@param brainId string
function Sync.MarkDirty(brainId)
    if brainId then
        Sync.pendingUpdates[brainId] = true
    end
end

---Broadcast partial state (only changed brains)
function Sync.BroadcastPartialState()
    if SentientNPC.Utils.TableCount(Sync.pendingUpdates) == 0 then
        return
    end

    -- For now, just do a full transmit
    -- In future, could implement delta sync
    SentientNPC.TransmitModData()

    Sync.pendingUpdates = {}
    Sync.lastPartialSync = SentientNPC.GetTimestamp()
end

---Send state to a specific player
---@param player IsoPlayer
function Sync.SendToPlayer(player)
    if not player then return end

    -- ModData.transmit sends to all, so we just transmit
    SentientNPC.TransmitModData()

    SentientNPC.Debug("State sent to player: %s", player:getUsername())
end

-- =============================================================================
-- PERIODIC SYNC
-- =============================================================================

---Periodic sync check
function Sync.OnTick()
    local now = SentientNPC.GetTimestamp()

    -- Full sync
    if (now - Sync.lastFullSync) >= Sync.SYNC_INTERVAL then
        Sync.BroadcastFullState()
    end

    -- Partial sync (more frequent)
    if (now - Sync.lastPartialSync) >= Sync.PARTIAL_SYNC_INTERVAL then
        Sync.BroadcastPartialState()
    end
end

-- =============================================================================
-- PLAYER EVENTS
-- =============================================================================

---Handle player joining
---@param player IsoPlayer
function Sync.OnPlayerJoin(player)
    if not player then return end

    SentientNPC.Info("Player joined: %s, sending state", player:getUsername())

    -- Small delay to ensure player is fully loaded
    -- Then send current state
    Sync.SendToPlayer(player)
end

---Handle player leaving
---@param player IsoPlayer
function Sync.OnPlayerLeave(player)
    if not player then return end

    SentientNPC.Info("Player left: %s", player:getUsername())

    -- Check if any NPCs were associated with this player
    local playerId = SentientNPC.Utils.GetCharacterID(player)
    local brains = SentientNPC.Brain.GetAll()

    for brainId, brain in pairs(brains) do
        if brain.master == playerId then
            -- Player was master of this NPC
            -- Could release, despawn, or transfer ownership
            SentientNPC.Debug("Master disconnected for NPC: %s", brain.name)
            -- For now, just clear master
            brain.master = nil
            Sync.MarkDirty(brainId)
        end
    end
end

-- =============================================================================
-- VALIDATION
-- =============================================================================

---Validate and clean orphaned brains
function Sync.ValidateBrains()
    local brains = SentientNPC.Brain.GetAll()
    local now = SentientNPC.GetTimestamp()
    local maxAge = 3600000  -- 1 hour in ms

    for brainId, brain in pairs(brains) do
        -- Check if brain has been updated recently
        local age = now - (brain.lastUpdate or 0)

        if age > maxAge then
            -- Brain hasn't been updated in a long time
            -- Check if zombie still exists
            local zombie = SentientNPC.Possession.FindZombieByPersistentId(brain.persistentId)

            if not zombie or zombie:isDead() then
                SentientNPC.Warn("Removing orphaned brain: %s (age: %ds)",
                    brain.name, age / 1000)
                SentientNPC.Brain.Remove(brainId)
            end
        end
    end
end

-- =============================================================================
-- EVENT REGISTRATION
-- =============================================================================

-- Periodic sync
Events.OnTick.Add(Sync.OnTick)

-- Player events
Events.OnConnected.Add(Sync.OnPlayerJoin)
Events.OnDisconnect.Add(Sync.OnPlayerLeave)

-- Periodic validation (every 10 minutes)
Events.EveryTenMinutes.Add(Sync.ValidateBrains)

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Sync module (server) loaded")

return Sync
