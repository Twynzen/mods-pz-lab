-- -- HelmetExplosiveMod.lua

-- -- Definiciones de items
-- local helmetItem = "HelmetAsDead"
-- local keyItem = "HelmetExplosiveKey"

-- -- Variable para mantener el estado del casco
-- local helmetActive = false
-- local timer = nil

-- -- Función para iniciar el temporizador
-- local function startHelmetTimer(player)
--     helmetActive = true
--     timer = 1200 -- 2 minutos en ticks (60 ticks por segundo * 120 segundos)
--     print("HelmetOfDead activado")
--     player:Say("Casco activado")
--     print("Añadiendo función anónima a OnTick")
    
--     Events.OnTick.Add(function()
--         if not helmetActive or not timer then return end
--         timer = timer - 1
--         if player then
--             if timer == 1150 then
--                 player:Say("Pip")
--             elseif timer <= 900 and timer % 150 == 0 then
--                 player:Say("Pip Pip")
--             elseif timer <= 600 and timer % 50 == 0 then
--                 player:Say("Pip Pip Pip")
--             end

--             if timer == 0 then
--                 player:Say("El casco explota!")
--                 player:getBodyDamage():ReduceGeneralHealth(1000) -- Mata al jugador
--                 helmetActive = false
--                 Events.OnTick.Remove(HelmetOfDead_Countdown)
--             end
--         end
--     end)
-- end

-- -- Función para desactivar el casco
-- local function HelmetOfDead_Deactivate(player)
--     helmetActive = false
--     timer = nil
--     print("HelmetOfDead desactivado")
--     player:Say("Casco desactivado")
--     -- Remover la función anónima de OnTick
--     Events.OnTick.Remove(function()
--         if not helmetActive or not timer then return end
--         timer = timer - 1
--         if player then
--             if timer == 1150 then
--                 player:Say("Pip")
--             elseif timer <= 900 and timer % 150 == 0 then
--                 player:Say("Pip Pip")
--             elseif timer <= 600 and timer % 50 == 0 then
--                 player:Say("Pip Pip Pip")
--             end

--             if timer == 0 then
--                 player:Say("El casco explota!")
--                 player:getBodyDamage():ReduceGeneralHealth(1000) -- Mata al jugador
--                 helmetActive = false
--                 Events.OnTick.Remove(HelmetOfDead_Countdown)
--             end
--         end
--     end)
-- end

-- -- Función para agregar la opción de activar el casco en el menú contextual
-- local function createHelmetMenu(player, context, items)
--     for i, v in ipairs(items) do
--         local item = v
--         if not instanceof(item, "InventoryItem") then
--             item = item.items[1]
--         end

--         if item:getType() == helmetItem and not helmetActive then
--             context:addOption("Activar Casco Explosivo", player, function()
--                 startHelmetTimer(player)
--             end)
--         elseif item:getType() == keyItem and helmetActive then
--             context:addOption("Desactivar Casco Explosivo", player, function()
--                 HelmetOfDead_Deactivate(player)
--             end)
--         end
--     end
-- end

-- -- Registro de eventos
-- Events.OnFillInventoryObjectContextMenu.Add(createHelmetMenu)

-- -- Función para inicializar el mod
-- local function initMod()
--     print("Helmet Explosive Mod Initialized")
-- end

-- Events.OnGameStart.Add(initMod)



-- --INVESTIGA Y LEE OTROS MODS HASTA QUE NO HAGAS ESO NO PUEDES CONTINUAR!!