--[[
    SentientNPC - Programs/Init.lua
    Program module initialization and behavior programs.

    Programs are high-level behavior controllers:
    - Idle: Stand around, do nothing
    - Patrol: Move between waypoints
    - Guard: Defend a position
    - Follow: Follow a target (companion)
    - Flee: Run away from threats
    - Wander: Random exploration

    Each program has stages (Prepare, Main, Alert, etc.)
    Stages return: {status, next, tasks, program, programData}

    PHASE 2 UPDATE:
    - Integrated with Detection system
    - Better threat response
    - Mood changes based on situation
]]

require "SentientNPC/Core"
require "SentientNPC/Utils"
require "SentientNPC/Brain"
require "SentientNPC/Detection"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Programs = SentientNPC.Programs or {}
local Programs = SentientNPC.Programs

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

---Check for threats and potentially switch to alert/flee
---@param zombie IsoZombie
---@param brain table
---@return table|nil Result to return if threat found, nil to continue normal behavior
local function checkThreats(zombie, brain)
    -- Skip threat check if hostile (they don't flee)
    if brain.hostileToPlayers then return nil end

    -- Use Detection system
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if threat and threat.threatLevel > 0.5 then
        -- High threat - flee!
        brain.mood = SentientNPC.Brain.Moods.FEARFUL

        return {
            status = true,
            program = "Flee",
            programData = {
                threatX = threat.data.x,
                threatY = threat.data.y,
                threatType = threat.type,
            },
        }
    elseif threat and threat.threatLevel > 0.2 then
        -- Medium threat - alert mode
        brain.mood = SentientNPC.Brain.Moods.ALERT

        -- Face the threat
        return {
            status = true,
            next = "Alert",
            tasks = {{
                action = "faceLocation",
                x = threat.data.x,
                y = threat.data.y,
                time = 500,
            }},
        }
    end

    return nil
end

-- =============================================================================
-- PROGRAM: IDLE
-- =============================================================================

Programs.Idle = {}

function Programs.Idle.Prepare(zombie, brain)
    brain.program.data.idleStart = SentientNPC.GetTimestamp()
    brain.mood = SentientNPC.Brain.Moods.NEUTRAL
    return {status = true, next = "Main", tasks = {}}
end

function Programs.Idle.Main(zombie, brain)
    local tasks = {}

    -- Check for threats first
    local threatResponse = checkThreats(zombie, brain)
    if threatResponse then return threatResponse end

    -- Random idle animation occasionally
    local rnd = ZombRand(100)

    if rnd < 5 then
        -- Small movement animation
        table.insert(tasks, {
            action = "animate",
            anim = "Shrug",
            time = 2000,
        })
    elseif rnd < 15 then
        -- Look around
        local angle = SentientNPC.Utils.RandFloat(0, math.pi * 2)
        local lookX = zombie:getX() + math.cos(angle) * 5
        local lookY = zombie:getY() + math.sin(angle) * 5
        table.insert(tasks, {
            action = "faceLocation",
            x = lookX,
            y = lookY,
            time = 1000,
        })
    else
        -- Just wait
        table.insert(tasks, {
            action = "wait",
            time = SentientNPC.Utils.RandInt(1000, 3000),
        })
    end

    return {status = true, next = "Main", tasks = tasks}
end

function Programs.Idle.Alert(zombie, brain)
    local tasks = {}

    -- Check if threat is gone
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if not threat or threat.threatLevel < 0.2 then
        -- Threat gone, return to normal
        brain.mood = SentientNPC.Brain.Moods.NEUTRAL
        return {status = true, next = "Main", tasks = {{action = "wait", time = 1000}}}
    end

    -- Still alert, face threat
    table.insert(tasks, {
        action = "faceLocation",
        x = threat.data.x,
        y = threat.data.y,
        time = 500,
    })

    -- Check if should flee
    if threat.threatLevel > 0.5 then
        return {
            status = true,
            program = "Flee",
            programData = {
                threatX = threat.data.x,
                threatY = threat.data.y,
            },
        }
    end

    return {status = true, next = "Alert", tasks = tasks}
end

-- =============================================================================
-- PROGRAM: PATROL
-- =============================================================================

Programs.Patrol = {}

function Programs.Patrol.Prepare(zombie, brain)
    -- Initialize patrol data
    local data = brain.program.data
    data.patrolRadius = data.patrolRadius or 15
    data.waypointIndex = 0
    data.waypoints = data.waypoints or {}

    -- Generate waypoints if none provided
    if #data.waypoints == 0 then
        local cx = brain.bornCoords.x
        local cy = brain.bornCoords.y
        local cz = brain.bornCoords.z
        local radius = data.patrolRadius

        -- Generate 4 waypoints around spawn point
        for i = 1, 4 do
            local angle = (i - 1) * (math.pi / 2) + SentientNPC.Utils.RandFloat(-0.3, 0.3)
            local dist = radius * SentientNPC.Utils.RandFloat(0.5, 1.0)
            local wx = cx + math.cos(angle) * dist
            local wy = cy + math.sin(angle) * dist

            -- Find walkable square
            local sq = SentientNPC.Utils.FindWalkableSquare(
                math.floor(wx), math.floor(wy), cz, 3
            )
            if sq then
                table.insert(data.waypoints, {
                    x = sq:getX(),
                    y = sq:getY(),
                    z = sq:getZ(),
                })
            end
        end

        SentientNPC.Debug("Generated %d waypoints for %s", #data.waypoints, brain.name)
    end

    brain.mood = SentientNPC.Brain.Moods.NEUTRAL
    return {status = true, next = "Main", tasks = {}}
end

function Programs.Patrol.Main(zombie, brain)
    local tasks = {}
    local data = brain.program.data

    -- Check for threats using Detection system
    local threatResponse = checkThreats(zombie, brain)
    if threatResponse then return threatResponse end

    -- Normal patrol
    brain.mood = SentientNPC.Brain.Moods.NEUTRAL

    if #data.waypoints == 0 then
        -- No waypoints, just idle
        table.insert(tasks, {action = "wait", time = 2000})
        return {status = true, next = "Main", tasks = tasks}
    end

    -- Get next waypoint
    data.waypointIndex = (data.waypointIndex % #data.waypoints) + 1
    local waypoint = data.waypoints[data.waypointIndex]

    if waypoint then
        -- Move to waypoint
        table.insert(tasks, {
            action = "move",
            x = waypoint.x,
            y = waypoint.y,
            z = waypoint.z,
            walkType = "Walk",
            tolerance = 2,
            timeout = 15000,
        })

        -- Pause at waypoint
        table.insert(tasks, {
            action = "wait",
            time = SentientNPC.Utils.RandInt(1000, 3000),
        })
    end

    return {status = true, next = "Main", tasks = tasks}
end

function Programs.Patrol.Alert(zombie, brain)
    local tasks = {}
    local data = brain.program.data

    -- Check if threat is gone
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if not threat or threat.threatLevel < 0.2 then
        -- Threat gone, return to patrol
        brain.mood = SentientNPC.Brain.Moods.NEUTRAL
        return {status = true, next = "Main", tasks = {{action = "wait", time = 1000}}}
    end

    -- Face the threat
    table.insert(tasks, {
        action = "faceLocation",
        x = threat.data.x,
        y = threat.data.y,
        time = 500,
    })

    -- High threat = flee
    if threat.threatLevel > 0.6 then
        return {
            status = true,
            program = "Flee",
            programData = {
                threatX = threat.data.x,
                threatY = threat.data.y,
                returnProgram = "Patrol",
            },
        }
    end

    return {status = true, next = "Alert", tasks = tasks}
end

-- =============================================================================
-- PROGRAM: GUARD
-- =============================================================================

Programs.Guard = {}

function Programs.Guard.Prepare(zombie, brain)
    local data = brain.program.data
    data.guardPos = data.guardPos or {
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
    }
    data.guardRadius = data.guardRadius or 3
    data.lastScan = 0
    data.alertCooldown = 0

    brain.mood = SentientNPC.Brain.Moods.NEUTRAL
    return {status = true, next = "Main", tasks = {}}
end

function Programs.Guard.Main(zombie, brain)
    local tasks = {}
    local data = brain.program.data
    local now = SentientNPC.GetTimestamp()

    -- Stay near guard position
    local distFromPost = SentientNPC.Utils.DistTo(
        zombie:getX(), zombie:getY(),
        data.guardPos.x, data.guardPos.y
    )

    if distFromPost > data.guardRadius then
        -- Return to post
        table.insert(tasks, {
            action = "move",
            x = data.guardPos.x,
            y = data.guardPos.y,
            z = data.guardPos.z,
            walkType = "Walk",
            tolerance = 1,
        })
        return {status = true, next = "Main", tasks = tasks}
    end

    -- Scan for entities using Detection system
    if (now - data.lastScan) > 2000 then
        data.lastScan = now

        -- Check for players
        local playerData = SentientNPC.Detection.GetClosestPlayer(zombie, brain)

        if playerData and playerData.distance < 20 then
            -- Face player
            table.insert(tasks, {
                action = "faceLocation",
                x = playerData.x,
                y = playerData.y,
                time = 500,
            })

            -- Alert if armed player approaches
            if playerData.armed and playerData.distance < 10 then
                brain.mood = SentientNPC.Brain.Moods.ALERT
                return {status = true, next = "Alert", tasks = tasks}
            end

            return {status = true, next = "Main", tasks = tasks}
        end

        -- Check for zombies
        local zombieData = SentientNPC.Detection.GetClosestZombie(zombie, brain)

        if zombieData and zombieData.distance < 15 then
            brain.mood = SentientNPC.Brain.Moods.ALERT

            -- Face zombie
            table.insert(tasks, {
                action = "faceLocation",
                x = zombieData.x,
                y = zombieData.y,
                time = 500,
            })

            -- Very close zombie = high alert
            if zombieData.distance < 5 then
                return {status = true, next = "Alert", tasks = tasks}
            end

            return {status = true, next = "Main", tasks = tasks}
        end

        -- Nothing detected, look around
        local angle = SentientNPC.Utils.RandFloat(0, math.pi * 2)
        table.insert(tasks, {
            action = "faceLocation",
            x = zombie:getX() + math.cos(angle) * 10,
            y = zombie:getY() + math.sin(angle) * 10,
            time = 1000,
        })
    else
        -- Wait between scans
        table.insert(tasks, {action = "wait", time = 500})
    end

    brain.mood = SentientNPC.Brain.Moods.NEUTRAL
    return {status = true, next = "Main", tasks = tasks}
end

function Programs.Guard.Alert(zombie, brain)
    local tasks = {}
    local data = brain.program.data

    -- Check threats
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if not threat or threat.threatLevel < 0.1 then
        -- Threat gone, return to main
        brain.mood = SentientNPC.Brain.Moods.NEUTRAL
        return {status = true, next = "Main", tasks = {{action = "wait", time = 1000}}}
    end

    -- Face the threat
    table.insert(tasks, {
        action = "faceLocation",
        x = threat.data.x,
        y = threat.data.y,
        time = 300,
    })

    -- Guards don't flee easily, but very high threat might make them
    if threat.threatLevel > 0.9 and threat.distance < 3 then
        return {
            status = true,
            program = "Flee",
            programData = {
                threatX = threat.data.x,
                threatY = threat.data.y,
                returnProgram = "Guard",
            },
        }
    end

    return {status = true, next = "Alert", tasks = tasks}
end

-- =============================================================================
-- PROGRAM: FOLLOW (Companion)
-- =============================================================================

Programs.Follow = {}

function Programs.Follow.Prepare(zombie, brain)
    brain.mood = SentientNPC.Brain.Moods.HAPPY
    return {status = true, next = "Main", tasks = {}}
end

function Programs.Follow.Main(zombie, brain)
    local tasks = {}

    -- Get master player (following Bandits pattern)
    local master = nil
    local gamemode = getWorld():getGameMode()

    if gamemode == "Multiplayer" then
        -- In multiplayer, brain.master should be the onlineID
        local masterId = brain.master
        if masterId then
            master = getPlayerByOnlineID(masterId)
        end
    else
        -- In singleplayer, always follow player 0
        master = getSpecificPlayer(0)
    end

    if not master then
        -- Master not found, wait
        brain.mood = SentientNPC.Brain.Moods.SAD
        return {status = true, next = "Main", tasks = {{action = "wait", time = 2000}}}
    end

    brain.mood = SentientNPC.Brain.Moods.HAPPY

    -- Check for threats (companions protect their master!)
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if threat and threat.type == "zombie" and threat.distance < 10 then
        -- Zombie near! Alert mode
        brain.mood = SentientNPC.Brain.Moods.ALERT
        return {
            status = true,
            next = "Protect",
            tasks = {{
                action = "faceLocation",
                x = threat.data.x,
                y = threat.data.y,
                time = 300,
            }},
        }
    end

    -- Calculate distance to master
    local dist = SentientNPC.Utils.DistBetween(zombie, master)

    -- Determine walk type based on master's movement
    local walkType = "Walk"
    if master:isSprinting() or dist > 10 then
        walkType = "Run"
    elseif master:isSneaking() then
        walkType = "SneakWalk"
    end

    -- Follow if too far
    if dist > 3 then
        -- Calculate position behind/beside master
        local masterDir = SentientNPC.Utils.GetFacingDirection(master)
        local followAngle = math.rad(masterDir + 150)  -- Slightly behind and to side
        local followDist = 2

        local targetX = master:getX() + math.cos(followAngle) * followDist
        local targetY = master:getY() + math.sin(followAngle) * followDist

        table.insert(tasks, {
            action = "move",
            x = targetX,
            y = targetY,
            z = master:getZ(),
            walkType = walkType,
            tolerance = 1.5,
            timeout = 5000,
        })
    else
        -- Close enough, face same direction as master
        local dir = SentientNPC.Utils.GetFacingDirection(master)
        local lookX = zombie:getX() + math.cos(math.rad(dir)) * 5
        local lookY = zombie:getY() + math.sin(math.rad(dir)) * 5

        table.insert(tasks, {
            action = "faceLocation",
            x = lookX,
            y = lookY,
            time = 500,
        })
    end

    return {status = true, next = "Main", tasks = tasks}
end

function Programs.Follow.Protect(zombie, brain)
    local tasks = {}

    -- Check if threat is still there
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if not threat or threat.distance > 15 then
        -- Threat gone, return to following
        brain.mood = SentientNPC.Brain.Moods.HAPPY
        return {status = true, next = "Main", tasks = {{action = "wait", time = 500}}}
    end

    -- Face the threat
    table.insert(tasks, {
        action = "faceLocation",
        x = threat.data.x,
        y = threat.data.y,
        time = 300,
    })

    -- Stay in protect mode
    return {status = true, next = "Protect", tasks = tasks}
end

-- =============================================================================
-- PROGRAM: COMPANION (alias for Follow)
-- =============================================================================

Programs.Companion = Programs.Follow

-- =============================================================================
-- PROGRAM: FLEE
-- =============================================================================

Programs.Flee = {}

function Programs.Flee.Prepare(zombie, brain)
    local data = brain.program.data
    data.fleeStart = SentientNPC.GetTimestamp()
    data.fleeDuration = data.fleeDuration or 10000  -- Flee for 10 seconds
    data.threatX = data.threatX or zombie:getX()
    data.threatY = data.threatY or zombie:getY()

    brain.mood = SentientNPC.Brain.Moods.FEARFUL
    SentientNPC.Debug("%s is fleeing!", brain.name)

    return {status = true, next = "Main", tasks = {}}
end

function Programs.Flee.Main(zombie, brain)
    local tasks = {}
    local data = brain.program.data
    local now = SentientNPC.GetTimestamp()

    -- Check if flee duration is over
    if (now - data.fleeStart) > data.fleeDuration then
        -- Stop fleeing
        brain.mood = SentientNPC.Brain.Moods.NEUTRAL

        -- Return to previous program if specified
        local returnProg = data.returnProgram or "Idle"
        return {
            status = true,
            program = returnProg,
            programData = {},
        }
    end

    -- Calculate flee direction (away from threat)
    local npcX, npcY = zombie:getX(), zombie:getY()
    local threatX = data.threatX or npcX
    local threatY = data.threatY or npcY

    -- Update threat position if still visible
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)
    if threat then
        threatX = threat.data.x
        threatY = threat.data.y
        data.threatX = threatX
        data.threatY = threatY
    end

    -- Direction away from threat
    local dx = npcX - threatX
    local dy = npcY - threatY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.1 then
        -- Threat is on top of us, pick random direction
        local angle = SentientNPC.Utils.RandFloat(0, math.pi * 2)
        dx = math.cos(angle)
        dy = math.sin(angle)
    else
        -- Normalize
        dx = dx / dist
        dy = dy / dist
    end

    -- Calculate flee target (20 tiles away from threat)
    local fleeDistance = 20
    local fleeX = npcX + dx * fleeDistance
    local fleeY = npcY + dy * fleeDistance

    -- Find walkable square near target
    local sq = SentientNPC.Utils.FindWalkableSquare(
        math.floor(fleeX), math.floor(fleeY), zombie:getZ(), 5
    )

    if sq then
        fleeX = sq:getX()
        fleeY = sq:getY()
    end

    -- Run away!
    table.insert(tasks, {
        action = "move",
        x = fleeX,
        y = fleeY,
        z = zombie:getZ(),
        walkType = "Run",
        tolerance = 3,
        timeout = 5000,
    })

    return {status = true, next = "Main", tasks = tasks}
end

-- =============================================================================
-- PROGRAM: WANDER
-- =============================================================================

Programs.Wander = {}

function Programs.Wander.Prepare(zombie, brain)
    local data = brain.program.data
    data.wanderRadius = data.wanderRadius or 30
    data.lastWander = 0

    brain.mood = SentientNPC.Brain.Moods.NEUTRAL
    return {status = true, next = "Main", tasks = {}}
end

function Programs.Wander.Main(zombie, brain)
    local tasks = {}
    local data = brain.program.data

    -- Check for threats
    local threatResponse = checkThreats(zombie, brain)
    if threatResponse then return threatResponse end

    -- Pick random nearby location
    local angle = SentientNPC.Utils.RandFloat(0, math.pi * 2)
    local dist = SentientNPC.Utils.RandFloat(5, data.wanderRadius)

    local targetX = zombie:getX() + math.cos(angle) * dist
    local targetY = zombie:getY() + math.sin(angle) * dist

    -- Find walkable square
    local sq = SentientNPC.Utils.FindWalkableSquare(
        math.floor(targetX), math.floor(targetY), zombie:getZ(), 3
    )

    if sq then
        table.insert(tasks, {
            action = "move",
            x = sq:getX(),
            y = sq:getY(),
            z = sq:getZ(),
            walkType = "Walk",
            tolerance = 2,
            timeout = 20000,
        })

        -- Pause after arriving
        table.insert(tasks, {
            action = "wait",
            time = SentientNPC.Utils.RandInt(2000, 5000),
        })
    else
        -- Couldn't find walkable spot, just wait
        table.insert(tasks, {action = "wait", time = 2000})
    end

    return {status = true, next = "Main", tasks = tasks}
end

function Programs.Wander.Alert(zombie, brain)
    local tasks = {}

    -- Check if threat is gone
    local threat = SentientNPC.Detection.GetHighestThreat(zombie, brain)

    if not threat or threat.threatLevel < 0.2 then
        -- Threat gone, return to wandering
        brain.mood = SentientNPC.Brain.Moods.NEUTRAL
        return {status = true, next = "Main", tasks = {{action = "wait", time = 1000}}}
    end

    -- Face the threat
    table.insert(tasks, {
        action = "faceLocation",
        x = threat.data.x,
        y = threat.data.y,
        time = 500,
    })

    -- High threat = flee
    if threat.threatLevel > 0.5 then
        return {
            status = true,
            program = "Flee",
            programData = {
                threatX = threat.data.x,
                threatY = threat.data.y,
                returnProgram = "Wander",
            },
        }
    end

    return {status = true, next = "Alert", tasks = tasks}
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Programs module loaded (Phase 2)")

return Programs
