# CLAUDE.md - Guia de Desarrollo para SentientNPC

## Descripcion del Proyecto

**SentientNPC** es un mod avanzado para Project Zomboid Build 42 Multiplayer que permite crear NPCs con inteligencia artificial hibrida. Los NPCs pueden tomar decisiones autonomas basadas en contexto, mantener memorias individuales, y comunicarse de forma dinamica.

## Arquitectura Core

El mod usa **zombies del juego base como contenedores** para los NPCs (arquitectura probada del mod Bandits):

```lua
-- Un NPC es un zombie "poseido" con:
zombie:setVariable("Possessed", true)   -- Marcado como NPC
zombie:setVariable("NPCId", "npc_001")  -- ID unico
zombie:setNoTeeth(true)                 -- No muerde
```

## Documentacion de Referencia

**IMPORTANTE**: Antes de desarrollar cualquier feature, consulta estos documentos en orden:

### 1. Arquitectura de NPCs (PRIMERO)
```
../DOCUMENTACION_BANDITS_B42_MASTER.md
```
- Como funciona el sistema de "brain" (estado del NPC)
- Sistema de Programas (comportamiento de alto nivel)
- Sistema de Acciones (comportamiento de bajo nivel)
- Ciclo de vida del NPC
- Sincronizacion multiplayer

### 2. Eventos de PZ (SEGUNDO)
```
../DOCUMENTACION_PZEVENTDOC_REFERENCIA.md
```
- `OnZombieUpdate` - Loop principal (CRITICO)
- `OnZombieCreate` - Inicializacion
- `OnZombieDead` - Cleanup
- `OnClientCommand` / `OnServerCommand` - Multiplayer
- Todos los eventos de tiempo y combate

### 3. API Java de PZ (TERCERO)
```
../JavaDocs.md
```
- `zombie.ai` - Sistema de IA nativo
- `zombie.characters` - Base de personajes
- `zombie.pathfind` - Pathfinding
- `zombie.network` - Multiplayer

### 4. Guia de Implementacion (CUARTO)
```
../guidemasternpcposesionmod.md
```
- Codigo funcional de PossessionManager
- AIBridge para comunicacion con LLM
- Proxy Python para Ollama
- Sistema hibrido BT + LLM

## Estructura del Proyecto

```
SentientNPC/
├── CLAUDE.md                    # Este archivo
├── DEVELOPMENT_PLAN.md          # Plan de desarrollo por fases
├── README.md                    # Documentacion publica
├── docs/                        # Documentacion interna
│   ├── ARCHITECTURE.md          # Arquitectura detallada
│   ├── API_REFERENCE.md         # Referencia de API del mod
│   └── MULTIPLAYER_SYNC.md      # Guia de sincronizacion MP
├── tools/                       # Herramientas externas
│   └── ai_proxy.py              # Proxy Python para Ollama
└── 42/                          # Mod para Build 42
    ├── mod.info                 # Metadata del mod
    └── media/
        ├── lua/
        │   ├── shared/          # Codigo cliente+servidor
        │   │   └── SentientNPC/
        │   │       ├── Core.lua
        │   │       ├── Brain.lua
        │   │       ├── Utils.lua
        │   │       ├── Programs/
        │   │       └── Actions/
        │   ├── client/          # Codigo solo cliente
        │   │   └── SentientNPC/
        │   │       ├── Update.lua
        │   │       ├── UI.lua
        │   │       ├── AIBridge.lua
        │   │       └── Rendering.lua
        │   └── server/          # Codigo solo servidor
        │       └── SentientNPC/
        │           ├── Spawner.lua
        │           ├── Sync.lua
        │           └── Commands.lua
        └── scripts/
            └── sentientnpc.txt  # Items y configuracion
```

## Reglas de Desarrollo

### 1. Patron Brain
Cada NPC tiene un "brain" (tabla Lua) que almacena TODO su estado:

```lua
brain = {
    id = "npc_001",
    type = "guard",              -- Tipo de NPC
    name = "John",               -- Nombre

    -- Estado
    hostile = false,
    sleeping = false,

    -- Programa activo
    program = {name = "Patrol", stage = "Main"},

    -- Cola de tareas
    tasks = {},

    -- Memorias
    memories = {},

    -- Stats
    health = 1.0,
    mood = "neutral"
}
```

### 2. Sistema Programa/Accion
- **Programas**: Deciden QUE hacer (alto nivel)
- **Acciones**: Ejecutan COMO hacerlo (bajo nivel)

```lua
-- Programa retorna tareas
function Programs.Patrol.Main(npc)
    local tasks = {}
    table.insert(tasks, {action="Move", x=100, y=200, z=0})
    return {status=true, next="Main", tasks=tasks}
end

-- Accion ejecuta la tarea
function Actions.Move.onStart(npc, task)
    npc:pathToLocationF(task.x, task.y, task.z)
    return true
end
```

### 3. Sincronizacion Multiplayer
- **Servidor**: Autoridad sobre spawn y estado global
- **Cliente**: Ejecuta logica de IA localmente
- **Sync**: Via ModData y sendClientCommand/sendServerCommand

```lua
-- Servidor -> Clientes
ModData.transmit("SentientNPC_State")

-- Cliente -> Servidor
sendClientCommand("SentientNPC", "RequestSpawn", args)

-- Servidor -> Cliente especifico
sendServerCommand(player, "SentientNPC", "SpawnConfirmed", args)
```

### 4. Sistema Hibrido de IA
Orden de decision:
1. **Reglas criticas** (HP bajo = huir) - INMEDIATO
2. **Cache de decisiones** - RAPIDO
3. **Behavior Tree** - FALLBACK
4. **Query LLM** (si disponible) - ASYNC

```lua
function HybridAI.decide(npc, context)
    -- 1. Reglas criticas
    if npc.hp < 0.2 then return {action="flee"} end

    -- 2. Cache
    local cached = AICache.get(npc.type, context.type)
    if cached then return cached end

    -- 3. Rate limit para LLM
    if not AIBridge.canQuery() then
        return BehaviorTree.run(npc)  -- Fallback
    end

    -- 4. Query LLM async
    AIBridge.requestDecision(npc.id, context)
    return {action="wait"}
end
```

## Comandos de Desarrollo

### Testing Local
```bash
# Copiar mod a carpeta de PZ
cp -r 42/* ~/Zomboid/mods/SentientNPC/

# Iniciar proxy de IA (opcional)
python tools/ai_proxy.py

# Logs del mod
tail -f ~/Zomboid/console.txt | grep SentientNPC
```

### Estructura de Commits
```
feat(core): Add basic possession system
fix(sync): Fix multiplayer brain desync
docs(api): Update Brain structure documentation
refactor(programs): Simplify patrol logic
```

## Checklist por Feature

Antes de considerar una feature completa:

- [ ] Funciona en singleplayer
- [ ] Funciona en multiplayer (host)
- [ ] Funciona en multiplayer (cliente)
- [ ] No causa lag con 20+ NPCs
- [ ] Tiene fallback si LLM no disponible
- [ ] Documentado en docs/
- [ ] Testeado con sandbox options

## Errores Comunes

### 1. Object Pooling de Zombies
```lua
-- MAL: Guardar referencia al zombie
local myZombie = zombie  -- Se recicla!

-- BIEN: Guardar ID y buscar cada vez
local zombieId = zombie:getOnlineID()
local zombie = getZombieById(zombieId)
```

### 2. OnZombieUpdate es MUY frecuente
```lua
-- MAL: Logica pesada cada tick
Events.OnZombieUpdate.Add(function(zombie)
    queryLLM(zombie)  -- 60 veces por segundo!
end)

-- BIEN: Rate limiting
local lastUpdate = {}
Events.OnZombieUpdate.Add(function(zombie)
    local now = os.time()
    if now - (lastUpdate[zombie:getOnlineID()] or 0) < 1 then return end
    lastUpdate[zombie:getOnlineID()] = now
    -- Logica pesada aqui
end)
```

### 3. Sincronizacion MP
```lua
-- MAL: Modificar estado solo en cliente
brain.state = "attacking"  -- No se sincroniza!

-- BIEN: Usar ModData para sync
local gmd = ModData.getOrCreate("SentientNPC")
gmd.brains[npcId].state = "attacking"
ModData.transmit("SentientNPC")
```

## Contacto y Recursos

- **Documentacion Bandits**: Referencia principal de arquitectura
- **PZEventDoc**: Eventos oficiales de PZ
- **JavaDocs**: API Java del juego
- **guidemasternpcposesionmod.md**: Codigo de ejemplo funcional

---

## PROGRESO DE DESARROLLO

### FASE 1: FUNDAMENTOS - COMPLETADO

**Estado**: Listo para testing inicial

**Archivos Implementados**:

| Archivo | Ubicacion | Proposito |
|---------|-----------|-----------|
| `Core.lua` | shared/ | Namespace, configuracion, logging, ModData |
| `Utils.lua` | shared/ | Distancias, deteccion, random, helpers |
| `Brain.lua` | shared/ | Estado del NPC, memoria, personalidad |
| `PossessionManager.lua` | shared/ | Poseer/liberar zombies, spawn |
| `Commands.lua` | shared/ | Comandos cliente/servidor |
| `Update.lua` | client/ | Loop principal OnZombieUpdate |
| `Sync.lua` | server/ | Sincronizacion MP periodica |
| `Actions/Init.lua` | shared/ | Acciones: idle, wait, move, animate |
| `Programs/Init.lua` | shared/ | Programas: Idle, Patrol, Guard, Follow |
| `sandbox-options.txt` | shared/ | Opciones de configuracion |

**Funcionalidades Disponibles**:

1. **Sistema de Posesion**
   - `SentientNPC.Possession.Possess(zombie, config)` - Convertir zombie en NPC
   - `SentientNPC.Possession.Release(zombie)` - Liberar NPC
   - `SentientNPC.Possession.SpawnNPC(x, y, z, config)` - Spawn nuevo NPC
   - `SentientNPC.Possession.SpawnNearPlayer(player, dist, config)` - Spawn cerca de jugador

2. **Sistema Brain**
   - `SentientNPC.Brain.Create(config)` - Crear brain
   - `SentientNPC.Brain.Get(brainId)` - Obtener brain por ID
   - `SentientNPC.Brain.GetFromZombie(zombie)` - Obtener brain de zombie
   - `SentientNPC.Brain.AddMemory(brain, content, type, importance)` - Agregar memoria
   - `SentientNPC.Brain.AddTask(brain, task)` - Agregar tarea

3. **Comandos (Admin)**
   - `SentientNPC.Commands.RequestSpawn({x, y, z, type, name})` - Solicitar spawn
   - `SentientNPC.Commands.RequestDespawn(npcId)` - Solicitar despawn
   - `SentientNPC.Commands.RequestInteract(npcId, action)` - Interactuar

4. **Programas Disponibles**
   - `Idle` - Estar quieto con animaciones ocasionales
   - `Patrol` - Patrullar area alrededor del punto de spawn
   - `Guard` - Defender posicion fija
   - `Follow` / `Companion` - Seguir a jugador master

**Para Testing**:

```lua
-- En consola Lua del juego (admin):

-- Spawn NPC cerca del jugador
local player = getPlayer()
local success, npcId = SentientNPC.Possession.SpawnNearPlayer(player, 5, {
    type = "guard",
    name = "Test Guard",
    program = "Patrol",
})

-- Listar NPCs activos
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    print(brain.name .. " - " .. brain.type .. " - " .. brain.program.name)
end

-- Cambiar programa de NPC
local brain = SentientNPC.Brain.Get(npcId)
brain.program.name = "Guard"
brain.program.stage = "Prepare"
```

**Variables de Zombie para Debug**:
- `zombie:getVariableBoolean("Possessed")` - Es NPC?
- `zombie:getVariableString("NPCId")` - ID del NPC
- `zombie:getVariableString("NPCType")` - Tipo de NPC
- `zombie:getVariableString("NPCName")` - Nombre

### FASE 2: COMPORTAMIENTO - EN PROGRESO

**Completado**:
- [x] Sistema de deteccion de amenazas mejorado (`Detection.lua`)
- [x] Programa Flee (huir de amenazas)
- [x] Programa Wander (exploracion random)
- [x] Mejoras a programas existentes con reacciones a amenazas
- [x] Comandos de consola: snpcSpawn(), snpcClear(), snpcList(), snpcProgram(), snpcCome()

**Pendiente**:
- [ ] Panel UI (removido temporalmente por conflictos de carga)
- [ ] Programa de combate
- [ ] Acciones de combate (atacar)
- [ ] Testing multiplayer extensivo

### Archivos Nuevos (Fase 2):

| Archivo | Ubicacion | Proposito |
|---------|-----------|-----------|
| `Detection.lua` | shared/ | Sistema de deteccion avanzado |

### Comandos de Consola Disponibles:

```lua
snpcSpawn("nombre", "programa")  -- Spawn NPC (programa: Idle, Patrol, Guard, Follow, Wander)
snpcClear()                       -- Eliminar todos los NPCs
snpcList()                        -- Listar NPCs activos
snpcProgram("Guard")              -- Cambiar programa de todos
snpcCome()                        -- Todos los NPCs vienen a ti
```

### Fixes Aplicados:
- **Detection.lua**: Removido `cell:canSee()` (no existe en B42). Usa solo distancia como Bandits.
- **Programs/Follow**: Arreglado matching de master (username vs onlineID).
- **Programs/Wander**: Agregado stage `Alert` faltante que causaba error.
- **Detection.lua**: Ajustados threat levels de zombies para mejor reacción.
- **PossessionManager.lua**: Outfit "Naked1-101" y femaleChance 0-100.
- **Programs/Follow**: Corregido siguiendo patron Bandits:
  - Singleplayer: usa `getSpecificPlayer(0)`
  - Multiplayer: usa `getPlayerByOnlineID(brain.master)`
- **Update.lua/snpcSpawn**: Usa onlineID para Follow

### Pendiente:
- UI Panel: Necesita patrón lazy-load para evitar crash al cargar
- Fase 3: Sistema de combate

### Programas Disponibles (Actualizado):

| Programa | Descripcion | Reacciones |
|----------|-------------|------------|
| Idle | Estar quieto | Huye de amenazas altas |
| Patrol | Patrullar waypoints | Alerta y huye si necesario |
| Guard | Defender posicion | Alerta, mas resistente a huir |
| Follow | Seguir al master | Modo proteccion si hay zombies |
| Flee | Huir de amenazas | Automatico, vuelve a programa anterior |
| Wander | Exploracion random | Huye de amenazas |

### SIGUIENTE: FASE 3 - COMBATE

---

**IMPORTANTE**: Este mod es ambicioso. Desarrolla en fases, testea frecuentemente, y prioriza estabilidad multiplayer sobre features.
