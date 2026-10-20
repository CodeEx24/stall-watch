#!/usr/bin/env python3
"""PreToolUse hook: block pushes to main/develop and any force push.

Parses each `git push` in a Bash command into arguments instead of matching
substrings, so a branch named `x-fix` or a flag like `--follow-tags` is not
mistaken for a force push, and `HEAD:main` / `+main` / `refs/heads/main` are
recognised as targeting a protected branch.
"""
import json
import re
import shlex
import subprocess
import sys

PROTECTED = {"main", "develop"}


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


def push_invocations(command: str):
    """Yield the argument list after `git push` for each push in the command."""
    for part in re.split(r"&&|\|\||;|\n|\|", command):
        try:
            tokens = shlex.split(part, posix=True)
        except ValueError:
            tokens = part.split()
        # Only a segment that starts with `git` is a git command; prose inside
        # a quoted commit message that mentions "git push" is not.
        if len(tokens) < 2 or tokens[0] != "git":
            continue
        if "push" in tokens[1:4]:  # git push / git -C <dir> push
            j = tokens.index("push", 1)
            yield tokens[j + 1:]


def is_force(args) -> bool:
    for a in args:
        if a.startswith("--force"):  # --force, --force-with-lease, --force-if-includes
            return True
        if re.fullmatch(r"-[a-zA-Z]*f[a-zA-Z]*", a):  # -f, -uf, -fu
            return True
        if a.startswith("+") and len(a) > 1:  # +refspec
            return True
    return False


def targets_protected(args, branch: str) -> bool:
    positional = [a for a in args if not a.startswith("-")]
    refspecs = positional[1:]  # first positional is the remote
    if not refspecs:
        # `git push` / `git push origin` pushes the current branch
        return branch in PROTECTED
    for spec in refspecs:
        dst = spec.lstrip("+").split(":")[-1]
        dst = dst.removeprefix("refs/heads/")
        if dst in PROTECTED or (dst == "HEAD" and branch in PROTECTED):
            return True
    return False


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: invalid hook input: {e}", file=sys.stderr)
        sys.exit(1)

    command = (data.get("tool_input") or {}).get("command", "")
    if data.get("tool_name") != "Bash" or "push" not in command:
        sys.exit(0)

    branch = current_branch()
    for args in push_invocations(command):
        if is_force(args):
            deny("Force push is blocked. Push a new commit instead of rewriting history.")
        if targets_protected(args, branch):
            deny(
                "Direct push to main/develop is blocked. Push a branch named "
                "<type>/stw-<nnn>/<title>, open a PR, and merge it after review "
                f"(current branch: {branch or 'unknown'})."
            )
    sys.exit(0)


if __name__ == "__main__":
    main()
