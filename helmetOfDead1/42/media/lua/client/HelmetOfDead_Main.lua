--[[
    Helmet of Dead - B42 Compatible
    Un casco explosivo que mata al jugador despues de un tiempo.
    Requiere HelmetKey para desactivarlo.
]]

local HelmetOfDead = {}

-- Configuracion
HelmetOfDead.HELMET_ITEM = "HelmetAsDead"
HelmetOfDead.KEY_ITEM = "HelmetKey"
HelmetOfDead.TIMER_DURATION = 7200  -- 2 minutos a 60 ticks/seg
HelmetOfDead.TICK_INTERVAL = 60     -- Update cada segundo

-- Estado del mod
HelmetOfDead.activeHelmets = {}     -- {playerID = {timer, active}}
HelmetOfDead.tickCounter = 0

-----------------------------------------------------------
-- Utilidades
-----------------------------------------------------------

local function getPlayerID(player)
    if not player then return nil end
    return player:getUsername() or tostring(player:getOnlineID())
end

local function hasHelmetEquipped(player)
    if not player then return false end
    local helmet = player:getWornItem("Hat")
    if helmet and helmet:getType() == HelmetOfDead.HELMET_ITEM then
        return true
    end
    return false
end

local function hasKey(player)
    if not player then return false end
    local inventory = player:getInventory()
    if inventory then
        return inventory:contains(HelmetOfDead.KEY_ITEM)
    end
    return false
end

-----------------------------------------------------------
-- Logica del Casco
-----------------------------------------------------------

function HelmetOfDead.activate(player)
    local playerID = getPlayerID(player)
    if not playerID then return end

    HelmetOfDead.activeHelmets[playerID] = {
        timer = HelmetOfDead.TIMER_DURATION,
        active = true
    }

    player:Say("*click* El casco se activa...")
    print("[HelmetOfDead] Activado para: " .. playerID)
end

function HelmetOfDead.deactivate(player)
    local playerID = getPlayerID(player)
    if not playerID then return end

    if HelmetOfDead.activeHelmets[playerID] then
        HelmetOfDead.activeHelmets[playerID].active = false
        HelmetOfDead.activeHelmets[playerID] = nil
        player:Say("*click* El casco se desactiva!")
        print("[HelmetOfDead] Desactivado para: " .. playerID)
    end
end

function HelmetOfDead.explode(player)
    local playerID = getPlayerID(player)
    print("[HelmetOfDead] BOOM! Explosion para: " .. tostring(playerID))

    player:Say("BOOM!")

    -- Matar al jugador
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        bodyDamage:ReduceGeneralHealth(1000)
    end

    -- Limpiar estado
    if playerID then
        HelmetOfDead.activeHelmets[playerID] = nil
    end
end

function HelmetOfDead.updateTimer(player)
    local playerID = getPlayerID(player)
    if not playerID then return end

    local helmetData = HelmetOfDead.activeHelmets[playerID]
    if not helmetData or not helmetData.active then return end

    -- Decrementar timer
    helmetData.timer = helmetData.timer - HelmetOfDead.TICK_INTERVAL

    local timer = helmetData.timer
    local totalTime = HelmetOfDead.TIMER_DURATION

    -- Sonidos de advertencia (cada vez mas frecuentes)
    if timer > totalTime * 0.75 then
        -- Fase 1: Pip ocasional
        if timer % 1800 == 0 then
            player:Say("*pip*")
        end
    elseif timer > totalTime * 0.5 then
        -- Fase 2: Pip pip
        if timer % 900 == 0 then
            player:Say("*pip pip*")
        end
    elseif timer > totalTime * 0.25 then
        -- Fase 3: Pip pip pip
        if timer % 300 == 0 then
            player:Say("*pip pip pip*")
        end
    else
        -- Fase 4: Beep constante
        if timer % 120 == 0 then
            player:Say("*BEEP BEEP BEEP*")
        end
    end

    -- Explosion!
    if timer <= 0 then
        HelmetOfDead.explode(player)
    end
end

-----------------------------------------------------------
-- Eventos
-----------------------------------------------------------

function HelmetOfDead.onTick()
    HelmetOfDead.tickCounter = HelmetOfDead.tickCounter + 1

    -- Solo actualizar cada TICK_INTERVAL
    if HelmetOfDead.tickCounter < HelmetOfDead.TICK_INTERVAL then
        return
    end
    HelmetOfDead.tickCounter = 0

    -- Obtener jugador local
    local player = getPlayer()
    if not player then return end

    local playerID = getPlayerID(player)
    local helmetEquipped = hasHelmetEquipped(player)
    local helmetData = HelmetOfDead.activeHelmets[playerID]

    -- Si tiene casco equipado pero no activo, activar
    if helmetEquipped and not helmetData then
        HelmetOfDead.activate(player)
    -- Si no tiene casco pero hay datos activos, limpiar
    elseif not helmetEquipped and helmetData then
        HelmetOfDead.activeHelmets[playerID] = nil
    -- Si esta activo, actualizar timer
    elseif helmetData and helmetData.active then
        HelmetOfDead.updateTimer(player)
    end
end

function HelmetOfDead.onContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local playerID = getPlayerID(player)
    local helmetData = HelmetOfDead.activeHelmets[playerID]

    -- Revisar si algun item es el casco o la llave
    for i, v in ipairs(items) do
        local item = v
        if not instanceof(item, "InventoryItem") then
            if v.items then
                item = v.items[1]
            end
        end

        if item and instanceof(item, "InventoryItem") then
            local itemType = item:getType()

            -- Opcion para desactivar con llave
            if itemType == HelmetOfDead.KEY_ITEM and helmetData and helmetData.active then
                context:addOption(
                    "Desactivar Casco Explosivo",
                    player,
                    HelmetOfDead.deactivate
                )
            end
        end
    end
end

function HelmetOfDead.onGameStart()
    print("[HelmetOfDead] Mod iniciado - B42")
end

-----------------------------------------------------------
-- Registro de Eventos
-----------------------------------------------------------

Events.OnGameStart.Add(HelmetOfDead.onGameStart)
Events.OnTick.Add(HelmetOfDead.onTick)
Events.OnFillInventoryObjectContextMenu.Add(HelmetOfDead.onContextMenu)

return HelmetOfDead
