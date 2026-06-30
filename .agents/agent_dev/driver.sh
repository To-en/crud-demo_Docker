#!/bin/bash

# Args: <task_type> <git_dir>
# task_type: hotfix | bugfix | feature | sandbox (default: sandbox)
# git_dir:   target git repo/submodule path (default: . = root)
TASK_TYPE=${1:-"sandbox"}
GIT_DIR=${2:-.}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SANDBOX_BRANCH="codex/${TASK_TYPE}_${TIMESTAMP}"

# Worktree always lands at project root, side-by-side
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH="${REPO_ROOT}/codex-worktrees/${TASK_TYPE}_${TIMESTAMP}"

echo "🚀 [Sandbox Protocol] Initializing..."
echo "   git dir  : ${GIT_DIR}"
echo "   worktree : ${WORKTREE_PATH}"

# Validate target is a git repo
if ! git -C "$GIT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ [$GIT_DIR] is not a git repository"
    exit 1
fi

# Create worktree on a new branch from current HEAD of target
CURRENT_BRANCH=$(git -C "$GIT_DIR" branch --show-current)
echo "🌿 Branching off [${CURRENT_BRANCH}] → [${SANDBOX_BRANCH}]..."
git -C "$GIT_DIR" worktree add "$WORKTREE_PATH" -b "$SANDBOX_BRANCH"

# Carry uncommitted work into worktree without touching main
# 1. tracked changes → stash create (copy only, main stays dirty)
STASH_SHA=$(git -C "$GIT_DIR" stash create)
if [ -n "$STASH_SHA" ]; then
    echo "📦 Carrying tracked changes via stash copy [${STASH_SHA:0:7}]..."
    git -C "$WORKTREE_PATH" stash apply "$STASH_SHA"
fi
# 2. untracked files → cp (stash create skips these)
UNTRACKED=$(git -C "$GIT_DIR" ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo "📋 Carrying untracked files into worktree..."
    echo "$UNTRACKED" | while read -r f; do
        mkdir -p "$WORKTREE_PATH/$(dirname "$f")"
        cp "$GIT_DIR/$f" "$WORKTREE_PATH/$f"
        echo "   + $f"
    done
fi

echo "🤖 Triggering Codex in Full Sandbox Mode..."
echo "----------------------------------------"
echo ">> INSTRUCTION FOR CODEX <<"
echo "You are now in full autonomous execution mode."
echo "Work exclusively inside: [${WORKTREE_PATH}]"
echo "Branch: [${SANDBOX_BRANCH}]"
echo "Task category: [${TASK_TYPE}]"
echo "RULES:"
echo "1. cd into [${WORKTREE_PATH}] before any file edits or git commands."
echo "2. Make atomic commits for each logical change."
echo "3. Commit messages must start with '[Codex Sub-task]' followed by what you did."
echo "4. Do NOT touch any other branches. Do NOT merge or rebase."
echo "5. When done, stop and report final status."
echo "----------------------------------------"
echo "💡 Worktree ready. After review: git worktree remove ${WORKTREE_PATH}"
