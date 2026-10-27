# Tags `edit.followTag` names follow a landed rewrite of their commit, every other tag left behind:
# • To what the rewrite made of it, the commit a squash took it into, the one kept below a drop
# • A fold into its commit, reworded or not, found by author and date with no rewrite list kept
#   – a hook's or notes' – while an identity two commits share leaves the hint
# • Matched as `git tag -l` matches, a `*` crossing a `/`
# • An annotated tag re-made there, its message and tagger kept – a signed one left
# • A tag the repo knows is pushed names the push that moves it there
# • Never on a guess by subject or a match by change alone, on a commit the run never rewrote, nor
#   for a run aborted or refused its final update
# • By compare-and-swap from the value read before the lookup, so a tag moved meanwhile stays
#   – and `--undo` puts each back
# • Naming a change moved or squashed across it and the branches still holding its old commit
_ST_SCENARIO "\e[1;96m[264] tags a repo opts in follow the rewrite\e[0m"
local FT_B FT_C FT_ANN FT_WHEN FT_GD FT_X FT_GIT
# Builds base, b, c and d – `cut-l` and `v1` on c, an annotated `cut-a` on d – opting in `cut-*`
_FT_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C a.txt a "FT base" && _ST_PZ_C b.txt b "FT b" && _ST_PZ_C c.txt c "FT c" && _ST_PZ_C d.txt d "FT d"
	git tag cut-l HEAD~1 && git tag v1 HEAD~1
	GIT_COMMITTER_NAME=Q GIT_COMMITTER_EMAIL=q@x.invalid git tag -a -m "FT cut" cut-a HEAD
	git config --add edit.followTag 'cut-*' && git config --add edit.followTag ''
	FT_B=$(git rev-parse HEAD~2) FT_C=$(git rev-parse HEAD~1) FT_ANN=$(git rev-parse cut-a)
	FT_WHEN=$(git for-each-ref --format='%(taggername) %(taggeremail) %(taggerdate:raw)' refs/tags/cut-a)
	FT_GD=$(git rev-parse --absolute-git-dir)
}
_FT_REPO ft-reword
printf 'FT signed\n-----BEGIN PGP SIGNATURE-----\n\nFT\n-----END PGP SIGNATURE-----\n' > "$TMP/ft-sig"
git tag -a -F "$TMP/ft-sig" cut-s "$FT_C"
git tag cut-dir/x "$FT_C"
# A fetch mapping the remote's tags beside its branches – the commit reads as pushed by it too
git remote add origin "$TMP/ft-nowhere.git" && git update-ref refs/remotes/origin/tags/cut-l "$FT_C"
_ST_RUN -M --text="FT b reworded" --allow-pushed "$FT_B"
_ST_EQ "a reword below the tags lands" "$RC" "0"
_ST_EQ "a lightweight tag follows its commit's counterpart" "$(git rev-parse cut-l)" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "saying so" "^Tag cut-l followed the rewrite, ${FT_C:0:12} → $(git rev-parse --short=12 HEAD~1), to its counterpart, the same change\$"
_ST_EQ "an annotated one is re-made on the counterpart" "$(git cat-file -t cut-a):$(git rev-parse 'cut-a^{commit}')" "tag:$(git rev-parse HEAD)"
_ST_EQ "its message and tagger kept, name, email and date" "$(git for-each-ref --format='%(contents:subject)|%(taggername) %(taggeremail) %(taggerdate:raw)' refs/tags/cut-a)" "FT cut|$FT_WHEN"
_ST_EQ "a pattern's * crosses a / as git tag -l reads it" "$(git rev-parse cut-dir/x)" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "a tag the repo knows is pushed names the push moving it there" "^Tag cut-l is pushed and stays there as it was – moving it there too is yours to do: git push --force origin refs/tags/cut-l\$"
_ST_OUT_LACKS "never for one it doesn't know" '^Tag cut-a is pushed'
_ST_EQ "a tag no pattern names stays behind, the empty value naming none" "$(git rev-parse v1)" "$FT_C"
_ST_OUT_HAS "named with its re-point as before" "^  git tag -f v1 $(git rev-parse --short=12 HEAD~1)\$"
_ST_EQ "a signed one stays" "$(git rev-parse 'cut-s^{commit}')" "$FT_C"
_ST_OUT_HAS "saying why" '^Not followed though edit.followTag names it – a moved copy would lose its signature$'
_ST_RUN --undo
_ST_EQ "--undo puts each back, the annotated one to its own tag object" "$RC:$(git rev-parse cut-l):$(git rev-parse cut-a)" "0:$FT_C:$FT_ANN"
_ST_OUT_HAS "saying so" "^Tag cut-l back on ${FT_C:0:12}, where the run found it\$"

_FT_REPO ft-fold
print c2 > c.txt && git add c.txt
_ST_RUN --amend-into="$FT_C" -- c.txt
_ST_EQ "a fold into the tagged commit lands, no hook or notes keeping its rewrite list" \
	"$RC:$(git show HEAD~1:c.txt):$(git config --get-all notes.rewriteRef):$(ls .git/hooks | grep -c '^post-rewrite$')" "0:c2::0"
_ST_EQ "its tag follows what the fold made of it" "$(git rev-parse cut-l)" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "saying so" '^Tag cut-l followed the rewrite, .*, to its counterpart, the one commit of its author and date$'
FT_X=$(git rev-parse HEAD)
git tag -f cut-l "$FT_X" >/dev/null
_ST_RUN --undo
_ST_EQ "--undo leaves a tag moved since where it stands" "$RC:$(git rev-parse cut-l):$(git rev-parse cut-a)" "0:$FT_X:$FT_ANN"
_ST_OUT_HAS "naming it" "^Tag cut-l moved since the run moved it – left where it stands now, the run found it on ${FT_C:0:12}\$"

_FT_REPO ft-fold-text
print c2 > c.txt && git add c.txt
_ST_RUN --amend-into="$FT_C" --text="FT c reworded" -- c.txt
_ST_EQ "a fold rewording its target lands" "$RC:$(git log -1 --format=%s HEAD~1)" "0:FT c reworded"
_ST_EQ "its tag follows the reworded commit" "$(git rev-parse cut-l)" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "saying so" '^Tag cut-l followed the rewrite, .*, to its counterpart, the one commit of its author and date$'

# Two commits of one author, date and subject – a fold into the tagged one finds no single match
_ST_PZ_NEW ft-twins
_ST_PZ_C a.txt a "FT base"
GIT_AUTHOR_DATE="@1700000000 +0000" _ST_PZ_C t1.txt t1 "FT twin"
GIT_AUTHOR_DATE="@1700000000 +0000" _ST_PZ_C t2.txt t2 "FT twin"
git tag cut-w HEAD~1 && git config edit.followTag 'cut-*'
FT_C=$(git rev-parse HEAD~1)
print t1b > t1.txt && git add t1.txt
_ST_RUN --amend-into="$FT_C" -- t1.txt
_ST_EQ "a fold into one of two commits sharing an identity leaves its tag" "$RC:$(git rev-parse cut-w)" "0:$FT_C"
_ST_OUT_HAS "with the hint as before" '^Tag cut-w points into the rewritten span'
_ST_OUT_HAS "saying why it stayed" '^Not followed though edit.followTag names it – another commit has its author, date and subject, so none this run made is told for its own$'

_FT_REPO ft-squash
_ST_RUN -S -y "$FT_C" "$(git rev-parse HEAD)"
_ST_EQ "a squash lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FT c|FT b|FT base|"
_ST_EQ "a tag on its member goes to the squash result" "$(git rev-parse 'cut-a^{commit}')" "$(git rev-parse HEAD)"
_ST_OUT_HAS "saying so" '^Tag cut-a followed the rewrite, .*, to the commit its own was squashed into$'

_FT_REPO ft-drop
_ST_RUN -d -y "$FT_B" "$FT_C"
_ST_EQ "a drop of two lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FT d|FT base|"
_ST_EQ "a tag on a dropped commit goes to the nearest one kept below it, past the other dropped" "$(git rev-parse cut-l)" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "saying so" '^Tag cut-l followed the rewrite, .*, to the nearest commit kept below the one dropped$'

# A drop's replay changing the context of the tagged commit's diff, which leaves an unopted tag
# a guess by subject, follows by author and date – an `--exec` remaking it keeps neither
_ST_PZ_NEW ft-guess
print -l 1 2 3 4 5 6 7 8 > f.txt && git add f.txt && git commit -qm "FT base"
print -l 1 two 3 4 5 6 7 8 > f.txt && git commit -qam "FT two"
print -l 1 two 3 4 five 6 7 8 > f.txt && git commit -qam "FT five"
git tag cut-g HEAD && git config edit.followTag 'cut-*'
_ST_RUN -d -y HEAD~1
_ST_EQ "a replay changing its diff's context still follows" "$RC:$(git rev-parse cut-g)" "0:$(git rev-parse HEAD)"
_ST_OUT_HAS "saying so" '^Tag cut-g followed the rewrite, .*, to its counterpart, the one commit of its author and date$'
FT_C=$(git rev-parse HEAD)
# Its author date pinned a second past the original's – a remake in that same
# second, keeping author and subject too, would read as what the run made of it
_ST_RUN --exec --base="$FT_C" -- sh -c 'git checkout -q --detach HEAD~1 && printf "1\n2\n3\n4\nFIVE\n6\n7\n8\n" > f.txt && GIT_AUTHOR_DATE="$1" git commit -qam "FT five"' - "@$(( $(git log -1 --format=%at) + 1 )) +0000"
_ST_EQ "a guess by subject moves nothing" "$RC:$(git rev-parse cut-g)" "0:$FT_C"
_ST_OUT_HAS "offered to check, as before" '^Tag cut-g points into the rewritten span – a guess at its counterpart'
_ST_OUT_HAS "saying why it stayed" '^Not followed though edit.followTag names it – no commit this run made has its author, date and subject, and its counterpart is only a guess$'

# Replanted by `--base` past main's X, which a cherry-pick on `maint` copies, its tag stays
_ST_PZ_NEW ft-onto
_ST_PZ_C a.txt a "FT base" && _ST_PZ_C x.txt x "FT x"
git tag cut-x && git config edit.followTag 'cut-*'
FT_X=$(git rev-parse HEAD)
git checkout -q -b maint HEAD~1 && _ST_PZ_C p.txt p "FT p" && git cherry-pick "$FT_X" >/dev/null
git checkout -q main && _ST_PZ_C f1.txt f1 "FT f1"
_ST_RUN --onto=maint --base="$FT_X"
_ST_EQ "a tag on a commit the run never replayed stays" "$RC:$(git rev-parse cut-x):$(git log --format=%s maint..main | paste -sd'|' -)" "0:$FT_X:FT f1"
_ST_OUT_HAS "saying why" '^Not followed though edit.followTag names it – no commit this run made has its author, date and subject, and a match by its change alone moves nothing$'

# An `--exec` dropping a tagged cherry-pick of an older commit keeps no
# record of it, so the stale-SHA rule's match below the span moves nothing
_ST_PZ_NEW ft-exec-dup
print -l a b > f.txt && git add f.txt && git commit -qm "FT base"
print -l a x b > f.txt && git commit -qam "FT add x" && FT_X=$(git rev-parse HEAD)
print -l a b > f.txt && git commit -qam "FT revert x"
git cherry-pick "$FT_X" >/dev/null && git tag cut-d && git config edit.followTag 'cut-*'
FT_C=$(git rev-parse HEAD)
_ST_PZ_C w.txt w "FT w"
_ST_RUN --exec --base="$(git rev-parse HEAD)" -- git rebase -q --onto "$FT_C^" "$FT_C"
_ST_EQ "a tag on a commit dropped unrecorded stays" "$RC:$(git rev-parse cut-d):$(git log --format=%s | paste -sd'|' -)" "0:$FT_C:FT w|FT revert x|FT add x|FT base"
_ST_OUT_HAS "saying why" '^Not followed though edit.followTag names it – no commit this run made has its author, date and subject, and a match by its change alone moves nothing$'

# A branch made from a pause holds the run's own rebuild – the branches the run read as it started
# kept with the pause, so its resume in a new process still tells that rebuild for the run's own
_ST_PZ_NEW ft-pause-branch
print -l a b > f.txt && git add f.txt && git commit -qm "FT base"
print -l a x b > f.txt && git commit -qam "FT d" && FT_B=$(git rev-parse HEAD)
_ST_PZ_C t.txt t "FT t" && git tag cut-p && git config edit.followTag 'cut-*'
print -l a X b > f.txt && git commit -qam "FT w"
_ST_RUN -d -y "$FT_B"
_ST_EQ "a drop stops at a later edit of its lines" "$RC" "2"
FT_X=$(_ST_PZ_WT)
git -C "${FT_X:-$ST_NO_WT}" branch save HEAD
_ST_RESOLVE "${FT_X:-$ST_NO_WT}" f.txt "$(print -l a X b)"
_ST_RUN --continue
_ST_EQ "the resume lands, its tag following the rebuild a branch made since holds" \
	"$RC:$(git log --format=%s | paste -sd'|' -):$(git rev-parse cut-p)" "0:FT w|FT t|FT base:$(git rev-parse HEAD~1)"
_ST_OUT_HAS "saying so" '^Tag cut-p followed the rewrite, .*, to its counterpart, the one commit of its author and date$'

# A peer re-pointing the tag while the run looks its counterpart up
# – a git that does so once, at the lookup's first read of the span
_FT_REPO ft-lookup-race
git tag -d cut-a >/dev/null
FT_GIT=$(whence -p git)
mkdir -p "$TMP/ft-shim"
printf '#!/bin/sh
for a; do case "$a" in "--format=%%H %%an"*) [ -e "%s/ft-arm" ] && rm -f "%s/ft-arm" && "%s" update-ref refs/tags/cut-l %s ;; esac; done
exec "%s" "$@"
' \
	"$FT_GD" "$FT_GD" "$FT_GIT" "$FT_B" "$FT_GIT" > "$TMP/ft-shim/git"
chmod +x "$TMP/ft-shim/git"
: > "$FT_GD/ft-arm"
print c2 > c.txt && git add c.txt
PATH="$TMP/ft-shim:$PATH" _ST_RUN --amend-into="$FT_C" -- c.txt
_ST_EQ "the lookup ran, the peer moving the tag in it" "$RC:$([ -e "$FT_GD/ft-arm" ] && echo armed)" "0:"
_ST_EQ "a tag moved during the lookup stays where the peer put it" "$(git rev-parse cut-l)" "$FT_B"
_ST_OUT_HAS "saying so" '^Tag cut-l moved meanwhile, by another run or by hand – left where it stands now$'

# A change moved or squashed across the tag is named – a fixup folded below it is not
_FT_REPO ft-across
_ST_RUN --move="$FT_B" --after="$(git rev-parse HEAD)"
_ST_EQ "a move across the tag lands, the tag following its commit" "$RC:$(git log -1 --format=%s cut-l):$(git ls-tree --name-only cut-l | paste -sd' ' -)" "0:FT c:a.txt c.txt"
_ST_OUT_HAS "naming the change it no longer holds" "^Tag cut-l's commit no longer holds the change of what this run moved above it: FT b\$"
_FT_REPO ft-across-squash
_ST_RUN -s="$FT_B" -y "$(git rev-parse HEAD)"
_ST_EQ "a squash across the tag lands" "$RC:$(git ls-tree --name-only cut-l | paste -sd' ' -)" "0:a.txt b.txt c.txt d.txt"
_ST_OUT_HAS "naming the change it now holds" "^Tag cut-l's commit now holds the change of what this run moved or squashed below it: FT d\$"
_FT_REPO ft-auto
print b2 > b.txt
GIT_EDIT_ACTOR=ft-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "fixup! FT b" -- b.txt </dev/null >/dev/null 2>&1
GIT_EDIT_ACTOR=ft-self _ST_RUN -s=auto
_ST_EQ "an -s=auto folding a fixup below the tag follows" "$RC:$(git log --format=%s | paste -sd'|' -):$(git rev-parse cut-l)" "0:FT d|FT c|FT b|FT base:$(git rev-parse HEAD~1)"
_ST_OUT_HAS "saying so" '^Tag cut-l followed the rewrite'
_ST_OUT_LACKS "never naming the fixup as moved across" "^Tag cut-l's commit now holds"

# A branch still holding the tag's old commit is named, the tag following the run's branch
_FT_REPO ft-shared
git branch rel "$FT_C"
_ST_RUN -M --text="FT b reworded" "$FT_B"
_ST_EQ "the tag follows the run's branch" "$RC:$(git rev-parse cut-l)" "0:$(git rev-parse HEAD~1)"
_ST_OUT_HAS "naming the branch still holding its old commit" '^Tag cut-l no longer marks its old commit on the branches still holding it: rel$'

# A land moves no tag – the branch it lands on only advances
_FT_REPO ft-land
git checkout -q -b topic && _ST_PZ_C t.txt t "FT t" && git tag cut-t
git checkout -q main && _ST_PZ_C e.txt e "FT e"
_ST_RUN --land=topic
_ST_EQ "a land replaying the branch lands, moving no tag" "$RC:$(git log -1 --format=%s):$(git rev-parse cut-l):$(git log -1 --format=%s cut-t)" "0:FT t:$FT_C:FT t"
_ST_OUT_LACKS "nor naming one" '^Tag cut-'

# An annotated tag without a tagger, as early git made them, is re-made so
_FT_REPO ft-no-tagger
printf 'object %s\ntype commit\ntag cut-n\n\nFT bare\n' "$FT_C" > "$TMP/ft-bare"
git update-ref refs/tags/cut-n "$(git hash-object -t tag -w --literally "$TMP/ft-bare")"
_ST_RUN -M --text="FT b reworded" "$FT_B"
_ST_EQ "an annotated tag without a tagger follows, re-made without one" \
	"$RC:$(git cat-file -t cut-n):$(git rev-parse 'cut-n^{commit}'):$(git cat-file tag cut-n | grep -c '^tagger'):$(git for-each-ref --format='%(contents:subject)' refs/tags/cut-n)" \
	"0:tag:$(git rev-parse HEAD~1):0:FT bare"

_FT_REPO ft-abort
_ST_RUN -d -y --verify=false "$FT_C"
_ST_EQ "a drop its gate fails pauses" "$RC" "2"
_ST_RUN --abort
_ST_EQ "aborted, it moves no tag" "$RC:$(git rev-parse cut-l):$(git rev-parse cut-a)" "0:$FT_C:$FT_ANN"
_ST_RUN -d -y --verify=false "$FT_C"
_ST_RUN --no-verify --continue
_ST_EQ "continued past the gate, its tags follow" "$RC:$(git rev-parse cut-l):$(git rev-parse 'cut-a^{commit}')" "0:$FT_B:$(git rev-parse HEAD)"

_FT_REPO ft-veto
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nexit 1\n' > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
_ST_RUN -M --text="FT b reworded" "$FT_B"
_ST_EQ "a run refused its final update moves no tag" "$RC:$(git rev-parse cut-l):$(git rev-parse cut-a)" "1:$FT_C:$FT_ANN"
rm -f .git/hooks/reference-transaction

# Another run moving the tag between the read and the move
# – a hook at the move's `preparing` stage (git 2.54+) re-points it first
_FT_REPO ft-race
printf '#!/bin/sh\n[ "$1" = preparing ] || exit 0\ngrep -q " refs/tags/cut-l$" || exit 0\n[ -e "%s/ft-arm" ] || exit 0\nrm -f "%s/ft-arm"\ngit update-ref refs/tags/cut-l %s\n' \
	"$FT_GD" "$FT_GD" "$FT_B" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > "$FT_GD/ft-arm"
_ST_RUN -M --text="FT b reworded" "$FT_B"
if [ -e "$FT_GD/ft-arm" ]; then
	ECHO_E "\e[0;90m  skipped – this git runs no reference-transaction hook at its preparing stage\e[0m"
else
	_ST_EQ "a tag moved meanwhile stays where it was put" "$RC:$(git rev-parse cut-l)" "0:$FT_B"
	_ST_OUT_HAS "saying so" '^Tag cut-l moved meanwhile, by another run or by hand – left where it stands now$'
	_ST_EQ "the others follow all the same" "$(git rev-parse 'cut-a^{commit}')" "$(git rev-parse HEAD)"
fi
rm -f .git/hooks/reference-transaction
unfunction _FT_REPO
cd "$TMP/repo"
