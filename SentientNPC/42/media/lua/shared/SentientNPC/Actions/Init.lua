--[[
    SentientNPC - Actions/Init.lua
    Action module initialization and registry.

    Actions are low-level behaviors that execute specific tasks:
    - Move to location
    - Wait for time
    - Play animation
    - Face direction

    Each action has: onStart, onWorking, onComplete callbacks
]]

require "SentientNPC/Core"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Actions = SentientNPC.Actions or {}
local Actions = SentientNPC.Actions

-- =============================================================================
-- ACTION: IDLE
-- =============================================================================

Actions.idle = {}

function Actions.idle.onStart(zombie, brain, task)
    -- Just stand there
    return true
end

function Actions.idle.onWorking(zombie, brain, task)
    local elapsed = SentientNPC.GetTimestamp() - (task.startTime or 0)
    local duration = task.duration or 1000

    return elapsed >= duration
end

function Actions.idle.onComplete(zombie, brain, task)
    return true
end

-- =============================================================================
-- ACTION: WAIT
-- =============================================================================

Actions.wait = {}

function Actions.wait.onStart(zombie, brain, task)
    task.waitUntil = SentientNPC.GetTimestamp() + (task.time or 1000)
    return true
end

function Actions.wait.onWorking(zombie, brain, task)
    return SentientNPC.GetTimestamp() >= task.waitUntil
end

function Actions.wait.onComplete(zombie, brain, task)
    return true
end

-- =============================================================================
-- ACTION: MOVE
-- =============================================================================

Actions.move = {}

function Actions.move.onStart(zombie, brain, task)
    if not task.x or not task.y then
        return false
    end

    -- Set walk type variable
    local walkType = task.walkType or "Walk"
    zombie:setVariable("NPCWalkType", walkType)

    -- Reset pathfinding
    local pathBehavior = zombie:getPathFindBehavior2()
    if pathBehavior then
        pathBehavior:reset()
        pathBehavior:cancel()
    end
    zombie:setPath2(nil)

    -- Only controller does pathfinding
    if SentientNPC.IsController(zombie) then
        zombie:pathToLocationF(task.x, task.y, task.z or zombie:getZ())
    end

    brain.moving = true

    SentientNPC.Verbose("NPC %s moving to (%d, %d)", brain.name, task.x, task.y)

    return true
end

function Actions.move.onWorking(zombie, brain, task)
    -- Check if reached destination
    local dist = SentientNPC.Utils.DistTo(
        zombie:getX(), zombie:getY(),
        task.x, task.y
    )

    local tolerance = task.tolerance or 1.5

    if dist <= tolerance then
        return true  -- Arrived
    end

    -- Check pathfinding state
    if SentientNPC.IsController(zombie) then
        local pathBehavior = zombie:getPathFindBehavior2()
        if pathBehavior then
            local result = pathBehavior:update()
            if result == BehaviorResult.Failed then
                SentientNPC.Verbose("Pathfinding failed for %s", brain.name)
                return true  -- Give up
            end
            if result == BehaviorResult.Succeeded then
                return true  -- Path complete
            end
        end
    end

    return false  -- Still moving
end

function Actions.move.onComplete(zombie, brain, task)
    brain.moving = false
    zombie:setVariable("NPCWalkType", "")
    return true
end

-- =============================================================================
-- ACTION: FACE_LOCATION
-- =============================================================================

Actions.faceLocation = {}

function Actions.faceLocation.onStart(zombie, brain, task)
    if not task.x or not task.y then
        return false
    end

    zombie:faceLocationF(task.x, task.y)
    return true
end

function Actions.faceLocation.onWorking(zombie, brain, task)
    local elapsed = SentientNPC.GetTimestamp() - (task.startTime or 0)
    return elapsed >= (task.time or 200)
end

function Actions.faceLocation.onComplete(zombie, brain, task)
    return true
end

-- =============================================================================
-- ACTION: ANIMATE
-- =============================================================================

Actions.animate = {}

function Actions.animate.onStart(zombie, brain, task)
    local anim = task.anim or "Idle"
    zombie:setBumpType(anim)
    return true
end

function Actions.animate.onWorking(zombie, brain, task)
    local elapsed = SentientNPC.GetTimestamp() - (task.startTime or 0)
    return elapsed >= (task.time or 1000)
end

function Actions.animate.onComplete(zombie, brain, task)
    return true
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Actions module loaded")

return Actions
