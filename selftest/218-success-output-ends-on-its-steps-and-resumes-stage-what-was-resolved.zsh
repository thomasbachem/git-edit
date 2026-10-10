# What a run prints leads to the next step, and a resume takes what the caller resolved:
# • A landing's output names its undo alone – the raw undo's re-sync and carry steps come from
#   `--status` for the last run, and from an `--undo` finding it taken back already
# • `--status` names a checkout left behind – its mark below the tip, with the bare carry, and the
#   files a sync left unbrought, with the carry from their base, until merged
# • A resume stages each conflicted file whose markers are gone, in every mode that replays – one
#   given none stays, named with the step staging it, and markers still there continue the conflict
# • A squash changing the tip refuses before its gate runs, naming the paths
# • A commit at a peer's renamed file holding that landing goes ahead, one lacking it refuses
# • A put composed in scratch merges into the checkout file, as an edit does
# • `-h` names the authored split point, the man page what an `auto` fold beside inputs judges
_ST_SCENARIO "\e[1;96m[218] success output ends on its steps, and resumes stage what was resolved\e[0m"
local SO_WT SO_A SO_B SO_C SO_OLD SO_NEW SO_JF SO_MAN

# Makes and enters repo <name> holding `f.txt` "1", then a commit per further <content>
_SO218_REPO () {
	# Args: <name> <content>...
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	_ST_PZ_C f.txt 1 "SO base"
	shift
	local C
	for C in "$@"; do _ST_PZ_C f.txt "$C" "SO $C"; done
}

# A drop's output keeps its undo and leaves the raw undo's steps to `--status`, which names them for
# the last run – run as printed, they take the run back whole, and the undo then finds it back
_SO218_REPO s1 2 3
print -r -- g > g.txt && git add g.txt && git commit -qm "SO g"
SO_OLD=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1
SO_NEW=$(git rev-parse HEAD)
_ST_OUT_HAS "a landing names its undo" '^Undo: git edit --undo  (or, the ref alone: git update-ref '
_ST_OUT_LACKS "but no raw undo's re-sync step" 'After the raw undo'
_ST_OUT_LACKS "nor its carry" 'Then bring the checkout back'
_ST_RUN --status
_ST_OUT_HAS "--status names the last run's undo" '^Undo: git edit --undo  (or, the ref alone: git update-ref '
_ST_OUT_HAS "and the raw undo's re-sync step" "^After the raw undo, re-sync the entries it leaves staged as this run's content – [^:]*: git diff-index --cached --exit-code --name-only ${SO_NEW:0:12} -- f.txt && git restore --staged -- f.txt$"
_ST_OUT_HAS "and its carry" "^Then bring the checkout back with it, as git edit --undo would: git edit --carry=${SO_NEW:0:12}$"
eval "$(print -r -- "$OUT" | sed -n 's/^Undo: git edit --undo  (or, the ref alone: \(.*\))$/\1/p')"
_ST_RUN --undo
_ST_OUT_HAS "an undo finding it taken back names the steps left" "^After the raw undo, re-sync the entries"
eval "$(print -r -- "$OUT" | sed -n 's/^After the raw undo, re-sync [^:]*: //p')"
mkdir -p "$TMP/so-bin" && ln -sf "$SELF" "$TMP/so-bin/git-edit"
PATH="$TMP/so-bin:$PATH" eval "$(print -r -- "$OUT" | sed -n 's/^Then bring the checkout back with it, as git edit --undo would: //p')" >/dev/null 2>&1
_ST_EQ "which take the run back whole" "$(git rev-parse HEAD):$(git status --porcelain | tr '\n' '|'):$(<f.txt)" "$SO_OLD::3"
_ST_RUN --status
_ST_OUT_LACKS "and are named no more once run" 'After the raw undo'

# A checkout a landing left behind is named, with the bare carry, until brought along
_SO218_REPO s2 2
print -r -- g > g.txt && git add g.txt && git commit -qm "SO g"
SO_OLD=$(git rev-parse HEAD)
_ST_RUN_UNSYNCED -d -y HEAD
_ST_RUN --status
_ST_OUT_HAS "--status names a checkout left behind, with the bare carry" "^Your checkout was left behind at ${SO_OLD:0:7}, the landings since not brought along – bring it along with: git edit --carry$"
_ST_RUN --carry
_ST_RUN --status
_ST_OUT_LACKS "and not once it is brought along" 'left behind'
# A file a sync left on a conflict is named, with the carry from its base, until merged by hand
_SO218_REPO s3 2 3
SO_OLD=$(git rev-parse HEAD)
print -r -- 3-mine > f.txt
_ST_RUN -d -y HEAD
_ST_RUN --status
_ST_OUT_HAS "--status names a file a sync left unbrought, with the carry from its base" "^Left unbrought by a run's sync, still lacking what landed past ${SO_OLD:0:7}: f.txt – bring them along with: git edit --carry=${SO_OLD:0:12}$"
_ST_OUT_LACKS "the checkout itself brought along" 'left behind at'
print -l 2 mine > f.txt
_ST_RUN --status
_ST_OUT_LACKS "and not once the file holds what landed" 'Left unbrought'

# A resume stages a file whose markers are gone – a drop's, a reorder's, a fold's, an edit's, a
# replant's – and continues the conflict over one still holding them
_SO218_REPO s4 2 3
_ST_RUN -d -y HEAD~1
SO_WT=$(_ST_PZ_WT)
_ST_RUN --continue
_ST_OUT_HAS "markers still there continue the conflict" "Conflict continues – resolve more files"
print -r -- 3 > "${SO_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "a drop's resume stages a file its markers left" "$RC:$(git show HEAD:f.txt)" "0:3"
_ST_OUT_HAS "naming it" '^Staged as resolved, their markers gone: f.txt$'
_ST_PZ_NEW s5
git config rerere.enabled false
print -l 1 2 3 > f.txt && git add f.txt && git commit -qm "SO base"
print -l 1 B 3 > f.txt && git commit -qam "SO B" && SO_B=$(git rev-parse HEAD)
print -l 1 B C > f.txt && git commit -qam "SO C" && SO_C=$(git rev-parse HEAD)
_ST_RUN --reorder "$SO_C" "$SO_B"
SO_WT=$(_ST_PZ_WT)
for SO_A in "1 2 C" "1 B C"; do
	[ -f .git/git-edit-state ] || break
	print -l ${=SO_A} > "${SO_WT:-$ST_NO_WT}/f.txt"
	_ST_RUN --continue
done
_ST_EQ "a reorder's" "$RC:$(git log --format=%s -2 | tr '\n' '|')" "0:SO B|SO C|"
_SO218_REPO s6 2
SO_A=$(git rev-parse HEAD~1)
print -r -- 2y > f.txt && git add f.txt
_ST_RUN --amend-into="$SO_A" -- f.txt
SO_WT=$(_ST_PZ_WT)
for SO_B in 1y 2y; do
	[ -f .git/git-edit-state ] || break
	print -r -- "$SO_B" > "${SO_WT:-$ST_NO_WT}/f.txt"
	_ST_RUN --continue
done
_ST_EQ "a fold's" "$RC:$(git show HEAD~1:f.txt):$(git show HEAD:f.txt)" "0:1y:2y"
_SO218_REPO s7 2 3
_ST_RUN HEAD~1
SO_WT=$(_ST_PZ_WT)
print -r -- 2x > "${SO_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
print -r -- 3 > "${SO_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "an edit's replay" "$RC:$(git show HEAD~1:f.txt):$(git show HEAD:f.txt)" "0:2x:3"
_SO218_REPO s8 2
git checkout -q -b feat && _ST_PZ_C f.txt feat "SO feat"
git checkout -q main && _ST_PZ_C f.txt main "SO main"
git checkout -q feat
_ST_RUN --onto=main
SO_WT=$(_ST_PZ_WT)
print -r -- both > "${SO_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "a replant's" "$RC:$(git show HEAD:f.txt):$(git rev-parse HEAD~1)" "0:both:$(git rev-parse main)"
git checkout -q main
# A file git gave no markers – a side's deletion – stays unstaged, named with the step staging it
_SO218_REPO s9 2
print -r -- g > g.txt && git add g.txt && git commit -qm "SO g"
print -r -- g2 > g.txt && git commit -qam "SO g2"
git rm -q g.txt && git commit -qm "SO g gone"
_ST_RUN -d -y HEAD~1
SO_WT=$(_ST_PZ_WT)
_ST_RUN --continue
_ST_OUT_HAS "a file given no markers stays unstaged, said so" '^Nothing tells a resolution of g.txt – no conflict markers to go by, so they stay unstaged$'
_ST_OUT_HAS "with the step staging it as it stands" "then git edit --continue: git -C $(_SHQ "${SO_WT:-$ST_NO_WT}") add -- g.txt$"
_ST_OUT_LACKS "never as more files to resolve" 'resolve more files'
git -C "${SO_WT:-$ST_NO_WT}" rm -q -- g.txt
_ST_RUN --continue
_ST_EQ "staged so, it lands" "$RC:$(git ls-tree --name-only HEAD | tr '\n' '|')" "0:f.txt|"

# A squash whose resolution changed the tip refuses before its gate runs, naming the paths
_SO218_REPO s10 t2 t3 t4
SO_OLD=$(git rev-parse HEAD)
git config edit.verifyCmd false
_ST_RUN -s="$(git rev-parse HEAD~2)" -y HEAD
SO_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${SO_WT:-$ST_NO_WT}" f.txt t4
_ST_RUN --continue
_ST_RESOLVE "${SO_WT:-$ST_NO_WT}" f.txt t3
_ST_RUN --continue
_ST_EQ "a squash changing the tip lands nothing" "$RC:$(git rev-parse HEAD)" "1:$SO_OLD"
_ST_OUT_HAS "refusing before its gate, naming the path" "The squash would change the tip's content, at f.txt – not applied"
_ST_OUT_LACKS "never pausing at the gate first" 'Verification failed'
_ST_RUN --abort

# A commit at a file a peer's landing of days ago renamed and edited, holding that edit, goes ahead
# – one whose file lacks it refuses, the carry reading it at its old name
_ST_PZ_NEW s11
mkdir -p old new && print -l l{1..9} > old/t.js && print -r -- x > x.txt && git add -A && git commit -qm "SO base"
git mv old/t.js new/t.js && git reset -q && sed -i.bak 's/^l3$/l3 peer/' new/t.js
GIT_EDIT_ACTOR=peer _ST_RUN --commit --text "SO move" -- old/t.js new/t.js
SO_JF=$(git rev-parse --git-common-dir)/git-edit-journal
sed -i.bak -E "s/^[0-9]+ /$(( EPOCHSECONDS - 5 * 86400 )) /" "$SO_JF"
cp new/t.js "$TMP/so11.js"
sed -i.bak 's/^l7$/l7 mine/' new/t.js
GIT_EDIT_ACTOR=me _ST_RUN --commit --text "SO mine" --after="$(git rev-parse HEAD~1)" -- new/t.js
_ST_EQ "a file at the new name holding the landing commits" "$RC:$(git show HEAD:new/t.js | tr '\n' '|')" "0:l1|l2|l3 peer|l4|l5|l6|l7 mine|l8|l9|"
sed 's/^l3 peer$/l3/;s/^l8$/l8 mine/' "$TMP/so11.js" > new/t.js
GIT_EDIT_ACTOR=me _ST_RUN --commit --text "SO stale" -- new/t.js
_ST_EQ "one lacking it refuses" "$RC" 1
_ST_OUT_HAS "reading it at its old name" 'on its old name old/t\.js'

# A put composed in scratch merges into a checkout file lacking it, a peer's line there kept – one
# the checkout holds already takes its entry alone, as does one whose lines the file changed
# further, the caller's later work, left on record
_ST_PZ_NEW s12
print -l a b c d e > f && git add f && git commit -qm "SO base"
print -l a b c d PEER > f
print -l MINE b c d e > "$TMP/so12.put"
_ST_RUN --commit --text "SO put" --put f="$TMP/so12.put"
_ST_EQ "a put composed in scratch merges into the file" "$RC:$(git show HEAD:f | tr '\n' ' '):$(tr '\n' ' ' < f)" "0:MINE b c d e :MINE b c d PEER "
_ST_OUT_LACKS "never read as later edits of the caller's" 'keep your later edits'
print -l MINE2 b c d e > "$TMP/so12.put"
print -l MINE2 b c d PEER > f
_ST_RUN --commit --text "SO put 2" --put f="$TMP/so12.put"
_ST_EQ "one the checkout file holds already takes its entry alone" "$RC:$(git show :f | tr '\n' ' '):$(tr '\n' ' ' < f)" "0:MINE2 b c d e :MINE2 b c d PEER "
_ST_OUT_HAS "its later edits named so" 'keep your later edits, now changes to what landed: f$'
print -l MINE3 b c d e > "$TMP/so12.put"
print -l OTHER b c d PEER > f
_ST_RUN --commit --text "SO put 3" --put f="$TMP/so12.put"
_ST_EQ "one whose line the file changed further lands, the file as it was" "$RC:$(git show HEAD:f | head -1):$(tr '\n' ' ' < f)" "0:MINE3:OTHER b c d PEER "
_ST_OUT_HAS "named as later edits" 'keep your later edits, now changes to what landed: f$'
_ST_OUT_LACKS "no merge offered" 'git merge-file -- f '
_ST_RUN --status
_ST_OUT_HAS "and left on record" '^Left unbrought by a run.s sync, still lacking what landed past [0-9a-f]*: f – '

# The docs name what an agent looks for
_ST_RUN -h
_ST_OUT_HAS "-h names the authored split point" 'authored split'
SO_MAN="$(dirname "$SELF")/man/man1/git-edit.1"
[ -f "$SO_MAN" ] || SO_MAN="$(dirname "$SELF")/../share/man/man1/git-edit.1"
_ST_EQ "the man page says an auto fold beside inputs judges every landing" "$(command grep -c 'judges every landing' "$SO_MAN")" 1
