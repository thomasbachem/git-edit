# git edit – Easily edit commits via interactive rebase

This Git subcommand script makes it easy to edit, modify, drop, or merge previous commits. It's essentially a more convenient wrapper around `git rebase --interactive`, with automatic stashing/unstashing and integrated merge conflict handling.

## Usage

```
git-edit [-m | --message | -s | --squash] <commit> [<target>]
git-edit [-d | --drop] <commit>...

MODES:
-e, --edit                      Edit <commit> (default mode)
-d, --drop                      Delete (drop) <commit>s or ranges
-s, --squash                    Merge (fixup/squash) <commit> into the previous one
-s <target>, --squash <target>  Merge (fixup/squash) <commit> into <target>
                                – also assumed when two commits (<commit> <target>) are supplied
FLAGS:
-m, --message                   Alter <commit> message after applying changes
```
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

Merge two commits, keeping only the target commit's message (or add `-m` to also edit the message):
```
git edit 0123456789abcdef0123456789abcdef01234567 abcdef0123456789abcdef0123456789abcdef01
```
This will:
1. Stash any current local changes
2. Determine the older of the two commits, making it the target
3. **Merge the newer commit into it**
4. Continue the rebase (pausing if merge conflicts occur so you can resolve them)
5. Restore your stashed changes

## Screenshot

![Screenshot](/screenshot.png?raw=true)

## Installation

Make the script available as a Git command by adding its folder to your `PATH`, e.g. by adding this line to `~/.zshrc`:
```
export PATH="$PATH:/your/path/to/git-edit"
```

## ⚠ Warning: History Rewriting

This script rewrites Git history from the chosen commit onward — changing the SHA-1 of that commit and all later commits.
- Safe if: Commits haven’t been pushed yet, or you’re the only developer
- Risky if: Others have based work on these commits (branches, forks, etc.)
If rewriting history, you’ll need to force-push (`git push --force`), which can disrupt collaborators.