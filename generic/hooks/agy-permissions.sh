#!/bin/bash

if ! command -v jq >/dev/null 2>&1; then
    # Graceful degradation
    echo '{"directive": "ask"}'
    exit 0
fi

input=$(cat)

tool=$(echo "$input" | jq -r '.toolCall.name // empty')
cmd=$(echo "$input" | jq -r '.toolCall.arguments.CommandLine // empty')

if [ "$tool" != "run_command" ]; then
    # Allowlist all other tools since they aren't raw bash execution
    echo '{"directive": "allow"}'
    exit 0
fi

# Deny list first (most specific overrides)
if [[ "$cmd" == "git clean -f"* ]] || \
   [[ "$cmd" == "git clean -fd"* ]] || \
   [[ "$cmd" == "git push --force"* ]] || \
   [[ "$cmd" == "git push -f"* ]] || \
   [[ "$cmd" == "git branch -D"* ]] || \
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
    echo '{"directive": "deny"}'
    exit 0
fi

# Ask list (specific overrides)
if [[ "$cmd" == "git push"* ]] || \
   [[ "$cmd" == "sed -i"* ]] || \
   [[ "$cmd" == "sed --in-place"* ]] || \
   [[ "$cmd" == "awk -i"* ]] || \
   [[ "$cmd" == "awk --in-place"* ]] || \
   [[ "$cmd" == "git worktree remove"* ]]; then
    echo '{"directive": "ask"}'
    exit 0
fi

# Allow list (broad prefixes based on settings.json)
if [[ "$cmd" == "pnpm "* ]] || [[ "$cmd" == "pnpm" ]] || \
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
   [[ "$cmd" == "mkdir "* ]] || [[ "$cmd" == "mkdir" ]] || \
   [[ "$cmd" == "touch "* ]] || [[ "$cmd" == "touch" ]] || \
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
    echo '{"directive": "allow"}'
    exit 0
fi

# Fallback for unrecognized bash commands
echo '{"directive": "ask"}'
