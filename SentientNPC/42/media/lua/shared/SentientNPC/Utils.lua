--[[
    SentientNPC - Utils.lua
    Utility functions for the SentientNPC mod.

    Contains helpers for:
    - Distance calculations
    - Character identification
    - Target detection
    - Random utilities
    - Math helpers
]]

require "SentientNPC/Core"

-- =============================================================================
-- NAMESPACE
-- =============================================================================

SentientNPC.Utils = SentientNPC.Utils or {}
local Utils = SentientNPC.Utils

-- =============================================================================
-- MATH UTILITIES
-- =============================================================================

---Linear interpolation between two values
---@param value number Input value
---@param inMin number Input minimum
---@param inMax number Input maximum
---@param outMin number Output minimum
---@param outMax number Output maximum
---@return number Interpolated output value
function Utils.Lerp(value, inMin, inMax, outMin, outMax)
    if inMax == inMin then return outMin end
    local t = (value - inMin) / (inMax - inMin)
    t = math.max(0, math.min(1, t))
    return outMin + t * (outMax - outMin)
end

---Clamp a value between min and max
---@param value number The value to clamp
---@param min number Minimum value
---@param max number Maximum value
---@return number Clamped value
function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

---Round a number to specified decimal places
---@param num number The number to round
---@param decimals number|nil Decimal places (default 0)
---@return number Rounded number
function Utils.Round(num, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

-- =============================================================================
-- DISTANCE CALCULATIONS
-- =============================================================================

---Calculate 2D distance between two points
---@param x1 number First X coordinate
---@param y1 number First Y coordinate
---@param x2 number Second X coordinate
---@param y2 number Second Y coordinate
---@return number Distance
function Utils.DistTo(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

---Calculate 3D distance between two points
---@param x1 number First X
---@param y1 number First Y
---@param z1 number First Z
---@param x2 number Second X
---@param y2 number Second Y
---@param z2 number Second Z
---@return number Distance
function Utils.DistTo3D(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = (z2 - z1) * 3  -- Z is weighted more in PZ
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Calculate Manhattan distance (faster, good for large distances)
---@param x1 number First X
---@param y1 number First Y
---@param x2 number Second X
---@param y2 number Second Y
---@return number Manhattan distance
function Utils.ManhattanDist(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

---Get distance between two characters
---@param char1 IsoGameCharacter First character
---@param char2 IsoGameCharacter Second character
---@return number Distance
function Utils.DistBetween(char1, char2)
    if not char1 or not char2 then return 9999 end
    return Utils.DistTo(char1:getX(), char1:getY(), char2:getX(), char2:getY())
end

-- =============================================================================
-- CHARACTER IDENTIFICATION
-- =============================================================================

---Get a unique ID for a character (works for players and zombies)
---@param character IsoGameCharacter The character
---@return number|nil The unique ID
function Utils.GetCharacterID(character)
    if not character then return nil end

    -- For zombies, use persistent outfit ID (survives object pooling)
    if instanceof(character, "IsoZombie") then
        return character:getPersistentOutfitID()
    end

    -- For players, use online ID
    if instanceof(character, "IsoPlayer") then
        return character:getOnlineID()
    end

    -- Fallback to online ID
    if character.getOnlineID then
        return character:getOnlineID()
    end

    return nil
end

---Get the online ID of a zombie (NOT persistent, changes on respawn)
---@param zombie IsoZombie The zombie
---@return number|nil Online ID
function Utils.GetZombieOnlineID(zombie)
    if not zombie then return nil end
    return zombie:getOnlineID()
end

---Get persistent outfit ID (survives object pooling)
---@param zombie IsoZombie The zombie
---@return number|nil Persistent ID
function Utils.GetPersistentID(zombie)
    if not zombie then return nil end
    return zombie:getPersistentOutfitID()
end

-- =============================================================================
-- FACING AND ANGLES
-- =============================================================================

---Get the direction a character is facing (in degrees, 0=North)
---@param character IsoGameCharacter The character
---@return number Direction in degrees
function Utils.GetFacingDirection(character)
    if not character then return 0 end
    local dir = character:getDir()
    if not dir then return 0 end
    return dir:toAngle()
end

---Check if character is facing a point (within tolerance)
---@param character IsoGameCharacter The character
---@param targetX number Target X
---@param targetY number Target Y
---@param tolerance number|nil Angle tolerance in degrees (default 45)
---@return boolean True if facing the point
function Utils.IsFacing(character, targetX, targetY, tolerance)
    tolerance = tolerance or 45
    if not character then return false end

    local cx, cy = character:getX(), character:getY()
    local facingAngle = Utils.GetFacingDirection(character)

    -- Calculate angle to target
    local dx = targetX - cx
    local dy = targetY - cy
    local targetAngle = math.deg(math.atan2(dy, dx))

    -- Normalize angles
    local diff = math.abs(facingAngle - targetAngle)
    if diff > 180 then diff = 360 - diff end

    return diff <= tolerance
end

---Calculate angle from one point to another
---@param x1 number Source X
---@param y1 number Source Y
---@param x2 number Target X
---@param y2 number Target Y
---@return number Angle in degrees
function Utils.AngleTo(x1, y1, x2, y2)
    return math.deg(math.atan2(y2 - y1, x2 - x1))
end

-- =============================================================================
-- TARGET DETECTION
-- =============================================================================

---Find the closest player to a position
---@param x number X coordinate
---@param y number Y coordinate
---@param maxRange number|nil Maximum range to search
---@return IsoPlayer|nil Closest player
---@return number Distance to closest player
function Utils.GetClosestPlayer(x, y, maxRange)
    maxRange = maxRange or SentientNPC.Config.DETECT_PLAYER_RANGE

    local closestPlayer = nil
    local closestDist = maxRange + 1

    local players = getOnlinePlayers()
    if not players then return nil, closestDist end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and not player:isDead() then
            local dist = Utils.DistTo(x, y, player:getX(), player:getY())
            if dist < closestDist then
                closestDist = dist
                closestPlayer = player
            end
        end
    end

    return closestPlayer, closestDist
end

---Find the closest zombie to a position (excluding possessed NPCs)
---@param x number X coordinate
---@param y number Y coordinate
---@param maxRange number|nil Maximum range
---@param excludeNPC IsoZombie|nil NPC to exclude from search
---@return IsoZombie|nil Closest zombie
---@return number Distance
function Utils.GetClosestZombie(x, y, maxRange, excludeNPC)
    maxRange = maxRange or SentientNPC.Config.DETECT_ZOMBIE_RANGE

    local closestZombie = nil
    local closestDist = maxRange + 1

    local cell = getCell()
    if not cell then return nil, closestDist end

    local zombieList = cell:getZombieList()
    if not zombieList then return nil, closestDist end

    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if zombie and not zombie:isDead() then
            -- Skip if this is the excludeNPC
            if excludeNPC and Utils.GetPersistentID(zombie) == Utils.GetPersistentID(excludeNPC) then
                -- Skip
            -- Skip possessed NPCs (they're not threats)
            elseif zombie:getVariableBoolean("Possessed") then
                -- Skip
            else
                local dist = Utils.DistTo(x, y, zombie:getX(), zombie:getY())
                if dist < closestDist then
                    closestDist = dist
                    closestZombie = zombie
                end
            end
        end
    end

    return closestZombie, closestDist
end

---Get all players within range
---@param x number X coordinate
---@param y number Y coordinate
---@param range number Range to search
---@return table List of {player, dist} pairs
function Utils.GetPlayersInRange(x, y, range)
    local result = {}

    local players = getOnlinePlayers()
    if not players then return result end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and not player:isDead() then
            local dist = Utils.DistTo(x, y, player:getX(), player:getY())
            if dist <= range then
                table.insert(result, {player = player, dist = dist})
            end
        end
    end

    -- Sort by distance
    table.sort(result, function(a, b) return a.dist < b.dist end)

    return result
end

-- =============================================================================
-- LINE OF SIGHT
-- =============================================================================

---Check if there's a clear line of sight between two points
---@param x1 number Start X
---@param y1 number Start Y
---@param z1 number Start Z
---@param x2 number End X
---@param y2 number End Y
---@param z2 number End Z
---@return boolean True if line is clear
function Utils.LineClear(x1, y1, z1, x2, y2, z2)
    -- Use PZ's built-in line-of-sight
    local sq1 = getCell():getGridSquare(x1, y1, z1)
    local sq2 = getCell():getGridSquare(x2, y2, z2)

    if not sq1 or not sq2 then return false end

    return sq1:isSeen(sq2, false)
end

---Check if character can see a target
---@param character IsoGameCharacter The observer
---@param target IsoGameCharacter The target
---@return boolean True if can see
function Utils.CanSee(character, target)
    if not character or not target then return false end

    return Utils.LineClear(
        character:getX(), character:getY(), character:getZ(),
        target:getX(), target:getY(), target:getZ()
    )
end

-- =============================================================================
-- RANDOM UTILITIES
-- =============================================================================

---Get a random integer in range [min, max]
---@param min number Minimum value
---@param max number Maximum value
---@return number Random integer
function Utils.RandInt(min, max)
    return ZombRand(max - min + 1) + min
end

---Get a random float in range [min, max]
---@param min number Minimum value
---@param max number Maximum value
---@return number Random float
function Utils.RandFloat(min, max)
    return ZombRandFloat(min, max)
end

---Pick a random element from a table
---@param tbl table The table to pick from
---@return any Random element (or nil if empty)
function Utils.Choice(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[ZombRand(#tbl) + 1]
end

---Shuffle a table in-place
---@param tbl table The table to shuffle
---@return table The same table, shuffled
function Utils.Shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = ZombRand(i) + 1
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

---Generate a random UUID-like string
---@return string UUID string
function Utils.GenerateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and ZombRand(16) or (ZombRand(4) + 8)
        return string.format("%x", v)
    end)
end

-- =============================================================================
-- TABLE UTILITIES
-- =============================================================================

---Deep copy a table (Kahlua-safe version)
---@param orig table Original table
---@return table Copy of the table
function Utils.DeepCopy(orig)
    -- Handle nil explicitly
    if orig == nil then return nil end

    local orig_type = type(orig)
    local copy

    if orig_type == "table" then
        copy = {}
        -- Use pairs() instead of next - more compatible with Kahlua
        for orig_key, orig_value in pairs(orig) do
            copy[Utils.DeepCopy(orig_key)] = Utils.DeepCopy(orig_value)
        end
        -- NOTE: Metatables are NOT copied - getmetatable/setmetatable
        -- are restricted in Project Zomboid's Kahlua implementation
    else
        -- For non-tables (numbers, strings, booleans), just copy the value
        copy = orig
    end

    return copy
end

---Count elements in a table (works for non-array tables)
---@param tbl table The table
---@return number Count
function Utils.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

---Check if table contains a value
---@param tbl table The table
---@param value any The value to find
---@return boolean True if found
function Utils.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

-- =============================================================================
-- STRING UTILITIES
-- =============================================================================

---Split a string by delimiter
---@param str string The string to split
---@param delimiter string The delimiter
---@return table Array of substrings
function Utils.Split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- =============================================================================
-- SQUARE UTILITIES
-- =============================================================================

---Get the square at coordinates
---@param x number X coordinate
---@param y number Y coordinate
---@param z number Z coordinate (floor level)
---@return IsoGridSquare|nil The square
function Utils.GetSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

---Check if a square is walkable
---@param square IsoGridSquare The square
---@return boolean True if walkable
function Utils.IsWalkable(square)
    if not square then return false end
    return not square:isSolid() and not square:isBlockedTo(nil)
end

---Find a walkable square near a position
---@param x number Center X
---@param y number Center Y
---@param z number Z level
---@param radius number Search radius
---@return IsoGridSquare|nil Walkable square
function Utils.FindWalkableSquare(x, y, z, radius)
    radius = radius or 5

    for r = 0, radius do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local sq = Utils.GetSquare(x + dx, y + dy, z)
                    if Utils.IsWalkable(sq) then
                        return sq
                    end
                end
            end
        end
    end

    return nil
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

SentientNPC.Debug("Utils module loaded")

return Utils
