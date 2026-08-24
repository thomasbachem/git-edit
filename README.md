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
--onto=<upstream>               Replant this branch onto <upstream> (fork point derived, even if orphaned)
--skip                          Resume past the paused commit instead of through it (--onto only)
--exec -- <cmd>...              Run <cmd> in an isolated temp worktree (parallel-safe)
--undo                          Revert the last completed ref move (refuses if the branch moved since)
--status                        Report the in-flight operation, or the last completed one
--selftest                      Run the built-in end-to-end test suite in a scratch repo
FLAGS:
-m, --message                   Alter <commit> message after applying changes
-C, --dir                       Run in a separate worktree (default: <repo>.git-edit)
-C=<path>, --dir=<path>         Run in the specified worktree path
--allow-pushed                  Override the refusal to rewrite commits that exist on a remote
--text <msg>                    Inline message for -M / -S / --split / --amend-into (skip editor); use - for stdin
-y, --yes                       Auto-confirm safe prompts (drop/squash confirmation)
-h                              Print this usage (`--help` goes to git's man viewer instead)
```

Every run ends with a single status line written as natural prose, anchored by `git-edit: <outcome>` for programmatic dispatch:

```
git-edit: ok — refs/heads/main moved <old-sha> → <new-sha>
git-edit: ok — refs/heads/main unchanged
git-edit: error — exit code <N>
git-edit: paused — edit|split <sha> in <worktree>; then 'git edit --continue' or 'git edit --abort'
git-edit: conflict — resolve in <worktree> (<files>); then 'git edit --continue' or 'git edit --abort'
```

Output is padded with blank lines for readability only when stdout is a terminal. Piped or captured — every agent invocation — it comes out tight, so even a `| tail -3` carries the trailer and the line naming the commit the run touched — every mode but `--exec`, whose command is yours and has no single target — instead of blank space. That pair is the guarantee — a stat block or a path list grows with the commit, so nothing above them is within reach of a short tail. Color follows the same rule and also honors `NO_COLOR` and `TERM=dumb`, so a captured run greps as plain text rather than as literal text split by escape sequences.

Agents `grep '^git-edit: (ok|error|conflict|paused)'` to dispatch on outcome; the rest is self-explanatory text that doesn't need brittle key=value parsing. SHAs, paths, and filenames are extractable with simple regex if needed (e.g. `moved [a-f0-9]+ → ([a-f0-9]+)$` for the new HEAD).

Every rewrite reports its old→new map the way git does: notes are carried across it (honoring `notes.rewriteRef` and `notes.rewriteMode`, and doing nothing when unset), and a `post-rewrite` hook runs with the same pairs on stdin. This matters because the plumbing modes compose commits with `commit-tree` rather than replaying them, so without it they would orphan anything keyed to a SHA — while `-d` and `--move`, which are rebase-backed, kept it. A squash maps every member onto the commit that absorbed them, and a split maps the original onto the remainder, which keeps its message and full tree.

Reach for `git edit -h` rather than `--help`: git intercepts `--help` for subcommands and hands it to `man`, which without a terminal emits backspace-overstruck text (`N^HNA^HAM^HME^HE`) — several times the size of the usage block and unreadable in a captured run.
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

Without a TTY (an agent, CI), the pause becomes a `paused` trailer naming an isolated worktree checked out **at the commit** — its content clean of any main-checkout WIP, which is exactly what makes in-place edits of an entangled commit tractable. Edit files there, then:

```
git edit --continue                      # amend + replay descendants + CAS-apply
git edit --continue --text "New subject" # the same, also rewording
```

Because the content was authored in the isolated worktree, a successful apply leaves your **main checkout holding the pre-edit file** — and its index holding that as a staged revert. `git edit` names the affected paths and the targeted `git restore --source=HEAD --staged --worktree -- <paths>` rather than a blanket reset, which would take unrelated WIP with it.

The amend stages that worktree wholesale, so a scratch file left there joins the commit — every untracked file it absorbs is **named before the amend**, since one arriving unannounced reads as a tool bug rather than a sweep.

On completion the **net history change** is printed (`git diff --stat` old-tip → new-tip) — the at-a-glance proof that history differs by exactly your edit. The replay source is re-read at `--continue` time, so commits that landed on the branch during authoring are carried along rather than dropped; the branch itself never moves until the final CAS, so `--abort` has nothing to roll back.

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

### Rewording Many Commits at Once

To reword **many** commits in one pass, drop the positional commit and feed `--- <commit>` records on stdin (via `--text -`). Each record is a header naming a commit followed by its new message — exactly the shape `git log` emits, so the flow is dump -> edit -> feed back:

```
git log --format='--- %h%n%B' origin/main..HEAD > msgs.txt   # every unpushed message, batch-shaped
$EDITOR msgs.txt                                             # fix the bodies that need it
git edit -M --text - < msgs.txt                              # a record whose message is unchanged is skipped
```

One walk rebuilds the span once under a single compare-and-swap, where N separate rewords would replay the tail N times and open N ref-move windows. It stays pure plumbing — every tree is reused verbatim, only messages change — and it is all-or-nothing: an unreachable, already-pushed, empty, or duplicated target aborts the whole batch before any object is written. A stale SHA (from a rewrite another session landed meanwhile) resolves to its current identity by patch id, and a header may name its commit any way `git rev-parse` accepts (`:/subject` included). The `--- ` line is a reserved record separator, so a commit whose own message contains a `--- ` line is refused before anything is written (its dump would split mid-body) — reword that one with the single `-M <commit>` form.

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

# Or fold only some of what's staged, leaving the rest staged
git edit --amend-into=<sha> -- src/js/foo.js

# Or fold and reword in one go — `git commit --amend -m` semantics
git edit --amend-into=<sha> --text="Better subject"
```

The pathspec form is worth reaching for whenever the index might hold more than you mean to fold. `--amend-into` snapshots the **whole** index, and in a shared checkout a parallel session can stage into it during the gap between your `git add` and this call — a pathspec makes that impossible to sweep into a past commit, and removes the `git diff --cached` pre-check you'd otherwise run to be sure.

What happens internally:
1. The staged index is snapshotted into a `fixup!` commit **object** (`git write-tree` + `git commit-tree`) — no ref moves, so the branch stays visually untouched and parallel sessions never see an intermediate `fixup!` commit.
2. A unique temp worktree is created at that object and `git rebase --autosquash` runs there, folding the fixup into `<sha>`.
3. The branch ref is atomically CAS-updated from its pre-operation tip to the rebased tip.

With `--text`, the target is reworded in the same run. That step is plumbing and runs *before* the fixup, so the autosquash carries the new message and one CAS applies both — the fold can never land with the reword missing, and no positional lookup is needed to find the amended commit afterwards (a replay can drop a commit that went empty, which would shift it). Because the replayed commits already carry the message, `--text` has to be given up front; passing it to `--continue` is refused rather than ignored.

Only **staged** changes are folded — unstaged edits in the main working tree are left untouched. Works the same for `<sha> = HEAD` and for older commits. Nothing is consumed until the final CAS lands: on any failure or `--abort`, your staged changes are simply still staged, ready for a retry — there is nothing to roll back. On success, the amended commit's `--stat` is printed so no follow-up `git show` is needed.

A conflict on the fold's **final** step resolves itself, exactly as a reorder's does: that step's result is the staged tree, provable before anything is committed, so only earlier steps pause for a human answer — and so does the final one when that resolution would leave its commit empty (its whole change sat on the folded lines), since whether the overlapped change survives is the resolver's call, not the tool's.

The completion summary also verifies what landed. The fold's correct tip is knowable up front — the pre-op tip plus the staged changes — so a tip that falls short of it is called out rather than waved through: a run that would leave history unchanged (every staged hunk already carried by the target, e.g. a staged revert of a later commit's change) is refused with the staged changes intact, a staged hunk that dissolved against a later commit's content lands with a note naming the divergence, and a conflict resolution that left a replayed commit empty gets its drop counted — a clean diffstat and an `ok` trailer would otherwise hide all three.

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

If the autosquash hits a merge conflict (the agent's change overlaps with a later commit that also modifies the same lines), the script doesn't auto-rollback. Instead it pauses, mirroring `git rebase`'s own pause-on-conflict pattern, and prints actionable detail. Every conflict-capable rebase runs with `rerere` enabled — from the step that conflicts through the one that resolves it, so a resolution is recorded even with `rerere.enabled` unset globally. When a cascade re-conflicts the same hunk, or a retry of the whole operation hits it again, the pause still happens, but the file arrives carrying the recorded resolution rather than markers: stage it and `--continue`, no second derivation (learned resolutions live in the repo-wide `rr-cache`):

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

### Splitting a Commit (`--split`)

When a commit mixed two concerns in **different files**, name one of them by pathspec:

```
git edit --split=<sha> --text="Extracted: the icons" -- src/svg/
```

The commit becomes two: first the extracted commit (pathspec-matched changes, message from `--text`), then a commit with the original message carrying the rest — both keeping the original author and date, with descendants rebuilt on top. Pure plumbing: no worktree, no rebase, **no conflicts possible** — the trees are composed directly from the original blobs (binary files and mode changes come along natively), and the tip tree is unchanged by construction. The pathspec must match a nonempty, proper subset of the commit's changes.

When both concerns live in the **same file**, no pathspec can name them apart. Drop it, and the split pauses instead:

```
git edit --split=<sha> --text="Refactor: Rename the compute helpers"
git-edit: paused — split 6953784 in /tmp/git-edit-split.wMtUwy; then 'git edit --continue' or 'git edit --abort'
```

The worktree holds the commit's **own** content. Edit it back to what the first commit should leave behind — undo there whatever belongs in the second — then `git edit --continue` (with `--text` if you didn't pass it up front). Authoring that one intermediate state is the whole description of a hunk-level split, and it's a description a non-interactive caller can give without `git add -p`.

From there it's the pathspec path's plumbing: the authored tree becomes the first commit, the target's own tree the remainder, descendants rebuilt on top, one CAS. The pair still ends at the target's tree, so this can't conflict either — and because it reads the branch at `--continue` time, a commit that landed during the pause is carried rather than dropped. `--continue` refuses rather than committing nonsense when either half would come out empty, when the worktree touches a path the target never did (the remainder would only revert it), or when the target itself was rewritten mid-pause. Both forms insert a new commit beneath the target and leave the target itself above it, keeping its tree, message and identity — so `--text` always names the inserted commit, and the remainder inherits a subject written for the whole change. Reword it afterwards with `git edit -M`.

`--continue` refuses while a staged file still carries `<<<<<<<`/`=======`/`>>>>>>>`, naming the file. That catches the common agent failure: a resolver script dies quietly, a blanket `git add` in the same command stages the markers verbatim, and the rebase would otherwise accept them as the resolution and advance to the next step.

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

### Replanting a Branch onto a Moved Upstream (`--onto`)

When the branch you're on forked from a `main` that has since moved — or been rewritten — `--onto` replays it on the new tip:

```
git edit --onto=main
```

The point of the mode is that it derives the fork point instead of asking for it. `git rebase --onto main <old-base> <branch>` needs `<old-base>` spelled out, and after a rewrite of `main` that commit is orphaned — so the caller has to have tracked the pre-rewrite SHA, or reconstruct it. `--onto` recovers it from `main`'s reflog via `git merge-base --fork-point`.

Where the reflog can't answer — a fresh clone, an expired reflog — it falls back to a plain merge base and **says so**. That fallback is only as good as the graph: if `main` was rewritten in a way that changed content, the last common ancestor sits well below the real fork, and the span then takes in commits `main` already has in a form patch ids no longer match. The notice tells you to check the replay list before continuing, and a conflict there is the signal to abort rather than resolve.

It reports the triage up front — what the upstream gained, and which of your commits it already carries by patch id:

```
$ git edit --onto=main
Replanting cancel (Optimization: Skip weather re-derivation) onto main...
Fork point 1e028e0 Optimization: Skip weather re-derivation was orphaned by a rewrite – recovered from the reflog.
main gained 5 commit(s); replaying 4 from 'cancel' on top:
  a1b2c3d Add cancellation parsing
  …
1 commit(s) are already on main and will be dropped:
  9e518b1 Refactor: Catch MCP selection drift
```

Those duplicates are dropped by the replay, and the count is repeated in the completion summary — a shorter branch that isn't accounted for reads as lost work. If a commit conflicts because the upstream took the same change a *different* way, resolving it would duplicate the change; `git edit --skip` steps over it instead, and the conflict message says so when the patch ids match.

Like `--reorder`, the replay runs in an isolated worktree and the branch ref moves once, at the end, under a CAS. Unlike `--reorder` — which preserves the tree — a replant genuinely changes the branch's content, so the caller's checkout is brought along with it (via `read-tree -u -m`, which keeps uncommitted work and refuses rather than overwriting it). Left stale, every commit the upstream gained would show up there as a local deletion, and the next `git commit -a` would carry it out.

Which is why uncommitted work on a path the replant has to rewrite is refused **up front**, before anything moves — otherwise the branch would land and the checkout would decline to follow it, leaving the ref and the files disagreeing. Dirt on any other path is fine and comes through untouched.

### Running the Project's Own Checks Inside a Pause (`edit.worktreeLink`)

A pause hands you an isolated worktree so the commit can be verified clean of any main-checkout WIP — but that worktree starts without whatever the repo deliberately doesn't track, so `npm test` there fails on a missing `node_modules` rather than on the commit. Name those paths once:

```
git config --add edit.worktreeLink node_modules
```

Every temporary worktree then gets them symlinked in from the checkout (repeatable for more than one path; `GIT_EDIT_WORKTREE_LINK=a:b` does the same ad hoc). Links, not copies — they cost nothing, and a check running against a copy could quietly diverge from what's actually installed.

One wrinkle worth knowing: a `.gitignore` pattern written for a directory (`node_modules/`, with the trailing slash) does **not** match the symlink standing in for it. Such a link would land *untracked* where the directory was ignored, and the amend at `--continue` stages the worktree wholesale — so `git edit` doesn't create it, and says why. Not linking is the whole remedy: an ignored link can never be staged, so nothing has to be cleaned up afterwards and `git edit` never removes a file you might own. Dropping the trailing slash gets you the link.

Link only what is regenerable — never the root of irreplaceable shared data. A symlinked root is followed by anything that walks it: on BSD/macOS, `rm -rf <link>/` with a trailing slash resolves *through* it and deletes the shared tree behind it. For a corpus or fixtures tree, name the specific subdirectory (`data/corpus` rather than `data`) — nested values work, and their parent directories are created in the worktree.

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

`git edit --undo` reverts the last completed operation, CAS-guarded: it refuses if the branch has moved since, so it can never rewind over newer work. `git edit --status` reports an in-flight operation in the same format as the original pause — worktree path, conflicted files, remaining steps, and the `conflict` or `paused` trailer that pause emitted — or the last completed operation when idle. Useful for an agent (or a second session) landing mid-operation without the original context.

### Self-Testing (`--selftest`)

```
git edit --selftest
```

The suite lives in `selftest.zsh` beside the script, sourced only for this mode — it drives `git-edit` as a subprocess rather than calling into it, so what it exercises is the shipped behaviour.

Builds a scratch repo (with a bare "remote" for pushed-guard coverage) in a temp dir and exercises every mode through real sub-invocations of the installed script: reword, fold, conflict → abort, conflict → resolve → continue (including cascades), drop, squash, split, reorder, move, replant, exec, the pushed guards, stale-SHA resolution and refusal, merge-topology handling, undo semantics, and status reporting — several hundred assertions, PASS/FAIL per check, non-zero exit on any failure. It also checks that every flag the parser declares is documented in both the man page and this README, so a new mode can't ship undocumented. Run it after any change to this script; sub-invocations run with stdin redirected so the non-TTY (agent) behaviors are always the ones tested.

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

A reorder's **final** step needs no resolution from you: a reorder preserves the tree, so the conflicted paths take the pre-op tip's blobs, and on the last step that is provable before anything is committed — the staged tree becomes the result, so it must equal the pre-op tree. `git edit` applies it and continues. If the proof fails (an earlier resolution changed content elsewhere, say), it hands back to you untouched rather than applying a resolution it cannot verify. Intermediate steps rebuild a state that never existed and still need authoring.

When a rewrite does change the tip tree, the completion names the affected paths and a targeted `git restore --source=HEAD --staged --worktree -- <paths>` — which also removes paths the rewrite dropped. It deliberately does not prescribe `git reset --hard` or a stash/reset/pop dance: both take unrelated WIP with them, and stashing cycles a checkout parallel sessions share.

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

### Driving It From a Script or Agent

The sections above assume someone reading the output; this is the contract for a caller that doesn't. Three rules, then the loop:

**Dispatch on the trailer, not the exit code.** A pipeline reports its last command's status, but the last stdout line is always the trailer. Under `| tail -3` two lines are guaranteed: the trailer and, above it, the line naming the commit the run touched. Nothing above those holds its position — and that's where a rewrite reports what it did to the *rest* of history (an edit's net history change, a fold's count of commits a resolution left empty, a tip differing from the staged result). A wrapper that forwards only the last line drops exactly those findings, so pass the lines above the trailer through to whatever decides what happens next.

**Judge a pause by its unmerged index entries, never by grepping for markers.** A marker grep conflates three states that need three different responses:

- **No unmerged files at all** — the current step became empty (its changes are already upstream): skip it, nothing to resolve.
- **Unmerged, no markers** — an add/add or modify/delete places one side's file whole (or none at all), with no textual merge to mark. The file reads as finished and is not.
- **Pre-filled by `rerere`** — a recorded resolution replayed into the file, which merely needs staging. Validate it like your own resolution first: a wrong resolution, recorded once, replays wrong every time after, and nothing flags it.

**Validate before staging.** "No markers left" is not validation — `--continue` refuses staged `<<<<<<<` blocks on its own, but semantically wrong content passes every marker check. Parse the file, run the test that covers it, compare row or line counts against both parents.

The loop those rules produce:

```
git edit --amend-into=<sha> -- <paths>       # exit 2 → conflict trailer names the worktree
git -C <worktree> diff --name-only --diff-filter=U
# resolve one file, validate it, then stage it singly:
git -C <worktree> add <file>                 # never a blanket `add -A` chained into --continue
git edit --continue                          # dispatch on the fresh trailer; cascades repeat the loop
```

**Span campaigns.** A mechanical change to many commits — a format migration, a normalizer sweep — should not run as one fold or edit per commit: each replays every descendant as a diff and re-derives the same conflicts. Map snapshots instead, inside `--exec`:

```
git edit --exec -- zsh -c '
  NEW=<base>
  for C in $(git rev-list --reverse <base>..HEAD); do
    git checkout -qf $C && git clean -qfd
    transform .          # the pure per-snapshot rewrite
    git add -A
    NEW=$(git commit-tree $(git write-tree) -p $NEW \
          -m "$(git log -1 --format=%B $C)")
  done
  git reset -q --hard $NEW'
```

The transform applies to each commit's *snapshot*, so no step can conflict — and because the script ends with HEAD moved, `--exec` supplies the compare-and-swap, the pushed guard, and the journal entry around it. It's a sketch: a real loop also carries each commit's author and dates onto `commit-tree` (`GIT_AUTHOR_NAME`/`EMAIL`/`DATE`), and stops at merge commits rather than flattening them. Conflict-freedom cuts the other way too: a buggy transform lands on every commit uniformly and silently, so sweep the result before trusting it — run the tests per rebuilt commit, or diff each rebuilt tree against its source. A hand-authored point fix stays on the normal modes; the snapshot map is for changes that are a pure function of each commit's content.

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