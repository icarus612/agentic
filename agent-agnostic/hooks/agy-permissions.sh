#!/bin/bash

if ! command -v jq >/dev/null 2>&1; then
    # Graceful degradation
    echo '{"decision": "ask"}'
    exit 0
fi

input=$(cat)

tool=$(echo "$input" | jq -r '.tool_name // .toolCall.name // empty')
cmd=$(echo "$input" | jq -r '.tool_arguments.CommandLine // .toolCall.arguments.CommandLine // empty')
cwd=$(echo "$input" | jq -r '.tool_arguments.Cwd // .toolCall.arguments.Cwd // empty')

if [ "$tool" != "default_api:run_command" ]; then
    # Allowlist all other tools since they aren't raw bash execution
    echo '{"decision": "allow"}'
    exit 0
fi

# Deny list first (most specific overrides)
if [[ "$cmd" == "git clean -f"* ]] || \
   [[ "$cmd" == "git clean -fd"* ]] || \
   [[ "$cmd" == "git push --force"* ]] || \
   [[ "$cmd" == "git push -f"* ]] || \
   [[ "$cmd" == "git branch --delete --force"* ]] || \
   [[ "$cmd" == "git config"* ]] || \
   [[ "$cmd" == "git remote"* ]] || \
   [[ "$cmd" == "git tag -d"* ]] || \
   [[ "$cmd" == "git tag --delete"* ]] || \
   [[ "$cmd" == "git rebase --abort"* ]] || \
   [[ "$cmd" == "git reflog expire"* ]] || \
   [[ "$cmd" == "git gc --prune"* ]] || \
   [[ "$cmd" == "git filter-branch"* ]] || \
   [[ "$cmd" == "git push origin --delete"* ]] || \
   [[ "$cmd" == "git reset --mixed HEAD~"* ]] || \
   [[ "$cmd" == "git reset --soft HEAD~"* ]] || \
   [[ "$cmd" == "git submodule deinit"* ]] || \
   [[ "$cmd" == "git rm --cached"* ]] || \
   [[ "$cmd" == "git update-ref -d"* ]]; then
    echo '{"decision": "deny"}'
    exit 0
fi

# Mutation Commands
if [[ "$cmd" == "rm "* ]] || [[ "$cmd" == "rm" ]] || \
   [[ "$cmd" == "mv "* ]] || [[ "$cmd" == "mv" ]] || \
   [[ "$cmd" == "cp "* ]] || [[ "$cmd" == "cp" ]] || \
   [[ "$cmd" == "mkdir "* ]] || [[ "$cmd" == "mkdir" ]] || \
   [[ "$cmd" == "touch "* ]] || [[ "$cmd" == "touch" ]]; then
    if [[ "$cwd" == "$HOME/repos/"*/.worktrees/* ]] || [[ "$cwd" == "$HOME/repos/"*/.workflows/* ]]; then
        if [[ "$cmd" != *" /"* ]] && [[ "$cmd" != *"~/"* ]] && [[ "$cmd" != *"../"* ]]; then
            echo '{"decision": "allow"}'
            exit 0
        fi
    fi
fi

# Ask list (specific overrides)
# `git branch -D` ASKS, it is not denied: `push-policy` makes SQUASH the universal
# integration route, and a squash merge leaves no merge ancestry, so `git branch -d`
# refuses EVERY landed branch however completely its content merged. Denying `-D` too
# left no way to delete a landed branch at all. The prompt is the safety check. Only
# the long form `git branch --delete --force` stays on the deny list, and force-PUSH
# remains denied in every form.
if [[ "$cmd" == "git push"* ]] || \
   [[ "$cmd" == "sed -i"* ]] || \
   [[ "$cmd" == "sed --in-place"* ]] || \
   [[ "$cmd" == "awk -i"* ]] || \
   [[ "$cmd" == "awk --in-place"* ]] || \
   [[ "$cmd" == "git worktree remove"* ]] || \
   [[ "$cmd" == "git branch -D"* ]]; then
    echo '{"decision": "ask"}'
    exit 0
fi

# Allow list (broad prefixes based on settings.json)
if [[ "$cmd" == "$HOME/.gemini/config/hooks/"* ]] || \
   [[ "$cmd" == "~/.gemini/config/hooks/"* ]] || \
   [[ "$cmd" == "locate "* ]] || [[ "$cmd" == "locate" ]] || \
   [[ "$cmd" == "fd "* ]] || [[ "$cmd" == "fd" ]] || \
   [[ "$cmd" == "xargs "* ]] || [[ "$cmd" == "xargs" ]] || \
   [[ "$cmd" == "less "* ]] || [[ "$cmd" == "less" ]] || \
   [[ "$cmd" == "more "* ]] || [[ "$cmd" == "more" ]] || \
   [[ "$cmd" == "bat "* ]] || [[ "$cmd" == "bat" ]] || \
   [[ "$cmd" == "pnpm "* ]] || [[ "$cmd" == "pnpm" ]] || \
   [[ "$cmd" == "grep "* ]] || [[ "$cmd" == "grep" ]] || \
   [[ "$cmd" == "git "* ]] || [[ "$cmd" == "git" ]] || \
   [[ "$cmd" == "ls "* ]] || [[ "$cmd" == "ls" ]] || \
   [[ "$cmd" == "cat "* ]] || [[ "$cmd" == "cat" ]] || \
   [[ "$cmd" == "find "* ]] || [[ "$cmd" == "find" ]] || \
   [[ "$cmd" == "echo "* ]] || [[ "$cmd" == "echo" ]] || \
   [[ "$cmd" == "head "* ]] || [[ "$cmd" == "head" ]] || \
   [[ "$cmd" == "tail "* ]] || [[ "$cmd" == "tail" ]] || \
   [[ "$cmd" == "wc "* ]] || [[ "$cmd" == "wc" ]] || \
   [[ "$cmd" == "pwd"* ]] || \
   [[ "$cmd" == "which "* ]] || [[ "$cmd" == "which" ]] || \
   [[ "$cmd" == "file "* ]] || [[ "$cmd" == "file" ]] || \
   [[ "$cmd" == "stat "* ]] || [[ "$cmd" == "stat" ]] || \
   [[ "$cmd" == "tree "* ]] || [[ "$cmd" == "tree" ]] || \
   [[ "$cmd" == "du "* ]] || [[ "$cmd" == "du" ]] || \
   [[ "$cmd" == "df "* ]] || [[ "$cmd" == "df" ]] || \
   [[ "$cmd" == "sort "* ]] || [[ "$cmd" == "sort" ]] || \
   [[ "$cmd" == "uniq "* ]] || [[ "$cmd" == "uniq" ]] || \
   [[ "$cmd" == "cut "* ]] || [[ "$cmd" == "cut" ]] || \
   [[ "$cmd" == "diff "* ]] || [[ "$cmd" == "diff" ]] || \
   [[ "$cmd" == "realpath "* ]] || [[ "$cmd" == "realpath" ]] || \
   [[ "$cmd" == "dirname "* ]] || [[ "$cmd" == "dirname" ]] || \
   [[ "$cmd" == "basename "* ]] || [[ "$cmd" == "basename" ]] || \
   [[ "$cmd" == "printenv "* ]] || [[ "$cmd" == "printenv" ]] || \
   [[ "$cmd" == "rg "* ]] || [[ "$cmd" == "rg" ]] || \
   [[ "$cmd" == "sed "* ]] || [[ "$cmd" == "sed" ]] || \
   [[ "$cmd" == "awk "* ]] || [[ "$cmd" == "awk" ]] || \
   [[ "$cmd" == "docker ps"* ]] || \
   [[ "$cmd" == "kubectl get"* ]] || \
   [[ "$cmd" == "go test"* ]] || \
   [[ "$cmd" == "cd "* ]] || [[ "$cmd" == "cd" ]] || \
   [[ "$cmd" == "pushd "* ]] || [[ "$cmd" == "pushd" ]] || \
   [[ "$cmd" == "popd "* ]] || [[ "$cmd" == "popd" ]] || \
   [[ "$cmd" == "jq "* ]] || [[ "$cmd" == "jq" ]] || \
   [[ "$cmd" == "node_modules/.bin/"* ]] || \
   [[ "$cmd" == "gh pr view"* ]] || \
   [[ "$cmd" == "gh pr diff"* ]] || \
   [[ "$cmd" == "gh pr list"* ]] || \
   [[ "$cmd" == "gh pr checks"* ]] || \
   [[ "$cmd" == "gh pr status"* ]] || \
   [[ "$cmd" == "gh issue view"* ]] || \
   [[ "$cmd" == "gh issue list"* ]] || \
   [[ "$cmd" == "gh run view"* ]] || \
   [[ "$cmd" == "gh run list"* ]] || \
   [[ "$cmd" == "gh repo view"* ]] || \
   [[ "$cmd" == "gh search"* ]] || \
   [[ "$cmd" == "gh auth status"* ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Fallback for unrecognized bash commands
echo '{"decision": "ask"}'
