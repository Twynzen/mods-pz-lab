# PLAN DE DESARROLLO - SentientNPC

## Vision del Proyecto

Crear el mod de NPCs mas avanzado para Project Zomboid Build 42, con:
- NPCs que toman decisiones autonomas basadas en contexto
- Sistema de memoria individual persistente
- Comunicacion dinamica y personalidades unicas
- Integracion opcional con modelos de IA local (Ollama)
- Soporte completo para multiplayer

---

## FASE 1: FUNDAMENTOS (Core)

### Objetivo
Establecer la base funcional del mod con posesion de zombies y sincronizacion basica.

### Tareas

#### 1.1 Estructura del Mod
- [ ] Crear `mod.info` con metadata
- [ ] Crear estructura de carpetas Lua
- [ ] Implementar sistema de logging
- [ ] Crear utilidades basicas (`Utils.lua`)

#### 1.2 Sistema de Posesion
- [ ] Implementar `PossessionManager.lua`
  - [ ] `possess(zombie, config)` - Convertir zombie en NPC
  - [ ] `release(zombie)` - Liberar zombie
  - [ ] `isPossessed(zombie)` - Verificar estado
- [ ] Configurar variables del zombie poseido
- [ ] Manejar `OnZombieCreate` para object pooling

#### 1.3 Sistema Brain
- [ ] Implementar `Brain.lua`
  - [ ] Estructura de datos del brain
  - [ ] `Brain.Create(zombie, config)`
  - [ ] `Brain.Get(zombie)`
  - [ ] `Brain.Update(zombie, brain)`
  - [ ] `Brain.Remove(zombie)`
- [ ] Cache de brains por ID

#### 1.4 Loop Principal
- [ ] Implementar `Update.lua` (cliente)
  - [ ] Hook a `OnZombieUpdate`
  - [ ] Filtrar solo zombies poseidos
  - [ ] Rate limiting para updates pesados
- [ ] Implementar `OnZombieDead` para cleanup

#### 1.5 Sincronizacion Multiplayer Basica
- [ ] Implementar `Sync.lua` (servidor)
  - [ ] ModData para estado global
  - [ ] `transmitState()` para broadcast
  - [ ] `receiveState()` para clientes
- [ ] Implementar `Commands.lua`
  - [ ] `OnClientCommand` handler
  - [ ] `OnServerCommand` handler

### Entregable Fase 1
- Poder "poseer" un zombie via comando de consola
- El zombie no ataca y puede ser identificado visualmente
- Estado sincronizado entre clientes en multiplayer

### Criterios de Exito
- [ ] Funciona en singleplayer
- [ ] Funciona en multiplayer (host + 1 cliente)
- [ ] No hay memory leaks despues de 10 minutos
- [ ] Logs claros de debug

---

## FASE 2: COMPORTAMIENTO (Behavior)

### Objetivo
Implementar sistema de programas y acciones para comportamiento autonomo.

### Tareas

#### 2.1 Sistema de Programas
- [ ] Crear estructura `Programs/`
- [ ] Implementar `ProgramManager.lua`
  - [ ] Registro de programas
  - [ ] Cambio de programa/stage
  - [ ] Ejecucion de programa actual
- [ ] Crear programas basicos:
  - [ ] `Idle.lua` - Estar quieto, animaciones idle
  - [ ] `Patrol.lua` - Patrullar area
  - [ ] `Follow.lua` - Seguir objetivo
  - [ ] `Guard.lua` - Defender posicion
  - [ ] `Flee.lua` - Huir de amenazas

#### 2.2 Sistema de Acciones
- [ ] Crear estructura `Actions/`
- [ ] Implementar `ActionManager.lua`
  - [ ] Cola de tareas
  - [ ] Ejecucion secuencial
  - [ ] Estados: start, working, complete
- [ ] Crear acciones basicas:
  - [ ] `Move.lua` - Movimiento con pathfinding
  - [ ] `Wait.lua` - Esperar tiempo
  - [ ] `FaceLocation.lua` - Girar hacia punto
  - [ ] `Animate.lua` - Reproducir animacion

#### 2.3 Sistema de Deteccion
- [ ] Implementar `Detection.lua`
  - [ ] `detectPlayers(npc, radius)` - Jugadores cercanos
  - [ ] `detectZombies(npc, radius)` - Zombies cercanos
  - [ ] `detectNPCs(npc, radius)` - Otros NPCs
  - [ ] `isVisible(npc, target)` - Linea de vision
  - [ ] `canHear(npc, source, volume)` - Deteccion por sonido

#### 2.4 Integracion
- [ ] Conectar programas con Update loop
- [ ] Ejecutar tareas generadas por programas
- [ ] Sincronizar estado de programa en MP

### Entregable Fase 2
- NPCs que patrullan autonomamente
- NPCs que siguen al jugador
- NPCs que huyen de zombies
- Deteccion basica de amenazas

### Criterios de Exito
- [ ] NPC patrulla sin intervenir
- [ ] NPC reacciona a jugador acercandose
- [ ] Comportamiento consistente en MP
- [ ] 10+ NPCs sin lag notable

---

## FASE 3: COMBATE (Combat)

### Objetivo
Implementar sistema de combate para NPCs.

### Tareas

#### 3.1 Sistema de Armas
- [ ] Implementar `Weapons.lua`
  - [ ] Estructura de datos de arma
  - [ ] Equipar armas al NPC
  - [ ] Gestion de municion
  - [ ] Compatibilidad con mods de armas

#### 3.2 Acciones de Combate
- [ ] Crear acciones:
  - [ ] `Shoot.lua` - Disparo a distancia
  - [ ] `Melee.lua` - Ataque cuerpo a cuerpo
  - [ ] `Reload.lua` - Recargar arma
  - [ ] `TakeCover.lua` - Buscar cobertura

#### 3.3 Programa de Combate
- [ ] Implementar `Combat.lua`
  - [ ] Seleccion de objetivo
  - [ ] Calculo de distancia optima
  - [ ] Decision atacar/huir
  - [ ] Coordinacion con otros NPCs

#### 3.4 Sistema de Dano
- [ ] Implementar recepcion de dano
- [ ] Sistema de salud del NPC
- [ ] Efectos de dano (cojear, sangrar)
- [ ] Muerte y loot

### Entregable Fase 3
- NPCs que atacan zombies
- NPCs que se defienden de jugadores hostiles
- Sistema de armas funcional
- NPCs pueden morir y dropear loot

### Criterios de Exito
- [ ] NPC mata zombie con arma
- [ ] NPC usa cobertura basica
- [ ] Dano funciona en MP
- [ ] Loot aparece al morir

---

## FASE 4: INTELIGENCIA ARTIFICIAL (AI)

### Objetivo
Implementar sistema hibrido de IA con soporte para LLM local.

### Tareas

#### 4.1 Sistema de Decision Hibrido
- [ ] Implementar `HybridAI.lua`
  - [ ] Capa 1: Reglas criticas (hardcoded)
  - [ ] Capa 2: Cache de decisiones
  - [ ] Capa 3: Behavior Tree
  - [ ] Capa 4: Query LLM (async)

#### 4.2 Bridge de IA
- [ ] Implementar `AIBridge.lua` (cliente)
  - [ ] Escribir requests a archivo
  - [ ] Leer responses de archivo
  - [ ] Rate limiting
  - [ ] Timeout y fallback
- [ ] Crear `tools/ai_proxy.py`
  - [ ] Watchdog para archivos
  - [ ] Conexion a Ollama
  - [ ] Manejo de errores

#### 4.3 Sistema de Memoria
- [ ] Implementar `Memory.lua`
  - [ ] Estructura de memoria
  - [ ] `addMemory(npc, content, importance)`
  - [ ] `getRelevantMemories(npc, context, limit)`
  - [ ] Scoring por recencia/importancia
  - [ ] Persistencia en save

#### 4.4 Personalidad
- [ ] Implementar `Personality.lua`
  - [ ] Rasgos de personalidad
  - [ ] Modificadores de decision
  - [ ] Generacion aleatoria

### Entregable Fase 4
- NPCs toman decisiones contextuales
- Sistema de memoria funcional
- Integracion opcional con Ollama
- Fallback robusto sin LLM

### Criterios de Exito
- [ ] NPC recuerda interacciones previas
- [ ] Decisiones varian por personalidad
- [ ] Funciona SIN Ollama (fallback)
- [ ] Con Ollama, respuestas en <2s

---

## FASE 5: DIALOGO (Dialogue)

### Objetivo
Implementar sistema de comunicacion y dialogo.

### Tareas

#### 5.1 Sistema de Dialogo
- [ ] Implementar `Dialogue.lua`
  - [ ] Mostrar texto sobre NPC
  - [ ] Sistema de lineas predefinidas
  - [ ] Generacion dinamica (con LLM)
- [ ] Crear `DialogueUI.lua`
  - [ ] Burbuja de dialogo
  - [ ] Opciones de respuesta del jugador

#### 5.2 Comunicacion entre NPCs
- [ ] Implementar `Communication.lua`
  - [ ] Broadcast de alertas
  - [ ] Compartir posicion de amenazas
  - [ ] Coordinacion de grupo

#### 5.3 Interaccion con Jugador
- [ ] Menu contextual de interaccion
- [ ] Opciones: hablar, comerciar, reclutar
- [ ] Sistema de reputacion basico

### Entregable Fase 5
- NPCs dicen lineas de dialogo
- NPCs comunican amenazas entre si
- Jugador puede interactuar basicamente

---

## FASE 6: POLISH (Finalizacion)

### Objetivo
Pulir, optimizar y preparar para release.

### Tareas

#### 6.1 Interfaz de Admin
- [ ] Panel de control de NPCs
- [ ] Spawn de NPCs por tipo
- [ ] Control manual de NPCs
- [ ] Debug visual

#### 6.2 Configuracion
- [ ] Sandbox options completas
- [ ] ModOptions para cliente
- [ ] Presets de dificultad

#### 6.3 Optimizacion
- [ ] Profiling de performance
- [ ] Optimizar Update loop
- [ ] Reducir trafico de red
- [ ] Culling de NPCs lejanos

#### 6.4 Documentacion
- [ ] README completo
- [ ] Guia de instalacion
- [ ] Guia de configuracion
- [ ] API para otros modders

#### 6.5 Testing
- [ ] Test suite basico
- [ ] Testing multiplayer extensivo
- [ ] Compatibilidad con mods populares

### Entregable Fase 6
- Mod listo para Steam Workshop
- Documentacion completa
- Estabilidad comprobada

---

## Cronograma Sugerido

| Fase | Descripcion | Complejidad |
|------|-------------|-------------|
| 1 | Fundamentos | Media |
| 2 | Comportamiento | Alta |
| 3 | Combate | Alta |
| 4 | IA | Muy Alta |
| 5 | Dialogo | Media |
| 6 | Polish | Media |

**Nota**: No se incluyen estimaciones de tiempo porque dependen de disponibilidad. Cada fase debe completarse y testearse antes de pasar a la siguiente.

---

## Dependencias Externas

### Requeridas
- Project Zomboid Build 42 (Multiplayer Unstable)
- Conocimiento de Lua

### Opcionales
- Python 3.8+ (para proxy de IA)
- Ollama (para LLM local)
- ChromaDB (para RAG avanzado)

---

## Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Object pooling de zombies | Alto | Reinicializar en OnZombieCreate |
| Desync en multiplayer | Alto | Testing frecuente, logs extensivos |
| Lag con muchos NPCs | Medio | Rate limiting, culling |
| Ollama no disponible | Bajo | Fallback a Behavior Trees |
| Cambios en API de PZ | Medio | Capa de compatibilidad |

---

## Metricas de Exito del Proyecto

- [ ] 50+ NPCs activos sin lag
- [ ] 0 crashes en sesion de 2 horas
- [ ] Funciona en servidor con 10+ jugadores
- [ ] Decisiones de IA en <500ms (sin LLM)
- [ ] Decisiones de IA en <3s (con LLM)
- [ ] Rating 4+ estrellas en Workshop

---

**Siguiente paso**: Comenzar con Fase 1, tarea 1.1 - Estructura del Mod
