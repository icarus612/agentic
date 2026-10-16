#!/usr/bin/env bash
# Denies shell writes to lane artifacts and subagent lane-bind.sh calls; interpreter one-liners are not inspected.
set -uo pipefail

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

printf '%s' "$payload" | python3 -c '
import json, os, posixpath, re, shlex, sys

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
payload_cwd = d.get("cwd")
vcwd = payload_cwd if isinstance(payload_cwd, str) and payload_cwd else None

cmd = re.sub(r"(<<-?\s*[\x27\"]?(\w+)[\x27\"]?[^\n]*\n).*?^\s*\2\s*$", r"\1", cmd,
             flags=re.S | re.M)
cmd = cmd.replace("\n", " ; ")
cmd = re.sub(r"\$\([^()]*\)|`[^`]*`", "$X", cmd)

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

VAR_TARGET = re.compile(r"/(contracts/l\d+\.md|reports/l\d+-exit\.md|lanes/.+)$")

def is_target(tok):
    if TARGET.search(tok):
        return True
    return bool(re.search(r"[$~]", tok)) and bool(VAR_TARGET.search(tok))

def write_deny(path, resolved=None):
    shown = path if resolved is None else path + " (resolves to " + resolved + ")"
    sys.stderr.write(
        "lane-artifact-shell-guard: BLOCKED - shell write to lane artifact: " + shown + "\n\n"
        "Lane contracts, exit reports and bindings are not written from the shell.\n"
        "Write the contract/exit report with the Write tool at the absolute path you were\n"
        "handed; scope-writes.sh checks it against your lane binding.\n")
    sys.exit(2)

def check(tok):
    if is_target(tok):
        write_deny(tok)
    if vcwd is not None and tok and tok[0] not in "/~$":
        joined = posixpath.normpath(vcwd + "/" + tok)
        if is_target(joined):
            write_deny(tok, joined)

def cd_target(args):
    ops = [a for a in args if a == "-" or not a.startswith("-")]
    if not ops or ops[0] in ("-", "~") or ops[0].startswith("~"):
        return None
    op = ops[0]
    if op.startswith("/"):
        return posixpath.normpath(op)
    if vcwd is None:
        return None
    return posixpath.normpath(vcwd + "/" + op)

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
        segments.append(tok if tok in ("(", ")") else None)
        current = []
    else:
        current.append(tok)
segments.append(current)

cwd_stack = []
for seg in segments:
    if seg is None:
        continue
    if seg == "(":
        cwd_stack.append(vcwd)
        continue
    if seg == ")":
        if cwd_stack:
            vcwd = cwd_stack.pop()
        continue
    words, i = [], 0
    while i < len(seg):
        tok = seg[i]
        if tok in REDIRECTS:
            if i + 1 < len(seg):
                check(seg[i + 1])
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
    if name in ("cd", "pushd"):
        vcwd = cd_target(args)
        continue
    if name == "popd":
        vcwd = None
        continue
    operands = [a for a in args if not a.startswith("-")]
    if name == "tee":
        for a in operands:
            check(a)
    elif name in COPIERS:
        if operands:
            check(operands[-1])
    elif name == "sed":
        if any(a == "--in-place" or a.startswith("--in-place=") or re.match(r"^-[A-Za-z]*i", a) for a in args):
            for a in operands:
                check(a)
    elif name == "perl":
        if any(re.match(r"^-[A-Za-z]*i", a) for a in args):
            for a in operands:
                check(a)
    elif name == "truncate":
        for a in operands:
            check(a)
    elif name == "dd":
        for a in args:
            if a.startswith("of="):
                check(a[3:])
sys.exit(0)
'
rc=$?
[ "$rc" = 2 ] && exit 2
exit 0
