# SentientNPC

Advanced NPC system with hybrid AI for Project Zomboid Build 42 Multiplayer.

## Features

- **Autonomous NPCs**: NPCs that make their own decisions based on context
- **Individual Memory**: Each NPC remembers past interactions and events
- **Hybrid AI System**: Combines rule-based behaviors with optional LLM integration
- **Full Multiplayer Support**: Synchronized across all clients
- **Modular Architecture**: Easy to extend with new NPC types and behaviors

## Requirements

- Project Zomboid Build 42 (Multiplayer Unstable)
- No other mods required

### Optional (for AI features)
- Python 3.8+
- Ollama (for local LLM)

## Installation

1. Download the mod
2. Extract to your `Zomboid/mods/` folder
3. Enable "SentientNPC" in the mod list

## Quick Start

### Spawning NPCs (Admin)

```lua
-- Via console command (coming soon)
/snpc spawn guard
```

### Interacting with NPCs

Right-click on an NPC to see interaction options:
- Talk
- Trade (if enabled)
- Recruit (if enabled)

## Configuration

### Sandbox Options

| Option | Default | Description |
|--------|---------|-------------|
| MaxNPCs | 20 | Maximum number of NPCs |
| AIEnabled | true | Enable AI decision system |
| AIResponseTime | 3000ms | Max time for AI decisions |

## NPC Types

| Type | Behavior |
|------|----------|
| Guard | Patrols area, defends against threats |
| Merchant | Trades with players |
| Wanderer | Roams the map |
| Survivor | Seeks shelter and resources |

## For Developers

See `CLAUDE.md` for development guidelines and `docs/` for detailed documentation.

### Project Structure

```
SentientNPC/
├── CLAUDE.md           # Development guide
├── docs/               # Documentation
└── 42/                 # Mod files for Build 42
    └── media/lua/
        ├── shared/     # Client + Server code
        ├── client/     # Client-only code
        └── server/     # Server-only code
```

## Credits

- Architecture inspired by Bandits mod
- Built for Project Zomboid by The Indie Stone

## License

MIT License - Feel free to use, modify, and distribute.

## Links

- [Steam Workshop](#) (Coming soon)
- [Discord](#) (Coming soon)
- [Bug Reports](issues)
