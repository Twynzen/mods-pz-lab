# Project Zomboid JavaDocs
## Referencia Completa de la API Java - Versión 42.13.0

**Documentación Extraída de:** [ProjectZomboidJavaDocs](https://demiurgequantified.github.io/ProjectZomboidJavaDocs/)

---

## 1. Introducción

Este documento es una referencia técnica completa de la API Java de Project Zomboid versión 42.13.0. La documentación oficial está generada automáticamente desde el código fuente del juego y organizada en paquetes según su funcionalidad.

Esta guía está diseñada para desarrolladores y modders que desean entender la arquitectura interna del juego, crear mods avanzados, o simplemente explorar cómo funciona Project Zomboid bajo el capó.

**Nota importante:** Esta es documentación no oficial (Unofficial PZ JavaDocs) mantenida por la comunidad. Las APIs pueden cambiar entre versiones del juego.

---

## 2. Estructura General de Paquetes

El código de Project Zomboid está organizado bajo el namespace raíz `zombie`. La documentación contiene más de **200 paquetes** organizados jerárquicamente. A continuación se presenta un análisis detallado de cada área funcional.

---

## 3. Sistemas Core (zombie.core)

Los paquetes core contienen la infraestructura fundamental del juego. Son los cimientos sobre los que se construye toda la funcionalidad.

| Paquete | Descripción y Uso |
|---------|-------------------|
| `zombie.core` | Paquete raíz con clases fundamentales del motor del juego |
| `zombie.core.backup` | Sistema de respaldo y guardado de partidas |
| `zombie.core.bucket` | Estructuras de datos tipo bucket para optimización |
| `zombie.core.collision` | Sistema de detección de colisiones |
| `zombie.core.fonts` | Gestión de fuentes tipográficas para la UI |
| `zombie.core.input` | Manejo de entrada (teclado, mouse, gamepad) |
| `zombie.core.logger` | Sistema de logging y depuración |
| `zombie.core.math` | Utilidades matemáticas, vectores, matrices |
| `zombie.core.math.interpolators` | Interpoladores matemáticos |
| `zombie.core.math.interpolators.xml` | Configuración XML de interpoladores |
| `zombie.core.network` | Funcionalidad de red de bajo nivel |
| `zombie.core.opengl` | Bindings y utilidades OpenGL para renderizado |
| `zombie.core.physics` | Motor de física del juego |
| `zombie.core.profiling` | Herramientas de profiling y performance |
| `zombie.core.properties` | Sistema de propiedades configurables |
| `zombie.core.raknet` | Implementación RakNet para networking |
| `zombie.core.random` | Generadores de números aleatorios |
| `zombie.core.rendering` | Sistema de renderizado principal |
| `zombie.core.secure` | Funcionalidades de seguridad |
| `zombie.core.sprite` | Sistema de sprites base |
| `zombie.core.stash` | Sistema de stash/almacenamiento temporal |
| `zombie.core.Styles` | Definición de estilos visuales |
| `zombie.core.textures` | Carga y gestión de texturas |
| `zombie.core.utils` | Utilidades generales del core |
| `zombie.core.VBO` | Vertex Buffer Objects para rendering |
| `zombie.core.znet` | Networking específico del juego |

### 3.1 Sistema de Modelos y Animación

El sistema de modelos skinned es crucial para la representación visual de personajes y zombies:

| Paquete | Funcionalidad |
|---------|---------------|
| `zombie.core.skinnedmodel` | Base del sistema de modelos 3D con skinning |
| `zombie.core.skinnedmodel.advancedanimation` | Sistema de animación avanzada (state machines) |
| `zombie.core.skinnedmodel.advancedanimation.debug` | Debug de animaciones avanzadas |
| `zombie.core.skinnedmodel.advancedanimation.events` | Eventos de animación |
| `zombie.core.skinnedmodel.animation` | Clases base de animación skeletal |
| `zombie.core.skinnedmodel.animation.debug` | Debug de animaciones |
| `zombie.core.skinnedmodel.animation.sharedskele` | Esqueletos compartidos entre modelos |
| `zombie.core.skinnedmodel.model` | Definición de modelos 3D y meshes |
| `zombie.core.skinnedmodel.model.jassimp` | Integración con Assimp para importar modelos |
| `zombie.core.skinnedmodel.population` | Población de modelos en el mundo |
| `zombie.core.skinnedmodel.runtime` | Runtime del sistema de modelos |
| `zombie.core.skinnedmodel.shader` | Shaders específicos para modelos skinned |
| `zombie.core.skinnedmodel.Texture` | Texturas de modelos skinned |
| `zombie.core.skinnedmodel.visual` | Aspecto visual y customización de modelos |

---

## 4. Sistemas de Inteligencia Artificial

La IA de Project Zomboid maneja tanto el comportamiento de zombies como de NPCs supervivientes y animales.

| Paquete | Descripción |
|---------|-------------|
| `zombie.ai` | Paquete raíz de IA |
| `zombie.ai.astar` | Implementación del algoritmo A* para pathfinding |
| `zombie.ai.sadisticAIDirector` | Director de IA que gestiona eventos y dificultad dinámica |
| `zombie.ai.states` | Máquina de estados para comportamiento de IA |
| `zombie.ai.states.animals` | Estados específicos para comportamiento animal |
| `zombie.ai.states.player` | Estados relacionados con IA de NPCs jugables |

---

## 5. Sistema de Personajes (zombie.characters)

Uno de los sistemas más extensos y críticos del juego. Define todo lo relacionado con personajes jugables, NPCs y zombies.

### 5.1 Paquetes Principales de Characters

| Paquete | Función |
|---------|---------|
| `zombie.characters` | Clases base de personajes (IsoGameCharacter, etc.) |
| `zombie.characters.action` | Sistema de acciones (comer, construir, atacar) |
| `zombie.characters.action.conditions` | Condiciones para ejecutar acciones |
| `zombie.characters.animals` | Sistema de animales |
| `zombie.characters.animals.behavior` | Comportamiento de animales |
| `zombie.characters.animals.datas` | Datos de animales |
| `zombie.characters.animals.pathfind` | Pathfinding específico de animales |
| `zombie.characters.AttachedItems` | Items visualmente adjuntos al personaje |
| `zombie.characters.BodyDamage` | Sistema de daño corporal detallado por zona |
| `zombie.characters.CharacterTimedActions` | Acciones con duración temporal (craftear, etc.) |
| `zombie.characters.Moodles` | Sistema de moodles (hambre, sed, pánico, etc.) |
| `zombie.characters.professions` | Definición de profesiones iniciales |
| `zombie.characters.skills` | Sistema de habilidades y progresión |
| `zombie.characters.traits` | Sistema de rasgos de personaje |
| `zombie.characters.WornItems` | Sistema de ropa y equipamiento |

---

## 6. Sistema del Mundo ISO (zombie.iso)

El sistema ISO es el corazón del mundo del juego. Maneja la representación isométrica 2.5D, objetos del mundo, clima, y más.

### 6.1 Paquetes ISO Core

| Paquete | Descripción |
|---------|-------------|
| `zombie.iso` | Clases base del mundo isométrico (IsoCell, IsoWorld) |
| `zombie.iso.areas` | Sistema de áreas del mapa |
| `zombie.iso.areas.isoregion` | Regiones ISO |
| `zombie.iso.areas.isoregion.data` | Datos de regiones |
| `zombie.iso.areas.isoregion.jobs` | Jobs de procesamiento de regiones |
| `zombie.iso.areas.isoregion.metagrid` | Meta-grid de regiones |
| `zombie.iso.areas.isoregion.regions` | Definición de regiones |
| `zombie.iso.enums` | Enumeraciones del sistema ISO |
| `zombie.iso.fboRenderChunk` | Renderizado por chunks con FBO |
| `zombie.iso.objects` | Objetos del mundo (puertas, ventanas, contenedores) |
| `zombie.iso.objects.interfaces` | Interfaces para objetos ISO |
| `zombie.iso.sprite` | Sistema de sprites isométricos |
| `zombie.iso.sprite.shapers` | Shapers de sprites |
| `zombie.iso.SpriteDetails` | Detalles de sprites |
| `zombie.iso.zones` | Definición de zonas especiales |

### 6.2 Sistema de Clima (Weather)

| Paquete | Funcionalidad |
|---------|---------------|
| `zombie.iso.weather` | Sistema de clima principal |
| `zombie.iso.weather.dbg` | Debug del clima |
| `zombie.iso.weather.fog` | Sistema de niebla atmosférica |
| `zombie.iso.weather.fx` | Efectos visuales del clima (lluvia, nieve) |

### 6.3 Generación del Mundo (WorldGen)

El sistema de generación procedural del mundo es extenso y modular:

| Paquete | Propósito |
|---------|-----------|
| `zombie.iso.worldgen` | Raíz de generación del mundo |
| `zombie.iso.worldgen.attachments` | Attachments del worldgen |
| `zombie.iso.worldgen.biomes` | Definición de biomas |
| `zombie.iso.worldgen.blending` | Blending entre zonas |
| `zombie.iso.worldgen.maps` | Generación de mapas |
| `zombie.iso.worldgen.roads` | Generación de carreteras |
| `zombie.iso.worldgen.rules` | Reglas de generación |
| `zombie.iso.worldgen.utils` | Utilidades del worldgen |
| `zombie.iso.worldgen.utils.probabilities` | Sistema de probabilidades |
| `zombie.iso.worldgen.utils.triangulation` | Triangulación para terreno |
| `zombie.iso.worldgen.veins` | Generación de vetas/recursos |
| `zombie.iso.worldgen.zombie` | Generación de zombies en el mundo |
| `zombie.iso.worldgen.zones` | Zonas del worldgen |

---

## 7. Sistema de Inventario (zombie.inventory)

El sistema de inventario maneja todos los items, recetas de crafteo, y tipos de objetos del juego.

| Paquete | Descripción |
|---------|-------------|
| `zombie.inventory` | Clases base de inventario (ItemContainer, etc.) |
| `zombie.inventory.types` | Tipos específicos de items (armas, comida, ropa) |
| `zombie.inventory.recipemanager` | Gestor de recetas de crafteo |

---

## 8. Sistema de Entidades (zombie.entity)

Sistema ECS (Entity-Component-System) moderno para gestión de entidades del juego.

| Paquete | Componente |
|---------|------------|
| `zombie.entity` | Base del sistema ECS |
| `zombie.entity.components.attributes` | Atributos de entidades |
| `zombie.entity.components.build` | Componentes de construcción |
| `zombie.entity.components.combat` | Componentes de combate |
| `zombie.entity.components.contextmenuconfig` | Configuración de menús contextuales |
| `zombie.entity.components.crafting` | Sistema de crafteo ECS |
| `zombie.entity.components.crafting.recipe` | Recetas del sistema ECS |
| `zombie.entity.components.fluids` | Manejo de fluidos |
| `zombie.entity.components.lua` | Componentes Lua |
| `zombie.entity.components.parts` | Sistema de partes |
| `zombie.entity.components.resources` | Recursos de entidades |
| `zombie.entity.components.script` | Componentes de script |
| `zombie.entity.components.signals` | Sistema de señales |
| `zombie.entity.components.sounds` | Sonidos de entidades |
| `zombie.entity.components.spriteconfig` | Configuración de sprites |
| `zombie.entity.components.test` | Componentes de testing |
| `zombie.entity.components.ui` | Componentes de UI |
| `zombie.entity.debug` | Debug de entidades |
| `zombie.entity.energy` | Sistema de energía |
| `zombie.entity.events` | Eventos de entidades |
| `zombie.entity.meta` | Metadata de entidades |
| `zombie.entity.network` | Networking de entidades |
| `zombie.entity.system` | Systems del patrón ECS |
| `zombie.entity.util` | Utilidades de entidades |
| `zombie.entity.util.assoc` | Asociaciones |
| `zombie.entity.util.enums` | Enums de entidades |
| `zombie.entity.util.reflect` | Reflection utilities |

---

## 9. Sistema de Red (zombie.network)

El sistema de networking es fundamental para el multijugador de Project Zomboid.

| Paquete | Función |
|---------|---------|
| `zombie.network` | Core de networking |
| `zombie.network.anticheats` | Sistema anti-cheat |
| `zombie.network.characters` | Sincronización de personajes |
| `zombie.network.chat` | Sistema de chat en red |
| `zombie.network.constants` | Constantes de red |
| `zombie.network.fields` | Campos serializables |
| `zombie.network.fields.character` | Campos de personaje |
| `zombie.network.fields.hit` | Campos de impacto |
| `zombie.network.fields.vehicle` | Campos de vehículos |
| `zombie.network.id` | Sistema de IDs de red |
| `zombie.network.packets` | Definición de paquetes de red |
| `zombie.network.packets.actions` | Paquetes de acciones |
| `zombie.network.packets.character` | Paquetes de personaje |
| `zombie.network.packets.connection` | Paquetes de conexión |
| `zombie.network.packets.hit` | Paquetes de impacto |
| `zombie.network.packets.safehouse` | Paquetes de safehouse |
| `zombie.network.packets.service` | Paquetes de servicio |
| `zombie.network.packets.sound` | Paquetes de sonido |
| `zombie.network.packets.vehicle` | Paquetes de vehículos |
| `zombie.network.packets.world` | Paquetes del mundo |
| `zombie.network.server` | Lógica del servidor dedicado |
| `zombie.network.statistics` | Estadísticas de red |
| `zombie.network.statistics.counters` | Contadores |
| `zombie.network.statistics.data` | Datos estadísticos |
| `zombie.network.statistics.tools` | Herramientas de estadísticas |

---

## 10. Sistema de Vehículos (zombie.vehicles)

El paquete `zombie.vehicles` contiene toda la lógica de vehículos del juego: física vehicular, sistema de partes, combustible, daño, y más. Es un sistema complejo que interactúa con múltiples otros sistemas como física, rendering, e inventario.

---

## 11. Sistema de UI (zombie.ui)

Sistema completo de interfaz de usuario del juego:

| Paquete | Descripción |
|---------|-------------|
| `zombie.ui` | Componentes base de UI (paneles, botones) |
| `zombie.ui.ISUIWrapper` | Wrappers para interacción Lua con UI Java |

---

## 12. Sistema de Scripting

Fundamental para la creación de mods, estos paquetes definen cómo funcionan los scripts del juego:

| Paquete | Uso |
|---------|-----|
| `zombie.scripting` | Core del sistema de scripts |
| `zombie.scripting.entity` | Entidades scriptables |
| `zombie.scripting.entity.components.attributes` | Atributos scriptables |
| `zombie.scripting.entity.components.contextmenuconfig` | Config de menús contextuales |
| `zombie.scripting.entity.components.crafting` | Crafteo scriptable |
| `zombie.scripting.entity.components.fluids` | Fluidos scriptables |
| `zombie.scripting.entity.components.lua` | Componentes Lua |
| `zombie.scripting.entity.components.parts` | Partes scriptables |
| `zombie.scripting.entity.components.resources` | Recursos scriptables |
| `zombie.scripting.entity.components.signals` | Señales scriptables |
| `zombie.scripting.entity.components.sound` | Sonidos scriptables |
| `zombie.scripting.entity.components.spriteconfig` | Config de sprites |
| `zombie.scripting.entity.components.test` | Testing |
| `zombie.scripting.entity.components.ui` | UI scriptable |
| `zombie.scripting.itemConfig` | Configuración de items |
| `zombie.scripting.itemConfig.enums` | Enums de items |
| `zombie.scripting.itemConfig.generators` | Generadores de items |
| `zombie.scripting.itemConfig.script` | Scripts de items |
| `zombie.scripting.logic` | Lógica de scripts |
| `zombie.scripting.objects` | Objetos scriptables |
| `zombie.scripting.ui` | UI scripting |
| `zombie.Lua` | Bridge Java-Lua para modding |

---

## 13. Otros Sistemas Importantes

### 13.1 Audio

`zombie.audio` y `zombie.audio.parameters` - Sistema de audio 3D posicional con parámetros dinámicos.

### 13.2 Radio y Media

| Paquete | Función |
|---------|---------|
| `zombie.radio` | Sistema de radio principal |
| `zombie.radio.devices` | Dispositivos de radio |
| `zombie.radio.media` | Medios reproducibles |
| `zombie.radio.script` | Scripts de radio |
| `zombie.radio.scripting` | Sistema de scripting de radio |
| `zombie.radio.StorySounds` | Sonidos narrativos |

### 13.3 Erosión

| Paquete | Función |
|---------|---------|
| `zombie.erosion` | Sistema de erosión principal |
| `zombie.erosion.categories` | Categorías de erosión |
| `zombie.erosion.obj` | Objetos erosionables |
| `zombie.erosion.season` | Erosión estacional |
| `zombie.erosion.utils` | Utilidades de erosión |

Sistema de erosión temporal que hace crecer vegetación, deteriora edificios, y simula el paso del tiempo en el mundo.

### 13.4 Sandbox

`zombie.sandbox` - Configuración de opciones sandbox del juego (dificultad, spawns, loot, etc.).

### 13.5 World Map

| Paquete | Función |
|---------|---------|
| `zombie.worldMap` | Sistema del mapa del mundo |
| `zombie.worldMap.editor` | Editor del mapa |
| `zombie.worldMap.markers` | Marcadores del mapa |
| `zombie.worldMap.network` | Networking del mapa |
| `zombie.worldMap.streets` | Sistema de calles |
| `zombie.worldMap.styles` | Estilos visuales del mapa |
| `zombie.worldMap.symbols` | Símbolos del mapa |

### 13.6 Randomized World

| Paquete | Función |
|---------|---------|
| `zombie.randomizedWorld` | Sistema principal |
| `zombie.randomizedWorld.randomizedBuilding` | Edificios aleatorios |
| `zombie.randomizedWorld.randomizedBuilding.TableStories` | Historias de mesas |
| `zombie.randomizedWorld.randomizedDeadSurvivor` | Supervivientes muertos |
| `zombie.randomizedWorld.randomizedRanch` | Ranchos aleatorios |
| `zombie.randomizedWorld.randomizedVehicleStory` | Historias de vehículos |
| `zombie.randomizedWorld.randomizedZoneStory` | Historias de zonas |

Generación de historias y escenarios aleatorios: edificios saqueados, supervivientes muertos, vehículos abandonados, y más.

### 13.7 Combate

`zombie.combat` - Sistema de combate cuerpo a cuerpo y a distancia.

### 13.8 Pathfinding

| Paquete | Función |
|---------|---------|
| `zombie.pathfind` | Sistema principal de pathfinding |
| `zombie.pathfind.extra` | Funcionalidad extra |
| `zombie.pathfind.highLevel` | Pathfinding de alto nivel |
| `zombie.pathfind.nativeCode` | Código nativo (JNI) |

### 13.9 Debug

| Paquete | Función |
|---------|---------|
| `zombie.debug` | Sistema de debug principal |
| `zombie.debug.debugWindows` | Ventanas de debug |
| `zombie.debug.objects` | Objetos de debug |
| `zombie.debug.options` | Opciones de debug |

### 13.10 Otros Paquetes

| Paquete | Función |
|---------|---------|
| `zombie.asset` | Sistema de assets |
| `zombie.basements` | Sistema de sótanos |
| `zombie.buildingRooms` | Habitaciones de edificios |
| `zombie.characterTextures` | Texturas de personajes |
| `zombie.chat` | Sistema de chat |
| `zombie.chat.defaultChats` | Chats predeterminados |
| `zombie.commands` | Sistema de comandos |
| `zombie.commands.serverCommands` | Comandos de servidor |
| `zombie.config` | Configuración del juego |
| `zombie.creative.creativerects` | Rectángulos creativos |
| `zombie.fileSystem` | Sistema de archivos |
| `zombie.fireFighting` | Sistema de extinción de incendios |
| `zombie.gameStates` | Estados del juego |
| `zombie.gizmo` | Sistema de gizmos (debug visual) |
| `zombie.globalObjects` | Objetos globales |
| `zombie.input` | Sistema de entrada |
| `zombie.interfaces` | Interfaces generales |
| `zombie.meta` | Metadata del juego |
| `zombie.modding` | Sistema de modding |
| `zombie.popman` | Population manager |
| `zombie.popman.animal` | Población de animales |
| `zombie.pot` | Sistema POT (translations) |
| `zombie.profanity` | Filtro de profanidad |
| `zombie.profanity.locales` | Locales de profanidad |
| `zombie.savefile` | Sistema de guardado |
| `zombie.seams` | Sistema de costuras visuales |
| `zombie.seating` | Sistema de asientos |
| `zombie.spnetwork` | Single-player network |
| `zombie.spriteModel` | Modelos de sprites |
| `zombie.statistics` | Estadísticas del juego |
| `zombie.text.templating` | Plantillas de texto |
| `zombie.tileDepth` | Profundidad de tiles |
| `zombie.util` | Utilidades generales |
| `zombie.util.hash` | Funciones hash |
| `zombie.util.io` | I/O utilities |
| `zombie.util.lambda` | Utilidades lambda |
| `zombie.util.list` | Utilidades de listas |
| `zombie.viewCone` | Sistema de cono de visión |
| `zombie.vispoly` | Polígonos de visibilidad |
| `zombie.world` | Sistema del mundo |
| `zombie.world.logger` | Logger del mundo |
| `zombie.world.moddata` | Mod data del mundo |
| `zombie.world.scripts` | Scripts del mundo |

---

## 14. Lista Completa de Paquetes Raíz

- `zombie`
- `zombie.ai`
- `zombie.asset`
- `zombie.audio`
- `zombie.basements`
- `zombie.buildingRooms`
- `zombie.characters`
- `zombie.characterTextures`
- `zombie.chat`
- `zombie.combat`
- `zombie.commands`
- `zombie.config`
- `zombie.core`
- `zombie.creative`
- `zombie.debug`
- `zombie.entity`
- `zombie.erosion`
- `zombie.fileSystem`
- `zombie.fireFighting`
- `zombie.gameStates`
- `zombie.gizmo`
- `zombie.globalObjects`
- `zombie.input`
- `zombie.interfaces`
- `zombie.inventory`
- `zombie.iso`
- `zombie.Lua`
- `zombie.meta`
- `zombie.modding`
- `zombie.network`
- `zombie.pathfind`
- `zombie.popman`
- `zombie.pot`
- `zombie.profanity`
- `zombie.radio`
- `zombie.randomizedWorld`
- `zombie.sandbox`
- `zombie.savefile`
- `zombie.scripting`
- `zombie.seams`
- `zombie.seating`
- `zombie.spnetwork`
- `zombie.spriteModel`
- `zombie.statistics`
- `zombie.text`
- `zombie.tileDepth`
- `zombie.ui`
- `zombie.util`
- `zombie.vehicles`
- `zombie.viewCone`
- `zombie.vispoly`
- `zombie.world`
- `zombie.worldMap`

---

## 15. Recursos Adicionales

- **Documentación Online:** [ProjectZomboidJavaDocs](https://demiurgequantified.github.io/ProjectZomboidJavaDocs/)
- **Índice de Clases:** Disponible en la sección Index de la documentación web
- **Árbol de Herencia:** Sección Tree muestra la jerarquía completa de clases
- **APIs Deprecadas:** Sección Deprecated lista métodos y clases obsoletas
- **Búsqueda:** La documentación incluye búsqueda por nombre de clase/método

---

*Documento generado automáticamente*  
*Project Zomboid JavaDocs v42.13.0 - Unofficial Documentation*