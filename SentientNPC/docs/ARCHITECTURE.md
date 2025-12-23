# Arquitectura de SentientNPC

## Vision General

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SENTINENTNPC ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          GAME LAYER                                   │  │
│  │  Project Zomboid Build 42 - IsoZombie como contenedor de NPC          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          POSSESSION LAYER                             │  │
│  │  PossessionManager - Convierte zombies en NPCs controlables           │  │
│  │  Brain - Estado completo del NPC (memoria, stats, programa)          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          BEHAVIOR LAYER                               │  │
│  │  Programs - Comportamiento de alto nivel (Patrol, Guard, Combat)      │  │
│  │  Actions - Comportamiento de bajo nivel (Move, Shoot, Wait)           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          DECISION LAYER                               │  │
│  │  HybridAI - Sistema de decision (Rules → Cache → BT → LLM)           │  │
│  │  Memory - Sistema de memoria individual con scoring                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          EXTERNAL LAYER (Opcional)                    │  │
│  │  AIBridge - Comunicacion con proxy via archivos                       │  │
│  │  ai_proxy.py - Conexion a Ollama/LLM local                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Componentes Principales

### 1. PossessionManager

Responsable de convertir zombies vanilla en NPCs controlables.

```lua
PossessionManager = {
    possess(zombie, config)    -- Convertir zombie en NPC
    release(zombie)            -- Liberar zombie
    isPossessed(zombie)        -- Verificar estado
    getAll()                   -- Obtener todos los NPCs
}
```

**Transformaciones al poseer:**
- `zombie:setNoTeeth(true)` - Deshabilitar mordida
- `zombie:setVariable("Possessed", true)` - Marcar como NPC
- Crear brain asociado

### 2. Brain (Cerebro del NPC)

Estructura de datos que almacena TODO el estado del NPC.

```lua
brain = {
    -- Identificacion
    id = "npc_001",
    zombieId = 12345678,

    -- Configuracion
    type = "guard",
    name = "John Smith",

    -- Estado actual
    program = {name = "Patrol", stage = "Main"},
    tasks = {},

    -- Stats
    health = 1.0,
    mood = "neutral",
    hostile = false,

    -- Memorias
    memories = {},

    -- Personalidad
    personality = {
        aggressive = 0.3,
        cautious = 0.7,
        social = 0.5
    }
}
```

### 3. Programs (Programas)

Definen comportamiento de alto nivel. Cada programa tiene stages.

```lua
Programs.Patrol = {
    Prepare = function(npc) ... end,  -- Inicializacion
    Main = function(npc) ... end,     -- Loop principal
    Alert = function(npc) ... end     -- Reaccion a amenaza
}

-- Retorno de programa
return {
    status = true,          -- Exito/fallo
    next = "Main",          -- Siguiente stage
    tasks = {               -- Tareas a ejecutar
        {action="Move", x=100, y=200, z=0},
        {action="Wait", time=200}
    }
}
```

### 4. Actions (Acciones)

Ejecutan comportamiento de bajo nivel.

```lua
Actions.Move = {
    onStart = function(npc, task)
        npc:pathToLocationF(task.x, task.y, task.z)
        return true
    end,

    onWorking = function(npc, task)
        -- Verificar si llego
        local dist = getDistance(npc, task.x, task.y)
        return dist < 1  -- true = completado
    end,

    onComplete = function(npc, task)
        return true
    end
}
```

### 5. HybridAI

Sistema de decision en capas.

```
┌─────────────────────────────────────────────────┐
│              HYBRID DECISION ENGINE              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Input: NPC + Context                           │
│           │                                     │
│           ▼                                     │
│  ┌─────────────────────────────────────────┐   │
│  │ CAPA 1: Reglas Criticas                 │   │
│  │ HP < 20%? → FLEE                        │   │
│  │ Ataque inminente? → DEFEND              │   │
│  └─────────────────┬───────────────────────┘   │
│           │ No match                           │
│           ▼                                     │
│  ┌─────────────────────────────────────────┐   │
│  │ CAPA 2: Cache de Decisiones             │   │
│  │ Contexto similar reciente? → Use cache  │   │
│  └─────────────────┬───────────────────────┘   │
│           │ No match                           │
│           ▼                                     │
│  ┌─────────────────────────────────────────┐   │
│  │ CAPA 3: Behavior Tree                   │   │
│  │ Arboles de decision predefinidos        │   │
│  └─────────────────┬───────────────────────┘   │
│           │ Si LLM disponible                  │
│           ▼                                     │
│  ┌─────────────────────────────────────────┐   │
│  │ CAPA 4: LLM Query (Async)               │   │
│  │ Decisiones complejas/creativas          │   │
│  └─────────────────────────────────────────┘   │
│           │                                     │
│           ▼                                     │
│  Output: {action, target, params}              │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 6. AIBridge

Comunicacion con LLM via archivos (IPC).

```
Lua (Mod)                    Python (Proxy)              Ollama
─────────────────────────────────────────────────────────────────

write request.json ────────► read request.json
                             build prompt
                             ─────────────────────────► POST /api/chat
                             ◄───────────────────────── response
                             write response.json
read response.json ◄────────
```

## Flujo de Ejecucion

### Loop Principal (OnZombieUpdate)

```
┌─────────────────────────────────────────────────────────────┐
│                    OnZombieUpdate(zombie)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. ¿Es poseido? ────No────► return (skip)                  │
│         │                                                   │
│         ▼ Yes                                               │
│  2. Obtener brain                                           │
│         │                                                   │
│         ▼                                                   │
│  3. Light Update (cada tick)                                │
│     - Actualizar posicion en cache                          │
│     - Verificar colisiones                                  │
│         │                                                   │
│         ▼                                                   │
│  4. ¿Rate limit OK? ────No────► return                      │
│         │                                                   │
│         ▼ Yes                                               │
│  5. Full Update (rate limited)                              │
│     - Ejecutar programa actual                              │
│     - Procesar tareas                                       │
│     - Verificar respuestas de IA                            │
│         │                                                   │
│         ▼                                                   │
│  6. Ejecutar acciones de la cola                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Ciclo de Vida del NPC

```
┌────────┐     ┌──────────┐     ┌────────┐     ┌────────┐
│ SPAWN  │────►│  ACTIVE  │────►│ DEATH  │────►│CLEANUP │
└────────┘     └──────────┘     └────────┘     └────────┘
    │               │                │              │
    │               │                │              │
    ▼               ▼                ▼              ▼
 possess()      Update loop      OnZombieDead   release()
 create brain   programs/actions drop loot      remove brain
 sync to MP     sync state       notify server  sync removal
```

## Sincronizacion Multiplayer

### Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    MULTIPLAYER SYNC                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SERVER (Autoridad)                                         │
│  ├── Spawn de NPCs                                          │
│  ├── Estado global (ModData)                                │
│  ├── Validacion de acciones                                 │
│  └── Broadcast a clientes                                   │
│                                                             │
│  CLIENTE (Ejecucion)                                        │
│  ├── Logica de IA local                                     │
│  ├── Renderizado                                            │
│  ├── Input del jugador                                      │
│  └── Requests al servidor                                   │
│                                                             │
│  COMUNICACION                                               │
│  ├── ModData.transmit() - Estado global                     │
│  ├── sendClientCommand() - Cliente → Servidor               │
│  └── sendServerCommand() - Servidor → Cliente               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Que se Sincroniza

| Dato | Frecuencia | Metodo |
|------|------------|--------|
| Lista de NPCs | Al cambiar | ModData |
| Estado del brain | Cada 10s | ModData |
| Spawn request | Evento | ClientCommand |
| Muerte | Evento | ClientCommand |
| Posicion | Nativo de PZ | (automatico) |

## Consideraciones de Performance

### Rate Limiting

```lua
-- Full update cada 100ms (no cada tick)
local UPDATE_INTERVAL = 100  -- ms

-- LLM query cada 5s maximo
local LLM_INTERVAL = 5000  -- ms

-- Sync a server cada 10s
local SYNC_INTERVAL = 10000  -- ms
```

### Culling

```lua
-- Solo procesar NPCs cercanos al jugador
local MAX_PROCESS_DISTANCE = 100  -- tiles

-- NPCs lejanos en modo "sleep"
local SLEEP_DISTANCE = 150  -- tiles
```

### Cache

```lua
-- Cache de decisiones por 30s
local DECISION_CACHE_TTL = 30  -- segundos

-- Cache de pathfinding
local PATH_CACHE_TTL = 5  -- segundos
```
