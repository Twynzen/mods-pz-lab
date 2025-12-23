# ServerPZ - Project Zomboid Mods Laboratory

Repositorio dedicado al estudio, análisis y desarrollo de mods para Project Zomboid.

## Propósito

Este repositorio sirve como un laboratorio de aprendizaje y experimentación para entender cómo funcionan los mods de Project Zomboid. Al estudiar y modificar estos mods, podemos:

- Aprender las mejores prácticas de modding para PZ
- Entender la estructura y arquitectura de mods complejos
- Experimentar con nuevas ideas y funcionalidades
- Desarrollar futuros mods de manera modular y organizada

## Estructura del Proyecto

El repositorio está organizado en carpetas separadas, cada una conteniendo un mod o herramienta diferente:

### Mods Principales

#### `/SentientNPC`
Nuestro mod principal en desarrollo. NPCs con comportamiento avanzado e inteligencia artificial.

**Características:**
- Sistema de NPCs con IA
- Comportamientos complejos y adaptativos
- Integración con sistemas del juego

#### `/Bandits`
Mod de sistema de bandidos para Project Zomboid.

**Características:**
- NPCs hostiles con comportamiento de bandido
- Sistema de grupos y patrullas
- Animaciones y assets personalizados

#### `/BanditsCreator`
Herramienta para crear y configurar bandidos personalizados.

**Características:**
- Interfaz de creación de bandidos
- Configuración de comportamientos
- Exportación a formato compatible

### Documentación y Recursos

#### `/PZEventDoc`
Documentación completa de eventos y API de Project Zomboid.

**Contenido:**
- Documentación de eventos del juego
- Referencias de API
- Ejemplos y casos de uso

## Flujo de Trabajo

1. **Estudio**: Analizar mods existentes para entender patrones y técnicas
2. **Experimentación**: Probar modificaciones y nuevas ideas
3. **Desarrollo**: Crear nuevos mods o mejorar existentes
4. **Documentación**: Registrar aprendizajes y hallazgos

## Tecnologías

- **Lua**: Lenguaje principal de scripting de PZ
- **Java**: Para funcionalidades avanzadas
- **Project Zomboid API**: Sistema de eventos y hooks del juego

## Estructura de un Mod de PZ

Cada mod típicamente contiene:
- `/media/lua/` - Scripts en Lua
- `/media/scripts/` - Definiciones de items y objetos
- `/media/textures/` - Texturas y sprites
- `/media/sound/` - Archivos de audio
- `mod.info` - Metadata del mod

## Recursos de Aprendizaje

- [PZ Modding Guide](https://pzwiki.net/wiki/Modding)
- [PZ Lua API](https://projectzomboid.com/modding/)
- Análisis de mods en este repositorio

## Notas de Desarrollo

Este es un espacio de aprendizaje activo. Los mods aquí pueden estar en diferentes estados de desarrollo:
- Experimentales
- En desarrollo activo
- Estables y funcionales
- Archivados para referencia

## Contribuciones

Este repositorio es principalmente educativo y de investigación personal, pero está abierto a ideas y sugerencias.

---

**Nota**: Este repositorio es para propósitos de estudio y desarrollo. Asegúrate de respetar las licencias de los mods originales si compartes o distribuyes modificaciones.
