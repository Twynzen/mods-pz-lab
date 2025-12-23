# Guía Técnica Completa: Mod de NPCs con IA para Project Zomboid Build 42

**Bottom Line Up Front:** Es posible crear un mod de NPCs con IA híbrida para Project Zomboid Build 42 usando la arquitectura del mod Bandits como base. HTTP GET funciona nativamente via `getUrlInputStream()`, pero para POST (requerido por Ollama) necesitarás un proceso externo con comunicación vía archivos. El sistema de memoria RAG puede implementarse con ChromaDB o SQLite-vec, y el comportamiento híbrido combina Behavior Trees para acciones inmediatas con consultas LLM para decisiones complejas.

---

## 1. API Lua de Project Zomboid Build 42

### 1.1 Métodos de Control de IsoZombie

Build 42 mantiene la jerarquía `IsoGameCharacter → IsoZombie` con estos métodos críticos para "posesión":

```lua
-- Métodos de estado/comportamiento
zombie:setVariable("Bandit", true)     -- Variable de animación (string/bool/int/float)
zombie:getVariable("Bandit")           -- Obtener variable
zombie:setFakeDead(boolean)            -- Simular muerte
zombie:setNoTeeth(boolean)             -- Deshabilitar mordida
zombie:setCrawler(boolean)             -- Modo crawler
zombie:setTarget(IsoMovingObject)      -- Establecer objetivo
zombie:makeInactive(boolean)           -- Desactivar zombie

-- Pathfinding
zombie:pathToCharacter(target)         -- Navegar hacia personaje
zombie:pathToLocationF(x, y, z)        -- Navegar a coordenadas
zombie:getPathFindBehavior2()          -- Obtener sistema de pathfinding

-- Identificación (CRÍTICO para multiplayer)
zombie:getOnlineID()                   -- ID de red (NO persistente)
zombie:getPersistentOutfitID()         -- ID de outfit (más estable)
zombie:isLocal()                       -- ¿Es controlado localmente?
zombie:isRemoteZombie()                -- ¿Es de otro cliente?
```

**Advertencia B42 - Object Pooling:** Las instancias `IsoZombie` se reciclan. Datos adjuntos a la instancia persisten al nuevo zombie. Usa `Events.OnZombieCreate` para reinicializar.

### 1.2 Sistema de Sincronización Multiplayer

```lua
-- ModData para estado global sincronizado
local data = ModData.getOrCreate("MiMod_NPCs")
data.npcStates = {}
ModData.transmit("MiMod_NPCs")  -- Enviar a todos

-- Recibir datos
Events.OnReceiveGlobalModData.Add(function(key, data)
    if key == "MiMod_NPCs" then
        -- Procesar estado de NPCs
    end
end)

-- Comandos cliente-servidor
sendClientCommand("MiMod", "PossessZombie", {zombieId = id})

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "MiMod" and command == "PossessZombie" then
        -- Validar y ejecutar en servidor
        sendServerCommand("MiMod", "PossessionConfirmed", {success = true})
    end
end)
```

**Detección de contexto:**
| Función | Retorno | Uso |
|---------|---------|-----|
| `isClient()` | boolean | ¿Cliente de red? |
| `isServer()` | boolean | ¿Servidor dedicado? |
| `isCoopHost()` | boolean | ¿Host de co-op? |
| `getPlayer()` | IsoPlayer | Jugador local (índice 0) |
| `getSpecificPlayer(n)` | IsoPlayer | Jugador por índice |

### 1.3 Sistema de Eventos B42

```lua
-- Eventos de zombie (críticos para el mod)
Events.OnZombieCreate.Add(function(zombie)
    -- Inicializar datos del NPC poseído
end)

Events.OnZombieUpdate.Add(function(zombie)
    -- Loop principal de IA (ejecuta cada tick)
    -- ADVERTENCIA: Muy frecuente, optimizar agresivamente
end)

Events.OnZombieDead.Add(function(zombie)
    -- Cleanup de posesión
end)

-- Eventos de timing
Events.EveryOneMinute.Add(function()
    -- Decisiones de IA (rate-limited)
end)

Events.EveryTenMinutes.Add(function()
    -- Actualizar caches de posición
end)
```

---

## 2. HTTP Requests y Comunicación Externa

### 2.1 Capacidad Nativa: getUrlInputStream()

**Descubrimiento crítico:** PZ expone `getUrlInputStream()` para lectura de URLs:

```lua
-- HTTP GET funciona nativamente
local stream = getUrlInputStream("http://localhost:11434/api/tags")
if stream then
    local line = stream:readLine()
    while line do
        print(line)
        line = stream:readLine()
    end
    stream:close()
end
```

**Limitación:** Solo GET, sin soporte para POST/headers - insuficiente para Ollama API directamente.

### 2.2 Arquitectura Recomendada: IPC via Archivos

Dado que Ollama requiere POST, implementar un proxy local:

```
┌─────────────────────────────────────────────────────────────┐
│  PZ LUA MOD              PROXY (Python)           OLLAMA   │
│  ───────────             ──────────────           ──────   │
│  Escribe request.json →  Lee request.json  →     POST API  │
│                          Escribe response.json ←  Response │
│  Lee response.json    ←                                    │
└─────────────────────────────────────────────────────────────┘
```

**Lado Lua (dentro del mod):**
```lua
local AIBridge = {}

function AIBridge.sendRequest(npcId, context)
    local request = {
        npc_id = npcId,
        context = context,
        timestamp = os.time()
    }
    
    local writer = getFileWriter("Zomboid/Lua/ai_request.json", true, false)
    writer:write(json.encode(request))
    writer:close()
end

function AIBridge.checkResponse(npcId)
    local reader = getFileReader("Zomboid/Lua/ai_response_" .. npcId .. ".json", false)
    if reader then
        local content = reader:readLine()
        reader:close()
        if content then
            return json.decode(content)
        end
    end
    return nil
end
```

**Proxy Python (ejecutar junto al servidor):**
```python
import json, time, os, requests
from pathlib import Path

WATCH_DIR = Path.home() / "Zomboid/Lua"
OLLAMA_URL = "http://localhost:11434/api/chat"

def process_request():
    request_file = WATCH_DIR / "ai_request.json"
    if not request_file.exists():
        return
    
    with open(request_file) as f:
        request = json.load(f)
    
    # Query Ollama
    response = requests.post(OLLAMA_URL, json={
        "model": "llama3.2:3b",
        "messages": [{"role": "user", "content": request["context"]}],
        "stream": False,
        "format": "json",
        "options": {"temperature": 0.3, "num_predict": 50}
    }, timeout=2.0)
    
    result = response.json()
    
    # Escribir respuesta
    response_file = WATCH_DIR / f"ai_response_{request['npc_id']}.json"
    with open(response_file, 'w') as f:
        json.dump({
            "npc_id": request["npc_id"],
            "decision": json.loads(result["message"]["content"]),
            "timestamp": time.time()
        }, f)
    
    request_file.unlink()  # Eliminar request procesado

while True:
    process_request()
    time.sleep(0.1)  # 100ms polling
```

---

## 3. API de Ollama para Decisiones de NPCs

### 3.1 Endpoints Principales

**`/api/chat` (Recomendado para NPCs):**
```json
POST http://localhost:11434/api/chat
{
    "model": "llama3.2:3b",
    "messages": [
        {"role": "system", "content": "Eres un NPC guardia. Responde SOLO con JSON válido."},
        {"role": "user", "content": "Un jugador se acerca con arma desenvainada"}
    ],
    "stream": false,
    "format": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["attack", "flee", "alert", "dialogue", "patrol", "idle"]},
            "target": {"type": ["string", "null"]},
            "dialogue": {"type": ["string", "null"]}
        },
        "required": ["action"]
    },
    "options": {
        "temperature": 0.3,
        "num_predict": 50,
        "top_k": 20
    }
}
```

### 3.2 Modelos Recomendados para Decisiones Rápidas

| Modelo | Params | VRAM | Tokens/s | Uso |
|--------|--------|------|----------|-----|
| `llama3.2:1b` | 1B | ~1GB | 120-150 | Decisiones ultra-rápidas |
| `gemma:2b` | 2B | ~2GB | 100-150 | Balance velocidad/calidad |
| `llama3.2:3b` | 3B | ~3GB | 70-90 | Diálogo y razonamiento |
| `phi-3-mini` | 3.8B | ~4GB | 80-100 | Razonamiento complejo |

### 3.3 Prompt Template para NPCs

```lua
local NPCPromptTemplate = [[
Eres %s, un %s en un apocalipsis zombie.

PERSONALIDAD: %s
ESTADO ACTUAL: HP=%d/%d, Humor=%s
MEMORIAS RELEVANTES:
%s

SITUACIÓN: %s

ACCIONES DISPONIBLES: patrol, attack, flee, trade, dialogue, alert, idle

Responde SOLO con JSON: {"action": "...", "target": "...", "dialogue": "..."}
]]

function buildNPCPrompt(npc, situation, memories)
    return string.format(NPCPromptTemplate,
        npc.name, npc.role, npc.personality,
        npc.hp, npc.maxHp, npc.mood,
        table.concat(memories, "\n"),
        situation
    )
end
```

---

## 4. Sistema RAG para Memoria Individual

### 4.1 Arquitectura de Memoria por NPC

```lua
-- Estructura de memoria
NPCMemory = {
    id = "mem_001",
    npc_id = "guardia_01",
    memory_type = "interaction",  -- observation, interaction, relationship, goal
    content = "El jugador me ayudó a encontrar mi espada perdida",
    importance = 0.8,             -- 0.0 a 1.0
    timestamp = 1702400000,
    access_count = 0,
    emotional_valence = 0.7,      -- -1.0 (negativo) a 1.0 (positivo)
    related_entities = {"player", "quest_lost_sword"}
}
```

### 4.2 Vector Store Recomendado: ChromaDB

```python
# Servidor de memoria (Python)
import chromadb
from fastembed import TextEmbedding

client = chromadb.PersistentClient(path="./npc_memories")
embedder = TextEmbedding(model_name="BAAI/bge-small-en-v1.5")

def add_memory(npc_id: str, content: str, importance: float = 0.5):
    collection = client.get_or_create_collection(f"npc_{npc_id}")
    embedding = list(embedder.embed([content]))[0].tolist()
    
    collection.add(
        ids=[f"{npc_id}_{int(time.time()*1000)}"],
        embeddings=[embedding],
        documents=[content],
        metadatas=[{
            "npc_id": npc_id,
            "importance": importance,
            "timestamp": time.time()
        }]
    )

def retrieve_memories(npc_id: str, query: str, k: int = 5):
    collection = client.get_collection(f"npc_{npc_id}")
    query_embedding = list(embedder.embed([query]))[0].tolist()
    
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=k
    )
    return results["documents"][0]
```

### 4.3 Scoring de Memoria (Fórmula de Generative Agents)

```lua
-- Score = α·Recencia + β·Importancia + γ·Relevancia
function calculateMemoryScore(memory, queryEmbedding, currentTime)
    local alpha, beta, gamma = 0.3, 0.3, 0.4
    
    -- Recencia: Decaimiento exponencial (0.995^horas)
    local hoursElapsed = (currentTime - memory.timestamp) / 3600
    local recencyScore = math.pow(0.995, hoursElapsed)
    
    -- Importancia: Valor guardado
    local importanceScore = memory.importance
    
    -- Relevancia: Similitud coseno (calculado externamente)
    local relevanceScore = memory.similarity or 0.5
    
    return alpha * recencyScore + beta * importanceScore + gamma * relevanceScore
end
```

---

## 5. Sistema de Comportamiento Híbrido

### 5.1 Behavior Tree en Lua

```lua
local BehaviorTree = require('behaviourtree')

-- Definir tareas
BehaviorTree.Task:new({
    name = 'detectEnemy',
    run = function(task, npc)
        local enemy = findNearestEnemy(npc)
        if enemy then
            npc.target = enemy
            task:success()
        else
            task:fail()
        end
    end
})

BehaviorTree.Task:new({
    name = 'engageCombat',
    run = function(task, npc)
        if not npc.target then task:fail(); return end
        
        local distance = getDistance(npc, npc.target)
        if distance < npc.attackRange then
            attack(npc, npc.target)
            task:success()
        else
            moveToward(npc, npc.target)
            task:running()
        end
    end
})

-- Construir árbol del NPC
local guardTree = BehaviorTree:new({
    tree = BehaviorTree.Priority:new({
        nodes = {
            -- Prioridad 1: Combate
            BehaviorTree.Sequence:new({
                nodes = {'detectEnemy', 'engageCombat'}
            }),
            -- Prioridad 2: Patrulla
            'patrol',
            -- Fallback: Idle
            'idle'
        }
    })
})
```

### 5.2 Integración Híbrida: Cuándo Usar IA vs Reglas

```lua
local HybridAI = {
    cache = {},
    rateLimit = {
        lastQuery = 0,
        minInterval = 5000  -- 5 segundos entre queries
    }
}

function HybridAI.decide(npc, context)
    -- Capa 1: Reglas hardcodeadas (inmediato)
    local ruleResult = HybridAI.checkCriticalRules(npc, context)
    if ruleResult then return ruleResult end
    
    -- Capa 2: Cache de decisiones similares
    local cacheKey = npc.archetype .. "_" .. context.type
    if HybridAI.cache[cacheKey] then
        return HybridAI.cache[cacheKey]
    end
    
    -- Capa 3: Rate limit check
    local now = os.time() * 1000
    if now - HybridAI.rateLimit.lastQuery < HybridAI.rateLimit.minInterval then
        return HybridAI.getFallbackAction(npc)  -- Behavior tree
    end
    
    -- Capa 4: Query LLM (async)
    HybridAI.rateLimit.lastQuery = now
    HybridAI.sendToLLM(npc, context)
    
    -- Retornar acción temporal mientras espera
    return {action = "wait", duration = 1.0}
end

function HybridAI.checkCriticalRules(npc, context)
    -- Reglas que NUNCA van a LLM
    if npc.hp < npc.maxHp * 0.2 then
        return {action = "flee"}  -- HP crítico = huir
    end
    if context.playerAttacking and context.distance < 2 then
        return {action = "defend"}  -- Ataque inminente = defender
    end
    return nil
end
```

### 5.3 Formato de Decisiones JSON

```lua
-- Schema de respuesta de IA
local DecisionSchema = {
    action = "string",       -- patrol, attack, flee, trade, dialogue, idle, alert
    target = "string|nil",   -- ID de entidad o posición
    parameters = {
        dialogue = "string", -- Para acción "dialogue"
        intensity = "number" -- 0.0 a 1.0
    },
    reasoning = "string"     -- Explicación breve (debug)
}

-- Validación
function validateDecision(response)
    local validActions = {"patrol", "attack", "flee", "trade", "dialogue", "idle", "alert"}
    
    if not response.action then return false, "missing_action" end
    
    local actionValid = false
    for _, a in ipairs(validActions) do
        if response.action == a then actionValid = true; break end
    end
    if not actionValid then return false, "invalid_action" end
    
    return true, response
end
```

---

## 6. Sistema de "Posesión" de Zombies

### 6.1 Conversión de Zombie Vanilla a NPC

```lua
local PossessionSystem = {}

function PossessionSystem.possess(zombie, npcData)
    -- Verificar que es zombie válido
    if not zombie or zombie:isDead() then return false end
    
    -- Marcar como poseído
    zombie:setVariable("Possessed", true)
    zombie:setVariable("PossessedNPC", npcData.id)
    zombie:setVariable("NPCType", npcData.type)  -- "guardia", "comerciante", etc.
    
    -- Deshabilitar comportamiento zombie
    zombie:setNoTeeth(true)        -- No muerde
    zombie:setVariable("NoTarget", true)
    
    -- Preservar apariencia visual
    local outfitId = zombie:getPersistentOutfitID()
    
    -- Inicializar datos del NPC
    PossessionSystem.initNPCData(zombie, npcData)
    
    -- Registrar en sistema global
    local globalData = ModData.getOrCreate("PossessedNPCs")
    globalData[zombie:getOnlineID()] = {
        npcId = npcData.id,
        outfitId = outfitId,
        createdAt = os.time()
    }
    ModData.transmit("PossessedNPCs")
    
    return true
end

function PossessionSystem.release(zombie)
    if not zombie:getVariableBoolean("Possessed") then return false end
    
    -- Restaurar comportamiento zombie
    zombie:setVariable("Possessed", false)
    zombie:setNoTeeth(false)
    zombie:setVariable("NoTarget", false)
    zombie:clearVariable("PossessedNPC")
    zombie:clearVariable("NPCType")
    
    -- Remover del registro global
    local globalData = ModData.get("PossessedNPCs")
    if globalData then
        globalData[zombie:getOnlineID()] = nil
        ModData.transmit("PossessedNPCs")
    end
    
    return true
end

function PossessionSystem.isPossessed(zombie)
    return zombie:getVariableBoolean("Possessed")
end
```

### 6.2 Control Granular del NPC Poseído

```lua
local NPCController = {}

function NPCController.setMovement(npc, enabled)
    npc:setVariable("CanMove", enabled)
    if not enabled then
        npc:setMoving(false)
    end
end

function NPCController.setCombat(npc, enabled)
    npc:setVariable("CanAttack", enabled)
    npc:setNoTeeth(not enabled)
end

function NPCController.setDialogue(npc, enabled)
    npc:setVariable("CanSpeak", enabled)
end

-- Estado especial: Congelado (para cutscenes)
function NPCController.freeze(npc)
    npc:setVariable("Frozen", true)
    NPCController.setMovement(npc, false)
    NPCController.setCombat(npc, false)
end

function NPCController.unfreeze(npc)
    npc:setVariable("Frozen", false)
    NPCController.setMovement(npc, true)
    NPCController.setCombat(npc, true)
end

-- Admin override para control total
function NPCController.adminControl(npc, action, params)
    if not isAdmin() then return false end
    
    if action == "moveTo" then
        npc:pathToLocationF(params.x, params.y, params.z)
    elseif action == "speak" then
        showDialogue(npc, params.text)
    elseif action == "kill" then
        npc:Kill(nil)
    end
    
    return true
end
```

### 6.3 Zombies Especiales (Sistema de Secta)

```lua
-- Zombie que "habla" (overlay de texto)
function createSpeakingZombie(zombie, dialogueLines)
    PossessionSystem.possess(zombie, {
        id = "cult_speaker_" .. zombie:getOnlineID(),
        type = "cult_member"
    })
    
    zombie:setVariable("CultMember", true)
    zombie:setVariable("DialogueLines", json.encode(dialogueLines))
    zombie:setVariable("CurrentDialogue", 0)
    
    -- Visual distintivo
    zombie:setVariable("GlowingEyes", true)  -- Marcador visual
end

-- Sistema de diálogo para zombies
function speakAsZombie(zombie)
    if not zombie:getVariableBoolean("CultMember") then return end
    
    local lines = json.decode(zombie:getVariableString("DialogueLines"))
    local current = zombie:getVariableFloat("CurrentDialogue") + 1
    
    if current > #lines then current = 1 end
    
    -- Mostrar texto sobre el zombie
    local text = lines[current]
    showOverheadText(zombie, text, {r=0.8, g=0.2, b=0.2})  -- Texto rojo
    
    zombie:setVariable("CurrentDialogue", current)
end
```

---

## 7. Arquitectura Completa del Mod

### 7.1 Estructura de Archivos Recomendada

```
PossessedNPCs/
├── 42.0.0/
│   ├── mod.info
│   └── media/
│       ├── lua/
│       │   ├── shared/
│       │   │   ├── PossessedNPCs/
│       │   │   │   ├── Core.lua           -- Inicialización
│       │   │   │   ├── NPCData.lua        -- Estructuras de datos
│       │   │   │   ├── Utils.lua          -- Utilidades
│       │   │   │   └── JSON.lua           -- Parser JSON
│       │   │   └── sandbox-options.txt    -- Opciones de servidor
│       │   ├── client/
│       │   │   ├── PossessedNPCs/
│       │   │   │   ├── UI.lua             -- Interfaz
│       │   │   │   ├── ContextMenu.lua    -- Menús contextuales
│       │   │   │   ├── Rendering.lua      -- Efectos visuales
│       │   │   │   └── AIBridge.lua       -- Comunicación con proxy
│       │   │   └── PossessedNPCs_ModOptions.lua
│       │   └── server/
│       │       └── PossessedNPCs/
│       │           ├── Spawning.lua       -- Spawn de NPCs
│       │           ├── Sync.lua           -- Sincronización MP
│       │           └── Persistence.lua    -- Guardado
│       └── scripts/
│           └── items_possessednpcs.txt    -- Items del mod
├── common/
│   └── media/
│       └── textures/                      -- Texturas compartidas
└── poster.png
```

### 7.2 Sistema de Configuración

**sandbox-options.txt:**
```lua
VERSION = 1,

option PossessedNPCs.MaxNPCs
{
    type = integer,
    min = 1,
    max = 100,
    default = 20,
    page = PossessedNPCs,
    translation = PNPC_MaxNPCs,
}

option PossessedNPCs.AIEnabled
{
    type = boolean,
    default = true,
    page = PossessedNPCs,
    translation = PNPC_AIEnabled,
}

option PossessedNPCs.AIResponseTime
{
    type = integer,
    min = 1000,
    max = 10000,
    default = 3000,
    page = PossessedNPCs,
    translation = PNPC_AIResponseTime,
}
```

**ModOptions (B42 Nativo):**
```lua
local options = PZAPI.ModOptions:create("PossessedNPCs", "Possessed NPCs")

options:addTickBox("showDialogues", "Show NPC Dialogues", true)
options:addSlider("dialogueDuration", "Dialogue Duration (s)", 1, 10, 5, 1)
options:addColorPicker("cultTextColor", "Cult Dialogue Color", {r=0.8, g=0.2, b=0.2, a=1})

-- Acceso
Events.OnGameStart.Add(function()
    local showDialogues = options:get("showDialogues")
end)
```

### 7.3 Loop Principal Optimizado

```lua
-- Evitar procesamiento excesivo en OnZombieUpdate
local NPCUpdateManager = {
    cache = {},
    lastFullUpdate = 0,
    updateInterval = 100  -- ms entre actualizaciones completas
}

Events.OnZombieUpdate.Add(function(zombie)
    -- Solo procesar zombies poseídos
    if not PossessionSystem.isPossessed(zombie) then return end
    
    local now = os.time() * 1000
    local npcId = zombie:getOnlineID()
    
    -- Actualización ligera cada tick
    NPCUpdateManager.lightUpdate(zombie, npcId)
    
    -- Actualización completa rate-limited
    if now - NPCUpdateManager.lastFullUpdate > NPCUpdateManager.updateInterval then
        NPCUpdateManager.fullUpdate(zombie, npcId)
        NPCUpdateManager.lastFullUpdate = now
    end
end)

function NPCUpdateManager.lightUpdate(zombie, npcId)
    -- Solo actualizar posición en cache
    NPCUpdateManager.cache[npcId] = NPCUpdateManager.cache[npcId] or {}
    NPCUpdateManager.cache[npcId].x = zombie:getX()
    NPCUpdateManager.cache[npcId].y = zombie:getY()
end

function NPCUpdateManager.fullUpdate(zombie, npcId)
    -- Ejecutar behavior tree
    local npcData = NPCUpdateManager.cache[npcId]
    
    -- Verificar si hay respuesta de IA pendiente
    local aiResponse = AIBridge.checkResponse(npcId)
    if aiResponse then
        executeAIDecision(zombie, aiResponse)
        return
    end
    
    -- Ejecutar árbol de comportamiento por defecto
    local tree = NPCBehaviorTrees[npcData.type]
    if tree then
        tree:setObject(zombie)
        tree:run()
    end
end
```

---

## 8. Código Funcional de Ejemplo

### 8.1 Integración Completa con Proxy

**proxy_server.py (Ejecutar junto al servidor PZ):**
```python
#!/usr/bin/env python3
import json
import time
import os
from pathlib import Path
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class AIProxyHandler(FileSystemEventHandler):
    def __init__(self, watch_dir, ollama_url="http://localhost:11434"):
        self.watch_dir = Path(watch_dir)
        self.ollama_url = ollama_url
        self.model = "llama3.2:3b"
        
    def on_created(self, event):
        if event.is_directory or not event.src_path.endswith("_request.json"):
            return
        self.process_request(event.src_path)
    
    def process_request(self, filepath):
        try:
            with open(filepath) as f:
                request = json.load(f)
            
            # Construir prompt
            npc_id = request["npc_id"]
            context = request["context"]
            memories = request.get("memories", [])
            
            prompt = f"""Eres un NPC en un juego de supervivencia zombie.

MEMORIAS RELEVANTES:
{chr(10).join(memories)}

SITUACIÓN ACTUAL: {context}

Responde SOLO con JSON válido:
{{"action": "patrol|attack|flee|trade|dialogue|idle|alert", "target": "...|null", "dialogue": "...|null"}}"""
            
            # Query Ollama
            response = requests.post(
                f"{self.ollama_url}/api/chat",
                json={
                    "model": self.model,
                    "messages": [{"role": "user", "content": prompt}],
                    "stream": False,
                    "format": "json",
                    "options": {"temperature": 0.3, "num_predict": 50}
                },
                timeout=5.0
            )
            
            result = response.json()
            decision = json.loads(result["message"]["content"])
            
            # Escribir respuesta
            response_path = self.watch_dir / f"{npc_id}_response.json"
            with open(response_path, 'w') as f:
                json.dump({
                    "npc_id": npc_id,
                    "decision": decision,
                    "timestamp": time.time()
                }, f)
            
            # Limpiar request
            os.unlink(filepath)
            
        except Exception as e:
            print(f"Error processing {filepath}: {e}")

if __name__ == "__main__":
    watch_dir = Path.home() / "Zomboid/Lua/AIBridge"
    watch_dir.mkdir(parents=True, exist_ok=True)
    
    handler = AIProxyHandler(watch_dir)
    observer = Observer()
    observer.schedule(handler, str(watch_dir), recursive=False)
    observer.start()
    
    print(f"AI Proxy listening in {watch_dir}")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
```

### 8.2 Módulo AIBridge.lua

```lua
-- media/lua/client/PossessedNPCs/AIBridge.lua
local AIBridge = {}

local BRIDGE_DIR = "Zomboid/Lua/AIBridge/"
local pendingRequests = {}
local responseCache = {}

function AIBridge.init()
    -- Crear directorio si no existe
    local writer = getFileWriter(BRIDGE_DIR .. "init.txt", true, false)
    writer:write("initialized")
    writer:close()
end

function AIBridge.requestDecision(npcId, context, memories)
    local request = {
        npc_id = npcId,
        context = context,
        memories = memories or {},
        timestamp = os.time()
    }
    
    local writer = getFileWriter(BRIDGE_DIR .. npcId .. "_request.json", true, false)
    writer:write(json.encode(request))
    writer:close()
    
    pendingRequests[npcId] = os.time()
end

function AIBridge.checkResponse(npcId)
    local reader = getFileReader(BRIDGE_DIR .. npcId .. "_response.json", false)
    if not reader then return nil end
    
    local content = reader:readLine()
    reader:close()
    
    if content then
        -- Eliminar archivo de respuesta
        -- (No hay función directa, usar marker)
        local marker = getFileWriter(BRIDGE_DIR .. npcId .. "_response.json.processed", true, false)
        marker:close()
        
        local response = json.decode(content)
        pendingRequests[npcId] = nil
        responseCache[npcId] = {
            decision = response.decision,
            timestamp = os.time()
        }
        return response.decision
    end
    
    return nil
end

function AIBridge.getCachedDecision(npcId, maxAge)
    maxAge = maxAge or 30  -- 30 segundos por defecto
    local cached = responseCache[npcId]
    
    if cached and (os.time() - cached.timestamp) < maxAge then
        return cached.decision
    end
    
    return nil
end

function AIBridge.isPending(npcId)
    return pendingRequests[npcId] ~= nil
end

return AIBridge
```

### 8.3 Sistema de Posesión Completo

```lua
-- media/lua/shared/PossessedNPCs/PossessionManager.lua
local PossessionManager = {}

local possessedNPCs = {}
local npcBehaviors = {}

function PossessionManager.init()
    Events.OnZombieCreate.Add(function(zombie)
        -- Limpiar datos de instancia reciclada
        if possessedNPCs[zombie:getOnlineID()] then
            possessedNPCs[zombie:getOnlineID()] = nil
        end
    end)
    
    Events.OnZombieDead.Add(function(zombie)
        PossessionManager.release(zombie)
    end)
    
    -- Sincronizar en multiplayer
    Events.OnReceiveGlobalModData.Add(function(key, data)
        if key == "PossessedNPCs_State" then
            PossessionManager.syncFromServer(data)
        end
    end)
end

function PossessionManager.possess(zombie, npcConfig)
    if not zombie or zombie:isDead() then 
        return false, "invalid_zombie" 
    end
    
    if PossessionManager.isPossessed(zombie) then
        return false, "already_possessed"
    end
    
    local npcId = npcConfig.id or ("npc_" .. zombie:getOnlineID())
    
    -- Configurar zombie
    zombie:setVariable("Possessed", true)
    zombie:setVariable("NPCId", npcId)
    zombie:setVariable("NPCType", npcConfig.type or "generic")
    zombie:setVariable("NPCName", npcConfig.name or "NPC")
    zombie:setNoTeeth(true)
    
    -- Guardar datos
    possessedNPCs[zombie:getOnlineID()] = {
        npcId = npcId,
        config = npcConfig,
        createdAt = os.time(),
        memories = {},
        state = "idle"
    }
    
    -- Inicializar behavior tree según tipo
    local behaviorType = npcConfig.behaviorTree or "default"
    npcBehaviors[npcId] = createBehaviorTree(behaviorType)
    
    -- Sincronizar en MP
    if isServer() or isCoopHost() then
        PossessionManager.syncToClients()
    end
    
    print("[PossessedNPCs] Possessed zombie " .. zombie:getOnlineID() .. " as " .. npcId)
    return true, npcId
end

function PossessionManager.release(zombie)
    if not PossessionManager.isPossessed(zombie) then return false end
    
    local npcId = zombie:getVariableString("NPCId")
    
    -- Restaurar zombie
    zombie:setVariable("Possessed", false)
    zombie:clearVariable("NPCId")
    zombie:clearVariable("NPCType")
    zombie:clearVariable("NPCName")
    zombie:setNoTeeth(false)
    
    -- Limpiar datos
    possessedNPCs[zombie:getOnlineID()] = nil
    npcBehaviors[npcId] = nil
    
    -- Sincronizar
    if isServer() or isCoopHost() then
        PossessionManager.syncToClients()
    end
    
    return true
end

function PossessionManager.isPossessed(zombie)
    return zombie:getVariableBoolean("Possessed")
end

function PossessionManager.getNPCData(zombie)
    return possessedNPCs[zombie:getOnlineID()]
end

function PossessionManager.addMemory(npcId, content, importance)
    for onlineId, data in pairs(possessedNPCs) do
        if data.npcId == npcId then
            table.insert(data.memories, {
                content = content,
                importance = importance or 0.5,
                timestamp = os.time()
            })
            -- Limitar memorias
            while #data.memories > 100 do
                table.remove(data.memories, 1)
            end
            return true
        end
    end
    return false
end

function PossessionManager.getRelevantMemories(npcId, context, limit)
    limit = limit or 5
    for onlineId, data in pairs(possessedNPCs) do
        if data.npcId == npcId then
            -- Ordenar por importancia y recencia
            local scored = {}
            local now = os.time()
            for _, mem in ipairs(data.memories) do
                local age = now - mem.timestamp
                local recency = math.exp(-age / 3600)  -- Decae por hora
                local score = mem.importance * 0.5 + recency * 0.5
                table.insert(scored, {memory = mem, score = score})
            end
            table.sort(scored, function(a, b) return a.score > b.score end)
            
            local result = {}
            for i = 1, math.min(limit, #scored) do
                table.insert(result, scored[i].memory.content)
            end
            return result
        end
    end
    return {}
end

function PossessionManager.syncToClients()
    local syncData = {}
    for onlineId, data in pairs(possessedNPCs) do
        syncData[onlineId] = {
            npcId = data.npcId,
            config = data.config,
            state = data.state
        }
    end
    local globalData = ModData.getOrCreate("PossessedNPCs_State")
    globalData.npcs = syncData
    globalData.timestamp = os.time()
    ModData.transmit("PossessedNPCs_State")
end

function PossessionManager.syncFromServer(data)
    if isServer() then return end
    -- Clientes actualizan su estado local
    for onlineId, npcData in pairs(data.npcs or {}) do
        possessedNPCs[onlineId] = possessedNPCs[onlineId] or {}
        possessedNPCs[onlineId].npcId = npcData.npcId
        possessedNPCs[onlineId].config = npcData.config
        possessedNPCs[onlineId].state = npcData.state
    end
end

return PossessionManager
```

---

## Diagrama de Arquitectura Completa

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MOD ARCHITECTURE OVERVIEW                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                              ┌─────────────────────┐   │
│  │   GAME LOOP     │                              │   AI PROXY (Python) │   │
│  │   (60 FPS)      │                              │                     │   │
│  └────────┬────────┘                              │  ┌───────────────┐  │   │
│           │                                       │  │    OLLAMA     │  │   │
│           ▼                                       │  │   (Local LLM) │  │   │
│  ┌────────────────────────────────────────┐      │  └───────┬───────┘  │   │
│  │         OnZombieUpdate                  │      │          │          │   │
│  │  ┌──────────────────────────────────┐  │      │          ▼          │   │
│  │  │ Is Possessed? ──No──► Skip      │  │      │  ┌───────────────┐  │   │
│  │  │      │                           │  │      │  │ ChromaDB/RAG │  │   │
│  │  │      ▼ Yes                       │  │      │  │  (Memories)  │  │   │
│  │  │ Light Update (position cache)    │  │      │  └───────────────┘  │   │
│  │  │      │                           │  │      └─────────┬───────────┘   │
│  │  │      ▼                           │  │                │               │
│  │  │ Rate Limited? ──Yes──► Skip      │  │      ┌─────────┴─────────┐     │
│  │  │      │                           │  │      │                   │     │
│  │  │      ▼ No                        │  │      │   FILE IPC        │     │
│  │  │ Full Update                      │  │      │                   │     │
│  │  │      │                           │  │      │ request.json  ───►│     │
│  │  │      ▼                           │  │      │◄─── response.json │     │
│  │  │ ┌──────────────────────────────┐ │  │      └───────────────────┘     │
│  │  │ │    HYBRID DECISION ENGINE    │ │  │                                │
│  │  │ │                              │ │  │                                │
│  │  │ │ 1. Critical Rules ──Hit?──►  │ │  │                                │
│  │  │ │         │                    │ │  │                                │
│  │  │ │         ▼ No                 │ │  │                                │
│  │  │ │ 2. AI Cache ──Hit?──────────►│ │  │                                │
│  │  │ │         │                    │ │  │                                │
│  │  │ │         ▼ No                 │ │  │                                │
│  │  │ │ 3. Rate Limit OK?            │ │  │                                │
│  │  │ │    │Yes      │No             │ │  │                                │
│  │  │ │    ▼         ▼               │ │  │                                │
│  │  │ │ Query LLM  BT Fallback       │ │  │                                │
│  │  │ └──────────────────────────────┘ │  │                                │
│  │  │      │                           │  │                                │
│  │  │      ▼                           │  │                                │
│  │  │ Execute Action                   │  │                                │
│  │  │ (pathfind, attack, speak, etc)   │  │                                │
│  │  └──────────────────────────────────┘  │                                │
│  └────────────────────────────────────────┘                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    MULTIPLAYER SYNC LAYER                            │   │
│  │  sendClientCommand() ◄──────────────────────► sendServerCommand()   │   │
│  │  ModData.transmit("PossessedNPCs_State")                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Recursos y Documentación

### Documentación Oficial y Comunitaria
- **PZwiki Modding**: https://pzwiki.net/wiki/Modding
- **Unofficial JavaDocs B42**: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/
- **FWolfe Modding Guide**: https://github.com/FWolfe/Zomboid-Modding-Guide
- **PZEventDoc**: https://github.com/demiurgeQuantified/PZEventDoc

### Repositorios de Referencia
- **Bandits NPC**: Steam Workshop ID 3268487204
- **PZNS Framework**: https://github.com/Project-Zomboid-Community-Modding/PZNS
- **Behavior Trees Lua**: https://github.com/tanema/behaviourtree.lua

### Herramientas de Desarrollo
- **VS Code + Umbrella Extension**: Syntax highlighting para PZ Lua
- **ZomboidDoc (pz-zdoc)**: Generador de documentación Lua
- **Ollama**: https://ollama.ai
- **ChromaDB**: https://www.trychroma.com
- **FastEmbed**: https://github.com/qdrant/fastembed

---

## Conclusión

Esta guía proporciona la base técnica completa para desarrollar un mod de NPCs con IA para Project Zomboid Build 42. Los puntos críticos son:

1. **HTTP POST no es nativo** - Usar proxy Python con IPC via archivos
2. **Object pooling de zombies** - Reinicializar datos en `OnZombieCreate`
3. **Híbrido es esencial** - LLM para decisiones complejas, Behavior Trees para acciones inmediatas
4. **Arquitectura de Bandits** - Usar zombies como base, no código NPC oculto
5. **Multiplayer** - Computación cliente-side determinística, sync vía ModData

Con esta documentación y el análisis del mod Bandits, Claude Code tiene información suficiente para implementar un sistema funcional de NPCs con IA desde cero.