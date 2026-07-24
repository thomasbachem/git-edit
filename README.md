# git edit – Easily edit commits via interactive rebase

This Git subcommand script makes it easy to edit, modify, drop, or merge previous commits. It's essentially a more convenient wrapper around `git rebase --interactive`, with automatic stashing/unstashing and integrated merge conflict handling.

## Usage

```
git-edit [-m | --message] <commit>
git-edit [-d | --drop | -s | --squash] <commit>...

MODES:
-e, --edit                      Edit <commit> (default mode)
-M, --reword                    Alter only <commit>'s message — no working-tree touch
-d, --drop                      Delete (drop) one or more <commit>s or ranges
-s, --squash                    Merge (fixup/squash) one or more <commit>s into the oldest one
-s <target>, --squash <target>  Merge (fixup/squash) <commit>s into <target>
                                – also assumed when multiple commits are supplied
-S, --resquash                  Merge contiguous <commit>s — no working-tree touch
--reorder <commit>...           Reorder a contiguous span (args give the new order, oldest-first)
--move=<sha> --after|--before=<sha>  Reposition one commit relative to an anchor (span derived automatically)
--exec -- <cmd>...              Run <cmd> in an isolated temp worktree (parallel-safe)
--undo                          Revert the last completed ref move (refuses if the branch moved since)
--status                        Report the in-flight operation, or the last completed one
--selftest                      Run the built-in end-to-end test suite in a scratch repo
FLAGS:
-m, --message                   Alter <commit> message after applying changes
-C, --dir                       Run in a separate worktree (default: <repo>.git-edit)
-C=<path>, --dir=<path>         Run in the specified worktree path
--allow-pushed                  Override the refusal to rewrite commits that exist on a remote
--text <msg>                    Inline message for -M / -S (skip editor); use - for stdin
-y, --yes                       Auto-confirm safe prompts (drop/squash confirmation)
```

Every run ends with a single status line written as natural prose, anchored by `git-edit: <outcome>` for programmatic dispatch:

```
git-edit: ok — refs/heads/main moved <old-sha> → <new-sha>
git-edit: ok — refs/heads/main unchanged
git-edit: error — exit code <N>
git-edit: conflict — resolve in <worktree> (<files>); then 'git edit --continue' or 'git edit --abort'
```

Agents `grep '^git-edit: (ok|error|conflict)'` to dispatch on outcome; the rest is self-explanatory text that doesn't need brittle key=value parsing. SHAs, paths, and filenames are extractable with simple regex if needed (e.g. `moved [a-f0-9]+ → ([a-f0-9]+)$` for the new HEAD).
*Tip:* Mode and flags can be given in any order.

## Usage Examples

### Editing

Open the given commit for manual editing, keeping its commit message (or add `-m` to also edit the message):
```
git edit 0123456789abcdef0123456789abcdef01234567
```
This will:
1. Stash any current local changes
2. Reset to the chosen commit
3. **Pause so you can make changes**
4. Amend the commit and continue the rebase (pausing if merge conflicts occur so you can resolve them)
5. Restore your stashed changes

### Merging

Merge multiple commits into the oldest one among them, keeping only the target commit's message (or add `-m` to also edit the message):
```
git edit 0123456789abcdef0123456789abcdef01234567 abcdef0123456789abcdef0123456789abcdef01
```
*Note:* You can also use ranges (e.g., `git edit HEAD~3..HEAD`).

This will:
1. Stash any current local changes
2. Determine the oldest of the provided commits, making it the target
3. **Merge the newer commits into it**
4. Continue the rebase (pausing if merge conflicts occur so you can resolve them)
5. Restore your stashed changes

### Rewording a Commit Message Without Touching the Working Tree

If all you want to do is fix a commit message, use `-M` / `--reword`:

```
git edit -M 0123456789abcdef0123456789abcdef01234567
```

This opens your `$EDITOR` on the current message, then rebuilds just the affected commit (and any descendants) using `git commit-tree` + `git update-ref` — no checkout, no stash, no rebase, no temporary worktree. The working tree is physically untouched (file inodes and mtimes preserved); the operation is atomic from your perspective: a single ref update at the end. Safe to run while another tool (e.g., an AI coding assistant) is editing files in your checkout.

### Squashing Commits

Plain `-s` (and implicit squash via multi-commit args) **auto-routes** to the plumbing path whenever the operation is eligible — contiguous range, no merge commits, target = oldest commit. So:

```
git edit HEAD~2..HEAD                       # implicit squash → plumbing
git edit -s HEAD~2..HEAD                    # explicit -s with a range → plumbing
git edit -s HEAD~2 HEAD~1 HEAD              # explicit -s on contiguous list → plumbing
git edit --text="Combined" HEAD~2..HEAD     # plumbing + inline message, no editor
git edit -s --text="Combined" HEAD~2..HEAD  # the same, explicit -s
```

Both contiguous and non-contiguous selections accept `--text="<msg>"` to skip the message editor. Non-contiguous selections fall back to the rebase-based path automatically (still working-tree-safe under auto-isolation in non-TTY contexts).

For explicit squash target (squash *into* a specific commit, not just the oldest in the set), use the **`=` form**:

```
git edit -s=<target> <commits>...           # squash <commits> into <target>
```

The `=` is required to disambiguate from "use this as a commit-to-squash" — plain `-s <target> <commits>` treats the first arg as another commit because `-s` doesn't greedily consume its next argument anymore.

Use `-S` / `--resquash` explicitly when you want a hard *guarantee* that the plumbing path will be used — it errors out loudly if the operation isn't plumbing-eligible, instead of silently falling back to the rebase path. Useful for scripts that want to detect "my assumption was wrong" rather than silently get a heavier operation:

```
git edit -S HEAD~2..HEAD                    # fixup style: keep the oldest's message
git edit -S --text="Combined" HEAD~2..HEAD  # inline message, plumbing only
```

Plumbing-only restrictions (since this path has no conflict resolution):
- The selected commits must be contiguous in history (no gaps).
- The range must not contain merge commits.

### Folding Local Changes Into a Past Commit (`--amend-into`)

The typical agent flow — "edit this file and amend it to commit X" — is supported via `--amend-into`. After staging the files you want folded:

```
# After editing files (e.g., via Claude Code's Edit tool)
git add <files>
git edit --amend-into=<sha>
```

What happens internally:
1. The staged index is snapshotted into a `fixup!` commit **object** (`git write-tree` + `git commit-tree`) — no ref moves, so the branch stays visually untouched and parallel sessions never see an intermediate `fixup!` commit.
2. A unique temp worktree is created at that object and `git rebase --autosquash` runs there, folding the fixup into `<sha>`.
3. The branch ref is atomically CAS-updated from its pre-operation tip to the rebased tip.

Only **staged** changes are folded — unstaged edits in the main working tree are left untouched. Works the same for `<sha> = HEAD` and for older commits. Nothing is consumed until the final CAS lands: on any failure or `--abort`, your staged changes are simply still staged, ready for a retry — there is nothing to roll back. On success, the amended commit's `--stat` is printed so no follow-up `git show` is needed.

#### Automatic target discovery (`--amend-into=auto`)

A fix belongs to whoever wrote the line being fixed, so `auto` resolves the target from the staged **lines** (via `git blame`), not merely the files:

```
git add <files>
git edit --amend-into=auto
```

That distinction is the whole point. Take a file where commit A added one rule and commits B and C later added and refined a second one: editing A's rule makes C the newest commit touching the *file*, but A still owns the *line*. A file-level guess folds into C silently and wrongly; the line-level one names A.

Hunks that only add lines have no old lines to attribute, so they carry no evidence — where a staged change is purely additive (or the paths are new files), resolution falls back to the newest unpushed commit touching those paths.

Resolution is conservative either way, and refuses rather than picking a winner:

- Staged lines last touched by **different** commits → refusal listing `sha (subject)` per candidate.
- Staged lines last touched by a **pushed** commit → refusal (its history lies beyond the rewrite horizon).
- On the fallback path, staged paths pointing at **different** commits → refusal listing `path -> sha (subject)` per path.

A refusal costs nothing: it is the same lookup an explicit invocation would have needed anyway.
- Only new files staged → refusal (no history to infer from).

#### Conflict resolution (`--continue` / `--abort`)

If the autosquash hits a merge conflict (the agent's change overlaps with a later commit that also modifies the same lines), the script doesn't auto-rollback. Instead it pauses, mirroring `git rebase`'s own pause-on-conflict pattern, and prints actionable detail. Every conflict-capable rebase runs with `rerere` enabled, so when a cascade re-conflicts the same hunk — or a retry of the whole operation hits it again — the first resolution replays automatically (learned resolutions live in the repo-wide `rr-cache`):

```
$ git edit --amend-into=<sha>
…
Conflict during autosquash – resolve in worktree, then 'git edit --continue'

Worktree: /var/folders/…/git-edit-amend-into.XXXXXX

Conflicted files:
  - x.txt

Currently failing on:
  fixup 234e7a5 # fixup! add x

Remaining steps (after resolution):
  pick ec00775 # add y
  pick 8b068f4 # modify x

Or abort the operation: git edit --abort
git-edit: conflict — resolve in /var/folders/…/git-edit-amend-into.XXXXXX (x.txt); then 'git edit --continue' or 'git edit --abort'
```

The "Remaining steps" list lets the agent predict cascade likelihood: if any of the remaining picks touch the same files as the agent's amendment, another conflict is likely. The trailer line gives the worktree path and conflicted files inline, so an agent can dispatch on `git-edit: conflict` and act on it without parsing the full output.

The worktree is preserved with the conflict markers in the files. The agent (or human) resolves the conflicts there:

```
# Edit conflicted files in the worktree, then stage them:
git -C <worktree> add <resolved-files>

# Continue (or abort + roll back):
git edit --continue
git edit --abort
```

Conflicts can cascade — resolving one may surface another when the rebase continues. Each `git edit --continue` either succeeds (and emits the `ok` trailer) or stops at the next conflict (and emits a fresh `conflict` trailer). The agent loops until either successful or an `--abort` resets everything.

State (worktree path, branch, target SHA, etc.) is persisted to `.git/git-edit-state` between invocations. Only one operation can be paused at a time; starting a new `--amend-into` while one is in flight errors out clearly.

### Splitting a Commit by Pathspec (`--split`)

When a commit mixed two concerns in **different files**, extract one of them into its own commit:

```
git edit --split=<sha> --text="Extracted: the icons" -- src/svg/
```

The commit becomes two: first the extracted commit (pathspec-matched changes, message from `--text`), then a commit with the original message carrying the rest — both keeping the original author and date, with descendants rebuilt on top. Pure plumbing: no worktree, no rebase, **no conflicts possible** — the trees are composed directly from the original blobs (binary files and mode changes come along natively), and the tip tree is unchanged by construction. The pathspec must match a nonempty, proper subset of the commit's changes; concerns mixed within a single file can't be split this way (that requires hunk-level interaction). Attempting it on a one-file commit prints the manual alternative: `git reset --mixed HEAD^ && git restore <file>`, then edit and commit each region in turn (works cleanly when the commit is `HEAD`; for a deeper one, rewrite it via a rebase first).

### Reordering Commits (`--reorder`)

Pass a contiguous span of commits in the **desired new order** (oldest-first):

```
git edit --reorder <sha-that-should-be-first> <sha-that-should-be-second> ...
```

The rebase runs in an isolated temp worktree with a scripted sequence editor; the branch ref only moves at the end (CAS-guarded on the pre-operation tip). Conflicts pause into the same `--continue` / `--abort` flow as `--amend-into` — and since the branch was never touched, `--abort` has nothing to roll back. On success the tool reports whether the tip tree is byte-identical to before (a clean reorder always is; conflict resolutions may change it) and prints the span in its new order.

Reordering commits that touch abutting lines conflicts on more than one step, and the steps differ in kind — so each pause says which kind it is. An **intermediate** step rebuilds a state that never existed in history (the later feature without the earlier one), so its content has to be authored rather than derived:

```
Step 1/2 rebuilds a state that never existed – author its content rather than deriving it:
  'git apply --3way' cannot work here at all (mid-rebase the paths sit at conflicted stages, not stage 0),
  and reverse-applying the other commit's diff tends to fail once its context has shifted.
```

The **final** step is the opposite: a reorder preserves the tree, so its resolution is fully determined and the pause prints the exact command:

```
Final step – a reorder preserves the tree, so the resolution is exactly the pre-op content:
  git -C <worktree> checkout <pre-op-tip> -- <files>
  git edit --continue
```

### Moving One Commit (`--move`)

The common special case of a reorder — "this commit belongs right after that one" — takes just the two endpoints:

```
git edit --move=<sha> --after=<anchor>     # or --before=<anchor>
```

The minimal contiguous span and its new ordering are derived automatically and executed through `--reorder`'s machinery — the shorthand for what would otherwise be a hand-built full-span `--reorder` call or a `git rebase --onto` chain. Works in both directions (moving a commit earlier or later), both SHAs go through stale-SHA resolution, and a commit already in position is a clean no-op. Typical agent flow: commit at `HEAD`, then slot the commit where it belongs with `--move=HEAD --after=<sha>`.

### Pushed-Commit Guard

Every rewriting mode refuses to touch a commit that already exists on a remote-tracking ref — rewriting pushed history disrupts collaborators, and in shared or public repos it should never happen by accident:

```
$ git edit -M --text="better subject" <pushed-sha>
Commit abc1234 is already pushed (on: origin/main)
  Rewriting pushed history disrupts collaborators – pass --allow-pushed to override.
```

Guarding the oldest commit an operation touches covers the whole rewritten span, since every descendant of an unpushed commit is itself unpushed. `--exec` can't know its targets up front, so it checks the *result* instead: if any remote ref that was an ancestor of the old tip would no longer be one of the new tip, the CAS is refused. Deliberate force-push workflows pass `--allow-pushed`.

### Undo, Status, and the Journal

Every completed operation is attributed in the ref's own reflog (`git reflog` shows `git edit: reword abc1234` entries) and appended to a journal, and every success prints its one-line inverse — so recovery never requires understanding this script:

```
Undo: git edit --undo  (or: git update-ref refs/heads/main <old> <new>)
```

`git edit --undo` reverts the last completed operation, CAS-guarded: it refuses if the branch has moved since, so it can never rewind over newer work. `git edit --status` reports an in-flight (conflict-paused) operation in the same format as the original pause — worktree path, conflicted files, remaining steps — or the last completed operation when idle. Useful for an agent (or a second session) landing mid-operation without the original context.

### Self-Testing (`--selftest`)

```
git edit --selftest
```

Builds a scratch repo (with a bare "remote" for pushed-guard coverage) in a temp dir and exercises every mode through real sub-invocations of the installed script: reword, fold, conflict → abort, conflict → resolve → continue (including cascades), drop, squash, reorder, move, exec, the pushed guards, stale-SHA resolution and refusal, merge-topology handling, undo semantics, and status reporting — ~168 assertions, PASS/FAIL per check, non-zero exit on any failure. Run it after any change to this script; sub-invocations run with stdin redirected so the non-TTY (agent) behaviors are always the ones tested.

### Running Any Raw Git Command Safely (`--exec`)

For the cases that don't fit `-M`/`-S`/`-d`/`-e` — e.g. an AI agent reaching for raw `git rebase -i`, `git commit --amend`, `git reset --hard` — wrap it in `--exec` so it runs in an isolated, per-invocation temporary worktree:

```
git edit --exec -- git rebase -i HEAD~3
git edit --exec -- git commit --amend
git edit --exec -- git reset --hard HEAD~1
```

The temp worktree is created fresh, the command runs there, and the original branch ref is updated atomically (compare-and-swap) iff the command moved HEAD. The temp worktree is removed on exit. Parallel-safe across sessions — two concurrent `--exec` calls each get their own worktree, and at most one wins the CAS on the shared branch ref.

Useful as a CLAUDE.md instruction: *"For any history-rewriting git command, run it via `git edit --exec -- …` so it can't disturb other sessions' working trees."*

### Auto-Isolation in Non-Interactive Contexts

When stdin isn't a TTY (i.e. when run by Claude Code, CI, or any script), `-C` is **enabled automatically** for the modes that would otherwise touch the main working tree (drop, edit, non-eligible squash). This protects parallel sessions from clobbering each other when an agent forgets to add `-C`.

Modes that already don't touch the working tree (`-M`, `-S`, `--exec`, auto-routed `-s` → plumbing) are left alone — they don't need it. A short gray notice prints when auto-isolation kicks in.

Because the rebase then lives in a worktree of its own, a conflict there **pauses** into the same `--continue` / `--abort` flow as `--amend-into` and `--reorder` rather than bailing out: the branch hasn't moved, so the caller can resolve in the printed worktree at its own pace, and `--abort` has nothing to roll back. Only an un-isolated non-TTY run (see the opt-out below) still aborts on conflict — there the rebase would sit in the main checkout, and leaving it paused would strand every other session.

To opt out (e.g., CI scripts that genuinely want to modify the main checkout), set `GIT_EDIT_NO_AUTO_ISOLATE=1` in the environment.

### Stale (Rewritten) SHAs

A SHA noted before an earlier rewrite no longer exists on the branch — a constant hazard for agents, which routinely record a SHA and come back to it a rewrite later. Rather than let a rebase quietly no-op on a commit it can't reach, every commit argument is checked against HEAD's history first.

When exactly one commit carries the **identical diff** (same `git patch-id`), that's proof of the same change rather than a guess, so it's substituted outright and the run proceeds — no retry:

```
Commit ec4fa40 was rewritten – using its current identity 8937ad57e60d (identical diff)
```

This covers the common cases by construction: a commit rebuilt as a descendant of some earlier edit keeps its diff, as do rewords and reorders. Because the test is the diff and not the journal, it also resolves rewrites made by plain `git rebase` outside this tool.

Where the content itself changed — folding into a commit, for instance — the diff no longer matches, and a same-subject commit is only a hint. Those are named but **not** acted on:

```
Commit 282effe (Add b) is not in HEAD's history – it was likely rewritten
  Its counterpart on HEAD is 038fa1ea384a (same subject, changed content) – retry with that.
```

Both matches must be unique; an ambiguous one is never guessed at. A squashed or dropped commit has no successor and is simply refused. Set `GIT_EDIT_NO_RESOLVE=1` to disable resolution entirely and have every unreachable commit refused.

### Merge Commits

History containing merges is handled by class of operation. The plumbing modes (`-M`, `-S`, `--split`, auto-routed `-s`) rebuild descendants with an old→new map, so a merge above the rewrite is reassembled with its parents faithfully substituted — side legs that don't descend from the rewrite are kept byte-identical rather than rebuilt. The rebase-based modes (`--amend-into`, `--reorder`, `-d`, rebase-path `-s`, `-e`) replay their span with plain `git rebase`, which silently drops merge commits — so a span containing a merge is **refused** instead:

```
Span cdab8f6..HEAD contains a merge commit – this rebase-based mode would silently flatten it
  Merge-preserving alternatives: -M / -S / --split (plumbing), or --exec with 'git rebase --rebase-merges ...' deliberately.
```

The guard is span-scoped, not repo-scoped: operating above the merge, or squashing a merge-free range below it (which auto-routes to plumbing), stays legal.

A resolved match that turns out to be **pushed** is named but never acted on — not even under `--allow-pushed`, which consents to rewriting the commit you named rather than one resolved on your behalf. Substituting is only ever a convenience, so where it would compound an inference with a shared-history rewrite, it stands aside and lets you ask for that commit deliberately:

```
Commit 556d220 (Add x) is not in HEAD's history – it was likely rewritten
  Its only match d2943df93dfe is already pushed – name it explicitly to rewrite it.
```

The search covers all of history, not a recent window: every rewrite preserves a commit's **author date**, so filtering on it first cuts the candidates to a handful before any patch id is computed. On a 3000-commit repo that is typically two commits and ~0.04s. The filter can only narrow the field, never widen it — a candidate it drops could only ever have been a false match. Should a single second hold more commits than `RESOLVE_SCAN_MAX` (100) — imported or scripted history — uniqueness can no longer be established from a partial view, and resolution degrades to a suggestion rather than acting on one.

### Coexisting with Concurrent Editors (e.g. AI Agents)

If something is actively modifying your working tree (e.g., an AI coding assistant), running `git edit` directly can clobber its work — the script stashes/unstashes and rewrites HEAD. Pass `-C` to run the rebase in a separate worktree instead:

```
git edit -C 0123456789abcdef0123456789abcdef01234567
```

Without a path, `<repo>.git-edit` is used as a sibling directory and is created on first use (auto-managed worktree). Your main working tree stays untouched; the branch ref is rewritten in the shared `.git`. When the agent is done, run `git reset --hard` in the main checkout to apply the changes.

To use a specific path: `git edit -C=/tmp/my-worktree <commit>` (use the `=` form to disambiguate from a commit ref).

Whenever a worktree is in use (both the auto-managed default and an explicit `-C=<path>`) and your git editor points to a known GUI editor (Sublime Text, VS Code, Cursor, Zed, JetBrains IDEs, etc.), the worktree is **opened automatically** in that editor at each interactive pause ("Now make your changes" / "Merge conflicts"), so you can start editing right away. Press `Space` at the prompt to re-open it (e.g. if you closed the window), `Enter` to continue, or `Escape` to cancel. To disable auto-open and revert to the press-`Space`-to-open behavior, set `GIT_EDIT_NO_AUTO_OPEN=1` in the environment.

The editor is resolved from git's full cascade — `$GIT_EDITOR`, `git config core.editor`, `$VISUAL`, then `$EDITOR` — so a Sublime setup like `git config --global core.editor "subl -n -w"` is detected even when `$VISUAL`/`$EDITOR` are unset. Terminal editors (vim, nano, etc.) are intentionally ignored, since "open a directory" doesn't apply to them.

## Screenshot

![Screenshot](/screenshot.png?raw=true)

## Installation

Make the script available as a Git command by adding its folder to your `PATH`, e.g. by adding this line to `~/.zshrc`:
```
export PATH="$PATH:/your/path/to/git-edit"
```

That single step also enables the manual: `man` derives `<dir>/man` from each `PATH` entry, so the bundled `man/man1/git-edit.1` is found automatically — `git edit --help` and `man git-edit` work with no further setup. (Note that `git edit --help` routes through git's man system; `git edit -h` prints the script's own usage without it.)

## ⚠ Warning: History Rewriting

This script rewrites Git history from the chosen commit onward — changing the SHA-1 of that commit and all later commits.
- Safe if: Commits haven’t been pushed yet, or you’re the only developer
- Risky if: Others have based work on these commits (branches, forks, etc.)
If rewriting history, you’ll need to force-push (`git push --force`), which can disrupt collaborators.