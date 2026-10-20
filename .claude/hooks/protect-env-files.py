#!/usr/bin/env python3
"""PreToolUse hook (Write|Edit|MultiEdit): never let Claude write real env files.

`.env`, `.env.local`, `.env.production`, `.env.*.local` hold real values and are
the person's to edit. Committed templates (`.env.example`, `.env.sample`,
`.env.template`) are allowed.
"""
import json
import os
import re
import sys

TEMPLATES = {".env.example", ".env.sample", ".env.template"}

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"Error: invalid hook input: {e}", file=sys.stderr)
    sys.exit(1)

path = (data.get("tool_input") or {}).get("file_path") or ""
name = os.path.basename(path.replace("\\", "/")).lower()
if re.fullmatch(r"\.env(\..+)?", name) and name not in TEMPLATES:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"Writing {name} is blocked: real env files are edited by the person only. Templates like .env.example are allowed.",
        }
    }))
sys.exit(0)
