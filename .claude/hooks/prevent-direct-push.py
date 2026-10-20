#!/usr/bin/env python3
"""PreToolUse hook: block pushes to main/develop and any force or mirror push.

Fails closed: every `git ... push` found anywhere in the command (env-var
prefixes, `git -c k=v`, subshells, `bash -c '...'`) is checked, and any
force/mirror/all flag or any protected-branch name among its arguments denies
the command. GitHub branch protection on `main` is the real control.
"""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _shell import git_invocations  # noqa: E402

PROTECTED = {"main", "develop", "master"}
FORCE_FLAGS = ("--force", "--mirror", "--all", "--prune")


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def current_branch() -> str:
    try:
        return subprocess.check_output(
            ["git", "branch", "--show-current"], stderr=subprocess.DEVNULL, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def is_force(args) -> bool:
    for a in args:
        if a.startswith(FORCE_FLAGS):
            return True
        if re.fullmatch(r"-[a-zA-Z]*f[a-zA-Z]*", a):  # -f, -uf
            return True
        if a.startswith("+") and len(a) > 1:  # +refspec
            return True
    return False


def names_protected(args) -> bool:
    for a in args:
        value = a.split("=", 1)[1] if a.startswith("--") and "=" in a else a
        for part in re.split(r"[:=]", value.lstrip("+")):
            if part.removeprefix("refs/heads/") in PROTECTED:
                return True
    return False


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: invalid hook input: {e}", file=sys.stderr)
        sys.exit(1)

    if data.get("tool_name") != "Bash":
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command") or ""
    if "push" not in command:
        sys.exit(0)

    pushes = list(git_invocations(command, "push"))
    if not pushes:
        sys.exit(0)

    branch = current_branch()
    for args in pushes:
        if is_force(args):
            deny("Force, mirror, --all and --prune pushes are blocked. Push a new commit on a feature branch instead.")
        if names_protected(args):
            deny("Pushing to main/develop is blocked. Push a branch named <type>/stw-<nnn>/<title> and open a PR.")
        if branch in PROTECTED:
            deny(f"You are on '{branch}'. Create a branch <type>/stw-<nnn>/<title> before pushing.")
    sys.exit(0)


if __name__ == "__main__":
    main()
