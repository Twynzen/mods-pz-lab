#!/usr/bin/env python3
"""
SentientNPC AI Proxy

Bridge between Project Zomboid mod and Ollama LLM.
Uses file-based IPC for communication.

Usage:
    python ai_proxy.py [--watch-dir PATH] [--ollama-url URL] [--model MODEL]

Requirements:
    pip install requests watchdog
"""

import json
import time
import os
import argparse
from pathlib import Path
from typing import Optional, Dict, Any

try:
    import requests
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install requests watchdog")
    exit(1)


class AIProxyHandler(FileSystemEventHandler):
    """Handles file system events for AI request processing."""

    def __init__(self, watch_dir: Path, ollama_url: str, model: str):
        self.watch_dir = watch_dir
        self.ollama_url = ollama_url
        self.model = model
        self.processed_files = set()

    def on_created(self, event):
        """Handle new file creation."""
        if event.is_directory:
            return

        filepath = Path(event.src_path)

        # Only process request files
        if not filepath.name.endswith("_request.json"):
            return

        # Avoid processing same file twice
        if filepath.name in self.processed_files:
            return

        self.processed_files.add(filepath.name)
        self.process_request(filepath)

    def process_request(self, filepath: Path):
        """Process an AI request file."""
        print(f"[AI Proxy] Processing: {filepath.name}")

        try:
            # Read request
            with open(filepath, 'r') as f:
                request = json.load(f)

            npc_id = request.get("npc_id", "unknown")
            context = request.get("context", "")
            memories = request.get("memories", [])
            personality = request.get("personality", {})

            # Build prompt
            prompt = self.build_prompt(npc_id, context, memories, personality)

            # Query Ollama
            decision = self.query_ollama(prompt)

            # Write response
            response_path = self.watch_dir / f"{npc_id}_response.json"
            with open(response_path, 'w') as f:
                json.dump({
                    "npc_id": npc_id,
                    "decision": decision,
                    "timestamp": time.time()
                }, f)

            print(f"[AI Proxy] Response written: {response_path.name}")
            print(f"[AI Proxy] Decision: {decision}")

            # Clean up request file
            try:
                os.unlink(filepath)
            except:
                pass

        except Exception as e:
            print(f"[AI Proxy] Error processing {filepath}: {e}")

        finally:
            # Allow reprocessing after some time
            time.sleep(0.1)
            self.processed_files.discard(filepath.name)

    def build_prompt(self, npc_id: str, context: str, memories: list, personality: dict) -> str:
        """Build the prompt for the LLM."""

        # Format memories
        memories_text = "\n".join(f"- {m}" for m in memories) if memories else "None"

        # Format personality
        personality_text = ", ".join(f"{k}={v:.1f}" for k, v in personality.items()) if personality else "balanced"

        prompt = f"""You are an NPC in a zombie survival game. Make a quick decision based on the situation.

NPC ID: {npc_id}
PERSONALITY: {personality_text}

RELEVANT MEMORIES:
{memories_text}

CURRENT SITUATION:
{context}

AVAILABLE ACTIONS: patrol, attack, flee, trade, dialogue, idle, alert, guard

Respond with ONLY valid JSON in this format:
{{"action": "action_name", "target": "target_or_null", "dialogue": "text_or_null"}}

Your decision:"""

        return prompt

    def query_ollama(self, prompt: str) -> Dict[str, Any]:
        """Query Ollama API."""
        try:
            response = requests.post(
                f"{self.ollama_url}/api/chat",
                json={
                    "model": self.model,
                    "messages": [{"role": "user", "content": prompt}],
                    "stream": False,
                    "format": "json",
                    "options": {
                        "temperature": 0.3,
                        "num_predict": 100,
                        "top_k": 20
                    }
                },
                timeout=5.0
            )

            result = response.json()
            content = result.get("message", {}).get("content", "{}")

            # Parse JSON response
            decision = json.loads(content)

            # Validate required fields
            if "action" not in decision:
                decision["action"] = "idle"

            return decision

        except requests.exceptions.Timeout:
            print("[AI Proxy] Ollama timeout, using fallback")
            return {"action": "idle", "target": None, "dialogue": None}

        except requests.exceptions.ConnectionError:
            print("[AI Proxy] Cannot connect to Ollama")
            return {"action": "idle", "target": None, "dialogue": None}

        except json.JSONDecodeError as e:
            print(f"[AI Proxy] Invalid JSON from LLM: {e}")
            return {"action": "idle", "target": None, "dialogue": None}

        except Exception as e:
            print(f"[AI Proxy] Ollama error: {e}")
            return {"action": "idle", "target": None, "dialogue": None}


def main():
    parser = argparse.ArgumentParser(description="SentientNPC AI Proxy")
    parser.add_argument(
        "--watch-dir",
        type=str,
        default=str(Path.home() / "Zomboid/Lua/SentientNPC_AIBridge"),
        help="Directory to watch for request files"
    )
    parser.add_argument(
        "--ollama-url",
        type=str,
        default="http://localhost:11434",
        help="Ollama API URL"
    )
    parser.add_argument(
        "--model",
        type=str,
        default="llama3.2:3b",
        help="Ollama model to use"
    )

    args = parser.parse_args()

    # Create watch directory
    watch_dir = Path(args.watch_dir)
    watch_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 50)
    print("SentientNPC AI Proxy")
    print("=" * 50)
    print(f"Watch directory: {watch_dir}")
    print(f"Ollama URL: {args.ollama_url}")
    print(f"Model: {args.model}")
    print("=" * 50)

    # Test Ollama connection
    try:
        response = requests.get(f"{args.ollama_url}/api/tags", timeout=2)
        models = response.json().get("models", [])
        print(f"Ollama connected. Available models: {len(models)}")
    except:
        print("WARNING: Cannot connect to Ollama. AI features will use fallback.")

    print()
    print("Listening for requests... (Ctrl+C to stop)")
    print()

    # Setup file watcher
    handler = AIProxyHandler(watch_dir, args.ollama_url, args.model)
    observer = Observer()
    observer.schedule(handler, str(watch_dir), recursive=False)
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[AI Proxy] Shutting down...")
        observer.stop()

    observer.join()
    print("[AI Proxy] Stopped")


if __name__ == "__main__":
    main()
