#!/usr/bin/env bash
# Denies shell writes to lane artifacts and subagent lane-bind.sh calls; interpreter one-liners are not inspected.
set -uo pipefail

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

printf '%s' "$payload" | python3 -c '
import json, os, re, shlex, sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
ti = d.get("tool_input")
cmd = ti.get("command") if isinstance(ti, dict) else ""
if not cmd or not isinstance(cmd, str):
    sys.exit(0)
is_subagent = "agent_type" in d

cmd = re.sub(r"(<<-?\s*[\x27\"]?(\w+)[\x27\"]?[^\n]*\n).*?^\s*\2\s*$", r"\1", cmd,
             flags=re.S | re.M)
cmd = cmd.replace("\n", " ; ")

try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    tokens = list(lex)
except Exception:
    tokens = cmd.split()

TARGET = re.compile(r"(^|/)\.artifacts/(contracts/l\d+\.md|reports/l\d+-exit\.md|lanes/.+)$")
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}
REDIRECTS = {">", ">>", ">|", "&>", "&>>", ">&"}
WRAPPERS = {"sudo", "command", "env", "nohup", "exec", "time"}
COPIERS = {"cp", "mv", "install", "ln", "rsync"}

def is_target(tok):
    return bool(TARGET.search(tok))

def write_deny(path):
    sys.stderr.write(
        "lane-artifact-shell-guard: BLOCKED - shell write to lane artifact: " + path + "\n\n"
        "Lane contracts, exit reports and bindings are not written from the shell.\n"
        "Write the contract/exit report with the Write tool at the absolute path you were\n"
        "handed; scope-writes.sh checks it against your lane binding.\n")
    sys.exit(2)

def bind_deny():
    sys.stderr.write(
        "lane-artifact-shell-guard: BLOCKED - lane-bind.sh called from a subagent.\n\n"
        "Only the main session / orchestrator records lane bindings (lane-bind.sh is run\n"
        "by lane-bind-on-launch.sh or by the orchestrator). A builder cannot bind itself.\n")
    sys.exit(2)

segments, current = [], []
for tok in tokens:
    if tok in SEPARATORS:
        segments.append(current)
        current = []
    else:
        current.append(tok)
segments.append(current)

for seg in segments:
    words, i = [], 0
    while i < len(seg):
        tok = seg[i]
        if tok in REDIRECTS:
            if i + 1 < len(seg) and is_target(seg[i + 1]):
                write_deny(seg[i + 1])
            i += 2
            continue
        words.append(tok)
        i += 1
    while words and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]) or words[0] in WRAPPERS):
        words.pop(0)
    if not words:
        continue
    name = os.path.basename(words[0])
    args = words[1:]
    if name in ("bash", "sh") and args:
        script = [a for a in args if not a.startswith("-")]
        if script and os.path.basename(script[0]) == "lane-bind.sh" and is_subagent:
            bind_deny()
    if name == "lane-bind.sh" and is_subagent:
        bind_deny()
    operands = [a for a in args if not a.startswith("-")]
    if name == "tee":
        for a in operands:
            if is_target(a):
                write_deny(a)
    elif name in COPIERS:
        if operands and is_target(operands[-1]):
            write_deny(operands[-1])
    elif name == "sed":
        if any(a == "--in-place" or a.startswith("--in-place=") or re.match(r"^-[A-Za-z]*i", a) for a in args):
            for a in operands:
                if is_target(a):
                    write_deny(a)
    elif name == "perl":
        if any(re.match(r"^-[A-Za-z]*i", a) for a in args):
            for a in operands:
                if is_target(a):
                    write_deny(a)
    elif name == "truncate":
        for a in operands:
            if is_target(a):
                write_deny(a)
    elif name == "dd":
        for a in args:
            if a.startswith("of=") and is_target(a[3:]):
                write_deny(a[3:])
sys.exit(0)
'
rc=$?
[ "$rc" = 2 ] && exit 2
exit 0
