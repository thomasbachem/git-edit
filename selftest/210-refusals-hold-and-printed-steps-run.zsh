# Refusals no other scenario reaches each hold, their neighbor going through:
# • A range or a `--move` whose ends lie on two sides of a merge
# • A pause's replay finished by hand with a tracked edit left past it
# • A kept `-C` path holding uncommitted changes
# • A fold whose staging a peer took back after its check
# • A pause whose `-C` path now holds another repository's checkout, which its abort leaves alone
# • A land of a branch sharing no history with the target
# • A carry partway through a rebase, a cherry-pick or a revert
# And printed steps run as printed – a `-C` path holding two spaces, a branch named `-x`, and the
# merge an unrelated land names
_ST_SCENARIO "\e[1;96m[210] unpinned refusals hold, and printed steps run as printed\e[0m"
local RF_S RF_M RF_B RF_T RF_WT RF_P RF_CMD RF_SHA RF_GITFN RF_OP

# A range or a `--move` across a merge's two sides – its ends on no one line of history
_ST_PZ_NEW rf1
_ST_PZ_C a.txt a "RF1 base"
RF_B=$(git rev-parse HEAD)
git checkout -q -b side && _ST_PZ_C s.txt s "RF1 side" && git checkout -q main
_ST_PZ_C m.txt m "RF1 main"
RF_S=$(git rev-parse side) RF_M=$(git rev-parse HEAD)
git merge -q --no-edit side
_ST_PZ_C u.txt u "RF1 u" && _ST_PZ_C v.txt v "RF1 v"
RF_T=$(git rev-parse HEAD)
_ST_RUN -d -y "$RF_S..$RF_M"
_ST_EQ "a range across a merge's two sides refuses, nothing dropped" "$RC:$(git rev-parse HEAD)" "1:$RF_T"
_ST_OUT_HAS "its ends named as on no one line of history" "its ends ${RF_S:0:7} and ${RF_M:0:7} are not on one line of history"
_ST_RUN --move="$RF_S..$RF_M" --after="$RF_B"
_ST_EQ "a --move run across them refuses too" "$RC:$(git rev-parse HEAD)" "1:$RF_T"
_ST_OUT_HAS "naming its ends" "Commits ${RF_S:0:7} and ${RF_M:0:7} are not on one line of history"
_ST_RUN --move="$RF_S" --after="$RF_M"
_ST_EQ "as does a --move anchored on the other side" "$RC:$(git rev-parse HEAD)" "1:$RF_T"
_ST_OUT_HAS "naming the commit and its anchor" "Commits ${RF_S:0:7} and ${RF_M:0:7} are not on one line of history"
_ST_RUN --move=HEAD~1 --after=HEAD
_ST_EQ "while a --move on one line goes through" "$RC:$(git log --format=%s -2 | tr '\n' '|')" "0:RF1 u|RF1 v|"
_ST_RUN -d -y HEAD..HEAD~1
_ST_EQ "as does a range named newest first" "$RC:$(git log -1 --format=%s)" "0:Merge branch 'side'"

# A replay finished by hand at the stop, a tracked edit left in the worktree past it
_ST_PZ_NEW rf2
_ST_PZ_C f.txt 1 "RF2 base" && _ST_PZ_C f.txt 2 "RF2 target" && _ST_PZ_C f.txt 3 "RF2 tip"
RF_T=$(git rev-parse HEAD)
_ST_RUN HEAD~1
RF_WT=$(_ST_PZ_WT)
print -r -- X > "${RF_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "the edit's replay stops on the tip's change" "$RC" "2"
print -r -- Y > "${RF_WT:-$ST_NO_WT}/f.txt" && git -C "$RF_WT" add f.txt && GIT_EDITOR=true git -C "$RF_WT" rebase --continue >/dev/null 2>&1
print -r -- Z > "${RF_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "a replay finished by hand, a tracked edit past it, refuses, nothing landed" "$RC:$(git rev-parse HEAD)" "1:$RF_T"
_ST_OUT_HAS "naming the edits that would never land" 'The worktree carries uncommitted edits past the finished replay'
git -C "${RF_WT:-$ST_NO_WT}" checkout -q -- f.txt
_ST_RUN --continue
_ST_EQ "with the edit gone, the replay finished by hand lands" "$RC:$(git show HEAD:f.txt):$(git show HEAD~1:f.txt)" "0:Y:X"

# A `-C` path holding two spaces – its printed `worktree add` makes that path, run as printed – and
# kept there, refused while it holds uncommitted changes
_ST_PZ_NEW rf3
_ST_PZ_C a.txt a "RF3 a" && _ST_PZ_C b.txt b "RF3 b" && _ST_PZ_C c.txt c "RF3 c"
RF_P="$TMP/rf3 two  spaces"
RF_SHA=$(git rev-parse HEAD)
_ST_RUN -d -y -C="$RF_P" HEAD
RF_CMD=$(grep -e '^git worktree add --detach ' <<<"$OUT" | head -1)
_ST_EQ "a drop in a -C path holding two spaces prints the worktree it adds" "$RC:$RF_CMD" "0:git worktree add --detach $(_SHQ "$RF_P") $RF_SHA"
command git worktree remove --force "$RF_P" 2>/dev/null
sh -c "${RF_CMD:-false}" >/dev/null 2>&1
_ST_EQ "which, run as printed, adds it at that very path" "$?:$(git -C "$RF_P" rev-parse HEAD 2>/dev/null):$([ -e "$TMP/rf3 two spaces" ] && echo collapsed)" "0:$RF_SHA:"
RF_T=$(git rev-parse HEAD)
print -r -- dirty > "$RF_P/a.txt"
_ST_RUN -d -y -C="$RF_P" HEAD
_ST_EQ "a kept -C path holding uncommitted changes refuses, nothing dropped" "$RC:$(git rev-parse HEAD):$(<"$RF_P/a.txt")" "1:$RF_T:dirty"
_ST_OUT_HAS "naming the path and a scratch one instead" "holds uncommitted changes – name a scratch path instead"
command git -C "$RF_P" checkout -q -- a.txt
_ST_RUN -d -y -C="$RF_P" HEAD
_ST_EQ "while clean, it takes the next run" "$RC:$(git log -1 --format=%s)" "0:RF3 a"
command git worktree remove --force "$RF_P" 2>/dev/null

# A fold whose staging a peer takes back between its check and its snapshot – stood in for by a
# `git` unstaging everything right after the fold's first `diff --cached`
_ST_PZ_NEW rf4
_ST_PZ_C a.txt a1 "RF4 a" && _ST_PZ_C b.txt b1 "RF4 b"
RF_T=$(git rev-parse HEAD)
mkdir -p "$TMP/rf4-git"
{
	print -r -- '#!/bin/sh'
	print -r -- "case \" \$* \" in *' diff --cached '*) if [ -e ${(q)TMP}/rf4-git/arm ]; then rm -f ${(q)TMP}/rf4-git/arm; ${(q)commands[git]} \"\$@\"; R=\$?; ${(q)commands[git]} reset -q; exit \$R; fi ;; esac"
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/rf4-git/git"
chmod +x "$TMP/rf4-git/git"
print -r -- a2 > a.txt && git add a.txt
: > "$TMP/rf4-git/arm"
PATH="$TMP/rf4-git:$PATH" _ST_RUN --amend-into=HEAD~1
_ST_EQ "a fold whose staging was taken back meanwhile refuses, nothing folded" "$RC:$(git rev-parse HEAD):$([ -e "$TMP/rf4-git/arm" ] || echo fired)" "1:$RF_T:fired"
_ST_OUT_HAS "saying so" 'The staged changes were unstaged meanwhile – nothing to fold'
git add a.txt
PATH="$TMP/rf4-git:$PATH" _ST_RUN --amend-into=HEAD~1
_ST_EQ "while that staging, kept, folds" "$RC:$(git show HEAD~1:a.txt)" "0:a2"

# A pause whose `-C` path now holds another repository's checkout
_ST_PZ_NEW rf5
_ST_PZ_C a.txt a1 "RF5 a" && _ST_PZ_C b.txt b1 "RF5 b"
RF_T=$(git rev-parse HEAD)
_ST_RUN -C="$TMP/rf5-wt" HEAD~1
RF_WT=$(_ST_PZ_WT)
print -r -- a2 > "${RF_WT:-$ST_NO_WT}/a.txt"
mv "${RF_WT:-$ST_NO_WT}" "$TMP/rf5-moved" && git init -q "$RF_WT" && print -r -- other > "$RF_WT/o.txt"
_ST_RUN --continue
_ST_EQ "a pause whose worktree is another repository's checkout now refuses, nothing landed" "$RC:$(git rev-parse HEAD)" "1:$RF_T"
_ST_OUT_HAS "naming it as no longer a checkout of this repository" 'is no longer a checkout of this repository'
_ST_RUN --abort
_ST_EQ "the abort it names clears the pause, the other checkout left alone" "$RC:$([ -e "$(git rev-parse --git-common-dir)/git-edit-state" ] && echo paused):$(<"${RF_WT:-$ST_NO_WT}/o.txt")" "0::other"

# A land of a branch sharing no history with the target – the merge it names joins them as printed
_ST_PZ_NEW rf6
_ST_PZ_C a.txt a "RF6 base"
RF_T=$(git rev-parse HEAD)
git update-ref refs/heads/lone "$(git commit-tree "$(printf '100644 blob %s\to.txt\n' "$(print -r -- o | git hash-object -w --stdin)" | git mktree)" -m "RF6 lone")"
_ST_RUN --land=lone
_ST_EQ "landing a branch sharing no history refuses, nothing landed" "$RC:$(git rev-parse HEAD)" "1:$RF_T"
_ST_OUT_HAS "saying so" 'lone shares no history with main – nothing to replay from, so nothing landed'
RF_CMD=$(sed -n 's/^ *Join the two by a merge if that is meant: //p' <<<"$OUT" | head -1)
RF_GITFN="git () { if [ \"\$1\" = edit ]; then shift; GIT_EDIT_NO_AUTO_OPEN=1 ${(qq)SELF} \"\$@\"; else command git \"\$@\"; fi; }"
OUT=$(sh -c "$RF_GITFN; ${RF_CMD:-false}" </dev/null 2>&1)
_ST_EQ "whose merge, run as printed, joins the two" "$?:$(git ls-tree --name-only HEAD | tr '\n' '|'):$(git rev-parse HEAD^1)" "0:a.txt|o.txt|:$RF_T"

# A branch named `-x` – its pointing and deletion steps, run as printed, act on it
_ST_PZ_NEW rf7
_ST_PZ_C a.txt a "RF7 base"
git checkout -q -b feat && _ST_PZ_C f.txt f "RF7 feat" && git checkout -q main
_ST_PZ_C m.txt m "RF7 main moved"
git update-ref refs/heads/-x feat && git branch -q -D feat
_ST_RUN --land=-x
_ST_EQ "a dash-led branch lands" "$RC:$(git log -1 --format=%s)" "0:RF7 feat"
RF_CMD=$(sed -n 's/.*point it at those (\(git update-ref refs\/heads\/-x [0-9a-f]*\)).*/\1/p' <<<"$OUT" | head -1)
sh -c "${RF_CMD:-false}" >/dev/null 2>&1
_ST_EQ "its pointing step, run as printed, points it at the copies" "$?:$(git rev-parse -q --verify refs/heads/-x)" "0:$(git rev-parse HEAD)"
RF_CMD=$(sed -n 's/.*or delete it (\(git update-ref -d refs\/heads\/-x\)).*/\1/p' <<<"$OUT" | head -1)
sh -c "${RF_CMD:-false}" >/dev/null 2>&1
_ST_EQ "its deletion step, run as printed, deletes it" "$?:$(git rev-parse -q --verify refs/heads/-x)" "0:"

# A carry partway through a rebase, a cherry-pick or a revert refuses, its conflict left as it was
for RF_OP in rebase cherry-pick revert; do
	_ST_PZ_NEW rf8-$RF_OP
	_ST_PZ_C a.txt a "RF8 base"
	RF_B=$(git rev-parse HEAD)
	git checkout -q -b x && _ST_PZ_C a.txt x "RF8 x" && git checkout -q main
	_ST_PZ_C a.txt y "RF8 y"
	case $RF_OP in
		rebase) git rebase x >/dev/null 2>&1 ;;
		cherry-pick) git cherry-pick x >/dev/null 2>&1 ;;
		revert) _ST_PZ_C a.txt z "RF8 z" && git revert --no-edit HEAD~1 >/dev/null 2>&1 ;;
	esac
	_ST_RUN --carry="$RF_B"
	_ST_EQ "a carry partway through a $RF_OP refuses, its conflict left as it was" "$RC:$(git ls-files -u | wc -l | tr -d ' ')" "1:3"
	# A rebase's `HEAD` is detached, refused as such before
	[ "$RF_OP" = rebase ] || _ST_OUT_HAS "naming the $RF_OP" "halfway through a $RF_OP – finish or abort it first"
	git "$RF_OP" --abort >/dev/null 2>&1
done
cd "$TMP/repo"
