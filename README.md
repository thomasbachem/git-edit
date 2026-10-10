# Fast, efficient, and safe Git history rewrites for AI agents

An AI coding agent that commits as it works keeps rewriting what it committed – folding in a fix, rewording, splitting, reordering – with nobody at the keyboard, and often with other sessions working in the same checkout. `git rebase -i` is built for a person at an editor, so the agent hand-rolls each rewrite: a scratch worktree, a scripted todo list, a compare-and-swap onto the branch, an index re-sync. That's five or six calls on the happy path, each a model turn, and one slip from reverting another session's commit. `git edit` makes it one call:

```
git edit <commit>                                     # edit that commit's content
git edit -M --text="Better subject" <commit>          # reword it, working tree untouched
git edit -M --subject="Better subject" <commit>       # or change its subject alone, the body kept
git edit -d <commit>                                  # drop it
git edit HEAD~2..HEAD                                 # squash all three into the oldest – ranges include both ends
git edit --amend-into=auto                            # fold staged changes into the commit that owns the lines
git edit --split=<commit> --text="Icons" -- src/svg/  # cut the icons out into a commit of their own
git edit --move=<commit> --after=<anchor>             # slot a commit where it belongs
git edit --land=feature                               # land a finished branch on the checked-out one
git edit --undo                                       # take the last operation back
```

What it's good at:

- **Leaving your checkout alone.** The plumbing modes never check anything out, and the rest work in a throwaway worktree, so history can be restructured with uncommitted work sitting right there, yours or another session's – and once a run lands, the checkout comes along, uncommitted edits merged onto what landed.
- **Sharing a checkout with parallel sessions.** A run *lands* – moves the branch – by compare-and-swap, and nothing is consumed until it does, so a commit another session lands meanwhile is never overwritten, and a failure or `--abort` leaves nothing to roll back. A commit or fold can take just your own lines from a file another session is also editing, and one that would take back what another session landed is refused.
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

Either way `man git-edit` works right away. Needs `zsh` and `git` 2.31 or later – `--snapshot` needs 2.40, and `git replay` (2.44+) rebuilds linear spans in one pass where it exists, never required.

## The modes

`git edit -h` prints the full flag reference, `man git-edit` the details behind each of these.

| | |
| --- | --- |
| `git edit <commit>` | **Edit** its content. Pauses for your changes, then amends the commit and replays the descendants |
| `git edit -M <commit>` | **Reword** only – pure plumbing, no checkout. `--text` skips the editor, `--subject` replaces the subject alone |
| `git edit -d <commit>...` | **Drop** commits or ranges – their content leaves your checkout too, named with the way back |
| `git edit -s <commit>...` | **Squash** into the oldest of them, a single commit into its parent – `-s=<target>` into a named one, `-S` to demand the plumbing path |
| `git edit --amend-into=<sha>` | **Fold** the staged changes into a past commit |
| `git edit --commit --text <msg> -- <path>...` | **Commit** files whole from the checkout, composed apart from the shared index – at the tip, or beside a commit with `--after=<anchor>` or `--before=<anchor>` |
| `git edit --split=<sha>` | **Split** one commit into two |
| `git edit --reorder <commit>...` | **Reorder** a contiguous span, the arguments giving the new order oldest-first |
| `git edit --move=<sha> --after=<anchor>` | **Move** one commit, or several as one block with a repeated `--move` – span and ordering derived |
| `git edit --onto=<upstream>` | **Replant** the branch onto a moved upstream |
| `git edit --land=<branch>` | **Land** another branch's commits on the checked-out one – a fast-forward where it can, else a replay onto the tip in a worktree of its own |
| `git edit --exec -- <cmd>...` | **Anything else**, run in an isolated worktree and applied only if it moved HEAD |

Edit is the default mode, and `-e` / `--edit` names it – which refuses a second commit where the bare form would take two as a squash. The other short flags have long spellings too – `--reword`, `--drop`, `--squash`, `--resquash`, `--message`, `--dir`, `--yes` – and mode and flags can be given in any order. A range `A..B` includes both its ends, unlike git's own. Every mode needs a checked-out branch but `-M`, `-S` and a split by pathspec.

## Folding staged changes into a past commit

```
git add src/foo.js
git edit --amend-into=<sha>                          # fold what's staged into that commit
git edit --amend-into=auto                           # or let it find the commit those lines belong to
git edit --amend-into=<sha> -- src/foo.js            # fold only these staged paths, leave the rest staged
git edit --amend-into=<sha> --text="Better subject"  # fold and reword under one ref update
git edit --amend-into=<sha> --tree=<tree-ish>        # fold a tree composed apart from the shared index
```

`auto` resolves the target from the folded **lines** rather than the files, because a fix belongs to whoever wrote the line being fixed: take a file where commit A added one rule and B and C later added and refined a second one – editing A's rule makes C the newest commit touching the *file*, while A still owns the *line*. Where the lines point at several commits, or at a pushed one, it refuses and names the candidates instead of picking a winner. A purely additive hunk has no old line to attribute, so it falls back to the newest unpushed commit touching the staged paths.

Only staged changes are folded, and nothing is consumed until the final compare-and-swap – on a conflict or an `--abort` they are simply still staged, ready for the retry. Name the paths whenever the index might hold more than you mean to fold: in a shared checkout a parallel session can stage into it between your `git add` and the call. A fold refuses what would break further up – a path the target predates (`--allow-new-path` overrides), a removal beneath the commit that adds the path, and a flipped file mode unless `--allow-mode-change` says it is meant – while a path renamed since folds onto its old name.

Where later commits rewrote the lines beside the fold, a replay stops at each of them for a state written by hand. A fold given as `--edits` alone resolves those stops itself wherever the commit there still holds each old text exactly once. `--snapshot` merges the fold into every commit from the target up instead, so a conflict stops once per distinct content of its file, and that resolution serves every commit carrying the same.

Where the shared index is itself the hazard, `--tree` takes the fold's content from a tree composed apart from it – a commit on `HEAD`, which pins the tip it was composed on.

## Committing from a shared checkout

```
git edit --commit --text "Subject" -- src/foo.js src/new.js   # commit these files as they stand
git edit --commit --text "Subject" --after=<sha> -- src/foo.js # or land the commit beside the run it continues
git edit --amend-into=<sha> --whole -- src/foo.js             # or fold them whole into a past commit
```

`--commit` takes files as `git commit -- <paths>` does – each as it stands, named one by one, a new one with no `git add`, a deleted one removed – into a private index seeded from `HEAD`, so files staged beside them stay staged and out of the commit. It lands like any rewrite: the repo's hooks run, `edit.verifyCmd` gates it unless `--no-verify` skips it, the branch moves only from the tip the files were composed on, and the journal and reflog name the caller. A file carrying conflict markers its tip version lacks is refused, as is a file-mode change unless `--allow-mode-change` says it is meant. With `--after=<anchor>` or `--before=<anchor>` the commit lands right beside that one instead of at the tip, in the same run, and `--exec` takes the same flags for the commits its command adds.

Where a file you changed also holds another session's uncommitted lines, taking it whole would take theirs too. The inputs compose the commit from your own changes alone, on the tip's content in a private index: `--edits` replays the replacements you made by hand, each old text matching exactly once, so a peer's line inside it refuses rather than merging; `--patch` applies hunks you split; `--put` replaces a file with one you rebuilt from `git show <sha>:<path>` plus your changes; `--chmod` and `--rm` set a bit and remove a path. Never generate `--edits` pairs from a diff of the checkout file, which holds the peer's lines too. Files wholly yours go after `--` beside the inputs. `--amend-into=<sha>` takes the same inputs, files whole beside them after `--whole`, and `--commit --tree=<commit>` lands a commit composed on the tip by anything else.

```
git edit --commit --text "Subject" --edits '{"src/app.js": [["old line\n", "new line\n"]]}'
git edit --commit --text "Subject" --edits=edits.json -- src/mine.js src/new.js   # edits, and files wholly yours
git edit --amend-into=<sha> --patch=fix.patch --put=src/new.js=/tmp/new.js
```

A shared checkout has one more way to lose work: a file still edited on old content – a conflict a sync left, an editor's buffer read before a landing – committed whole takes back what another session landed. So `--commit`, `--whole`, the inputs and a fold of what is staged refuse where a file lacks what another `GIT_EDIT_ACTOR` caller's run of the last 7 days landed on it, naming that run and the remedy – usually the `git edit --carry` that merges your edits onto what landed. Runs under your own label never count, nor do edits made on the landed lines afterwards, and a fold counts only the runs at or below its target. `--base=<sha>` names the commit your files rest on instead, refusing any path changed since – the tip's own SHA where taking a landing back is the point.

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

Where both halves live in the **same file**, no pathspec can name them apart. Drop it, and the split pauses with a worktree holding the commit's own content: edit it back to what the first commit should leave behind, then `git edit --continue`. That one authored state is the whole description of a hunk-level split, and a non-interactive caller can give it without `git add -p`.

Either form inserts the new commit **beneath** the target, which keeps its own tree, message and identity – so `--text` names the inserted commit, and the remainder keeps a subject written for the whole change. Reword it afterwards with `git edit -M --subject`, which keeps the body.

## Replanting onto a moved upstream

```
git edit --onto=main
```

The point of the mode is that it derives the fork point instead of asking for it. `git rebase --onto main <old-base> <branch>` needs `<old-base>` spelled out, and after a rewrite of `main` that commit is orphaned – so the caller has to have tracked the pre-rewrite SHA. `--onto` recovers it from `main`'s reflog, and says so when it has to fall back to a plain merge base.

It reports the triage up front: what the upstream gained, and which of your commits it already carries by patch id – those are dropped and counted in the summary, since a shorter branch that isn't accounted for reads as lost work. A commit the upstream took a *different* way conflicts, and `git edit --skip` steps over it rather than duplicating the change. Your checkout comes along as after any landing, uncommitted edits merged onto the replanted files, so no stash is needed first – only a checkout halfway through a merge, rebase, cherry-pick or revert refuses up front. A branch with no commits of its own past the fork simply moves to the upstream.

## Landing a finished branch

```
git edit --land=feature --dry-run     # fast-forward or replay, and which commits
git edit --land=feature               # land them on the checked-out branch
```

Sessions sharing one checkout finish their branches into its `main` while it holds other sessions' uncommitted work – by hand that's a temp commit and a raw `git rebase`, or an `update-ref`, outside every guard. `--land` does it in one call. Where `main` still sits on the branch's fork it fast-forwards; otherwise the branch's commits replay onto its tip in a worktree of their own, and a conflict pauses like any replay, with `--continue`, `--skip` and `--abort`. Your checkout comes along as after any landing, and the branch itself never moves – the run names the command that points it at the copies.

What lands is the commits `main` never held, read from its reflog rather than guessed from a merge base – so a land taken back, a catch-up merge or land, or a rewrite of `main` neither leaves the branch's commits out nor brings back what `main` dropped. The run says which fork it used, and `--base=<sha>` names one outright. A commit that looks like a copy of one `main` holds or held – a cherry-pick, or one reworded or amended since it landed – refuses the whole land rather than be guessed at, naming the steps that bring its change in or leave it out.

A branch already landed ends `ok – … unchanged`, a target that moved meanwhile is refused rather than overwritten, a merge commit in the span is refused rather than flattened, and `--undo` takes a land back. A name is a branch first; a tag, SHA or revision such as `feat~1` lands as what it resolves to.

## When it pauses

A conflict, an edit and a content split all pause the same way: the branch has not moved, the worktree the run is using holds the state to fix, and the trailer names it. Resolve or author there, stage what you changed, then `git edit --continue` – or `git edit --abort`, which has nothing to roll back. A conflicted file whose markers are gone the resume stages itself. A cascade just repeats the loop, and `git edit --status` reprints the pause for a session that arrives without the original context.

An edit or a content split re-reads the branch at `--continue`, carrying along a commit that landed while you worked. A conflict resolution is built on the tip it read, so where the branch moved meanwhile its `--continue` refuses at once, keeping the resolution in the worktree for `git edit --abort` and a redo. A rebase continued, quit or trimmed by hand in that worktree is checked against what the run paused at, never landed blind.

A repository holds one pause at a time. Another caller's run waits up to `--wait` (90 seconds by default) for it to clear, then runs on what it landed – or refuses as in flight. A labeled caller's pause is its own: another `GIT_EDIT_ACTOR` label's `--continue` or `--abort` refuses unless `--allow-other-actor` says it is meant.

Where the right content is provable – the final step of a fold or a reorder – `git edit` resolves the stop itself, and a pause it can't derive names the exact answer where one exists. A reorder only moves commits, so one that would end on another tree refuses to land, naming the files.

At a terminal a pause asks rather than exits: `Enter` resumes it, staging each conflicted file you cleared of markers, `Escape` twice cancels it, and `q` or `Ctrl-C` leaves it for later. The worktree opens in your GUI editor where git's editor settings name one (Sublime Text, VS Code, Cursor, Zed, a JetBrains IDE), `Space` re-opens it, and `GIT_EDIT_NO_AUTO_OPEN=1` turns that off. Without a terminal, or with `CI`, `CLAUDECODE` or `GIT_EDIT_ACTOR` set, the run is an agent's, and a pause exits for `--continue`.

## Your checkout

Once a run lands – an agent's as much as a terminal's, any mode – the checkout it started in comes along. A file the move changed and nobody touched takes what landed, and uncommitted edits merge onto it. A merge that would conflict writes nothing: the edits stay as changes to what landed, and the run names the `git merge-file` that brings the markers in – at a terminal for you to run once you mean to resolve them, in an agent's run for whoever owns the edits. A file the run itself committed keeps your later edits as they are. An untracked file in a landing's way, a peer's staging, and a file staged and edited both are left as they were and named, and what a move took out – a file it removed, what a drop held – leaves the checkout too, named with the way back.

Where the sync can't run – a checkout halfway through a merge or a rebase, its index locked past the wait, the branch checked out elsewhere – the run names the bare `git edit --carry` that brings it along once it can, never a `git restore`, which run later would take an edit another session made since. Each checkout remembers the tip it was last brought to, so a bare carry, or the next landing's sync, brings every landing it missed since and none twice, each file merging from where it was last brought to – an edit of yours that undoes part of an earlier landing stays. A path left behind is recorded until it comes along, and `--status` names it with its carry. What a run leaves to do – a conflict's merge, or that carry – prints last, right above the trailer.

## Many sessions at once

Where many sessions rewrite one branch, some lose the race. A run stops with nothing applied as soon as it can no longer land – its branch moved off the tip it read, or another run paused on that branch – rather than pause, run its gate or replay for nothing, and names who moved the branch. A pause wins over a run already in flight, which reruns with `--wait=600`; a resume refused keeps its resolution for `git edit --abort` and a redo, as `--status` names.

When many sessions fold fixes into the same deep history at once, each fold replays everything above its target and collides with the next. Land each fix at the tip as its own commit instead, then have each owner squash its fixes into their target, one session at a time, and run the suite once on the result:

```
git edit --commit --text "fixup! <target's subject>" -- <paths>   # its gate may wait for the squash: --no-verify
git edit -s=<target> <fixup commit>...                             # each owner in turn, gate on
```

A lost race, or a wait that ran out, points here when other callers landed on the branch 3 or more times in the last 10 minutes.

## Verifying what a rewrite built

An `ok` trailer says the branch moved, not that the result works. A conflict resolution can be wrong with no marker left behind, and a fold can break a later commit that built on the old content:

```
git edit --amend-into=<sha> --verify='npm test' -- src/foo.js
git config edit.verifyCmd 'npm test'      # or as a standing gate on every operation
```

The command runs in the operation's own worktree before the compare-and-swap applies anything – at the commit the mode authored, the first one it rebuilt, each commit a conflict resolution wrote, and the new tip, `--verify-span` upgrading that to every rebuilt commit and `--no-verify-span` stepping a standing span back down for one run. A failure pauses with nothing applied, or refuses outright in the modes that have no pause. Either way it answers the two questions a failure raises: it runs the same check at the commit the failing one replaces, so a failure that predates the rewrite isn't blamed on it, and it climbs to the first commit above that passes, which for a fold is the commit carrying what the folded code now needs earlier. From there `git edit --continue` re-verifies, `--no-verify --continue` applies the result anyway, and `--abort` cancels.

Pair it with `edit.worktreeLink`. A fresh worktree holds none of what the repo deliberately doesn't track, so `npm test` there would fail on a missing `node_modules` rather than on the commit – name those paths once and every temp worktree gets them symlinked in:

```
git config --add edit.worktreeLink node_modules
```

## Driving it from a script or an agent

Every run ends with a single status line, written as prose and anchored by `git-edit: <outcome>`:

```
git-edit: ok – <ref> moved <old-sha> → <new-sha>
git-edit: ok – <ref> unchanged[, <why>]
git-edit: error – <reason>
git-edit: conflict – resolve in <worktree> (<files>); then 'git edit --continue' or 'git edit --abort'
git-edit: paused – <operation> <sha> in <worktree>; then 'git edit --continue' or 'git edit --abort'
git-edit: paused – verify failed at <sha> in <worktree>; output in <path>; then 'git edit --continue' (re-verify), '--no-verify --continue' (apply anyway), or 'git edit --abort'
git-edit: paused – <operation> <sha> is <label>'s, not yours: leave it to that caller, or wait for it ('--allow-other-actor' takes it on)
```

`git edit -h trailer` lists the rest – a dry run, a carry, `--status`, a mode-change pause.

**Dispatch on the trailer, not on the exit code.** A pipeline reports its last command's status, while the trailer is always the last stdout line: `grep -E '^git-edit: (ok|error|conflict|paused)'` decides what happens next, and the rest reads as text rather than as brittle key=value pairs.

**Keep the lines above it.** A captured run comes out tight, so even a `| tail -3` reaches the trailer and the line naming the commit the run touched, what the run leaves to do right above them. To read what landed and what checked it, grep by name rather than count lines: `grep -E '^(Verif|Tip tree|Trees|Note: tip tree|git-edit:)'`. The verification line carries its own shortfall – `Verified 2 of 7 commit(s) … – 5 unchecked in between` – and a run that declined its gate says so, so silence means the repo has no gate configured.

**Resolve by the unmerged index, one file at a time.** Judge a pause by its trailer, then by `git -C <worktree> -c core.quotePath=false diff --name-only --diff-filter=U` – never by grepping for conflict markers: a verify or mode pause has nothing unmerged, an emptied step nothing to resolve, an add/add or modify/delete places one side's file whole, and a `rerere` replay arrives pre-filled, all four reading as finished to a marker grep. And "no markers left" is not validation – check each file before you stage it, as a blanket `git add -A` chained into `--continue` stages whatever a broken resolver left behind.

```
git edit --amend-into=<sha> -- <paths>       # exit 2 -> the conflict trailer names the worktree
git -C <worktree> -c core.quotePath=false diff --name-only --diff-filter=U
# resolve one file, validate it, then stage it singly:
git -C <worktree> add <file>
git edit --continue                          # dispatch on the fresh trailer, cascades repeat the loop
```

**Every move is attributed.** Each reflog entry names the operation and, where `GIT_EDIT_ACTOR` holds a label such as an agent session's id, ends with ` [<label>]`. The undo journal keeps it too, so a labeled caller's `--undo` refuses another label's run unless `--allow-other-actor` says it is meant. A run cut short – signaled or killed after its branch moved – is journaled all the same, by itself or the next run.

Look a flag up with `git edit -h <flag>` – one entry of the man page, as plain text – rather than grepping `--help`. `man git-edit` carries the rest under SCRIPTING: the pause states in full, what `rerere` replays into a later conflict, and the snapshot-map recipe for a mechanical change across many commits, which belongs in a single `--exec` rather than in one fold per commit.

Worth putting in an agent's own instructions verbatim: *with `GIT_EDIT_ACTOR` set to your session's id, commit through `git edit --commit --text "…" -- <paths>` – or, where another session has uncommitted lines in the same file, through `--edits` with the replacements you made, files wholly yours still after `--` – and for any history-rewriting git command reach for `git edit` – for one it doesn't cover, `git edit --exec -- …` – so it can't disturb another session's working tree or take back what one landed.* The label is what tells another session's landing from your own – unlabeled, every unlabeled run counts as yours.

## Flags and standalone commands

`git edit -h <flag>...` prints any flag's entry of the man page in full.

| | |
| --- | --- |
| `--text <msg>`, `--subject <line>`, `-m`, `--message` | The new message – inline (`-` reads stdin), the subject alone with the body kept, or in an editor at a terminal |
| `--edits=<file\|json>`, `--patch=<file>`, `--put=<path>=<file>`, `--rm=<path>`, `--chmod=<path>=+x\|-x` | The inputs of `--commit` and `--amend-into`, composing your own changes on the tip – see *Committing from a shared checkout* |
| `--whole`, `--tree=<tree-ish>`, `--snapshot` | How `--amend-into` folds – named files whole, a tree composed apart, or merged into each commit from its target up |
| `--base=<sha>` | The commit your files rest on, in place of the landings check – with `--exec`, the tip its result was built on. With `--land`, the commit `<branch>` forked from |
| `--allow-pushed`, `--allow-new-path`, `--allow-mode-change`, `--allow-other-actor` | Overrides – rewrite pushed commits, fold a path into a commit that predates it, take a file-mode change, take on another caller's run or pause |
| `--verify=<cmd>`, `--verify-span`, `--no-verify-span`, `--no-verify` | The gate – see *Verifying what a rewrite built* |
| `-C`, `--dir[=<path>]` | Run an edit, drop, squash or a land's replay in a kept worktree, `<repo>.git-edit` by default |
| `--dry-run`, `--wait=<secs>`, `-y`, `--yes` | Say what would land, wait for another caller's pause (90 s by default), confirm a terminal prompt |
| `--continue`, `--abort`, `--skip` | Resume, cancel, or resume past the paused commit (`--onto` and `--land`) |
| `--undo`, `--status`, `--carry[=<old tip>]` | Take back the last run – report the one in flight, else the last – bring the checkout along to what landed |
| `-h [<topic>...]`, `--version`, `--selftest[=<ids>]`, `--jobs[=<n>]` | The usage or a flag's entry (prefer it to `--help`, which git routes through `man`), the version, the suite |

Set with `git config`, per repo or globally: `edit.worktreeLink` (paths to link into every temp worktree, repeatable), `edit.verifyCmd`, `edit.verifySpan`, `edit.verifyBudget`. `GIT_EDIT_NO_AUTO_OPEN`, `GIT_EDIT_NO_RESOLVE`, `GIT_EDIT_NO_REPLAY`, `GIT_EDIT_PROGRESS`, `GIT_EDIT_WORKTREE_LINK` and `NO_COLOR` cover the same ground ad hoc – `man git-edit` has all of them. Every temp worktree reads the config your checkout reads, too – an `onbranch` include's identity or signing key, and a relative `core.hooksPath` such as husky's.

## A run, as an agent sees it

```
$ git add parse.js
$ git edit --amend-into=auto --verify='node --check parse.js'
auto-target: commit that last touched the staged lines
Amending staged changes into 41c544c (Add argument parser)...
git write-tree + commit-tree -> 79b79f7 # fixup! object, branch untouched
git worktree add --detach /tmp/git-edit-amend-into.tYrxEG 79b79f7…
… git rebase --interactive --root, in that worktree
node --check parse.js # verify 2 commit(s)
Verified 2 of 3 commit(s) with `node --check parse.js` in 0s – 1 unchecked in between, `--verify-span` covers them (also: edit.verifySpan)
git update-ref -m 'git edit: amend-into 41c544c' refs/heads/main 1999506… b5719e0…
Undo: git edit --undo  (or, the ref alone: git update-ref -m 'git edit: undo amend-into 41c544c' refs/heads/main b5719e0… 1999506…)
Folded parse.js – the amended commit as a whole now:
 parse.js | 3 +++
 1 file changed, 3 insertions(+)
Index now empty; working tree keeps no changes.
  amended: 341c112 Add argument parser
git-edit: ok – refs/heads/main moved b5719e0… → 1999506…
```

## ⚠ Warning: History Rewriting

Rewriting history changes the SHA of the commit you name and of every commit after it.
- Safe if: Those commits aren't pushed yet, or you're the only developer
- Risky if: Others have based work on them (branches, forks, etc.)

Which is why pushed commits are refused unless you pass `--allow-pushed`: landing the result then means a force-push (`git push --force`), and that disrupts everyone who has them.
