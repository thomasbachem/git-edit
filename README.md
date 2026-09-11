# Fast, efficient, and safe Git history rewrites for AI agents

An AI coding agent that commits as it works keeps rewriting what it committed – folding in a fix, rewording, splitting, reordering – with nobody at the keyboard, and often with other sessions working in the same checkout. `git rebase -i` is built for a person at an editor, so the agent hand-rolls each rewrite: a scratch worktree, a scripted todo list, a compare-and-swap onto the branch, an index re-sync. That's five or six calls on the happy path, each a model turn, and one slip from reverting another session's commit. `git edit` makes it one call:

```
git edit <commit>                                     # edit that commit's content
git edit -M --text="Better subject" <commit>          # reword it, working tree untouched
git edit -d <commit>                                  # drop it
git edit HEAD~2..HEAD                                 # squash a range into its oldest commit
git edit --amend-into=auto                            # fold staged changes into the commit that owns the lines
git edit --split=<commit> --text="Icons" -- src/svg/  # cut the icons out into a commit of their own
git edit --move=<commit> --after=<anchor>             # slot a commit where it belongs
git edit --undo                                       # take the last operation back
```

What it's good at:

- **Leaving your checkout alone.** The plumbing modes never check anything out, and the rest work in a throwaway worktree – so history can be restructured with uncommitted work sitting right there, yours or another session's. Where a rewrite does change files you have checked out, it names the targeted `git restore` rather than a blanket `reset --hard`.
- **Sharing a checkout with parallel sessions.** Every ref move is a compare-and-swap and nothing is consumed until it lands, so a commit another session lands meanwhile is never overwritten, and a failure or `--abort` leaves nothing to roll back. Folds take `-- <paths>`, since a peer can stage into the shared index mid-call.
- **Being driven by an agent.** One call per intent, a closing status line to dispatch on, stale SHAs that resolve to their rewritten identity, refusals that name their fix – and guards against the ways agents fail, like staged conflict markers or a marker-less conflict read as resolved.
- **Folding a fix into the commit that owns the lines.** `--amend-into=auto` finds it by blame, then folds in isolation – gated by your test suite, if you pass `--verify`.

Pushed commits are refused unless you pass `--allow-pushed`, merge commits are rebuilt faithfully or refused but never flattened, and `git edit --undo` takes back the last operation.

## Installation

```
brew install thomasbachem/tap/git-edit
```

Or clone the repo and add the folder to your `PATH`, e.g. by adding this line to `~/.zshrc`:

```
export PATH="$PATH:/your/path/to/git-edit"
```

Either way `man git-edit` works right away – the formula installs the page, and on the `PATH` route `man` derives `<dir>/man` from each entry and finds the bundled `man/man1/git-edit.1`. Needs `zsh` and `git` 2.31+ – `git replay` (2.44+) rebuilds linear spans in one pass where it exists, and is never required.

## The modes

`git edit -h` prints the full flag reference, `man git-edit` the details behind each of these.

| | |
| --- | --- |
| `git edit <commit>` | **Edit** its content. Pauses for your changes, then amends the commit and replays the descendants |
| `git edit -M <commit>` | **Reword** only – pure plumbing, no checkout. `--text` skips the editor |
| `git edit -d <commit>...` | **Drop** commits or ranges. Their content stays in your checkout as uncommitted work |
| `git edit -s <commit>...` | **Squash** into the oldest of them – `-s=<target>` into a named one, `-S` to demand the plumbing path instead of a rebase fallback |
| `git edit --amend-into=<sha>` | **Fold** the staged changes into a past commit |
| `git edit --split=<sha>` | **Split** one commit into two |
| `git edit --reorder <commit>...` | **Reorder** a contiguous span, the arguments giving the new order oldest-first |
| `git edit --move=<sha> --after=<anchor>` | **Move** one commit (`--before=<anchor>` likewise) – span and ordering derived |
| `git edit --onto=<upstream>` | **Replant** the branch onto a moved upstream |
| `git edit --exec -- <cmd>...` | **Anything else**, run in an isolated worktree and applied only if it moved HEAD |

Edit is the default mode, and `-e` / `--edit` names it – which refuses a second commit where the bare form would take two as a squash. The other short flags have long spellings too – `--reword`, `--drop`, `--squash`, `--resquash`, `--message`, `--dir`, `--yes` – and mode and flags can be given in any order.

## Folding staged changes into a past commit

```
git add src/foo.js
git edit --amend-into=<sha>                          # fold what's staged into that commit
git edit --amend-into=auto                           # or let it find the commit those lines belong to
git edit --amend-into=<sha> -- src/foo.js            # fold only these staged paths, leave the rest staged
git edit --amend-into=<sha> --text="Better subject"  # fold and reword under one ref update
```

`auto` resolves the target from the staged **lines** rather than the files, because a fix belongs to whoever wrote the line being fixed. Take a file where commit A added one rule and B and C later added and refined a second one: editing A's rule makes C the newest commit touching the *file*, while A still owns the *line*. Where those lines point at several commits, or at a pushed one, it refuses and names the candidates instead of picking a winner. A purely additive hunk has no old line to attribute, so it falls back to the newest unpushed commit touching the staged paths – and refuses just the same where the paths disagree, or where every one of them is new.

Only staged changes are folded, and nothing is consumed until the final compare-and-swap – on a conflict or an `--abort` they are simply still staged, ready for the retry. The pathspec form is worth reaching for whenever the index might hold more than you mean to fold: in a shared checkout a parallel session can stage into it between your `git add` and the call. A staged path the target predates is refused where a later commit introduces it, since folding beneath that introduction turns every descendant touching the file into an add/add conflict – `--allow-new-path` overrides.

## Rewording a whole span in one pass

`-M` with no commit named reads `--- <commit>` records from stdin instead – exactly the shape `git log` emits, so the flow is dump -> edit -> feed back:

```
git log --format='--- %h%n%B' origin/main..HEAD > msgs.txt   # every unpushed message, batch-shaped
$EDITOR msgs.txt                                             # fix the bodies that need it
git edit -M --text - < msgs.txt                              # a record left unchanged is skipped
```

One walk rebuilds the span under a single compare-and-swap, where N separate rewords would replay the tail N times and open N ref-move windows. Every tree is reused verbatim, and the batch is all-or-nothing: an unreachable, already-pushed, empty or duplicated target aborts it before an object is written.

## Splitting a commit

Name one half by pathspec, and the split is pure plumbing – the trees are composed from the original blobs, so no conflict is possible:

```
git edit --split=<sha> --text="Extracted: the icons" -- src/svg/
```

Where both halves live in the **same file**, no pathspec can name them apart. Drop it, and the split pauses with a worktree holding the commit's own content: edit it back to what the first commit should leave behind, then `git edit --continue`. Authoring that one intermediate state is the whole description of a hunk-level split, and it is one a non-interactive caller can give without `git add -p`.

Either form inserts the new commit **beneath** the target and leaves the target above it with its own tree, message and identity – so `--text` always names the inserted commit, and the remainder keeps a subject written for the whole change. Reword it afterwards with `git edit -M`.

## Replanting onto a moved upstream

```
git edit --onto=main
```

The point of the mode is that it derives the fork point instead of asking for it. `git rebase --onto main <old-base> <branch>` needs `<old-base>` spelled out, and after a rewrite of `main` that commit is orphaned – so the caller has to have tracked the pre-rewrite SHA. `--onto` recovers it from `main`'s reflog, and says so when it has to fall back to a plain merge base.

It reports the triage up front: what the upstream gained, and which of your commits it already carries by patch id. Those are dropped by the replay and counted again in the summary, since a shorter branch that isn't accounted for reads as lost work. A commit the upstream took a *different* way conflicts, and `git edit --skip` steps over it rather than duplicating the change. A replant genuinely changes the branch's content, so your checkout is brought along with it – which is why uncommitted work on a path the replant rewrites is refused up front, before anything moves.

## When it pauses

A conflict, an edit and a content split all pause the same way: the branch has not moved, the worktree the run is using holds the state to fix, and the trailer names it. Resolve or author there, stage what you changed, then `git edit --continue` – or `git edit --abort`, which has nothing to roll back. A cascade just repeats the loop, and `git edit --status` reprints the pause for a session that arrives without the original context. An edit or a content split re-reads the branch at `--continue`, carrying along a commit that landed while you worked – a conflict resolution, built on the old tip, refuses to apply over one instead, and keeps your resolution in the worktree.

Some steps need no answer from you. A reorder preserves the tree and a fold's result is the staged tree, so on the final step the right content is provable before anything is committed and `git edit` applies it itself, handing back only where the proof fails. What is left over is the genuinely ambiguous case: an intermediate reorder step rebuilds a state that never existed in history, which has to be authored rather than derived, and the pause says so.

Without a TTY – an agent, CI, any script – the modes that would otherwise touch your checkout isolate themselves into a temp worktree automatically (`GIT_EDIT_NO_AUTO_ISOLATE=1` opts out). In a terminal, a worktree run opens that worktree in your GUI editor when git's editor cascade points at one (Sublime Text, VS Code, Cursor, Zed, a JetBrains IDE): `Space` re-opens it, `Enter` continues, `Escape` cancels, and `GIT_EDIT_NO_AUTO_OPEN=1` turns it off.

## Verifying what a rewrite built

An `ok` trailer says the branch moved, not that the result works. A conflict resolution can be wrong with no marker left behind, and a fold can break a later commit that built on the old content:

```
git edit --amend-into=<sha> --verify='npm test' -- src/foo.js
git config edit.verifyCmd 'npm test'      # or as a standing gate on every operation
```

The command runs in the operation's own worktree – at the commit the mode authored and at the new tip, `--verify-span` upgrading that to every rebuilt commit – before the compare-and-swap applies anything. A failure pauses with nothing applied and answers the two questions it raises: it runs the same check at the commit the failing one replaces, so a failure that predates the rewrite is cleared rather than blamed on it, and it climbs to the first commit above that passes, which for a fold is the commit carrying what the folded code now needs earlier. From there `git edit --continue` re-verifies, `--no-verify --continue` applies the result anyway, and `--abort` cancels.

Pair it with `edit.worktreeLink`. A fresh worktree holds none of what the repo deliberately doesn't track, so `npm test` there would fail on a missing `node_modules` rather than on the commit – name those paths once and every temp worktree gets them symlinked in:

```
git config --add edit.worktreeLink node_modules
```

## Driving it from a script or an agent

Every run ends with a single status line, written as prose and anchored by `git-edit: <outcome>`:

```
git-edit: ok – refs/heads/main moved <old-sha> → <new-sha>
git-edit: ok – refs/heads/main unchanged
git-edit: error – <reason>
git-edit: paused – edit|split <sha> in <worktree>; then 'git edit --continue' or 'git edit --abort'
git-edit: paused – verify failed at <sha> in <worktree>; output in <path>; then 'git edit --continue' (re-verify), '--no-verify --continue' (apply anyway), or 'git edit --abort'
git-edit: conflict – resolve in <worktree> (<files>); then 'git edit --continue' or 'git edit --abort'
```

**Dispatch on the trailer, not on the exit code.** A pipeline reports its last command's status, while the trailer is always the last stdout line: `grep '^git-edit: (ok|error|conflict|paused)'` decides what happens next, and the rest reads as text rather than as brittle key=value pairs.

**Keep the lines above it.** Blank-line padding is added only when stdout is a terminal, so a captured run comes out tight and even a `| tail -3` reaches the trailer and the line naming the commit the run touched. Above those sit the findings a rewrite reports about the *rest* of history – an edit's net history change, the commits a replay dropped as empty, a tip that differs from the staged result – and they move with the commit. A wrapper that forwards only the last line drops exactly those.

**Judge a pause by its trailer, then by the unmerged index** (`git -C <worktree> diff --name-only --diff-filter=U`) – never by grepping for conflict markers. A verify pause has nothing unmerged, an emptied step has nothing to resolve, an add/add or modify/delete places one side's file whole with no textual merge to mark, and a `rerere` replay arrives pre-filled. All four read as finished to a marker grep.

**Validate before staging, one file at a time.** "No markers left" is not validation – `--continue` refuses staged `<<<<<<<` blocks on its own, but semantically wrong content passes every marker check. A blanket `git add -A` chained into `--continue` stages whatever a broken resolver left behind before anything could look at it.

```
git edit --amend-into=<sha> -- <paths>       # exit 2 -> the conflict trailer names the worktree
git -C <worktree> diff --name-only --diff-filter=U
# resolve one file, validate it, then stage it singly:
git -C <worktree> add <file>
git edit --continue                          # dispatch on the fresh trailer, cascades repeat the loop
```

`man git-edit` carries the rest under SCRIPTING: the pause states in full, what `rerere` replays into a later conflict, and the snapshot-map recipe for a mechanical change across many commits, which belongs in a single `--exec` rather than in one fold per commit.

Worth putting in an agent's own instructions verbatim: *for any history-rewriting git command, reach for `git edit` – and for one it doesn't cover, `git edit --exec -- …` – so it can't disturb another session's working tree.*

## Flags and standalone commands

| | |
| --- | --- |
| `-m`, `--message` | Also edit the commit message after applying the changes |
| `--text <msg>` | Inline message for `-M`, `-s`/`-S`, `--split` and `--amend-into`, skipping the editor – `-` reads it from stdin |
| `-C`, `--dir[=<path>]` | Run in a separate worktree (default `<repo>.git-edit`), as non-interactive runs do by themselves |
| `--allow-pushed` | Rewrite a commit that already exists on a remote-tracking ref |
| `--allow-new-path` | Let `--amend-into` fold a staged path into a commit that predates it |
| `--verify=<cmd>` / `--verify-span` / `--no-verify` | Gate the rewrite on your own check, at the tip or across the span – or skip a configured one |
| `--skip` | With `--onto`, resume past the paused commit instead of through it |
| `-y`, `--yes` | Auto-confirm the drop/squash prompt a terminal run shows |
| `-h` | Print the usage. Prefer it to `--help`, which git routes through `man` – without a terminal that arrives as backspace-overstruck text |
| `--continue` / `--abort` | Resume or cancel the paused operation |
| `--undo` / `--status` | Revert the last completed operation, or report the in-flight one |
| `--version` | Print the released version – it tracks the tag, so a checkout following `main` reports the last one cut |
| `--selftest` | Run the end-to-end suite in a scratch repo – several hundred assertions driving the installed script as a subprocess, including a check that every flag it declares is documented in the man page and here |

Set with `git config`, per repo or globally: `edit.worktreeLink` (paths to link into every temp worktree, repeatable), `edit.verifyCmd`, `edit.verifySpan`, `edit.verifyBudget`. `GIT_EDIT_NO_AUTO_ISOLATE`, `GIT_EDIT_NO_AUTO_OPEN`, `GIT_EDIT_NO_RESOLVE`, `GIT_EDIT_NO_REPLAY`, `GIT_EDIT_WORKTREE_LINK` and `NO_COLOR` cover the same ground ad hoc – `man git-edit` has all of them.

## Screenshot

![Screenshot](/screenshot.png?raw=true)

## ⚠ Warning: History Rewriting

Rewriting history changes the SHA of the commit you name and of every commit after it.
- Safe if: Those commits aren't pushed yet, or you're the only developer
- Risky if: Others have based work on them (branches, forks, etc.)

Which is why pushed commits are refused unless you pass `--allow-pushed`: landing the result then means a force-push (`git push --force`), and that disrupts everyone who has them.
