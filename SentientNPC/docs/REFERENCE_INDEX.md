# Indice de Documentacion de Referencia

## Documentos Principales

Este proyecto cuenta con documentacion exhaustiva ubicada en el directorio padre (`serverpz/`).

### 1. Arquitectura de Mod de NPCs (Bandits)
**Archivo**: `../DOCUMENTACION_BANDITS_B42_MASTER.md`

Contenido:
- Sistema Brain completo
- Sistema de Programas (ZombiePrograms)
- Sistema de Acciones (ZombieActions)
- Spawn y servidor
- Clanes y customizacion
- Sistema de armas
- Compatibilidad B41/B42
- Ciclo de vida del NPC

**Usar cuando**: Necesites entender como implementar un sistema de NPCs probado.

---

### 2. Eventos de Project Zomboid
**Archivo**: `../DOCUMENTACION_PZEVENTDOC_REFERENCIA.md`

Contenido:
- OnZombieUpdate, OnZombieCreate, OnZombieDead
- Eventos de tiempo (EveryMinute, EveryTenMinutes, etc)
- Comunicacion cliente-servidor
- Eventos de combate
- Eventos de personajes
- Hooks importantes

**Usar cuando**: Necesites saber que eventos existen y como usarlos.

---

### 3. API Java de Project Zomboid
**Archivo**: `../JavaDocs.md`

Contenido:
- Paquetes de IA (zombie.ai)
- Paquetes de personajes (zombie.characters)
- Paquetes de red (zombie.network)
- Paquetes de pathfinding (zombie.pathfind)
- Sistema ECS (zombie.entity)

**Usar cuando**: Necesites saber que clases Java estan disponibles desde Lua.

---

### 4. Guia de Implementacion Completa
**Archivo**: `../guidemasternpcposesionmod.md`

Contenido:
- API Lua de IsoZombie
- Sistema de sincronizacion MP
- HTTP Requests y comunicacion externa
- API de Ollama
- Sistema RAG para memoria
- Sistema hibrido de comportamiento
- Codigo funcional de ejemplo:
  - PossessionManager.lua
  - AIBridge.lua
  - ai_proxy.py

**Usar cuando**: Necesites codigo de ejemplo funcional o la guia de implementacion.

---

## Documentos Internos del Proyecto

### CLAUDE.md
Guia de desarrollo con reglas, patrones y errores comunes.

### DEVELOPMENT_PLAN.md
Plan de desarrollo por fases con tareas y criterios de exito.

### docs/ARCHITECTURE.md
Arquitectura detallada del proyecto con diagramas.

---

## Enlaces Externos Utiles

### Documentacion Oficial
- PZwiki Modding: https://pzwiki.net/wiki/Modding
- JavaDocs B42: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/
- LuaDocs B42: https://demiurgequantified.github.io/ProjectZomboidLuaDocs/

### Repositorios de Referencia
- PZEventDoc: https://github.com/demiurgeQuantified/PZEventDoc
- Bandits Mod: Steam Workshop ID 3268487204
- FWolfe Modding Guide: https://github.com/FWolfe/Zomboid-Modding-Guide

### Herramientas de IA
- Ollama: https://ollama.ai
- ChromaDB: https://www.trychroma.com
- FastEmbed: https://github.com/qdrant/fastembed

---

## Orden de Lectura Recomendado

1. **CLAUDE.md** - Entender el proyecto
2. **DEVELOPMENT_PLAN.md** - Ver las fases
3. **docs/ARCHITECTURE.md** - Arquitectura tecnica
4. **guidemasternpcposesionmod.md** - Codigo de ejemplo
5. **DOCUMENTACION_BANDITS_B42_MASTER.md** - Referencia de arquitectura probada
6. **DOCUMENTACION_PZEVENTDOC_REFERENCIA.md** - Eventos disponibles
7. **JavaDocs.md** - API Java (consulta)
