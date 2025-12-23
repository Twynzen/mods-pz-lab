# DOCUMENTACION MAESTRA: BANDITS MOD - PROJECT ZOMBOID BUILD 42
## Sistema de NPCs Avanzado - Analisis Tecnico Ultra Detallado

---

# INDICE

1. [ARQUITECTURA GENERAL](#1-arquitectura-general)
2. [SISTEMA CORE: BANDIT Y BANDITBRAIN](#2-sistema-core-bandit-y-banditbrain)
3. [SISTEMA DE PROGRAMAS (ZOMBIE PROGRAMS)](#3-sistema-de-programas-zombie-programs)
4. [SISTEMA DE ACCIONES (ZOMBIE ACTIONS)](#4-sistema-de-acciones-zombie-actions)
5. [SISTEMA DE SPAWN Y SERVIDOR](#5-sistema-de-spawn-y-servidor)
6. [SISTEMA DE CLANES Y CUSTOMIZACION](#6-sistema-de-clanes-y-customizacion)
7. [SISTEMA DE ARMAS Y COMBATE](#7-sistema-de-armas-y-combate)
8. [SISTEMA DE COMPATIBILIDAD B41/B42](#8-sistema-de-compatibilidad-b41b42)
9. [CICLO DE VIDA DEL NPC](#9-ciclo-de-vida-del-npc)
10. [GUIA PARA CREAR MOD DE NPCs CON IA](#10-guia-para-crear-mod-de-npcs-con-ia)

---

# 1. ARQUITECTURA GENERAL

## 1.1 Estructura de Archivos

```
Bandits/42/
├── mod.info                           # Metadatos del mod
├── media/
│   ├── lua/
│   │   ├── shared/                    # Codigo compartido cliente/servidor
│   │   │   ├── Bandit.lua             # API principal del NPC
│   │   │   ├── BanditBrain.lua        # Sistema de "cerebro" y memoria
│   │   │   ├── BanditUtils.lua        # Utilidades generales
│   │   │   ├── BanditPrograms.lua     # Subprogramas de comportamiento
│   │   │   ├── BanditCustom.lua       # Sistema de clanes/personalizacion
│   │   │   ├── BanditWeapons.lua      # Sistema de armas
│   │   │   ├── BanditCompatibility.lua # Capa de compatibilidad B41/B42
│   │   │   ├── BanditZombie.lua       # Cache de zombies
│   │   │   ├── BanditPlayer.lua       # Interaccion con jugadores
│   │   │   ├── ZombiePrograms/        # Programas de IA por tipo
│   │   │   │   ├── ZPBandit.lua       # Programa hostil/asalto
│   │   │   │   ├── ZPCompanion.lua    # Programa companero
│   │   │   │   ├── ZPDefend.lua       # Programa defensor
│   │   │   │   ├── ZPLooter.lua       # Programa merodeador
│   │   │   │   └── ...
│   │   │   └── ZombieActions/         # Acciones atomicas
│   │   │       ├── ZAMove.lua         # Accion de movimiento
│   │   │       ├── ZAShoot.lua        # Accion de disparo
│   │   │       ├── ZAMelee.lua        # Accion cuerpo a cuerpo
│   │   │       └── ...
│   │   ├── server/                    # Codigo solo servidor
│   │   │   ├── BanditServerSpawner.lua # Sistema de spawn
│   │   │   └── BanditServerCommands.lua
│   │   └── client/                    # Codigo solo cliente
│   │       ├── BanditUpdate.lua       # Loop principal de actualizacion
│   │       └── ...
│   └── bandits/                       # Configuracion de NPCs
│       ├── bandits.txt                # Definiciones de bandidos
│       └── clans.txt                  # Definiciones de clanes
```

## 1.2 Principio Fundamental: Zombies como Base

**CONCEPTO CLAVE**: El mod usa **zombies del juego base como contenedores** para los NPCs.

```lua
-- Los bandidos son zombies modificados con:
zombie:setNoTeeth(true)           -- No muerden
zombie:setVariable("Bandit", true) -- Marcados como bandidos
```

**Ventajas**:
- Usa el sistema de pathfinding nativo del juego
- Animaciones ya existentes
- Colisiones y fisica integradas
- Sincronizacion multijugador automatica

**Desventajas**:
- Limitaciones en animaciones personalizadas
- Comportamientos deben "overridear" el comportamiento zombie

## 1.3 Flujo de Datos Principal

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUJO DE UN NPC BANDIDO                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SPAWN (Server)                                              │
│     └─> BanditServerSpawner.spawnGroup()                        │
│         └─> addZombiesInOutfit() [API del juego]                │
│             └─> banditize(zombie, bandit, clan, args)           │
│                 └─> Crea "brain" con toda la configuracion      │
│                     └─> gmd.Queue[id] = brain                   │
│                                                                 │
│  2. INICIALIZACION (Cliente)                                    │
│     └─> BanditUpdate.OnZombieUpdate()                           │
│         └─> Detecta zombie en Queue                             │
│             └─> Banditize(zombie, brain)                        │
│                 └─> Configura variables de zombie               │
│                 └─> BanditBrain.Update(zombie, brain)           │
│                                                                 │
│  3. LOOP PRINCIPAL (Cliente - cada tick)                        │
│     └─> BanditUpdate.OnZombieUpdate()                           │
│         └─> BanditBrain.Get(zombie) -> brain                    │
│         └─> ManageActionState(bandit)                           │
│         └─> ManageHealth(bandit)                                │
│         └─> ManageCollisions(bandit)                            │
│         └─> ManageEndurance(bandit)                             │
│         └─> ZombiePrograms[brain.program.name][stage](bandit)   │
│             └─> Retorna {status, next, tasks[]}                 │
│         └─> Ejecuta tasks via ZombieActions                     │
│                                                                 │
│  4. SINCRONIZACION (Multiplayer)                                │
│     └─> BanditScheduler sincroniza brains entre clientes        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

# 2. SISTEMA CORE: BANDIT Y BANDITBRAIN

## 2.1 BanditBrain - El "Cerebro" del NPC

El `brain` es una **tabla Lua que almacena todo el estado** del NPC:

```lua
brain = {
    -- IDENTIFICACION
    id = 12345678,              -- ID persistente del zombie
    fullname = "John Smith",     -- Nombre generado

    -- POSICION INICIAL
    bornCoords = {x=100, y=200, z=0},
    born = 1234,                 -- Hora de nacimiento (game hours)

    -- AFILIACION
    clan = "bandits_default",    -- ID del clan
    cid = "guid-del-clan",       -- GUID del clan
    bid = "guid-del-bandido",    -- GUID unico del bandido

    -- HOSTILIDAD
    hostile = true,              -- Hostil a otros NPCs
    hostileP = true,             -- Hostil a jugadores

    -- PROGRAMA DE IA
    program = {
        name = "Bandit",         -- Nombre del programa activo
        stage = "Main"           -- Etapa actual
    },
    programFallback = "Bandit",  -- Programa por defecto

    -- TAREAS PENDIENTES
    tasks = {},                  -- Cola de acciones a ejecutar

    -- ESTADISTICAS
    health = 1.5,                -- Multiplicador de salud (1-2.6)
    accuracyBoost = 0,           -- Bonus precision (-8 a +8)
    strengthBoost = 1.0,         -- Multiplicador fuerza
    enduranceBoost = 1.0,        -- Multiplicador resistencia
    endurance = 1.00,            -- Resistencia actual (0-1)

    -- ESTADOS
    stationary = false,          -- Esta quieto forzosamente
    sleeping = false,            -- Esta durmiendo
    aiming = false,              -- Esta apuntando
    moving = false,              -- Esta moviendose
    inVehicle = false,           -- Esta en vehiculo

    -- ARMAS
    weapons = {
        melee = "Base.BareHands",
        primary = {
            name = "Base.AssaultRifle",
            bulletsLeft = 30,
            magCount = 3,
            magSize = 30,
            type = "mag",        -- "mag" o "nomag"
            racked = true,
            clipIn = true
        },
        secondary = {...}
    },

    -- EXPERTISES (Habilidades especiales)
    exp = {0, 0, 0},             -- 3 slots de expertises

    -- PERSONALIDAD (generada aleatoriamente)
    personality = {
        alcoholic = false,
        smoker = true,
        compulsiveCleaner = false,
        comicsCollector = false,
        -- etc...
    },

    -- APARIENCIA
    female = false,
    skin = 1,                    -- Indice de color de piel (1-5)
    hairType = 3,
    hairColor = 2,
    beardType = 1,
    clothing = {...},            -- Ropa equipada
    tint = {...},                -- Colores de ropa

    -- VOZ
    voice = "Male1",
    speech = 0.00,               -- Cooldown de dialogo

    -- INFECCION
    infection = 0,               -- Nivel de infeccion zombie (0-100)

    -- RELACIONES
    master = nil,                -- ID del jugador maestro (companions)
    loyal = false,               -- Es leal al master

    -- DIFERENCIADORES
    rnd = {0, 5, 42, 500, 1234}, -- Numeros aleatorios para variacion
}
```

## 2.2 Sistema de Expertises

Las **expertises** son habilidades especiales que modifican el comportamiento:

```lua
Bandit.Expertise = {
    None = 0,           -- Sin habilidad
    Recon = 1,          -- Mayor rango de deteccion (hearDist = 13)
    Tracker = 2,        -- Rango extremo de deteccion (hearDist = 55)
    Medic = 3,          -- Puede curar
    Electrician = 4,    -- Apaga generadores
    Mechanic = 5,       -- Sabotea vehiculos
    Thief = 6,          -- Roba de contenedores
    Looter = 7,         -- Busca loot en edificios
    Driver = 8,         -- Conduce vehiculos
    Sniper = 9,         -- Mayor precision a distancia
    Gunner = 10,        -- Mayor velocidad de disparo
    Sprinter = 11,      -- Corre mas rapido
    Guard = 12,         -- Se queda en posicion
    Forager = 13,       -- Busca comida
    Fisher = 14,        -- Pesca
    Gardener = 15,      -- Cuida plantas
    Cook = 16           -- Cocina
}

-- Verificar si tiene expertise:
if Bandit.HasExpertise(bandit, Bandit.Expertise.Recon) then
    config.hearDist = 13  -- Mayor rango de escucha
end
```

## 2.3 API Principal de Bandit.lua

```lua
-- OBTENCION DE DATOS
Bandit.GetWeapons(bandit)              -- Retorna tabla de armas
Bandit.IsOutOfAmmo(bandit)             -- true si sin municion
Bandit.HasExpertise(bandit, expId)     -- Verifica expertise
Bandit.IsHostile(bandit)               -- Verifica hostilidad
Bandit.IsSleeping(bandit)              -- Verifica si duerme

-- MODIFICACION DE ESTADO
Bandit.SetProgram(bandit, programName, args)  -- Cambia programa de IA
Bandit.SetSleeping(bandit, bool)              -- Establece sueno
Bandit.ForceStationary(bandit, bool)          -- Fuerza quietud

-- TAREAS
Bandit.AddTask(bandit, task)           -- Agrega tarea a cola
Bandit.ClearTasks(bandit)              -- Limpia cola de tareas
Bandit.HasActionTask(bandit)           -- Tiene tarea activa?
Bandit.HasTaskType(bandit, type)       -- Tiene tarea de tipo X?

-- COMUNICACION
Bandit.Say(bandit, dialogKey)          -- Dice dialogo
Bandit.SayLocation(bandit, square)     -- Comunica ubicacion de enemigo

-- COMBATE
Bandit.GetCombatWalktype(bandit, enemy, dist) -- Tipo de caminar en combate
Bandit.UpdateItemsToSpawnAtDeath(bandit)      -- Actualiza loot al morir
```

---

# 3. SISTEMA DE PROGRAMAS (ZOMBIE PROGRAMS)

## 3.1 Arquitectura de Programas

Cada programa define el **comportamiento general** del NPC:

```lua
ZombiePrograms.NombrePrograma = {}
ZombiePrograms.NombrePrograma.Stages = {}  -- Etapas opcionales

-- FUNCION DE INICIALIZACION (opcional)
ZombiePrograms.NombrePrograma.Init = function(bandit)
    -- Configuracion inicial
end

-- FUNCION PREPARE (siempre primera etapa)
ZombiePrograms.NombrePrograma.Prepare = function(bandit)
    local tasks = {}
    -- Preparacion...
    return {status=true, next="Main", tasks=tasks}
end

-- FUNCION MAIN (etapa principal)
ZombiePrograms.NombrePrograma.Main = function(bandit)
    local tasks = {}
    -- Logica principal...
    return {status=true, next="Main", tasks=tasks}
end

-- OTRAS ETAPAS PERSONALIZADAS
ZombiePrograms.NombrePrograma.Escape = function(bandit)
    -- Logica de escape...
end
```

## 3.2 Programas Disponibles

### ZPBandit (Programa de Asalto/Hostil)

```lua
-- ETAPAS: Prepare -> Main -> Escape -> Surrender

ZombiePrograms.Bandit.Main = function(bandit)
    local tasks = {}
    local health = bandit:getHealth()

    -- 1. HUIR SI SALUD BAJA
    if SandboxVars.Bandits.General_RunAway and health < 0.7 then
        return {status=true, next="Escape", tasks=tasks}
    end

    -- 2. ENCENDER LUCES (si esta en habitacion)
    local room = bandit:getSquare():getRoom()
    if room then
        -- Busca interruptores de luz y los enciende
    end

    -- 3. SABOTAJE (si tiene expertise)
    if Bandit.HasExpertise(bandit, Bandit.Expertise.Electrician) then
        -- Apaga generadores enemigos
    end
    if Bandit.HasExpertise(bandit, Bandit.Expertise.Mechanic) then
        -- Desinstala ruedas de vehiculos
    end

    -- 4. ROBO (si tiene expertise Thief)
    if SandboxVars.Bandits.General_Theft then
        -- Roba items de bases de jugadores
    end

    -- 5. DESTRUCCION DE CULTIVOS
    if SandboxVars.Bandits.General_SabotageCrops then
        -- Pisotea plantas
    end

    -- 6. BUSCAR Y ATACAR OBJETIVO
    local config = {mustSee = true, hearDist = 5}
    if Bandit.HasExpertise(bandit, Bandit.Expertise.Tracker) then
        config.hearDist = 55  -- RANGO ENORME
    end

    local target, enemy = BanditUtils.GetTarget(bandit, config)

    if target.x then
        -- Comunicar posicion a companeros
        Bandit.SayLocation(bandit, targetSquare)
        -- Moverse hacia objetivo
        local walkType = Bandit.GetCombatWalktype(bandit, enemy, target.dist)
        table.insert(tasks, BanditUtils.GetMoveTaskTarget(...))
    end

    return {status=true, next="Main", tasks=tasks}
end
```

### ZPCompanion (Programa de Companero)

```lua
-- ETAPAS: Prepare -> Main -> Guard

ZombiePrograms.Companion.Main = function(bandit)
    local tasks = {}

    -- 1. SI ESTA EN GUARDPOST, CAMBIAR A MODO GUARDIA
    if BanditPost.At(bandit, "guard") then
        return {status=true, next="Guard", tasks={}}
    end

    -- 2. OBTENER JUGADOR MAESTRO
    local master = BanditPlayer.GetMasterPlayer(bandit)
    if not master then
        -- Sin maestro, quedarse quieto
        return {status=true, next="Main", tasks={{action="Time", anim="Shrug", time=200}}}
    end

    -- 3. SINCRONIZAR MOVIMIENTO CON MAESTRO
    local walkType = "Walk"
    if master:isSprinting() or dist > 10 then
        walkType = "Run"
    elseif master:isSneaking() then
        walkType = "SneakWalk"
    end

    -- 4. MODO COMBATE SI MAESTRO APUNTA
    if master:isAiming() and not Bandit.IsOutOfAmmo(bandit) then
        walkType = "WalkAim"
    end

    -- 5. ATACAR ENEMIGOS CERCANOS (defensa proactiva)
    if dist < 20 then
        local closestEnemy = BanditUtils.GetClosestZombieLocation(bandit)
        if closestEnemy.dist < 8 then
            table.insert(tasks, BanditUtils.GetMoveTask(...))
            return {status=true, next="Main", tasks=tasks}
        end
    end

    -- 6. SEGUIR AL MAESTRO
    table.insert(tasks, BanditUtils.GetMoveTaskTarget(endurance, dx, dy, dz, did, true, walkType, distTarget))

    return {status=true, next="Main", tasks=tasks}
end

-- MODO GUARDIA: Se queda en posicion y ataca enemigos
ZombiePrograms.Companion.Guard = function(bandit)
    Bandit.ForceStationary(bandit, true)  -- No se mueve

    local closestEnemy = BanditUtils.GetClosestZombieLocation(bandit)
    if closestEnemy.dist < 24 then
        -- Girar hacia enemigo para disparar
        local task = {action="FaceLocation", x=closestEnemy.x, y=closestEnemy.y, time=100}
        table.insert(tasks, task)
    end

    return {status=true, next="Guard", tasks=tasks}
end
```

### ZPDefend (Programa de Defensor de Edificio)

```lua
-- ETAPAS: Prepare -> Wait

ZombiePrograms.Defend.Wait = function(bandit)
    local tasks = {}

    -- 1. SI SALE DEL EDIFICIO, CAMBIAR A LOOTER
    if bandit:isOutside() then
        Bandit.SetProgram(bandit, "Looter", {})
        return {status=true, next="Prepare", tasks={}}
    end

    -- 2. DORMIR EN HORARIOS ESPECIFICOS
    local hour = getGameTime():getHour()
    if (hour >= 0 and hour < 7) or (hour >= 13 and hour < 14) then
        Bandit.SetSleeping(bandit, true)
        -- Colocar colchon visual
        BanditBasePlacements.Matress(bandit:getX(), bandit:getY(), bandit:getZ())
        local task = {action="Sleep", anim="Sleep", time=100}
        table.insert(tasks, task)
    else
        -- IDLE: Animaciones aleatorias (fumar, toser, rascarse, etc.)
        Bandit.SetSleeping(bandit, false)
        local action = ZombRand(30)
        if action == 0 then
            table.insert(tasks, {action="Time", anim="Cough", time=200})
        elseif action == 2 then
            table.insert(tasks, {action="Time", anim="Smoke", time=200})
        end
        -- ... mas animaciones
    end

    -- 3. DETECTAR INTRUSOS EN EL EDIFICIO
    local playerList = BanditPlayer.GetPlayers()
    for i=0, playerList:size()-1 do
        local player = playerList:get(i)
        local playerBuilding = player:getSquare():getBuilding()
        local banditBuilding = bandit:getSquare():getBuilding()

        -- Si jugador esta en mismo edificio
        if playerBuilding and banditBuilding and playerBuilding:getID() == banditBuilding:getID() then
            local dist = BanditUtils.DistTo(player:getX(), player:getY(), bandit:getX(), bandit:getY())
            local spotDist = 30
            if player:isSneaking() then spotDist = spotDist - 3 end

            if dist <= spotDist then
                -- ALERTA! Cambiar a modo combate
                Bandit.Say(bandit, "DEFENDER_SPOTTED")
                Bandit.SetProgram(bandit, "Bandit", {})
                return {status=true, next="Prepare", tasks={}}
            end
        end
    end

    return {status=true, next="Wait", tasks=tasks}
end
```

### ZPLooter (Programa de Merodeador Pasivo)

```lua
ZombiePrograms.Looter.Main = function(bandit)
    local tasks = {}

    -- CONFIG DE DETECCION (menor que Bandit)
    local config = {mustSee = true, hearDist = 7}

    if Bandit.HasExpertise(bandit, Bandit.Expertise.Recon) then
        config.hearDist = 20
    elseif Bandit.HasExpertise(bandit, Bandit.Expertise.Tracker) then
        config.hearDist = 60
    end

    -- BUSCAR OBJETIVO
    local target, enemy = BanditUtils.GetTarget(bandit, config)

    if target.x then
        -- Engancharse en combate
        Bandit.SayLocation(bandit, targetSquare)
        local walkType = Bandit.GetCombatWalktype(bandit, enemy, target.dist)
        table.insert(tasks, BanditUtils.GetMoveTaskTarget(...))
        return {status=true, next="Main", tasks=tasks}
    end

    -- SIN OBJETIVO: Animacion de encogerse de hombros
    table.insert(tasks, {action="Time", anim="Shrug", time=200})

    return {status=true, next="Main", tasks=tasks}
end
```

## 3.3 Retorno de Programas

```lua
return {
    status = true,      -- true = exito, false = fallo
    next = "StageName", -- Siguiente etapa a ejecutar
    tasks = {           -- Lista de tareas a ejecutar
        {action="Move", x=100, y=200, z=0, walkType="Run"},
        {action="Shoot", eid=12345, anim="RifleFireStand"},
        {action="Time", anim="Smoke", time=200}
    }
}
```

---

# 4. SISTEMA DE ACCIONES (ZOMBIE ACTIONS)

## 4.1 Estructura de una Accion

```lua
ZombieActions.NombreAccion = {}

-- Llamada al iniciar la accion
ZombieActions.NombreAccion.onStart = function(zombie, task)
    -- Configuracion inicial
    -- Retorna true si se inicio correctamente
    return true
end

-- Llamada cada tick mientras la accion esta activa
ZombieActions.NombreAccion.onWorking = function(zombie, task)
    -- Logica de progreso
    -- Retorna false para continuar, true para terminar
    return false
end

-- Llamada al completar la accion
ZombieActions.NombreAccion.onComplete = function(zombie, task)
    -- Finalizacion
    return true
end
```

## 4.2 Acciones Principales

### ZAMove - Movimiento

```lua
ZombieActions.Move.onStart = function(zombie, task)
    -- Configurar tipo de caminar
    zombie:setVariable("BanditWalkType", task.walkType)

    -- Resetear pathfinding
    zombie:getPathFindBehavior2():reset()
    zombie:getPathFindBehavior2():cancel()
    zombie:setPath2(nil)

    -- Animacion de transicion (Idle -> Run/Walk)
    if not Bandit.IsMoving(zombie) then
        local dist = BanditUtils.DistTo(zombie:getX(), zombie:getY(), task.x, task.y)
        if dist > 2 then
            if task.walkType == "Run" then
                zombie:setBumpType("IdleToRun")
            elseif task.walkType == "Walk" then
                zombie:setBumpType("IdleToWalk")
            end
        end
        Bandit.SetMoving(zombie, true)
    end

    -- Iniciar pathfinding
    if BanditUtils.IsController(zombie) then
        zombie:getPathFindBehavior2():pathToLocation(task.x, task.y, task.z)
    end

    return true
end

ZombieActions.Move.onWorking = function(zombie, task)
    zombie:setVariable("BanditWalkType", task.walkType)

    -- Soporte para caminar hacia atras (B42)
    if BanditCompatibility.GetGameVersion() >= 42 then
        zombie:setAnimatingBackwards(task.backwards or false)
    end

    -- Si tiene objetivo dinamico (jugador/NPC)
    if task.tid then
        if task.isPlayer then
            local player = getPlayer()
            if BanditUtils.GetCharacterID(player) == task.tid then
                zombie:pathToCharacter(player)
            end
        else
            local target = BanditZombie.Cache[task.tid]
            if target then
                zombie:pathToCharacter(target)
            end
        end
    else
        -- Pathfinding normal
        local result = zombie:getPathFindBehavior2():update()
        if result == BehaviorResult.Failed or result == BehaviorResult.Succeeded then
            return true  -- Terminar accion
        end
    end

    return false  -- Continuar
end
```

### ZAShoot - Disparo

```lua
ZombieActions.Shoot.onStart = function(bandit, task)
    bandit:setBumpType(task.anim)  -- Animacion de disparo
    return true
end

ZombieActions.Shoot.onWorking = function(bandit, task)
    -- Obtener enemigo
    local enemy = BanditZombie.Cache[task.eid] or BanditPlayer.GetPlayerById(task.eid)
    if not enemy then return true end

    -- Mirar hacia enemigo
    bandit:faceLocationF(enemy:getX(), enemy:getY())

    -- Esperar tiempo de disparo
    if task.time <= 0 then return true end

    return false
end

ZombieActions.Shoot.onComplete = function(bandit, task)
    local brainShooter = BanditBrain.Get(shooter)
    local weapon = brainShooter.weapons[task.slot]
    local weaponItem = BanditCompatibility.InstanceItem(weapon.name)

    -- Verificar que apunta al enemigo
    local enemy = BanditZombie.Cache[task.eid] or BanditPlayer.GetPlayerById(task.eid)
    if not BanditUtils.IsFacing(sx, sy, sd, enemy:getX(), enemy:getY(), 5) then
        return true
    end

    -- CONSUMIR MUNICION
    weapon.bulletsLeft = weapon.bulletsLeft - 1
    Bandit.UpdateItemsToSpawnAtDeath(shooter)

    -- EFECTOS VISUALES
    BanditCompatibility.StartMuzzleFlash(shooter)

    -- SONIDO
    local emitter = shooter:getEmitter()
    local swingSound = weaponItem:getSwingSound()
    emitter:playSound(swingSound)

    -- ALERTAR ZOMBIES CERCANOS
    local radius = weaponItem:getSoundRadius()
    local zombieList = BanditZombie.CacheLightZ
    for id, zombie in pairs(zombieList) do
        local dist = math.abs(sx - zombie.x) + math.abs(sy - zombie.y)
        if dist < radius then
            zombie:spottedNew(shooter, true)
        end
    end

    -- APLICAR DANO
    if BanditUtils.LineClear(shooter, enemy) then
        BanditUtils.ManageLineOfFire(shooter, enemy, weaponItem)
    end

    return true
end
```

## 4.3 Estructura de Task

```lua
task = {
    action = "Move",           -- Tipo de accion

    -- Parametros comunes
    time = 200,                -- Duracion en ticks
    anim = "RifleFireStand",   -- Animacion a usar
    lock = true,               -- Bloquea otras acciones

    -- Parametros de movimiento
    x = 100, y = 200, z = 0,   -- Destino
    walkType = "Run",          -- Walk, Run, SneakWalk, WalkAim, Limp
    backwards = false,         -- Caminar hacia atras

    -- Parametros de objetivo
    tid = 12345,               -- Target ID
    isPlayer = true,           -- Es jugador?

    -- Parametros de disparo
    eid = 12345,               -- Enemy ID
    slot = "primary",          -- Slot de arma

    -- Parametros de interaccion
    itemType = "Base.Pistol",  -- Tipo de item
    sound = "DoorOpen",        -- Sonido a reproducir
}
```

---

# 5. SISTEMA DE SPAWN Y SERVIDOR

## 5.1 Spawner Principal (BanditServerSpawner.lua)

### Funcion banditize - Crear el "Brain"

```lua
local function banditize(zombie, bandit, clan, args)
    local id = zombie:getPersistentOutfitID()

    local brain = {}

    -- AUTO-GENERADOS
    brain.id = id
    brain.inVehicle = false
    brain.fullname = BanditNames.GenerateName(bandit.general.female)
    brain.born = getGameTime():getWorldAgeHours()
    brain.bornCoords = {x=zombie:getX(), y=zombie:getY(), z=zombie:getZ()}

    -- ESTADOS INICIALES
    brain.stationary = false
    brain.sleeping = false
    brain.aiming = false
    brain.moving = false
    brain.endurance = 1.00
    brain.speech = 0.00
    brain.infection = 0

    -- DE PERFIL DE BANDIDO
    brain.clan = bandit.general.cid
    brain.cid = bandit.general.cid
    brain.bid = bandit.general.bid
    brain.female = bandit.general.female or false
    brain.skin = bandit.general.skin or 1
    brain.hairType = bandit.general.hairType or 1
    brain.hairColor = bandit.general.hairColor or 1
    brain.beardType = bandit.general.beardType or 1

    -- ESTADISTICAS (escaladas de 1-9 a valores reales)
    brain.health = BanditUtils.Lerp(bandit.general.health or 5, 1, 9, 1, 2.6)
    brain.accuracyBoost = BanditUtils.Lerp(bandit.general.sight or 5, 1, 9, -8, 8)
    brain.enduranceBoost = BanditUtils.Lerp(bandit.general.endurance or 5, 1, 9, 0.25, 1.75)
    brain.strengthBoost = BanditUtils.Lerp(bandit.general.strength or 5, 1, 9, 0.25, 1.75)

    -- EXPERTISES
    brain.exp = {bandit.general.exp1 or 0, bandit.general.exp2 or 0, bandit.general.exp3 or 0}

    -- ARMAS
    brain.weapons = {}
    brain.weapons.melee = "Base.BareHands"
    brain.weapons.primary = {bulletsLeft=0, magCount=0}
    brain.weapons.secondary = {bulletsLeft=0, magCount=0}

    if bandit.weapons then
        if bandit.weapons.melee then
            brain.weapons.melee = BanditCompatibility.GetLegacyItem(bandit.weapons.melee)
        end
        for _, slot in pairs({"primary", "secondary"}) do
            if bandit.weapons[slot] and bandit.ammo[slot] then
                brain.weapons[slot] = BanditWeapons.Make(bandit.weapons[slot], bandit.ammo[slot])
            end
        end
    end

    brain.clothing = bandit.clothing or {}
    brain.tint = bandit.tint or {}
    brain.bag = bandit.bag

    -- PERSONALIDAD ALEATORIA
    brain.personality = {}
    brain.personality.alcoholic = (ZombRand(50) == 0)
    brain.personality.smoker = (ZombRand(4) == 0)
    brain.personality.compulsiveCleaner = (ZombRand(90) == 0)
    -- ... mas rasgos

    -- DE CLAN
    brain.hostile = not clan.spawn.friendly
    brain.hostileP = brain.hostile

    -- DE ARGUMENTOS
    brain.program = {name = args.program, stage = "Prepare"}
    brain.programFallback = args.program
    brain.master = args.pid
    brain.permanent = args.permanent and true or false
    brain.key = args.key
    brain.voice = args.voice or Bandit.PickVoice(zombie)

    -- AGREGAR A COLA
    local gmd = GetBanditModData()
    gmd.Queue[id] = brain
end
```

### Sistema de Spawn por Tipo

```lua
local function spawnType(player, args)
    local pid = BanditUtils.GetCharacterID(player)
    local cid = args.cid

    local clan = BanditCustom.ClanGet(cid).spawn
    local groupSize = clan.groupMin + ZombRand(clan.groupMax - clan.groupMin + 1)
    groupSize = math.floor(groupSize * SandboxVars.Bandits.General_SpawnMultiplier + 0.5)

    local spawnPoints = {}

    -- GENERAR PUNTOS DE SPAWN
    if args.dist then
        -- Spawn a distancia del jugador (circular)
        spawnPoints = generateSpawnPointUniform(player, args.dist, groupSize)
    elseif args.x and args.y and args.z then
        -- Spawn en posicion especifica
        spawnPoints = generateSpawnPointHere(player, args.x, args.y, args.z, groupSize)
    end

    -- SELECCIONAR PROGRAMA SEGUN CLAN
    local programArgs = {pid = pid, cid = cid, permanent = false}

    if clan.wanderer and clan.assault then
        programArgs.program = BanditUtils.Choice({"Looter", "Bandit"})
    elseif clan.wanderer then
        programArgs.program = "Looter"
    elseif clan.assault then
        programArgs.program = "Bandit"
    elseif clan.companion then
        programArgs.program = "Companion"
    end

    -- TIPOS ESPECIALES
    if clan.roadblock then
        local res = spawnRoadblock(player, spawnPoints[1])
        if res then programArgs.program = "Roadblock" end
    end

    if clan.campers then
        local res = spawnCamp(player, spawnPoints[1])
        if res then programArgs.program = "Camper" end
    end

    if clan.defenders then
        local building = spawnHouse(player, spawnPoints[1])
        if building then
            programArgs.program = "Defend"
            spawnPoints = generateSpawnPointBuilding(building, groupSize)
        end
    end

    -- SPAWN DEL GRUPO
    spawnGroup(spawnPoints, programArgs)

    -- MARCADOR EN MAPA
    if SandboxVars.Bandits.General_ArrivalIcon then
        local icon, color, desc = getIconDataByProgram(programArgs.program, clan.friendly)
        BanditEventMarkerHandler.set(getRandomUUID(), icon, 1800, x, y, color, desc)
    end
end
```

### Evento de Spawn Periodico

```lua
-- Se ejecuta cada 10 minutos del juego
local function checkEvent()
    if isClient() then return end

    local player = getSelectedPlayer()
    local day = getWorldAge()  -- Dias desde inicio

    local clanData = BanditCustom.ClanGetAll()

    for cid, clan in pairs(clanData) do
        local spawnConfig = clan.spawn

        -- Verificar si estamos en el rango de dias para este clan
        if day >= spawnConfig.dayStart and day <= spawnConfig.dayEnd then

            -- Calcular probabilidad de spawn
            local spawnChance = spawnConfig.spawnChance * SandboxVars.Bandits.General_SpawnMultiplier / 6
            local spawnRandom = ZombRandFloat(0, 100)

            if spawnRandom < spawnChance then
                print("[BANDITS] Spawning bandits from clan: " .. cid)
                local args = {cid = cid, dist = 55 + ZombRand(10)}
                spawnType(player, args)
                TransmitBanditModData()
            end
        end
    end
end

Events.EveryTenMinutes.Add(checkEvent)
```

---

# 6. SISTEMA DE CLANES Y CUSTOMIZACION

## 6.1 Estructura de Datos de Clan

```lua
-- Archivo: bandits/clans.txt
[guid-del-clan]
    general: name = My Bandit Clan

    spawn: dayStart = 0
    spawn: dayEnd = 365
    spawn: spawnChance = 15
    spawn: groupMin = 2
    spawn: groupMax = 5
    spawn: friendly = false

    spawn: wanderer = true
    spawn: assault = true
    spawn: defenders = false
    spawn: roadblock = false
    spawn: campers = false
    spawn: companion = false
```

## 6.2 Estructura de Datos de Bandido

```lua
-- Archivo: bandits/bandits.txt
[guid-del-bandido]
    general: modid = LOCAL
    general: cid = guid-del-clan
    general: name = John Bandit
    general: female = false
    general: skin = 2
    general: hairType = 5
    general: beardType = 3
    general: hairColor = 4
    general: health = 7
    general: strength = 6
    general: endurance = 5
    general: sight = 8
    general: exp1 = 2
    general: exp2 = 0
    general: exp3 = 0

    clothing: Shirt = Base.Shirt_Denim
    clothing: Pants = Base.Trousers_JeanBaggy
    clothing: Shoes = Base.Shoes_TrainerTINT

    tint: Shirt = 4473924

    weapons: primary = Base.AssaultRifle
    weapons: secondary = Base.Pistol
    weapons: melee = Base.Machete

    ammo: primary = 3
    ammo: secondary = 2

    bag: name = Base.Bag_DuffelBag
```

## 6.3 API de BanditCustom

```lua
-- CARGAR/GUARDAR
BanditCustom.Load()                    -- Carga de archivos
BanditCustom.Save()                    -- Guarda a archivos

-- CLANES
BanditCustom.ClanCreate(cid)           -- Crear nuevo clan
BanditCustom.ClanGet(cid)              -- Obtener clan por ID
BanditCustom.ClanGetAll()              -- Todos los clanes
BanditCustom.ClanGetAllSorted()        -- Clanes ordenados por nombre

-- BANDIDOS
BanditCustom.Create(bid)               -- Crear nuevo bandido
BanditCustom.GetById(bid)              -- Obtener por ID
BanditCustom.GetFromClan(cid)          -- Todos los de un clan
BanditCustom.GetNextId()               -- Generar nuevo UUID
BanditCustom.Delete(bid)               -- Eliminar bandido
```

---

# 7. SISTEMA DE ARMAS Y COMBATE

## 7.1 Estructura de Arma

```lua
weapon = {
    name = "Base.AssaultRifle",  -- Tipo de item
    type = "mag",                -- "mag" (con cargador) o "nomag" (sin cargador)

    -- Para armas con cargador
    bulletsLeft = 30,            -- Balas en cargador actual
    magSize = 30,                -- Capacidad del cargador
    magCount = 3,                -- Cargadores de repuesto
    magName = "Base.556Clip",    -- Tipo de cargador
    clipIn = true,               -- Cargador insertado
    racked = true,               -- Bala en recamara

    -- Para armas sin cargador (escopetas, revolveres)
    ammoSize = 8,                -- Capacidad maxima
    ammoCount = 50,              -- Municion de repuesto
    ammoName = "Base.ShotgunShells"
}
```

## 7.2 Creacion de Arma

```lua
BanditWeapons.Make = function(itemType, boxCount)
    local weapon = BanditCompatibility.InstanceItem(itemType)
    local ammoType = weapon:getAmmoType():getItemKey()

    local ret = {}
    ret.name = itemType
    ret.racked = false

    if BanditCompatibility.UsesExternalMagazine(weapon) then
        -- ARMA CON CARGADOR
        local magazineType = weapon:getMagazineType()
        local magazine = BanditCompatibility.InstanceItem(magazineType)
        local magSize = magazine:getMaxAmmo()
        local magCount = math.floor(boxCount * boxSize / magSize) - 1

        ret.type = "mag"
        ret.bulletsLeft = magSize
        ret.magSize = magSize
        ret.magCount = magCount
        ret.magName = magazineType
        ret.clipIn = true
    else
        -- ARMA SIN CARGADOR
        local ammoSize = weapon:getMaxAmmo()

        ret.type = "nomag"
        ret.bulletsLeft = ammoSize
        ret.ammoSize = ammoSize
        ret.ammoCount = boxCount * boxSize - ammoSize
        ret.ammoName = ammoType
    end

    return ret
end
```

## 7.3 Compatibilidad con Mods de Armas

```lua
-- BRITA'S WEAPON PACK
if getActivatedMods():contains("Brita") then
    table.insert(BanditWeapons.Primary, BanditWeapons.MakeHandgun("Base.AK103", "Base.AKClip", 30, "[1]Shot_762x39", 5))
    table.insert(BanditWeapons.Primary, BanditWeapons.MakeHandgun("Base.M4A1", "Base.556Clip", 30, "[1]Shot_556", 7))
    -- ... mas armas
end

-- FIREARMS MOD
if getActivatedMods():contains("firearmmod") then
    table.insert(BanditWeapons.Primary, BanditWeapons.MakeHandgun("Base.AK47", "Base.AK_Mag", 30, "M14Shoot", 10))
    -- ... mas armas
end

-- VFE (Vanilla Firearms Expanded)
if getActivatedMods():contains("VFExpansion1") then
    table.insert(BanditWeapons.Primary, BanditWeapons.MakeHandgun("Base.FAL", "Base.FALClip", 20, "M14Shoot", 17))
    -- ... mas armas
end
```

---

# 8. SISTEMA DE COMPATIBILIDAD B41/B42

## 8.1 Capa de Compatibilidad

```lua
BanditCompatibility.GetGameVersion = function()
    return getCore():getGameVersion():getMajor()  -- 41 o 42
end

-- INSTANCIACION DE ITEMS
BanditCompatibility.InstanceItem = function(itemFullType)
    if getGameVersion() >= 42 then
        return instanceItem(itemFullType)  -- API nueva B42
    else
        local itemTypeLegacy = BanditCompatibility.GetLegacyItem(itemFullType)
        return InventoryItemFactory.CreateItem(itemTypeLegacy)  -- API vieja B41
    end
end

-- MAPA DE ITEMS LEGACY (B41 -> B42)
local legacyItemMap = {
    ["Base.WineOpen"] = "Base.WineEmpty",
    ["Base.BaseballBat_Nails"] = "Base.BaseballBatNails",
    ["Base.WaterBottle"] = "Base.WaterBottleFull",
    ["Base.Whiskey"] = "Base.WhiskeyFull",
    ["Base.FightingKnife"] = "Base.HuntingKnife",
    -- ... mas mapeos
}

-- FLASH DE DISPARO
BanditCompatibility.StartMuzzleFlash = function(shooter)
    if getGameVersion() >= 42 then
        -- B42: Usar IsoLightSource
        local square = shooter:getSquare()
        local lightSource = IsoLightSource.new(square:getX(), square:getY(), square:getZ(), 0.8, 0.8, 0.7, 18, 2)
        getCell():addLamppost(lightSource)
    else
        -- B41: Metodo nativo
        shooter:startMuzzleFlash()
    end
end

-- SPAWN DE ZOMBIES
BanditCompatibility.AddZombiesInOutfit = function(x, y, z, outfit, femaleChance, crawler, fallOnFront, fakeDead, knockedDown, invulnerable, sitting, health)
    if getGameVersion() >= 42 then
        -- B42: Nuevo parametro "sitting"
        return addZombiesInOutfit(x, y, z, 1, outfit, femaleChance, crawler, fallOnFront, fakeDead, knockedDown, invulnerable, sitting, health)
    else
        -- B41: Sin parametro "sitting"
        return addZombiesInOutfit(x, y, z, 1, outfit, femaleChance, crawler, fallOnFront, fakeDead, knockedDown, health)
    end
end

-- RANGO DE ARMAS
BanditCompatibility.GetMaxRange = function(weapon)
    if getGameVersion() >= 42 then
        -- B42: Rangos mas realistas
        local wrange = weapon:getMaxRange()
        local scope = weapon:getWeaponPart("Scope")
        if scope then
            wrange = wrange + scope:getMaxSightRange()
        end
        return wrange
    else
        -- B41: Rangos mas cortos, necesitan ajuste
        local weaponType = WeaponType.getWeaponType(weapon)
        local wrange = weapon:getMaxRange()
        if weaponType == WeaponType.firearm then
            if wrange >= 10 then
                wrange = wrange + 20  -- Boost para rifles
            end
        elseif weaponType == WeaponType.handgun then
            wrange = wrange + 6  -- Boost para pistolas
        end
        return wrange
    end
end
```

---

# 9. CICLO DE VIDA DEL NPC

## 9.1 Flujo Completo

```
┌────────────────────────────────────────────────────────────────────┐
│                     CICLO DE VIDA DEL NPC                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────┐                                                       │
│  │ SPAWN   │  Server: BanditServerSpawner.spawnGroup()             │
│  │         │  -> addZombiesInOutfit() crea zombie                  │
│  │         │  -> banditize() crea brain                            │
│  │         │  -> gmd.Queue[id] = brain                             │
│  └────┬────┘                                                       │
│       │                                                            │
│       ▼                                                            │
│  ┌─────────┐                                                       │
│  │ INIT    │  Cliente: BanditUpdate detecta nuevo zombie           │
│  │         │  -> Banditize(zombie, brain)                          │
│  │         │  -> Configura variables del zombie                    │
│  │         │  -> zombie:setNoTeeth(true)                           │
│  │         │  -> zombie:setVariable("Bandit", true)                │
│  └────┬────┘                                                       │
│       │                                                            │
│       ▼                                                            │
│  ┌─────────┐                                                       │
│  │ LOOP    │  Cada tick (BanditUpdate.OnZombieUpdate):             │
│  │ ACTIVO  │                                                       │
│  │         │  1. ManageActionState() - Estado de animacion         │
│  │         │  2. ManageHealth() - Sangrado, infeccion              │
│  │         │  3. ManageCollisions() - Puertas, ventanas, vallas    │
│  │         │  4. ManageEndurance() - Cansancio                     │
│  │         │  5. ManageTorch() - Linterna                          │
│  │         │  6. ManageOnFire() - En llamas                        │
│  │         │  7. ManageSpeechCooldown() - Dialogo                  │
│  │         │                                                       │
│  │         │  8. Ejecutar Programa:                                │
│  │         │     result = ZombiePrograms[program][stage](bandit)   │
│  │         │     -> Retorna {status, next, tasks}                  │
│  │         │                                                       │
│  │         │  9. Procesar Tasks:                                   │
│  │         │     Para cada task:                                   │
│  │         │       ZombieActions[task.action].onStart()            │
│  │         │       ZombieActions[task.action].onWorking()          │
│  │         │       ZombieActions[task.action].onComplete()         │
│  │         │                                                       │
│  │         │  10. Sincronizacion multiplayer                       │
│  └────┬────┘                                                       │
│       │                                                            │
│       ▼                                                            │
│  ┌─────────┐                                                       │
│  │ MUERTE  │  Cuando health <= 0:                                  │
│  │         │  -> Task "Die" con animacion de muerte                │
│  │         │  -> Spawn de loot definido                            │
│  │         │  -> BanditBrain.Remove(bandit)                        │
│  │         │  -> Zombie muere normalmente                          │
│  └────┬────┘                                                       │
│       │                                                            │
│       ▼                                                            │
│  ┌─────────┐                                                       │
│  │ZOMBIFY  │  Si brain.infection >= 100:                           │
│  │(opcional)│  -> Zombify(bandit)                                  │
│  │         │  -> zombie:setNoTeeth(false) - Puede morder           │
│  │         │  -> zombie:setVariable("Bandit", false)               │
│  │         │  -> Se convierte en zombie normal                     │
│  └─────────┘                                                       │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 9.2 Diagrama de Estados del Programa

```
┌─────────────────────────────────────────────────────────────────┐
│              MAQUINA DE ESTADOS: PROGRAMA BANDIT                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│    ┌──────────┐                                                 │
│    │ PREPARE  │──────────────────┐                              │
│    └────┬─────┘                  │                              │
│         │                        │                              │
│         ▼                        ▼                              │
│    ┌──────────┐            ┌──────────┐                         │
│    │   MAIN   │◄──────────►│  ESCAPE  │                         │
│    │          │            │          │                         │
│    │ - Sabotear│  health    │ - Huir   │                        │
│    │ - Robar  │   < 0.7    │ - Alejar │                        │
│    │ - Atacar │            │          │                         │
│    └────┬─────┘            └──────────┘                         │
│         │                                                       │
│         │ (rendicion)                                           │
│         ▼                                                       │
│    ┌──────────┐                                                 │
│    │SURRENDER │                                                 │
│    │          │                                                 │
│    │ - Manos  │                                                 │
│    │   arriba │                                                 │
│    └──────────┘                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│            MAQUINA DE ESTADOS: PROGRAMA COMPANION               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│    ┌──────────┐                                                 │
│    │ PREPARE  │                                                 │
│    └────┬─────┘                                                 │
│         │                                                       │
│         ▼                                                       │
│    ┌──────────┐     en guardpost    ┌──────────┐               │
│    │   MAIN   │────────────────────►│  GUARD   │               │
│    │          │◄────────────────────│          │               │
│    │ - Seguir │   sale de post      │ - Quieto │               │
│    │ - Defender│                    │ - Vigilar│               │
│    └──────────┘                     └──────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              MAQUINA DE ESTADOS: PROGRAMA DEFEND                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│    ┌──────────┐                                                 │
│    │ PREPARE  │                                                 │
│    └────┬─────┘                                                 │
│         │                                                       │
│         ▼                                                       │
│    ┌──────────┐   intruso detectado   ┌──────────┐             │
│    │   WAIT   │──────────────────────►│ BANDIT   │             │
│    │          │                       │ PROGRAM  │             │
│    │ - Dormir │                       │          │             │
│    │ - Idle   │    sale del           │ - Atacar │             │
│    │ - Vigilar│    edificio           │          │             │
│    └────┬─────┘         │             └──────────┘             │
│         │               │                                       │
│         ▼               ▼                                       │
│    ┌──────────┐   ┌──────────┐                                 │
│    │  (loop)  │   │  LOOTER  │                                 │
│    │          │   │ PROGRAM  │                                 │
│    └──────────┘   └──────────┘                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

# 10. GUIA PARA CREAR MOD DE NPCs CON IA

## 10.1 Conceptos Clave Aprendidos

### Usar Zombies como Base
```lua
-- CORRECTO: Usar el sistema de zombies existente
local zombieList = addZombiesInOutfit(x, y, z, 1, "Naked", 0, false, false, false, false, false, false, 1)
local zombie = zombieList:get(0)
zombie:setNoTeeth(true)
zombie:setVariable("MyNPC", true)

-- INCORRECTO: Intentar crear IsoPlayer o entidades custom
-- (No funciona bien en multiplayer, problemas de sincronizacion)
```

### Sistema de Brain para Estado
```lua
-- Almacenar estado en tabla separada, no en modData del zombie
MyNPCBrain = {}
MyNPCBrain.Cache = {}

function MyNPCBrain.Create(zombie, config)
    local brain = {
        id = zombie:getPersistentOutfitID(),
        state = "idle",
        memory = {},
        goals = {},
        -- ... mas datos
    }
    MyNPCBrain.Cache[brain.id] = brain
    return brain
end

function MyNPCBrain.Get(zombie)
    local id = zombie:getPersistentOutfitID()
    return MyNPCBrain.Cache[id]
end
```

### Programas para Comportamiento de Alto Nivel
```lua
MyNPCPrograms = {}

MyNPCPrograms.Patrol = {}
MyNPCPrograms.Patrol.Main = function(npc)
    local brain = MyNPCBrain.Get(npc)
    local tasks = {}

    -- LOGICA DE DECISION
    if brain.threat_detected then
        -- Cambiar a modo combate
        return {status=true, next="Combat", tasks={}}
    end

    -- Continuar patrulla
    local nextWaypoint = brain.waypoints[brain.current_waypoint]
    table.insert(tasks, {
        action = "Move",
        x = nextWaypoint.x,
        y = nextWaypoint.y,
        z = nextWaypoint.z,
        walkType = "Walk"
    })

    return {status=true, next="Main", tasks=tasks}
end
```

### Acciones para Comportamiento de Bajo Nivel
```lua
MyNPCActions = {}

MyNPCActions.CustomAction = {}

MyNPCActions.CustomAction.onStart = function(npc, task)
    npc:setBumpType(task.anim)
    return true
end

MyNPCActions.CustomAction.onWorking = function(npc, task)
    if task.time <= 0 then
        return true  -- Terminado
    end
    task.time = task.time - 1
    return false  -- Continuar
end

MyNPCActions.CustomAction.onComplete = function(npc, task)
    -- Efectos al completar
    return true
end
```

## 10.2 Arquitectura Sugerida para NPCs con IA Avanzada

```
┌─────────────────────────────────────────────────────────────────┐
│                   ARQUITECTURA NPC IA AVANZADA                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐                                            │
│  │   PERCEPTION    │  <- Detectar entorno                       │
│  │                 │     - Enemigos visibles                    │
│  │                 │     - Sonidos                              │
│  │                 │     - Objetos de interes                   │
│  │                 │     - Estado del mundo                     │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │    MEMORY       │  <- Almacenar informacion                  │
│  │                 │     - Ultima posicion de enemigos          │
│  │                 │     - Lugares visitados                    │
│  │                 │     - Interacciones pasadas                │
│  │                 │     - Conocimiento del mapa                │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │   REASONING     │  <- Tomar decisiones                       │
│  │                 │     - Utility AI (puntuar opciones)        │
│  │                 │     - Behavior Trees                       │
│  │                 │     - Goal-Oriented Action Planning        │
│  │                 │     - Machine Learning (opcional)          │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │   PLANNING      │  <- Secuenciar acciones                    │
│  │                 │     - Pathfinding                          │
│  │                 │     - Task decomposition                   │
│  │                 │     - Resource allocation                  │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │   EXECUTION     │  <- Ejecutar acciones                      │
│  │                 │     - ZombieActions                        │
│  │                 │     - Animaciones                          │
│  │                 │     - Efectos                              │
│  └─────────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 10.3 Ejemplo: Sistema de Comunicacion entre NPCs

```lua
-- SISTEMA DE COMUNICACION
NPCCommunication = {}
NPCCommunication.Messages = {}  -- Cola de mensajes pendientes

-- TIPOS DE MENSAJES
NPCCommunication.Type = {
    THREAT_SPOTTED = 1,
    HELP_NEEDED = 2,
    ALL_CLEAR = 3,
    FOLLOW_ME = 4,
    HOLD_POSITION = 5,
    RETREAT = 6
}

-- ENVIAR MENSAJE A NPCs CERCANOS
function NPCCommunication.Broadcast(sender, msgType, data, radius)
    local senderBrain = MyNPCBrain.Get(sender)
    local sx, sy = sender:getX(), sender:getY()

    -- Encontrar NPCs en radio
    for id, brain in pairs(MyNPCBrain.Cache) do
        if id ~= senderBrain.id then
            local dist = BanditUtils.DistTo(sx, sy, brain.lastX, brain.lastY)
            if dist <= radius then
                -- Agregar mensaje a cola del receptor
                table.insert(NPCCommunication.Messages, {
                    recipient = id,
                    sender = senderBrain.id,
                    type = msgType,
                    data = data,
                    timestamp = getGameTime():getWorldAgeHours()
                })
            end
        end
    end
end

-- PROCESAR MENSAJES RECIBIDOS
function NPCCommunication.ProcessMessages(npc)
    local brain = MyNPCBrain.Get(npc)
    local myMessages = {}

    -- Filtrar mensajes para este NPC
    for i = #NPCCommunication.Messages, 1, -1 do
        local msg = NPCCommunication.Messages[i]
        if msg.recipient == brain.id then
            table.insert(myMessages, msg)
            table.remove(NPCCommunication.Messages, i)
        end
    end

    -- Procesar cada mensaje
    for _, msg in ipairs(myMessages) do
        if msg.type == NPCCommunication.Type.THREAT_SPOTTED then
            -- Agregar amenaza a memoria
            brain.memory.threats[msg.data.threatId] = {
                x = msg.data.x,
                y = msg.data.y,
                reported_by = msg.sender,
                timestamp = msg.timestamp
            }
        elseif msg.type == NPCCommunication.Type.HELP_NEEDED then
            -- Cambiar objetivo a ayudar
            brain.goals.current = "assist"
            brain.goals.assist_target = msg.sender
        end
        -- ... mas tipos
    end
end

-- USO EN PROGRAMA
MyNPCPrograms.Squad.Main = function(npc)
    local brain = MyNPCBrain.Get(npc)
    local tasks = {}

    -- Procesar comunicaciones
    NPCCommunication.ProcessMessages(npc)

    -- Si detecto amenaza, comunicar
    local threat = DetectThreat(npc)
    if threat then
        NPCCommunication.Broadcast(npc, NPCCommunication.Type.THREAT_SPOTTED, {
            threatId = threat.id,
            x = threat:getX(),
            y = threat:getY()
        }, 50)  -- Radio de 50 tiles
    end

    -- Si aliado necesita ayuda, ir a asistir
    if brain.goals.current == "assist" then
        local ally = MyNPCBrain.Cache[brain.goals.assist_target]
        if ally then
            table.insert(tasks, {
                action = "Move",
                x = ally.lastX,
                y = ally.lastY,
                z = ally.lastZ,
                walkType = "Run"
            })
        end
    end

    return {status=true, next="Main", tasks=tasks}
end
```

## 10.4 Consideraciones para Build 42 MP

### Sincronizacion Multiplayer
```lua
-- El mod usa ModData global para sincronizar entre clientes
function GetBanditModData()
    local gmd = ModData.getOrCreate("Bandits")
    if not gmd.Brains then gmd.Brains = {} end
    if not gmd.Queue then gmd.Queue = {} end
    return gmd
end

-- Transmitir cambios al servidor
function TransmitBanditModData()
    local gmd = GetBanditModData()
    ModData.transmit("Bandits")
end

-- El servidor distribuye a todos los clientes
Events.OnServerReceive.Add(function(module, command, player, args)
    if module == "Spawner" then
        -- Procesar spawn en servidor
        -- Luego transmitir a clientes
    end
end)
```

### Controller vs Non-Controller
```lua
-- Solo un cliente "controla" cada zombie
function BanditUtils.IsController(zombie)
    if isClient() then
        -- En multiplayer, verificar si somos el controlador
        return zombie:isMovementController()
    end
    return true  -- En singleplayer siempre somos el controlador
end

-- Usar para acciones que solo debe hacer el controlador
ZombieActions.Move.onWorking = function(zombie, task)
    if BanditUtils.IsController(zombie) then
        zombie:pathToLocation(task.x, task.y, task.z)
    end
    return false
end
```

---

# APENDICE A: ARCHIVOS CLAVE Y SUS FUNCIONES

| Archivo | Ubicacion | Proposito |
|---------|-----------|-----------|
| `Bandit.lua` | shared/ | API principal, funciones helper |
| `BanditBrain.lua` | shared/ | Sistema de estado/memoria |
| `BanditUtils.lua` | shared/ | Utilidades generales |
| `BanditPrograms.lua` | shared/ | Subprogramas reutilizables |
| `BanditCustom.lua` | shared/ | Sistema de clanes y personalizacion |
| `BanditWeapons.lua` | shared/ | Sistema de armas |
| `BanditCompatibility.lua` | shared/ | Capa compatibilidad B41/B42 |
| `BanditZombie.lua` | shared/ | Cache de zombies |
| `BanditPlayer.lua` | shared/ | Interaccion con jugadores |
| `ZPBandit.lua` | shared/ZombiePrograms/ | Programa hostil |
| `ZPCompanion.lua` | shared/ZombiePrograms/ | Programa companero |
| `ZPDefend.lua` | shared/ZombiePrograms/ | Programa defensor |
| `ZPLooter.lua` | shared/ZombiePrograms/ | Programa merodeador |
| `ZAMove.lua` | shared/ZombieActions/ | Accion movimiento |
| `ZAShoot.lua` | shared/ZombieActions/ | Accion disparo |
| `BanditServerSpawner.lua` | server/ | Sistema de spawn |
| `BanditUpdate.lua` | client/ | Loop principal |

---

# APENDICE B: VARIABLES SANDBOX DISPONIBLES

```lua
SandboxVars.Bandits.General_SpawnMultiplier     -- Multiplicador de spawn (1-5)
SandboxVars.Bandits.General_RunAway             -- NPCs huyen con poca salud
SandboxVars.Bandits.General_Theft               -- NPCs roban items
SandboxVars.Bandits.General_SabotageVehicles    -- NPCs sabotean vehiculos
SandboxVars.Bandits.General_SabotageCrops       -- NPCs destruyen cultivos
SandboxVars.Bandits.General_GeneratorCutoff     -- NPCs apagan generadores
SandboxVars.Bandits.General_LimitedEndurance    -- NPCs se cansan
SandboxVars.Bandits.General_BleedOut            -- NPCs sangran
SandboxVars.Bandits.General_Infection           -- NPCs pueden infectarse
SandboxVars.Bandits.General_CarryTorches        -- NPCs llevan linternas
SandboxVars.Bandits.General_EnterVehicles       -- NPCs entran vehiculos
SandboxVars.Bandits.General_ArrivalIcon         -- Mostrar iconos en mapa
SandboxVars.Bandits.General_OriginalBandits     -- Usar bandidos originales
SandboxVars.Bandits.General_DefenderLootAmount  -- Cantidad de loot defensores
```

---

# APENDICE C: EVENTOS DEL JUEGO UTILIZADOS

```lua
Events.OnZombieUpdate.Add(BanditUpdate)           -- Loop principal NPC
Events.EveryTenMinutes.Add(checkEvent)            -- Spawn periodico
Events.OnGameStart.Add(onGameStart)               -- Inicializacion
Events.OnClientCommand.Add(onClientCommand)       -- Comandos cliente->servidor
Events.OnServerCommand.Add(onServerCommand)       -- Comandos servidor->cliente
```

---

**FIN DE LA DOCUMENTACION MAESTRA**

*Documento generado para investigacion y desarrollo de mod de NPCs con IA avanzada para Project Zomboid Build 42 Multiplayer*
