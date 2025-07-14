# git edit – Easily edit commits via interactive rebase

This Git command script allows you to edit/modify/modify previous Git commits easily. It essentially is a more convenient version of using `git rebase --interactive` for that use case.

## Usage

```
git-edit [-m | --message | -d | --drop | -s | --squash] <commit>

-m, --message     Alter commit message after editing
-d, --drop        Just delete (drop) the commit
-s, --squash      Merge (fixup/squash) this commit into the previous one
```

![Screenshot](/screenshot.png?raw=true)

## What it does

This script will stash any local changes, then reset your local copy to the state of the commit you want to edit, then pause to let you make changes. After resuming, all changes will be added (amended) to the commit, and the rebase will continue.

The script also pauses in case any merge conflicts arise, so you can manually resolve them before continuing with the merge/rebase. After completion, your previous local changes will be unstashed/reapplied.

If you want to alter the commit message after editing as well, add the `-m`/`--message` switch. You can also delete (drop) a commit instead of editing by using `-d`/`--drop`, or merge (fixup/squash) it into the previous one using `-s`/`--squash`.

## Git Command

You can use it simply as `git edit` by adding its parent folder to your `PATH`, e.g. by adding this line to `~./zshrc`: `export PATH=$PATH:/your/path/to/git-custom-commands`.

## Warning

Note that this will change the SHA1 of the commit as well as of all later commmits – it rewrites the history from that point forward. This is unproblematic as long as you either didn't push these commits yet, or are a single developer. If not, it can cause other maintainers, branches, or forks quite a hassle. So please know what you're doing when using `git push --force`!
