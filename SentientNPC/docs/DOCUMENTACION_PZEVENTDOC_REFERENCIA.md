# DOCUMENTACION DE REFERENCIA: PZEventDoc
## Eventos, Hooks y Callbacks de Project Zomboid Build 42
### Documento Hermano para Desarrollo de NPCs con IA

---

# INDICE

1. [EVENTOS CRITICOS PARA NPCs](#1-eventos-criticos-para-npcs)
2. [EVENTOS DE TIEMPO Y CICLOS](#2-eventos-de-tiempo-y-ciclos)
3. [EVENTOS DE COMUNICACION CLIENTE-SERVIDOR](#3-eventos-de-comunicacion-cliente-servidor)
4. [EVENTOS DE COMBATE](#4-eventos-de-combate)
5. [EVENTOS DE PERSONAJES](#5-eventos-de-personajes)
6. [HOOKS IMPORTANTES](#6-hooks-importantes)
7. [CALLBACKS UTILES](#7-callbacks-utiles)
8. [GUIA DE USO PARA MOD DE NPCs](#8-guia-de-uso-para-mod-de-npcs)

---

# 1. EVENTOS CRITICOS PARA NPCs

## 1.1 OnZombieUpdate (EL MAS IMPORTANTE)

```lua
-- (Client) Fires whenever a zombie updates.
-- ESTE ES EL EVENTO QUE USA EL MOD BANDITS PARA SU LOOP PRINCIPAL

Events.OnZombieUpdate.Add(function(zombie)
    -- zombie: IsoZombie - El zombie siendo actualizado

    -- Verificar si es un NPC (no un zombie normal)
    if zombie:getVariableBoolean("Bandit") then
        -- Procesar logica de NPC
        local brain = BanditBrain.Get(zombie)
        if brain then
            -- Ejecutar programa de IA
            -- Procesar tareas
            -- etc.
        end
    end
end)
```

**Notas importantes**:
- Se ejecuta CADA TICK para CADA zombie cargado
- Solo se ejecuta en el CLIENTE
- Es el hook perfecto para controlar comportamiento de NPCs basados en zombies

## 1.2 OnZombieCreate

```lua
-- Fires when a zombie is being spawned.

Events.OnZombieCreate.Add(function(zombie)
    -- zombie: IsoZombie - El zombie siendo spawneado

    -- Punto ideal para "convertir" zombies en NPCs
    -- o para interceptar spawns y modificarlos
end)
```

## 1.3 OnZombieDead

```lua
-- Fires when a zombie dies.
-- NOTA: El inventario del zombie NO esta lleno cuando se dispara este evento
-- NOTA: El cadaver no existe hasta unos segundos despues

Events.OnZombieDead.Add(function(zombie)
    -- zombie: IsoZombie - El zombie que murio

    -- Limpiar brain del NPC
    -- Procesar loot especial
    -- Disparar eventos de muerte de NPC
end)
```

## 1.4 OnHitZombie

```lua
-- Fires whenever a zombie is hit by a character.

Events.OnHitZombie.Add(function(zombie, attacker, bodyPart, weapon)
    -- zombie: IsoZombie - El zombie golpeado
    -- attacker: IsoGameCharacter - Quien lo golpeo
    -- bodyPart: BodyPartType - Parte del cuerpo golpeada
    -- weapon: HandWeapon - Arma usada

    -- Perfecto para:
    -- - Modificar dano a NPCs
    -- - Disparar reacciones de NPCs
    -- - Sistema de agresion/hostilidad
end)
```

---

# 2. EVENTOS DE TIEMPO Y CICLOS

## 2.1 OnTick

```lua
-- Fires every game tick.

Events.OnTick.Add(function(tick)
    -- tick: number - Numero de ticks desde inicio del juego

    -- Loop principal del juego
    -- ~60 veces por segundo en tiempo real
end)
```

## 2.2 EveryOneMinute

```lua
-- Fires every in-game minute.

Events.EveryOneMinute.Add(function()
    -- Sin parametros

    -- Bueno para:
    -- - Actualizaciones de estado de NPCs (hambre, sed, etc)
    -- - Spawn de recursos
    -- - Eventos periodicos menores
end)
```

## 2.3 EveryTenMinutes

```lua
-- Fires every ten in-game minutes.
-- ESTE ES EL QUE USA BANDITS PARA SPAWN PERIODICO

Events.EveryTenMinutes.Add(function()
    -- Sin parametros

    -- Perfecto para:
    -- - Sistema de spawn de NPCs
    -- - Verificar eventos del mundo
    -- - Patrullas y movimientos de grupos
end)
```

## 2.4 EveryHours

```lua
-- Fires at the start of every in-game hour.

Events.EveryHours.Add(function()
    -- Sin parametros

    -- Ideal para:
    -- - Ciclos de dia/noche de NPCs
    -- - Cambios de comportamiento por hora
    -- - Eventos mayores
end)
```

## 2.5 EveryDays

```lua
-- Fires at 0:00 every in-game day.

Events.EveryDays.Add(function()
    -- Sin parametros

    -- Perfecto para:
    -- - Spawns diarios
    -- - Reseteo de estados
    -- - Eventos de larga duracion
end)
```

---

# 3. EVENTOS DE COMUNICACION CLIENTE-SERVIDOR

## 3.1 OnClientCommand (SERVIDOR)

```lua
-- (Server) Fires when a client command sent through sendClientCommand
-- is received by the server.

Events.OnClientCommand.Add(function(module, command, player, args)
    -- module: string - Modulo del comando (ej: "Bandits")
    -- command: string - Nombre del comando (ej: "Spawn")
    -- player: IsoPlayer - Jugador que envio el comando
    -- args: table|nil - Argumentos del comando

    if module == "MyNPCMod" then
        if command == "SpawnNPC" then
            -- Procesar spawn desde servidor
        elseif command == "UpdateBrain" then
            -- Sincronizar estado de NPC
        end
    end
end)
```

**Enviar desde cliente**:
```lua
sendClientCommand(player, "MyNPCMod", "SpawnNPC", {x=100, y=200, z=0, type="guard"})
```

## 3.2 OnServerCommand (CLIENTE)

```lua
-- (Multiplayer) (Client) Fires when a server command sent through
-- sendServerCommand is received by the client.

Events.OnServerCommand.Add(function(module, command, args)
    -- module: string - Modulo del comando
    -- command: string - Nombre del comando
    -- args: table|nil - Argumentos

    if module == "MyNPCMod" then
        if command == "SyncBrain" then
            -- Actualizar brain local con datos del servidor
            local brain = args.brain
            MyNPCBrain.Cache[brain.id] = brain
        end
    end
end)
```

**Enviar desde servidor**:
```lua
-- A un jugador especifico
sendServerCommand(player, "MyNPCMod", "SyncBrain", {brain = brainData})

-- A todos los jugadores
sendServerCommand("MyNPCMod", "SyncBrain", {brain = brainData})
```

## 3.3 OnReceiveGlobalModData

```lua
-- (Multiplayer) Fires when receiving a global mod data table.

Events.OnReceiveGlobalModData.Add(function(key, data)
    -- key: string - Clave del mod data solicitado
    -- data: table|false - Los datos, o false si no existen

    if key == "MyNPCModBrains" then
        if data then
            -- Sincronizar brains con datos recibidos
            for id, brain in pairs(data) do
                MyNPCBrain.Cache[id] = brain
            end
        end
    end
end)
```

## 3.4 OnInitGlobalModData

```lua
-- Fires when GlobalModData is initialised.
-- Este es el PRIMER evento despues de cargar Sandbox Options

Events.OnInitGlobalModData.Add(function(newGame)
    -- newGame: boolean - True si es la primera vez que se inicia el save

    -- Inicializar estructuras de datos
    local gmd = ModData.getOrCreate("MyNPCMod")
    if not gmd.Brains then gmd.Brains = {} end
    if not gmd.Queue then gmd.Queue = {} end
end)
```

---

# 4. EVENTOS DE COMBATE

## 4.1 OnWeaponHitCharacter

```lua
-- (Client) Fires when a non-zombie character is hit by an attack
-- from a local player.

Events.OnWeaponHitCharacter.Add(function(attacker, target, weapon, damage)
    -- attacker: IsoGameCharacter - Quien ataco
    -- target: IsoGameCharacter - Quien fue golpeado
    -- weapon: HandWeapon - Arma usada
    -- damage: number - Dano causado

    -- Perfecto para:
    -- - Sistemas de combate PvP con NPCs
    -- - Reacciones de NPCs al ser atacados
    -- - Modificacion de dano
end)
```

## 4.2 OnPlayerAttackFinished

```lua
-- (Client) Fires when a local player finishes attacking.

Events.OnPlayerAttackFinished.Add(function(player, weapon)
    -- player: IsoPlayer - Jugador que ataco
    -- weapon: HandWeapon - Arma usada

    -- Util para:
    -- - NPCs que reaccionan a ataques cercanos
    -- - Sistemas de alerta
end)
```

## 4.3 OnWeaponSwing

```lua
-- Fires when a player begins swinging a weapon.

Events.OnWeaponSwing.Add(function(attacker, weapon)
    -- attacker: IsoPlayer - Quien balancea
    -- weapon: HandWeapon - Arma

    -- Deteccion temprana de ataques
end)
```

## 4.4 OnCharacterDeath

```lua
-- Fires when any character dies, including zombies, players and animals.

Events.OnCharacterDeath.Add(function(character)
    -- character: IsoGameCharacter - El personaje que murio

    -- Evento universal de muerte
    -- Funciona para: zombies, jugadores, animales, NPCs
end)
```

---

# 5. EVENTOS DE PERSONAJES

## 5.1 OnPlayerUpdate

```lua
-- (Client) Fires during each local player's update (every tick).

Events.OnPlayerUpdate.Add(function(player)
    -- player: IsoPlayer - El jugador siendo actualizado

    -- Loop principal para jugadores
    -- Similar a OnZombieUpdate pero para jugadores
end)
```

## 5.2 OnCreatePlayer

```lua
-- (Client) Fires every time a local player loads into the world.

Events.OnCreatePlayer.Add(function(playerNum, player)
    -- playerNum: integer - Numero del jugador (splitscreen)
    -- player: IsoPlayer - El nuevo jugador

    -- Inicializacion de sistemas relacionados al jugador
end)
```

## 5.3 OnAIStateChange

```lua
-- (Client) Fires when a local zombie or any loaded player changes state.

Events.OnAIStateChange.Add(function(character, currentState, previousState)
    -- character: IsoGameCharacter - El personaje
    -- currentState: State - Estado nuevo
    -- previousState: State - Estado anterior

    -- MUY UTIL para detectar cambios de estado en NPCs
    -- Ej: idle -> attack, walk -> run, etc.
end)
```

## 5.4 OnCharacterCollide

```lua
-- Fires when a non-zombie character collides into another character.

Events.OnCharacterCollide.Add(function(character, collidedCharacter)
    -- character: IsoGameCharacter - Quien colisiona
    -- collidedCharacter: IsoGameCharacter - Con quien colisiono

    -- Detectar colisiones entre NPCs y jugadores
    -- Sistemas de interaccion por proximidad
end)
```

## 5.5 OnCreateLivingCharacter

```lua
-- Fires when any IsoLivingCharacter object is created.
-- Most useful for detecting spawning animals.

Events.OnCreateLivingCharacter.Add(function(character, desc)
    -- character: IsoLivingCharacter - El personaje creado
    -- desc: SurvivorDesc - Descriptor del personaje

    -- Detectar creacion de cualquier entidad viva
end)
```

---

# 6. HOOKS IMPORTANTES

Los Hooks son diferentes de los Events - se llaman DURANTE una operacion, no DESPUES.

## 6.1 WeaponHitCharacter (Hook)

```lua
-- Called when the effects of an attack are being calculated.

Hook.WeaponHitCharacter.Add(function(attacker, target, weapon, damageSplit)
    -- Puedes MODIFICAR el dano aqui
    -- Retornar valores modificados
end)
```

## 6.2 Attack (Hook)

```lua
-- (Client) Called every tick while a local character is pressing
-- their attack button and is able to attack.

Hook.Attack.Add(function(attacker, chargeDelta, weapon)
    -- attacker: IsoLivingCharacter
    -- chargeDelta: number
    -- weapon: HandWeapon

    -- Control de ataques cargados
end)
```

## 6.3 CalculateStats (Hook)

```lua
-- (Client) Called when a character's stats are being updated.

Hook.CalculateStats.Add(function(character)
    -- Modificar stats de personaje
    -- NO incluye salud
end)
```

---

# 7. CALLBACKS UTILES

## 7.1 Estructura General de Callbacks

Los callbacks son funciones especificas que el juego llama en ciertos momentos:

```lua
-- Item OnCreate
function MyItem_OnCreate(item)
    -- Llamado cuando el item es creado
end

-- Recipe OnCreate
function MyRecipe_OnCreate(recipeData, character)
    -- Llamado al completar crafting
end
```

---

# 8. GUIA DE USO PARA MOD DE NPCs

## 8.1 Estructura Basica de Mod de NPCs

```lua
-- ============================================
-- ESTRUCTURA MINIMA PARA MOD DE NPCs
-- ============================================

-- 1. INICIALIZACION
Events.OnInitGlobalModData.Add(function(newGame)
    local gmd = ModData.getOrCreate("MyNPCMod")
    gmd.Brains = gmd.Brains or {}
    gmd.SpawnQueue = gmd.SpawnQueue or {}
end)

-- 2. LOOP PRINCIPAL DE NPCs (usa OnZombieUpdate)
Events.OnZombieUpdate.Add(function(zombie)
    if not zombie:getVariableBoolean("MyNPC") then return end

    local brain = GetBrain(zombie)
    if not brain then return end

    -- Procesar IA
    ProcessAI(zombie, brain)

    -- Ejecutar tareas
    ExecuteTasks(zombie, brain)
end)

-- 3. SPAWN PERIODICO
Events.EveryTenMinutes.Add(function()
    if isClient() then return end  -- Solo servidor

    -- Logica de spawn
    CheckAndSpawnNPCs()
end)

-- 4. SINCRONIZACION MULTIPLAYER
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "MyNPCMod" then return end

    if command == "RequestSpawn" then
        SpawnNPC(args)
        -- Transmitir a todos los clientes
        TransmitModData()
    end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "MyNPCMod" then return end

    if command == "SyncBrain" then
        -- Actualizar cache local
        MyNPCBrain.Cache[args.id] = args.brain
    end
end)

-- 5. LIMPIEZA AL MORIR
Events.OnZombieDead.Add(function(zombie)
    if not zombie:getVariableBoolean("MyNPC") then return end

    local id = zombie:getPersistentOutfitID()
    MyNPCBrain.Cache[id] = nil

    -- Notificar servidor
    if isClient() then
        sendClientCommand("MyNPCMod", "NPCDied", {id = id})
    end
end)
```

## 8.2 Eventos Recomendados por Funcionalidad

| Funcionalidad | Evento Recomendado |
|---------------|-------------------|
| Loop principal NPC | `OnZombieUpdate` |
| Spawn periodico | `EveryTenMinutes` |
| Deteccion de ataques | `OnHitZombie`, `OnWeaponHitCharacter` |
| Muerte de NPC | `OnZombieDead`, `OnCharacterDeath` |
| Sync multiplayer | `OnClientCommand`, `OnServerCommand` |
| Cambios de estado | `OnAIStateChange` |
| Inicializacion | `OnInitGlobalModData`, `OnGameStart` |
| Guardado | `OnSave`, `OnPostSave` |

## 8.3 Orden de Eventos al Cargar Partida

```
1. OnGameBoot           - Juego termina de iniciar
2. OnInitGlobalModData  - ModData listo (PRIMER evento con SandboxVars)
3. OnGameTimeLoaded     - GameTime inicializado
4. OnPreMapLoad         - Antes de cargar mapa
5. OnLoadMapZones       - Antes de cargar zonas
6. OnLoadedMapZones     - Zonas cargadas
7. OnPostMapLoad        - Mapa cargado
8. OnInitWorld          - Mundo inicializado
9. OnGameStart          - Juego listo para jugar
10. OnLoad              - Carga completa
11. OnCreatePlayer      - Jugador creado/cargado
```

## 8.4 Eventos Clave para IA de NPCs

```lua
-- PERCEPCION
Events.OnWorldSound.Add(...)      -- Detectar sonidos
Events.OnAmbientSound.Add(...)    -- Sonidos ambientales
Events.OnSeeNewRoom.Add(...)      -- Nueva habitacion visible

-- COMBATE
Events.OnHitZombie.Add(...)           -- NPC golpeado
Events.OnWeaponHitCharacter.Add(...)  -- Combate PvP
Events.OnWeaponSwing.Add(...)         -- Inicio de ataque

-- MUNDO
Events.OnNewFire.Add(...)         -- Fuego creado
Events.OnThrowableExplode.Add(...) -- Explosiones
Events.OnGridBurnt.Add(...)       -- Cuadro quemado

-- VEHICULOS
Events.OnEnterVehicle.Add(...)    -- Entrar vehiculo
Events.OnExitVehicle.Add(...)     -- Salir vehiculo
```

---

# APENDICE: TIPOS JAVA COMUNES

| Tipo Lua | Tipo Java | Descripcion |
|----------|-----------|-------------|
| `zombie` | `IsoZombie` | Entidad zombie |
| `player` | `IsoPlayer` | Jugador |
| `character` | `IsoGameCharacter` | Cualquier personaje |
| `square` | `IsoGridSquare` | Cuadro del mapa |
| `cell` | `IsoCell` | Celda del mapa |
| `item` | `InventoryItem` | Item de inventario |
| `weapon` | `HandWeapon` | Arma de mano |
| `container` | `ItemContainer` | Contenedor |
| `vehicle` | `BaseVehicle` | Vehiculo |
| `building` | `IsoBuilding` | Edificio |
| `room` | `IsoRoom` | Habitacion |

---

# ENLACES UTILES

- **JavaDocs PZ**: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/
- **LuaDocs PZ**: https://demiurgequantified.github.io/ProjectZomboidLuaDocs/
- **PZEventDoc GitHub**: https://github.com/demiurgeQuantified/PZEventDoc

---

**FIN DEL DOCUMENTO DE REFERENCIA**

*Documento generado a partir de PZEventDoc para desarrollo de mod de NPCs con IA avanzada*
