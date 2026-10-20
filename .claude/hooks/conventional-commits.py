#!/usr/bin/env python3
"""PreToolUse hook: commit subjects must be Conventional Commits and cite a Jira key.

Required subject shape: `type(scope)?: description (STW-nnn)`, for example
`feat(stall): record every detector run (STW-32)`. The message is read from
`-m` / `-am` / `-m"..."` / `--message` (shell-parsed, so apostrophes, `;` and
newlines inside the message are fine) or from a heredoc. Commits whose message
cannot be read (editor, `-F file`) are allowed.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _shell import git_invocations  # noqa: E402

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


def first_line(text: str) -> str:
    lines = text.strip().splitlines()
    return lines[0].strip() if lines else ""


def is_heredoc_substitution(value: str) -> bool:
    """`-m "$(cat <<'EOF' ...)"` — the subject is read by the heredoc check instead."""
    return value.lstrip().startswith("$(") and "<<" in value


def message_from_args(args):
    for i, a in enumerate(args):
        if a in ("-m", "--message") and i + 1 < len(args) and is_heredoc_substitution(args[i + 1]):
            return None
        if a == "--message" or re.fullmatch(r"-[a-zA-Z]*m", a):  # -m, -am, -qm
            if i + 1 < len(args):
                return first_line(args[i + 1])
        if a.startswith("--message="):
            return first_line(a.split("=", 1)[1])
        if re.fullmatch(r"-[a-zA-Z]*m.+", a) and not a.startswith("--"):  # -m"msg"
            return first_line(a.split("m", 1)[1])
    return None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: invalid hook input: {e}", file=sys.stderr)
        sys.exit(1)

    if data.get("tool_name") != "Bash":
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command") or ""
    if "commit" not in command:
        sys.exit(0)

    heredoc = re.search(r"git[^\n]*\bcommit[^\n]*?<<-?\s*['\"]?(\w+)['\"]?\s*\n(.*?)\n\s*\1", command, re.DOTALL)
    subjects = [first_line(heredoc.group(2))] if heredoc else []
    for args in git_invocations(command, "commit"):
        msg = message_from_args(args)
        if msg is not None:
            subjects.append(msg)

    for subject in subjects:
        if not SUBJECT.match(subject):
            deny(
                f"Commit subject must be Conventional Commits ending with the Jira key, e.g. `{EXAMPLE}`. "
                f"Types: feat fix docs style refactor perf test chore ci build revert. Got: {subject!r}"
            )
    sys.exit(0)


if __name__ == "__main__":
    main()
