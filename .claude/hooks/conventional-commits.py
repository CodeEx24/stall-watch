#!/usr/bin/env python3
"""PreToolUse hook: commit subjects must be Conventional Commits and cite a Jira key.

Required subject shape: `type(scope)?: description (STW-nnn)`, for example
`feat(stall): record every detector run (STW-32)`. The message is read from
`-m` / `--message` arguments (shell-parsed, so apostrophes are fine) or from a
heredoc. Commits whose message cannot be read (editor, -F file) are allowed.
"""
import json
import re
import shlex
import sys

SUBJECT = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\([a-z0-9-]+\))?!?: \S.*\(STW-\d+(, ?STW-\d+)*\)$"
)
EXAMPLE = "feat(stall): record every detector run (STW-32)"


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def commit_subject(command: str):
    heredoc = re.search(r"git commit[^\n]*?<<-?\s*['\"]?(\w+)['\"]?\s*\n(.*?)\n\s*\1", command, re.DOTALL)
    if heredoc:
        return heredoc.group(2).strip().splitlines()[0].strip()
    for part in re.split(r"&&|\|\||;|\n", command):
        try:
            tokens = shlex.split(part, posix=True)
        except ValueError:
            continue
        if len(tokens) < 2 or tokens[0] != "git" or "commit" not in tokens[1:4]:
            continue
        for i, tok in enumerate(tokens):
            if tok in ("-m", "--message") and i + 1 < len(tokens):
                return tokens[i + 1].strip().splitlines()[0].strip()
            if tok.startswith("--message="):
                return tok.split("=", 1)[1].strip().splitlines()[0].strip()
    return None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: invalid hook input: {e}", file=sys.stderr)
        sys.exit(1)

    command = (data.get("tool_input") or {}).get("command", "")
    if data.get("tool_name") != "Bash" or "git" not in command or "commit" not in command:
        sys.exit(0)

    subject = commit_subject(command)
    if subject is None:
        sys.exit(0)
    if not SUBJECT.match(subject):
        deny(
            f"Commit subject must be Conventional Commits ending with the Jira key, e.g. `{EXAMPLE}`. "
            f"Types: feat fix docs style refactor perf test chore ci build revert. Got: {subject!r}"
        )
    sys.exit(0)


if __name__ == "__main__":
    main()
