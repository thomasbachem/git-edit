# Each replayed commit pairs with its own pick by git's record of the replay – a pick git left out
# pairs with nothing, commits of one author and second included – so an absorption among them
# refuses naming its victim and a hand finish reads each commit against its own original, while a
# line the stop's own fold rewrites never counts as taken in, a later rename of the file landing –
# and a pick git left out, its whole change taken in at a stop, refuses too
_ST_SCENARIO "\e[1;96m[160] replays pair by git's record, a stop's own lines are never taken in\e[0m"
local RP_D="@1760000000 +0000" RP_T RP_B RP_WT RP_V
# Commits <file> holding <line>... as <subject>, every one in the same second
_RP_C () {
	# Args: <file> <subject> <line>...
	print -l -- "${@:3}" > "$1" && git add -- "$1" && GIT_AUTHOR_DATE=$RP_D GIT_COMMITTER_DATE=$RP_D git commit -qm "$2"
}
# Takes the record step out of a pause's todo, as a replay that never saved one would run
_RP_NO_RECORD () {
	local TODO=$(git -C "$1" rev-parse --path-format=absolute --git-path rebase-merge/git-rebase-todo 2>/dev/null)
	[ -f "$TODO" ] && LC_ALL=C sed -i.rp '/git-edit-replayed/d' "$TODO"
}
# Writes the six-line file to <path>, each of alpha, delta, epsilon and gamma suffixed
_RP_W () {
	# Args: <alpha's> <delta's> <epsilon's> <gamma's> <path>
	print -l -- alpha$1 beta gamma$4 delta$2 epsilon$3 zeta > "$5"
}
# One author and second: a drop's stop taking in a later commit's line, a pick between them left
# out as emptied, refuses naming that commit – the pick git left out shifts no pairing
_ST_PZ_NEW rp1
_RP_C f.txt "RP1 base" 1 2 3 4 5 6 7 8 9 10 11 12
_RP_C f.txt "RP1 Y add debug" 1 2 DEBUG 3 4 5 6 7 8 9 10 11 12
_RP_C f.txt "RP1 Z edit line 3" 1 2 DEBUG 3z 4 5 6 7 8 9 10 11 12
_RP_C f.txt "RP1 X remove debug" 1 2 3z 4 5 6 7 8 9 10 11 12
_RP_C f.txt "RP1 V edit 8 and 12" 1 2 3z 4 5 6 7 a8 9 10 11 a12
_RP_C g.txt "RP1 top" g
RP_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~4
RP_WT=$(_ST_PZ_WT)
_ST_EQ "the stop's todo saves git's record in a step of its own" "$(grep -c 'git-edit-replayed' "$(git -C "${RP_WT:-$ST_NO_WT}" rev-parse --path-format=absolute --git-path rebase-merge/git-rebase-todo 2>/dev/null)" 2>/dev/null)" "1"
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 a8 9 10 11 12)"
_ST_RUN --continue
_ST_EQ "a stop taking in a later commit's line among commits of one second refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming that commit, past the pick left out" 'RP1 V edit 8 and 12 – f.txt'
_ST_RUN --abort
_ST_RUN -d -y HEAD~4
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9 10 11 12)"
_ST_RUN --continue
_ST_EQ "while its stop resolved to its own content lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:RP1 top|RP1 V edit 8 and 12|RP1 Z edit line 3|RP1 base|"
_ST_OUT_HAS "the later revert the drop emptied named as such" 'emptied: [0-9a-f]* RP1 X remove debug'
# Where the replay saved no record, the pairing by author and second tells the picks
# apart by their patch and subject
git reset -q --hard "$RP_T"
_ST_RUN -d -y HEAD~4
RP_WT=$(_ST_PZ_WT)
_RP_NO_RECORD "${RP_WT:-$ST_NO_WT}"
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 a8 9 10 11 12)"
_ST_RUN --continue
_ST_EQ "without a record the absorption refuses too" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming the same commit" 'RP1 V edit 8 and 12 – f.txt'
_ST_RUN --abort
# A stop whose resolution took in a later commit's whole change, git leaving that commit out as
# emptied, refuses naming it – a drop's, and a fold's resolved to the tip's content
_ST_PZ_NEW rp9
print -l 1 2 3 4 5 6 7 8 9 10 11 12 > f.txt && git add f.txt && git commit -qm "RP9 base"
print -l 1 2 DEBUG 3 4 5 6 7 8 9 10 11 12 > f.txt && git commit -qam "RP9 Y add debug"
print -l 1 2 DEBUG 3z 4 5 6 7 8 9 10 11 12 > f.txt && git commit -qam "RP9 Z edit line 3"
print -l 1 2 DEBUG 3z 4 5 6 7 8 9 10 11 12w > f.txt && git commit -qam "RP9 W edit line 12"
print g > g.txt && git add g.txt && git commit -qm "RP9 top"
RP_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~3
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9 10 11 12w)"
_ST_RUN --continue
_ST_EQ "a drop's stop taking in a later commit whole refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming the commit git left out" 'RP9 W edit line 12 – f.txt (left out as emptied)'
_ST_RUN --abort
_ST_PZ_NEW rp10
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 13 14 > f.txt && git add f.txt && git commit -qm "RP10 base"
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 13 T14 > f.txt && git commit -qam "RP10 target"
RP_B=$(git rev-parse HEAD)
print -l -- 1 2 3 4 5 6 7 a8 9 10 11 a12 13 T14 > f.txt && git commit -qam "RP10 later only f"
print g > g.txt && git add g.txt && git commit -qm "RP10 top"
RP_T=$(git rev-parse HEAD)
print -l -- 1 2 3 4 5 6 7 a8 E9 10 11 a12 13 T14 > f.txt
_ST_RUN --amend-into="$RP_B" --whole -- f.txt
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 5 6 7 a8 E9 10 11 a12 13 T14)"
_ST_RUN --continue
git -C "${RP_WT:-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a fold's stop taking in a later commit whole, its step skipped, refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming the commit left out" 'RP10 later only f – f.txt (left out as emptied)'
_ST_RUN --abort
git checkout -q -- f.txt
# While a fold of the very change a later commit made, no stop on its file, lands with
# that commit dropped as emptied
_ST_PZ_NEW rp11
print -l 1 2 3 4 5 6 7 8 9 > f.txt && print -l a b c > g.txt && git add -A && git commit -qm "RP11 base"
print -l 1 2 3 4 5 6 7 8 T9 > f.txt && git commit -qam "RP11 T edit 9"
RP_B=$(git rev-parse HEAD)
print -l a bL c > g.txt && git commit -qam "RP11 L edit b"
print -l a b c > g.txt && git commit -qam "RP11 U undo L"
print h > h.txt && git add h.txt && git commit -qm "RP11 top"
print -l a bL c > g.txt && git add g.txt
_ST_RUN --amend-into="$RP_B"
git -C "${$(_ST_PZ_WT):-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a fold of a change a later commit made, no stop on its file, lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:RP11 top|RP11 U undo L|RP11 T edit 9|RP11 base|"
_ST_OUT_HAS "that commit dropped as emptied" 'dropped: [0-9a-f]* RP11 L edit b'
# Commits sharing author, second and subject alike: the victim named is the replay of its own pick
_ST_PZ_NEW rp2
_RP_C f.txt "RP2 base" 1 2 3 4 5 6 7 8 9 10 11 12
_RP_C f.txt "wip" 1 2 DEBUG 3 4 5 6 7 8 9 10 11 12
_RP_C f.txt "wip" 1 2 DEBUG 3z 4 5 6 7 8 9 10 11 12
_RP_C f.txt "wip" 1 2 3z 4 5 6 7 8 9 10 11 12
_RP_C f.txt "wip" 1 2 3z 4 5 6 7 a8 9 10 11 a12
_RP_C g.txt "wip" g
RP_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~4
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 a8 9 10 11 12)"
_ST_RUN --continue
RP_V=$(git -C "${RP_WT:-$ST_NO_WT}" log -1 --format=%h HEAD~1 2>/dev/null)
_ST_EQ "one subject throughout, the absorption refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming the replay of the commit that lost the line" "${RP_V:-none} wip – f.txt"
_ST_EQ "and that commit alone" "$(grep -c -e '– f.txt' <<<"$OUT")" "1"
_ST_RUN --abort
# Builds that history in a repo of its own, whose drop of `HEAD~4` stops at the next commit, the one
# after it then left out as emptied
_RP_HAND () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	_RP_C f.txt "RP3 base" 1 2 3 4 5 6 7 8 9
	print e > e.txt && git add e.txt && _RP_C f.txt "RP3 Y add debug and e" 1 2 DEBUG 3 4 5 6 7 8 9
	_RP_C f.txt "RP3 Z edit line 3" 1 2 DEBUG 3z 4 5 6 7 8 9
	git rm -q e.txt && GIT_AUTHOR_DATE=$RP_D GIT_COMMITTER_DATE=$RP_D git commit -qm "RP3 X remove e"
	print -r -- $'Install\n=======' > README.rst && git add README.rst && GIT_AUTHOR_DATE=$RP_D GIT_COMMITTER_DATE=$RP_D git commit -qm "RP3 R docs"
	_RP_C g.txt "RP3 top" g
	RP_T=$(git rev-parse HEAD)
}
# A hand finish past a pick git left out reads each commit against its own original's markers –
# an underline a commit brings lands, while markers the stop's resolution committed refuse
_RP_HAND rp3
_ST_RUN -d -y HEAD~4
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9)"
GIT_EDITOR=true git -C "${RP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a hand finish past a pick left out, a commit bringing an underline, lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:RP3 top|RP3 R docs|RP3 Z edit line 3|RP3 base|"
# Where no recorded resolution resolves the stop
_RP_HAND rp3m
_ST_RUN -d -y HEAD~4
RP_WT=$(_ST_PZ_WT)
git -C "${RP_WT:-$ST_NO_WT}" add -A && GIT_EDITOR=true git -C "${RP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "while one committing the stop's markers refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming the file that carries them" 'committed conflict markers'
_ST_OUT_HAS "in the stop's own commit" '[0-9a-f] f.txt'
_ST_OUT_LACKS "never the commit bringing its own underline" 'README.rst'
_ST_RUN --abort
# A fold's stop resolved to the target with the fold, then a later commit renaming the file – its
# replay removes the folded line where the original removed the old one – lands
_ST_PZ_NEW rp4
_RP_W "" "" "" "" f.txt && git add f.txt && git commit -qm "RP4 base"
_RP_W T "" "" "" f.txt && git commit -qam "RP4 T edit alpha"
RP_B=$(git rev-parse HEAD)
_RP_W T N "" "" f.txt && git commit -qam "RP4 N edit delta"
git mv f.txt f2.txt && git commit -qm "RP4 L rename f to f2"
_RP_W T N F "" f2.txt && git add f2.txt
_ST_RUN --amend-into="$RP_B"
RP_WT=$(_ST_PZ_WT)
[ -n "$RP_WT" ] && _RP_W T "" F "" "$RP_WT/f.txt" && git -C "$RP_WT" add f.txt
_ST_RUN --continue
_ST_OUT_HAS "the next stop lists what remains" 'Remaining steps'
_ST_OUT_LACKS "never the record's step among it" 'git-edit-replayed'
[ -n "$RP_WT" ] && _RP_W T N F "" "$RP_WT/f.txt" && git -C "$RP_WT" add f.txt
_ST_RUN --continue
_ST_EQ "a fold's stop file renamed by a later commit lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f2.txt | tr '\n' ' ')" \
	"0:RP4 L rename f to f2|RP4 N edit delta|RP4 T edit alpha|RP4 base|:alphaT beta gamma deltaN epsilonF zeta "
# As does one moving the file with an edit of its own
_ST_PZ_NEW rp5
_RP_W "" "" "" "" f.txt && git add f.txt && git commit -qm "RP5 base"
_RP_W T "" "" "" f.txt && git commit -qam "RP5 T edit alpha"
RP_B=$(git rev-parse HEAD)
_RP_W T N "" "" f.txt && git commit -qam "RP5 N edit delta"
git rm -q f.txt && _RP_W T N "" L f2.txt && git add f2.txt && git commit -qm "RP5 L move f to f2, edit gamma"
_RP_W T N F L f2.txt && git add f2.txt
_ST_RUN --amend-into="$RP_B"
RP_WT=$(_ST_PZ_WT)
[ -n "$RP_WT" ] && _RP_W T "" F "" "$RP_WT/f.txt" && git -C "$RP_WT" add f.txt
_ST_RUN --continue
[ -n "$RP_WT" ] && _RP_W T N F "" "$RP_WT/f.txt" && git -C "$RP_WT" add f.txt
_ST_RUN --continue
_ST_EQ "as does one moving it with an edit of its own" "$RC:$(git show HEAD:f2.txt | tr '\n' ' '):$(git cat-file -e HEAD:f.txt 2>/dev/null || echo gone)" \
	"0:alphaT beta gammaL deltaN epsilonF zeta :gone"
# While a fold's stop taking in a later commit's line refuses, naming it, a rename following
_ST_PZ_NEW rp6
_RP_W "" "" "" "" f.txt && git add f.txt && git commit -qm "RP6 base"
_RP_W T "" "" "" f.txt && git commit -qam "RP6 T edit alpha"
RP_B=$(git rev-parse HEAD)
_RP_W T N "" N f.txt && git commit -qam "RP6 N edit gamma and delta"
git mv f.txt f2.txt && git commit -qm "RP6 L rename f to f2"
RP_T=$(git rev-parse HEAD)
_RP_W T N F N f2.txt && git add f2.txt
_ST_RUN --amend-into="$RP_B"
RP_WT=$(_ST_PZ_WT)
[ -n "$RP_WT" ] && _RP_W T N F "" "$RP_WT/f.txt" && git -C "$RP_WT" add f.txt
_ST_RUN --continue
[ -n "$RP_WT" ] && _RP_W T N F N "$RP_WT/f.txt" && git -C "$RP_WT" add f.txt
_ST_RUN --continue
_ST_EQ "a fold's stop taking in a later commit's line refuses, a rename following" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming the commit that lost it" 'RP6 N edit gamma and delta – f.txt'
_ST_OUT_LACKS "never the rename" 'RP6 L rename f to f2 – f.txt'
_ST_RUN --abort
# A stop taking in a later commit's pure deletion refuses – a fold's, and a reorder's whose stop
# put its own lines in place of a block the later commit deletes – while keeping the block lands
_ST_PZ_NEW rp7
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 13 14 > f.txt && git add f.txt && git commit -qm "RP7 base"
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 13 T14 > f.txt && git commit -qam "RP7 target"
RP_B=$(git rev-parse HEAD)
print -l -- 1 2 3 4 8 9 10 L11 12 13 T14 > f.txt && git commit -qam "RP7 later deletes 5-7, edits 11"
print g > g.txt && git add g.txt && git commit -qm "RP7 top"
RP_T=$(git rev-parse HEAD)
print -l -- 1 2 3 4 8 9 10 L11 E12 13 T14 > f.txt
_ST_RUN --amend-into="$RP_B" --whole -- f.txt
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 8 9 10 11 E12 13 T14)"
_ST_RUN --continue
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 8 9 10 L11 E12 13 T14)"
_ST_RUN --continue
_ST_EQ "a fold's stop taking in a later commit's deletion refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming that commit" 'RP7 later deletes 5-7, edits 11 – f.txt'
_ST_RUN --abort
git checkout -q -- f.txt && print -l -- 1 2 3 4 8 9 10 L11 E12 13 T14 > f.txt
_ST_RUN --amend-into="$RP_B" --whole -- f.txt
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 5 6 7 8 9 10 11 E12 13 T14)"
_ST_RUN --continue
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 8 9 10 L11 E12 13 T14)"
_ST_RUN --continue
_ST_EQ "one keeping the block lands, the later commit deleting it" "$RC:$(git diff HEAD~2 HEAD~1 -- f.txt | grep -c '^-[5-7]$')" "0:3"
_ST_PZ_NEW rp8
print -l a b p d1 d2 d3 d4 q r s t u v w > f.txt && git add f.txt && git commit -qm "RP8 base"
print -l a b p q r s t u v w2 > f.txt && git commit -qam "RP8 A delete block, edit w"
print -l a b p n1 n2 n3 q r s t u v w2 > f.txt && git commit -qam "RP8 B insert where the block was"
print g > g.txt && git add g.txt && git commit -qm "RP8 top"
RP_T=$(git rev-parse HEAD)
_ST_RUN --move=HEAD~1 --before=HEAD~2
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l a b p n1 n2 n3 q r s t u v w)"
_ST_RUN --continue
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l a b p n1 n2 n3 q r s t u v w2)"
_ST_RUN --continue
_ST_EQ "a reorder's stop taking in a later commit's deletion refuses" "$RC:$(git rev-parse HEAD)" "1:$RP_T"
_ST_OUT_HAS "naming that commit" 'RP8 A delete block, edit w – f.txt'
_ST_RUN --abort
_ST_RUN --move=HEAD~1 --before=HEAD~2
RP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l a b p d1 d2 d3 d4 n1 n2 n3 q r s t u v w)"
_ST_RUN --continue
_ST_RESOLVE "${RP_WT:-$ST_NO_WT}" f.txt "$(print -l a b p n1 n2 n3 q r s t u v w2)"
_ST_RUN --continue
_ST_EQ "one keeping the block lands, each commit with its own change" "$RC:$(git log --format=%s | tr '\n' '|'):$(git diff HEAD~2 HEAD~1 -- f.txt | grep -c '^-d[1-4]$')" \
	"0:RP8 top|RP8 A delete block, edit w|RP8 B insert where the block was|RP8 base|:4"
unfunction _RP_C _RP_NO_RECORD _RP_W _RP_HAND
cd "$TMP/repo"
