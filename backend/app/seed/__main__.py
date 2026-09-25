import asyncio
import sys
import traceback

from app.seed import seed_database

sys.stdout.reconfigure(encoding="utf-8")  # igual que Node, aunque la salida vaya a un archivo o tubería en Windows

try:
    asyncio.run(seed_database())
except Exception:
    print("[Seed Error]", file=sys.stderr)
    traceback.print_exc()
    sys.exit(1)
