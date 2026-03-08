---
name: commit-and-push
description: Commit and push Git changes safely in the current repository. Use when the user asks to commit, push, or both, including cases where only specific files should be included.
---

# Commit And Push

## Overview

Create a clean commit from intended changes and push it to the current branch.

Prioritize atomic commits: each commit should do one self-contained thing.
When a task naturally splits into multiple self-contained steps, commit them separately.

## Workflow

1. Check repository and branch state.
2. Review staged and unstaged changes separately.
3. Decide commit scope:
   - If user asks to commit staged changes, commit only staged changes.
   - If user specifies files, stage only those files.
   - If scope is ambiguous, prefer smaller atomic scope and ask before broad staging.
4. If files are being moved and also edited, split the work:
   - First commit the move/rename by itself.
   - Then commit the content changes separately.
   - This helps Git preserve rename tracking instead of showing delete-and-recreate noise.
   - Do not treat the post-rename commit as a catch-all bucket for every remaining change; after the pure move commit, continue splitting follow-up edits by logical area.
5. Commit with a clear message for one logical change.
6. Push to current upstream branch.
7. Report commit hash, branch, pushed ref, and what scope was committed.

## Splitting Large Refactors

- If a previous combined commit is being reconstructed or split, rebuild it in the smallest independently reviewable groups rather than restoring all remaining paths at once.
- Common follow-up buckets after a rename-only commit are:
  - build / CI / packaging
  - runtime code changes
  - tests / fixtures
  - docs / README / skills
- Before each commit, explicitly check whether any staged paths belong to more than one of those groups. If they do, split again.

## Commands

Check state:

```bash
git status --short
git branch --show-current
git remote -v
```

Review what will be committed:

```bash
git diff
git diff --staged
```

Stage changes:

```bash
git add <file1> <file2>
# or stage all intended files
git add -A
```

Commit:

```bash
git commit -m "<message>"
```

Push:

```bash
git push
```

## Guardrails

- Default to staged-only when user says "commit" and there are staged changes.
- Do not auto-stage unstaged files when user asked for staged-only commit.
- Never stage unrelated files without explicit user approval.
- If there are mixed changes, prefer file-specific `git add` and split them into separate commits when they are independently reviewable.
- If a file move also changes content, do not combine both in one commit unless the user explicitly asks for that tradeoff.
- After a move-only commit, continue enforcing atomicity on the remaining content edits; "everything after the rename" is not a valid commit scope by itself.
- Split unrelated logical changes into separate commits when possible.
- When reconstructing an earlier large commit, restore or stage files in narrow subsets and commit each subset immediately after verification.
- If commit fails due to no staged changes, re-check `git status --short` and report clearly.
- Do not amend or force-push unless user explicitly asks.
