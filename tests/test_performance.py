"""Run focused LuaJIT scheduling/retention checks without requiring Lupa.

Set LUAJIT to a LuaJIT 2.1 executable, or put luajit on PATH.
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    runtime = os.environ.get('LUAJIT') or shutil.which('luajit')
    if not runtime:
        sys.exit('LuaJIT 2.1 is required for developer tests. Set LUAJIT or add luajit to PATH.')
    raise SystemExit(subprocess.run([runtime, str(root / 'tests/test_performance.lua'), str(root)], check=False).returncode)
