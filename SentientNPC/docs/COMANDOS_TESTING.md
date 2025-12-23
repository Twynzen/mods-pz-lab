# Comandos de Testing - SentientNPC

Guia rapida de comandos para probar el mod en la consola Lua de Project Zomboid.

---

## COMANDOS DE CONSOLA (Fase 2)

### Comandos Principales
```lua
-- Spawn NPC cerca de ti
snpcSpawn("NombreNPC", "Patrol")

-- Eliminar todos los NPCs
snpcClear()

-- Listar NPCs activos
snpcList()

-- Cambiar programa de todos los NPCs
snpcProgram("Guard")    -- Opciones: Idle, Patrol, Guard, Follow, Wander, Flee

-- Hacer que todos los NPCs vengan a ti
snpcCome()
```

### Ejemplos de Uso
```lua
-- Spawn un guardia
snpcSpawn("Guardia1", "Guard")

-- Spawn un patrullero
snpcSpawn("Soldado", "Patrol")

-- Spawn un companero que te sigue
snpcSpawn("Amigo", "Follow")

-- Spawn un NPC que explora
snpcSpawn("Explorador", "Wander")
```

---

## LIMPIEZA (Usar primero si hay desorden)

### Eliminar TODOS los NPCs del mod
```lua
local zombies = SentientNPC.Possession.GetAllPossessed()
for _, zombie in ipairs(zombies) do
    SentientNPC.Possession.Release(zombie)
    zombie:removeFromWorld()
end
print("Eliminados: " .. #zombies .. " NPCs")
```

### Eliminar TODOS los zombies del mapa (nuclear)
```lua
local cell = getCell()
local zombieList = cell:getZombieList()
local count = zombieList:size()
for i = count - 1, 0, -1 do
    local zombie = zombieList:get(i)
    if zombie then
        zombie:removeFromWorld()
    end
end
print("Eliminados: " .. count .. " zombies")
```

### Eliminar zombies en radio de 20 tiles
```lua
local p = getPlayer()
local cell = getCell()
local zombieList = cell:getZombieList()
local count = 0
for i = zombieList:size() - 1, 0, -1 do
    local zombie = zombieList:get(i)
    if zombie then
        local dist = math.sqrt((zombie:getX()-p:getX())^2 + (zombie:getY()-p:getY())^2)
        if dist < 20 then
            zombie:removeFromWorld()
            count = count + 1
        end
    end
end
print("Eliminados: " .. count .. " zombies cercanos")
```

---

## SPAWN DE NPCs

### Spawn basico (Idle)
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+3, p:getY()+3, p:getZ(), {
    type = "generic",
    name = "TestNPC",
    program = "Idle"
})
```

### Spawn Patrullero
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+5, p:getY()+5, p:getZ(), {
    type = "guard",
    name = "Patrullero",
    program = "Patrol"
})
```

### Spawn Guardia
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+8, p:getY()+8, p:getZ(), {
    type = "guard",
    name = "Guardia",
    program = "Guard"
})
```

### Spawn Companero (te sigue)
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+3, p:getY()+3, p:getZ(), {
    type = "companion",
    name = "Companero",
    program = "Follow",
    master = p:getUsername()
})
```

### Spawn con outfit especifico
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+3, p:getY()+3, p:getZ(), {
    type = "guard",
    name = "Policia",
    program = "Guard",
    outfit = "Police"
})
```

### Spawn NPC femenino
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+3, p:getY()+3, p:getZ(), {
    type = "generic",
    name = "Maria",
    program = "Idle",
    female = true
})
```

### Spawn usando SpawnNearPlayer
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNearPlayer(p, 5, {
    type = "guard",
    name = "NPC Cercano",
    program = "Patrol"
})
```

---

## DEBUG E INFORMACION

### Listar todos los NPCs activos
```lua
local brains = SentientNPC.Brain.GetAll()
local count = 0
for id, brain in pairs(brains) do
    print(string.format("[%s] %s - Programa: %s (%s)",
        id, brain.name, brain.program.name, brain.program.stage))
    count = count + 1
end
print("Total NPCs: " .. count)
```

### Ver info de un NPC especifico
```lua
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    print("=== " .. brain.name .. " ===")
    print("ID: " .. brain.id)
    print("Tipo: " .. brain.type)
    print("Programa: " .. brain.program.name)
    print("Stage: " .. brain.program.stage)
    print("Posicion: " .. brain.lastX .. ", " .. brain.lastY)
    print("Mood: " .. (brain.mood or "neutral"))
    print("Hostile: " .. tostring(brain.hostileToPlayers))
    break -- Solo el primero
end
```

### Ver estadisticas globales
```lua
local gmd = SentientNPC.GetModData()
print("=== Stats SentientNPC ===")
print("NPCs activos: " .. (gmd.stats.activeNPCs or 0))
print("Total spawneados: " .. (gmd.stats.totalSpawned or 0))
print("Total muertos: " .. (gmd.stats.totalDied or 0))
```

### Verificar si zombie es NPC
```lua
local cell = getCell()
local zombieList = cell:getZombieList()
for i = 0, zombieList:size() - 1 do
    local zombie = zombieList:get(i)
    if SentientNPC.Possession.IsPossessed(zombie) then
        local name = SentientNPC.Possession.GetNPCName(zombie)
        print("NPC encontrado: " .. (name or "sin nombre"))
    end
end
```

---

## MODIFICAR NPCs EN TIEMPO REAL

### Cambiar programa de todos los NPCs a Patrol
```lua
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    brain.program.name = "Patrol"
    brain.program.stage = "Prepare"
    brain.program.data = {}
    print("Cambiado: " .. brain.name .. " a Patrol")
end
```

### Cambiar programa de todos a Guard
```lua
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    brain.program.name = "Guard"
    brain.program.stage = "Prepare"
    brain.program.data = {}
    print("Cambiado: " .. brain.name .. " a Guard")
end
```

### Cambiar programa de todos a Follow (seguirte)
```lua
local p = getPlayer()
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    brain.program.name = "Follow"
    brain.program.stage = "Prepare"
    brain.program.data = {}
    brain.master = p:getUsername()
    print("Cambiado: " .. brain.name .. " a Follow")
end
```

### Hacer NPC hostil
```lua
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    brain.hostileToPlayers = true
    local zombie = SentientNPC.Possession.GetZombieForBrain(brain)
    if zombie then
        zombie:setVariable("NPCHostile", true)
    end
    print(brain.name .. " ahora es hostil")
    break -- Solo el primero
end
```

### Hacer NPC pacifico
```lua
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    brain.hostileToPlayers = false
    local zombie = SentientNPC.Possession.GetZombieForBrain(brain)
    if zombie then
        zombie:setVariable("NPCHostile", false)
        zombie:setTarget(nil)
    end
    print(brain.name .. " ahora es pacifico")
end
```

---

## CONTROL DE UPDATES

### Desactivar updates de NPCs (pausar IA)
```lua
SentientNPC.Update.Disable()
print("Updates desactivados")
```

### Activar updates de NPCs
```lua
SentientNPC.Update.Enable()
print("Updates activados")
```

### Activar modo debug verbose
```lua
SentientNPC.Config.DEBUG = true
SentientNPC.Config.DEBUG_VERBOSE = true
print("Debug verbose activado")
```

### Desactivar debug
```lua
SentientNPC.Config.DEBUG = false
SentientNPC.Config.DEBUG_VERBOSE = false
print("Debug desactivado")
```

---

## TESTS ESPECIFICOS

### Test: Spawn y verificar posesion
```lua
local p = getPlayer()
local success, npcId = SentientNPC.Possession.SpawnNPC(p:getX()+3, p:getY()+3, p:getZ(), {
    name = "TestPosesion",
    program = "Idle"
})
if success then
    print("OK - NPC creado con ID: " .. npcId)
    local brain = SentientNPC.Brain.Get(npcId)
    if brain then
        print("OK - Brain encontrado: " .. brain.name)
    else
        print("ERROR - Brain no encontrado")
    end
else
    print("ERROR - Spawn fallo: " .. tostring(npcId))
end
```

### Test: Verificar que NPC no ataca
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+2, p:getY()+2, p:getZ(), {
    name = "TestNoAtaque",
    program = "Idle"
})
print("NPC spawneado cerca - NO deberia atacarte")
print("Camina hacia el y verifica que no muerde")
```

### Test: Patrol con waypoints
```lua
local p = getPlayer()
local success, npcId = SentientNPC.Possession.SpawnNPC(p:getX()+5, p:getY()+5, p:getZ(), {
    name = "TestPatrol",
    program = "Patrol"
})
if success then
    print("NPC Patrol creado - Observa si se mueve entre waypoints")
    print("Deberia moverse en un patron alrededor de donde spawneo")
end
```

### Test: Guard detecta jugador
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+10, p:getY()+10, p:getZ(), {
    name = "TestGuard",
    program = "Guard"
})
print("Guard spawneado a 10 tiles")
print("Acercate y deberia girarse hacia ti")
```

### Test: Follow funciona
```lua
local p = getPlayer()
SentientNPC.Possession.SpawnNPC(p:getX()+3, p:getY()+3, p:getZ(), {
    name = "TestFollow",
    program = "Follow",
    master = p:getUsername()
})
print("Companion spawneado - Alejate y deberia seguirte")
```

---

## OUTFITS DISPONIBLES (ejemplos)

```
Naked, Civilian, Police, Fireman, Ranger,
ArmyTrack, Army, Farmer, Doctor, Nurse,
ConstructionWorker, Mechanic, Bandit
```

Usa con:
```lua
outfit = "Police"
```

---

## NOTAS IMPORTANTES

1. **Siempre limpia antes de probar** - Usa los comandos de limpieza si hay muchos NPCs
2. **Spawn de a uno** - Prueba con 1 NPC a la vez hasta confirmar que funciona
3. **Revisa la consola** - Los mensajes `[SentientNPC]` dan info util
4. **Guarda antes de probar** - Por si algo sale mal

---

## TROUBLESHOOTING

### NPC no se mueve
```lua
-- Verificar que el programa esta corriendo
local brains = SentientNPC.Brain.GetAll()
for id, brain in pairs(brains) do
    print(brain.name .. " - " .. brain.program.name .. " - " .. brain.program.stage)
    print("Tasks pendientes: " .. #brain.tasks)
end
```

### NPC sigue atacando
```lua
-- Forzar reset de target
local zombies = SentientNPC.Possession.GetAllPossessed()
for _, zombie in ipairs(zombies) do
    zombie:setTarget(nil)
    zombie:setNoTeeth(true)
end
print("Targets reseteados")
```

### Errores en consola
```lua
-- Activar debug para mas info
SentientNPC.Config.DEBUG = true
SentientNPC.Config.DEBUG_VERBOSE = true
```
