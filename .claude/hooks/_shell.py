"""Shared shell-command parsing for the PreToolUse git hooks.

Hooks are a convenience guard, not a security boundary (GitHub branch
protection is). They are written to fail closed: when in doubt, a command is
treated as the git invocation it might be.
"""
import re
import shlex

SEPARATORS = {";", "&", "&&", "|", "||", "(", ")", "\n", "{", "}"}
# Options that git accepts *before* the subcommand and that take a value.
GLOBAL_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


def tokenize(command: str) -> list[str]:
    """Split like a POSIX shell, keeping ; & | ( ) as separate tokens."""
    lexer = shlex.shlex(command or "", posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        return list(lexer)
    except ValueError:  # unbalanced quotes: fall back to a crude split
        return re.findall(r"[^\s;&|()]+|[;&|()]+", command or "")


def is_git(token: str) -> bool:
    base = re.split(r"[\\/]", token)[-1].lower()
    return base in {"git", "git.exe"}


def git_invocations(command: str, subcommand: str, _depth: int = 0):
    """Yield the argument list after `git [global opts] <subcommand>`.

    Also descends into quoted strings that themselves look like commands
    (`bash -c '...'`, `$(...)`), so a git call cannot hide inside them.
    """
    tokens = tokenize(command)
    for i, tok in enumerate(tokens):
        if _depth < 3 and " " in tok and "git" in tok and subcommand in tok:
            yield from git_invocations(tok, subcommand, _depth + 1)
        if not is_git(tok):
            continue
        j = i + 1
        while j < len(tokens) and tokens[j].startswith("-") and tokens[j] not in SEPARATORS:
            j += 2 if tokens[j] in GLOBAL_OPTS_WITH_VALUE else 1
        if j < len(tokens) and tokens[j] == subcommand:
            k = j + 1
            args = []
            while k < len(tokens) and tokens[k] not in SEPARATORS:
                args.append(tokens[k])
                k += 1
            yield args
