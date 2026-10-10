# A commit lost by hand from a paused replay – taken out of its todo, or stepped over with a raw
# `git rebase --skip` – refuses the resume, named, however it is finished, while one git emptied
# itself or a stop resolved empty through git edit lands – and the guards around a replay:
# • The absorption guard reads a later edit of one line and a file no stop conflicted on
# • Tree rules compare trees, gitlinks too
# • A pick whose signature failed resumes
# • A squash names its target's new commit, a swap's split remedy runs
# • An undo finding its run taken back already moves nothing
_ST_SCENARIO "\e[1;96m[173] lost commits refuse a resume, replay guards read what they claim\e[0m"
local LP_WT LP_T LP_C1 LP_A LP_B LP_R LP_N LP_S LP_G LP_WAY LP_SUB
# Writes f: 14 lines, line 5 and 9 as given, <extra> after line 12 where given
_LP_F () {
	# Args: <line 5> <line 9> [<extra>]
	local I
	for I in {1..14}; do
		case $I in 5) print -r -- "$1" ;; 9) print -r -- "$2" ;; *) print "line $I" ;; esac
		[ $I = 12 ] && [ -n "$3" ] && print -r -- "$3"
	done
	return 0
}
# Commits f as `_LP_F` writes it under <subject>
_LP_C () {
	# Args: <subject> <line 5> <line 9> [<extra>]
	_LP_F "${@:2}" > f && git add f && git commit -qm "$1"
}
# Drops c1 of base, c1 five+nine, c2 FIVE, c4 NINE, pausing at c2
_LP_DROP_FIX () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	_LP_C "LP base" "line 5" "line 9" && _LP_C "LP c1 five+nine" five nine && LP_C1=$(git rev-parse HEAD)
	_LP_C "LP c2 FIVE" FIVE nine && _LP_C "LP c4 NINE" FIVE NINE
	LP_T=$(git rev-parse HEAD)
	_ST_RUN -d -y "$LP_C1"
	LP_WT=$(_ST_PZ_WT)
}

# A pick taken out of a paused drop's todo by hand refuses the resume, naming it
_ST_PZ_NEW lp1
_LP_C "LP base" "line 5" "line 9" && _LP_C "LP c1 five+nine" five nine && LP_C1=$(git rev-parse HEAD)
_LP_C "LP c2 FIVE" FIVE nine && _LP_C "LP c3 adds z" FIVE nine zzz && _LP_C "LP c4 NINE" FIVE NINE zzz
LP_T=$(git rev-parse HEAD)
_ST_RUN -d -y "$LP_C1"
LP_WT=$(_ST_PZ_WT)
GIT_SEQUENCE_EDITOR="lp() { grep -v 'LP c3 adds z' \"\$1\" > \"\$1.lp\"; mv \"\$1.lp\" \"\$1\"; }; lp" git -C "${LP_WT:-$ST_NO_WT}" rebase --edit-todo
_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F FIVE "line 9")"
_ST_RUN --continue
_ST_EQ "a pick taken out of a paused drop's todo refuses the resume" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
_ST_OUT_HAS "naming it" 'LP c3 adds z – taken out of its todo by hand'
_ST_OUT_HAS "and the way on" "Cancel with 'git edit --abort', then run it again"
_ST_RUN --abort
# And a fold's, its fixup stopping on the line beside a later commit's, which stops too
_ST_PZ_NEW lp2
_ST_PZ_C f $'1\n2\n3\n4\n5\n6\n7\n8' "LP2 base" && _ST_PZ_C f $'1\n2\n3\n4\nfive\n6\n7\n8' "LP2 A five" && LP_A=$(git rev-parse HEAD)
_ST_PZ_C z.txt z "LP2 Z adds z" && _ST_PZ_C f $'1\n2\n3\n4\nfive\nsix\n7\n8' "LP2 B six" && _ST_PZ_C t.txt t "LP2 top"
LP_T=$(git rev-parse HEAD)
print -l 1 2 3 4 fiVe six 7 8 > f && git add f
_ST_RUN --amend-into="$LP_A"
LP_WT=$(_ST_PZ_WT)
GIT_SEQUENCE_EDITOR="lp() { grep -v 'LP2 Z adds z' \"\$1\" > \"\$1.lp\"; mv \"\$1.lp\" \"\$1\"; }; lp" git -C "${LP_WT:-$ST_NO_WT}" rebase --edit-todo
_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f $'1\n2\n3\n4\nfiVe\n6\n7\n8'
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f $'1\n2\n3\n4\nfiVe\nsix\n7\n8' && _ST_RUN --continue
_ST_EQ "as does one taken out of a fold's" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
_ST_OUT_HAS "naming it" 'LP2 Z adds z – taken out of its todo by hand'
_ST_RUN --abort
# A fold's later stop skipped by hand refuses where the result lacks that commit's change – the
# tree the fold staged no longer reached – while one the fold overrides lands, scenario 120's
_ST_RUN --amend-into="$LP_A"
LP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f $'1\n2\n3\n4\nfiVe\n6\n7\n8'
_ST_RUN --continue
GIT_EDITOR=true git -C "${LP_WT:-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a fold's stop skipped by hand, its change lost, refuses" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
_ST_OUT_HAS "naming it" 'LP2 B six – left out by hand'
_ST_RUN --abort

# A drop's stop stepped over by a hand `git rebase --skip` refuses, resumed through git edit at the
# next stop or finished by hand – the commit's change is not already there
for LP_WAY in edit hand; do
	_LP_DROP_FIX "lp3-$LP_WAY"
	GIT_EDITOR=true git -C "${LP_WT:-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
	_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F "line 5" NINE)"
	[ "$LP_WAY" = hand ] && GIT_EDITOR=true git -C "${LP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
	_ST_RUN --continue
	_ST_EQ "a stop skipped by hand refuses the resume, finished by $LP_WAY" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
	_ST_OUT_HAS "naming it as left out by hand" 'LP c2 FIVE – left out by hand, its change not already there'
	_ST_RUN --abort
done
# While its stop resolved empty and continued through git edit drops it, as the caller's call, and a
# pick git empties itself past a stop – its change already there – goes as emptied
_ST_PZ_NEW lp4
_LP_C "LP base" "line 5" "line 9" && print g1 > g && git add g && git commit -qm "LP g"
_LP_F five nine > f && print -l g1 zzz > g && git add f g && git commit -qm "LP c1 five+nine, zzz"
LP_C1=$(git rev-parse HEAD)
_LP_C "LP c2 FIVE" FIVE nine && print g1 > g && git add g && git commit -qm "LP c3 drops zzz"
_LP_C "LP c4 NINE" FIVE NINE
_ST_RUN -d -y "$LP_C1"
LP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F "line 5" "line 9")"
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F "line 5" NINE)" && _ST_RUN --continue
_ST_EQ "a stop resolved empty through git edit, and a pick git emptied, land" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP c4 NINE|LP g|LP base|"
_ST_OUT_HAS "both named as emptied" '2 commit(s) left empty by the drop'

# A replant's stop stepped over by `git edit --skip` lands without it,
# while a hand skip refuses, naming that as the way
for LP_WAY in edit hand; do
	_ST_PZ_NEW "lp5-$LP_WAY"
	_LP_C "LP5 base" 5 9 && git branch lp5-up
	_LP_C "LP5 f1 five" mine 9 && _LP_C "LP5 f2 nine" mine nine
	git checkout -q lp5-up && _LP_C "LP5 up five" UP 9 && git checkout -q main
	LP_T=$(git rev-parse HEAD)
	_ST_RUN --onto=lp5-up
	if [ "$LP_WAY" = edit ]; then
		_ST_RUN --skip
		_ST_EQ "a replant's stop left out by git edit --skip lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP5 f2 nine|LP5 up five|LP5 base|"
	else
		GIT_EDITOR=true git -C "${$(_ST_PZ_WT):-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
		_ST_RUN --continue
		_ST_EQ "while one skipped by hand refuses" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
		_ST_OUT_HAS "naming it" 'LP5 f1 five – left out by hand'
		_ST_OUT_HAS "and git edit's own skip as the way" "'git edit --skip' at a commit's stop is how to leave it out"
		_ST_RUN --abort
	fi
done

# An empty step's pause names git edit's own continue, never a hand skip, which loses the change and
# rewrites later messages under the caller's cleanup – and that continue is no hand skip
_ST_PZ_NEW lp6
_ST_PZ_C f.txt v1 "LP6 base" && _ST_PZ_C f.txt v2 "LP6 commit" && _ST_PZ_C f.txt v1 "LP6 revert"
LP_T=$(git rev-parse HEAD)
_ST_RUN --reorder HEAD HEAD~1
_ST_EQ "a step gone empty pauses" "$RC" "2"
_ST_OUT_HAS "its hint naming git edit's continue" 'Continuing drops that commit'
_ST_OUT_LACKS "never a hand skip" 'rebase --skip'
_ST_RUN --continue
_ST_EQ "that continue reaches the reorder's tree rule, not the lost-commit guard" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
_ST_OUT_HAS "which names the file" 'no longer ends on the tree it began with'
_ST_OUT_LACKS "no hand skip read" 'left out by hand'
_ST_RUN --abort

# A drop's stop resolved to the file as the tip holds it takes in a later commit's edit of a line
# the dropped commit introduced – the edit's removed line counts with the line it put in its place
_ST_PZ_NEW lp7
_LP_C "LP base" "line 5" "line 9" && _LP_C "LP c1 five+nine" five nine && LP_C1=$(git rev-parse HEAD)
_LP_C "LP c2 FIVE" FIVE nine && _ST_PZ_C g g "LP c3 g" && _LP_C "LP c4 NINE" FIVE NINE
LP_T=$(git rev-parse HEAD)
_ST_RUN -d -y "$LP_C1"
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f "$(_LP_F FIVE NINE)"
_ST_RUN --continue
_ST_EQ "a stop taking in a later one-line edit refuses" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
_ST_OUT_HAS "naming that commit" 'LP c4 NINE – f (left out as emptied)'
_ST_RUN --abort
_ST_RUN -d -y "$LP_C1"
LP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F FIVE "line 9")"
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F FIVE NINE)" && _ST_RUN --continue
_ST_EQ "while each stop resolved to its own commit's change lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP c4 NINE|LP c3 g|LP c2 FIVE|LP base|"
# A resolution that also stages a later commit's change to a file the stop never conflicted on
_ST_PZ_NEW lp8
_LP_C "LP base" "line 5" "line 9" && _ST_PZ_C g g1 "LP g"
_LP_C "LP c1 five+nine" five nine && LP_C1=$(git rev-parse HEAD)
_LP_C "LP c2 FIVE" FIVE nine && _ST_PZ_C g G1 "LP c3 G1" && _ST_PZ_C h h "LP top"
LP_T=$(git rev-parse HEAD)
_ST_RUN -d -y "$LP_C1"
LP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f "$(_LP_F FIVE "line 9")" && print G1 > "${LP_WT:-$ST_NO_WT}/g" && git -C "${LP_WT:-$ST_NO_WT}" add g
_ST_RUN --continue
_ST_EQ "a stop staging a later commit's change to a file it never conflicted on refuses" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
_ST_OUT_HAS "naming that commit and file" 'LP c3 G1 – g (left out as emptied)'
_ST_RUN --abort
_ST_RUN -d -y "$LP_C1"
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f "$(_LP_F FIVE "line 9")"
_ST_RUN --continue
_ST_EQ "while one staging the stop's own change alone lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP top|LP c3 G1|LP c2 FIVE|LP g|LP base|"

# A reorder whose replay changes a gitlink refuses whatever the caller's config hides of submodules,
# a moved gitlink change keeping the tree landing
for LP_WAY in cfg gitmodules; do
	_ST_PZ_NEW "lp9-$LP_WAY"
	_ST_PZ_C a a "LP9 base" && LP_S=$(git rev-parse HEAD)
	_ST_PZ_C b b "LP9 second" && LP_G=$(git rev-parse HEAD)
	git update-index --add --cacheinfo "160000,$LP_S,sub"
	[ "$LP_WAY" = gitmodules ] && print -l '[submodule "sub"]' '	path = sub' '	url = ./nowhere' '	ignore = all' > .gitmodules && git add .gitmodules
	git commit -qm "LP9 sub at S"
	git update-index --cacheinfo "160000,$LP_G,sub" && git commit -qm "LP9 A sub to G" && LP_A=$(git rev-parse HEAD)
	git update-index --cacheinfo "160000,$LP_S,sub" && print r > r && git add r && git commit -qm "LP9 R sub back, r" && LP_R=$(git rev-parse HEAD)
	[ "$LP_WAY" = cfg ] && git config diff.ignoreSubmodules all
	LP_T=$(git rev-parse HEAD)
	_ST_RUN --reorder "$LP_R" "$LP_A"
	_ST_EQ "a reorder changing a gitlink refuses under $LP_WAY" "$RC:$(git rev-parse HEAD)" "1:$LP_T"
	_ST_OUT_HAS "naming it" 'changes the content of sub'
	_ST_OUT_LACKS "never calling the tree identical" 'Tip tree identical'
done
print s > s && git add s && git commit -qm "LP9 s"
_ST_RUN --reorder HEAD "$LP_R"
_ST_EQ "while a gitlink change moved past an unrelated commit lands" "$RC:$(git log -3 --format=%s | tr '\n' '|')" "0:LP9 R sub back, r|LP9 s|LP9 A sub to G|"

# A replay whose later clean pick fails its signature resumes once signing works, its change made
# again rather than refused over as staged – a drop's and a reorder's alike
# Its status on a later line, as gpg's – a git before 2.36 finds `SIG_CREATED` only after a newline
print -r -- '#!/bin/sh
IN=$(cat)
if [ -e "$(git rev-parse --git-common-dir)/lpfail" ]; then case $IN in *FAILME*) echo "lp gpg: card removed" >&2; exit 2 ;; esac; fi
echo "[GNUPG:] BEGIN_SIGNING H8" >&2
echo "[GNUPG:] SIG_CREATED D 1 8 00 1700000000 ABCDEF" >&2
printf -- "-----BEGIN PGP SIGNATURE-----\n\nlp\n-----END PGP SIGNATURE-----\n"' > "$TMP/lp-gpg"
chmod +x "$TMP/lp-gpg"
for LP_WAY in drop reorder; do
	_ST_PZ_NEW "lp10-$LP_WAY"
	_ST_PZ_C f $'1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12' "LP10 base"
	_ST_PZ_C f $'1\n2\n3\n4\nfive\n6\n7\n8\n9\n10\n11\n12' "LP10 A five" && LP_A=$(git rev-parse HEAD)
	_ST_PZ_C f $'1\n2\n3\n4\nfive\nsix\n7\n8\n9\n10\n11\n12' "LP10 B six" && LP_B=$(git rev-parse HEAD)
	_ST_PZ_C f $'1\n2\n3\n4\nfive\nsix\n7\n8\n9\n10\n11\ntwelve' "LP10 C twelve FAILME"
	git config commit.gpgSign true && git config gpg.program "$TMP/lp-gpg"
	if [ "$LP_WAY" = drop ]; then
		_ST_RUN -d -y "$LP_A"
		LP_WT=$(_ST_PZ_WT)
		_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f $'1\n2\n3\n4\n5\nsix\n7\n8\n9\n10\n11\n12'
		LP_N="LP10 C twelve FAILME|LP10 B six|LP10 base|"
	else
		_ST_RUN --reorder "$LP_B" "$LP_A"
		LP_WT=$(_ST_PZ_WT)
		_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f $'1\n2\n3\n4\n5\nsix\n7\n8\n9\n10\n11\n12'
		_ST_RUN --continue
		_ST_RESOLVE "${LP_WT:-$ST_NO_WT}" f $'1\n2\n3\n4\nfive\nsix\n7\n8\n9\n10\n11\n12'
		LP_N="LP10 C twelve FAILME|LP10 A five|LP10 B six|LP10 base|"
	fi
	: > "$(git rev-parse --git-common-dir)/lpfail"
	_ST_RUN --continue
	_ST_EQ "a $LP_WAY whose later pick fails its signature pauses" "$RC" "1"
	mv "$(git rev-parse --git-common-dir)/lpfail" "$(git rev-parse --git-common-dir)/lpok"
	# A git before 2.42.1 sets the failed pick's stop up as a conflict's, its message pending – the
	# continue commits the change itself, the pick run again coming out empty, which a reorder stops on
	if [ -e "$(git -C "${LP_WT:-$ST_NO_WT}" rev-parse --path-format=absolute --git-path rebase-merge/message 2>/dev/null)" ]; then
		_ST_RUN --continue
		if [ "$LP_WAY" = reorder ]; then
			_ST_EQ "below git 2.42.1 the pick made again pauses as empty" "$RC" "2"
			_ST_OUT_HAS "its hint dropping that commit" 'Continuing drops that commit'
			_ST_RUN --continue
		fi
		_ST_EQ "and resumes once signing works, its change committed once" "$RC:$(git log --format=%s | tr '\n' '|')" "0:$LP_N"
	else
		_ST_RUN --continue
		_ST_EQ "and resumes once signing works" "$RC:$(git log --format=%s | tr '\n' '|')" "0:$LP_N"
		_ST_OUT_HAS "saying the failed pick is made again" 'LP10 C twelve FAILME left its change staged as its commit failed'
	fi
	git config --unset commit.gpgSign && git config --unset gpg.program
done

# The path-by-path merge a git before 2.40 reads a left-out pick by builds the tree a rebase
# would – a pick clean beside another change, one already there – and fails one conflicting
_ST_PZ_NEW lp15
_ST_PZ_C f $'1\n2\n3\n4\n5\n6' "LP15 base" && LP_A=$(git rev-parse HEAD)
_ST_PZ_C f $'1\nTWO\n3\n4\n5\n6' "LP15 two" && LP_B=$(git rev-parse HEAD)
git checkout -q -b lp15-up "$LP_A" && _ST_PZ_C f $'1\n2\n3\n4\n5\nSIX' "LP15 six" && _ST_PZ_C g g "LP15 g" && LP_S=$(git rev-parse HEAD)
_ST_PZ_C f $'1\nTWO\n3\n4\n5\nSIX' "LP15 both" && LP_G=$(git rev-parse HEAD)
git checkout -q -b lp15-deux "$LP_A" && _ST_PZ_C f $'1\nDEUX\n3\n4\n5\n6' "LP15 deux" && LP_R=$(git rev-parse HEAD)
git checkout -q main
_ST_EQ "the path-by-path merge takes a pick in beside another change" "$(_PICK_PATHS_ONTO . "$LP_B" "$LP_S" "$LP_A")" "$(git rev-parse "$LP_G^{tree}")"
_ST_EQ "and finds one already there" "$(_PICK_PATHS_ONTO . "$LP_B" "$LP_G" "$LP_A")" "$(git rev-parse "$LP_G^{tree}")"
_PICK_PATHS_ONTO . "$LP_B" "$LP_R" "$LP_A" >/dev/null 2>&1
_ST_EQ "while one conflicting fails" "$?" "1"

# A squash names the commit its target became, where one before it went empty – at one author date,
# as a scripted session makes them, and at distinct ones
for LP_WAY in same distinct; do
	_ST_PZ_NEW "lp11-$LP_WAY"
	LP_N=1700000000
	_LP_AT () { [ "$LP_WAY" = distinct ] && LP_N=$(( LP_N + 60 )); GIT_AUTHOR_DATE="$LP_N +0000" GIT_COMMITTER_DATE="$LP_N +0000" "$@"; }
	print base > f && git add f && _LP_AT git commit -qm "LP11 base"
	print x >> f && git add f && _LP_AT git commit -qm "LP11 A adds x" && LP_A=$(git rev-parse HEAD)
	print base > f && git add f && _LP_AT git commit -qm "LP11 B removes x"
	print x >> f && print c > c && git add f c && _LP_AT git commit -qm "LP11 C adds c and x again" && LP_B=$(git rev-parse HEAD)
	print d > d && git add d && _LP_AT git commit -qm "LP11 D adds d"
	_ST_RUN -s="$LP_B" "$LP_A"
	_ST_EQ "a squash past a commit gone empty lands ($LP_WAY dates)" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP11 D adds d|LP11 C adds c and x again|LP11 base|"
	_ST_OUT_HAS "naming the target's new commit" "squashed into: $(git rev-parse --short HEAD~1) LP11 C adds c and x again"
done

# A split by path of a directory turned file says which way it turned, its remedy dropping an
# exclude that would leave the named side out again – and running as printed
_ST_PZ_NEW lp12
mkdir e && print ex > e/x && print base > base && git add -A && git commit -qm "LP12 base"
git rm -rq e && print efile > e && print o > other && git add -A && git commit -qm "LP12 e: directory to file, plus other"
LP_T=$(git rev-parse --short=7 HEAD)
_ST_RUN --split=HEAD --text "LP12 e file" -- e ':(exclude)e/x'
_ST_EQ "a split leaving out one side of a swap refuses" "$RC" "1"
_ST_OUT_HAS "naming the swap's direction" "$LP_T turns a directory into a file at one path"
_ST_OUT_HAS "and a remedy without the exclude" "Name both sides, without the exclude: git edit --split=$LP_T --text <msg> -- e e/x"
_ST_RUN --split=HEAD --text "LP12 e file" -- e e/x
_ST_EQ "which lands as printed" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP12 e: directory to file, plus other|LP12 e file|LP12 base|"
_ST_PZ_NEW lp12b
print e > e && print base > base && git add -A && git commit -qm "LP12b base"
git rm -q e && mkdir e && print ex > e/x && print o > other && git add -A && git commit -qm "LP12b e: file to directory"
_ST_RUN --split=HEAD --text "LP12b e dir" -- e/x
_ST_OUT_HAS "while a file turned directory says so" 'turns a file into a directory at one path'
_ST_OUT_HAS "its remedy naming both sides as given" 'Name both sides: git edit --split=[0-9a-f]* --text <msg> -- e/x e'

# An undo whose run was taken back outside git-edit – the raw update-ref a refusal names – moves
# nothing, says so, and journals it undone, so a further undo passes over it
_ST_PZ_NEW lp13
_ST_PZ_C a a "LP13 base" && _ST_PZ_C c c "LP13 C"
git branch side && git worktree add -q "$TMP/lp13-side" side
LP_T=$(git rev-parse HEAD)
( cd "$TMP/lp13-side" && GIT_EDIT_ACTOR=lp-alice _ST_RUN -M HEAD --text "LP13 C by alice"; print -r -- "$OUT" > "$TMP/lp13.out" )
LP_S=$(git rev-parse side)
GIT_EDIT_ACTOR=lp-bob _ST_RUN -M HEAD --text "LP13 C by bob"
git update-ref refs/heads/side "$LP_T" "$LP_S"
GIT_EDIT_ACTOR=lp-bob _ST_RUN --undo
( cd "$TMP/lp13-side" && GIT_EDIT_ACTOR=lp-alice _ST_RUN --undo; print -r -- "$RC" > "$TMP/lp13.rc"; print -r -- "$OUT" > "$TMP/lp13.out" )
OUT=$(<"$TMP/lp13.out")
_ST_EQ "an undo of a run taken back by hand moves nothing" "$(<"$TMP/lp13.rc"):$(git rev-parse side):$(git reflog side | wc -l | tr -d ' ')" "0:$LP_T:3"
_ST_OUT_HAS "saying so" "side already sat at ${LP_T:0:7}, taken back outside git-edit, so nothing moved"
_ST_OUT_HAS "in an unchanged trailer" '^git-edit: ok – refs/heads/side unchanged, already at '
( cd "$TMP/lp13-side" && GIT_EDIT_ACTOR=lp-alice _ST_RUN --undo; print -r -- "$OUT" > "$TMP/lp13.out" )
OUT=$(<"$TMP/lp13.out")
_ST_OUT_HAS "a further undo passing over it" 'Nothing to undo'
git worktree remove --force "$TMP/lp13-side"
# A landing whose compare-and-swap fails with the ref already at its target, no signal in between,
# was beaten there by someone else – refused, never journaled as its own move
_ST_PZ_NEW lp14
_ST_PZ_C a a "LP14 base" && _ST_PZ_C c c "LP14 C"
mkdir -p "$TMP/lp14-git"
{
	print -r -- '#!/bin/sh'
	print -r -- "if [ -e ${(q)TMP}/lp14-arm ] && [ \"\$1\" = update-ref ]; then"
	print -r -- '	for W; do P2=$P1; P1=$W; done'
	print -r -- "	rm -f ${(q)TMP}/lp14-arm; ${(q)commands[git]} update-ref refs/heads/main \"\$P2\""
	print -r -- 'fi'
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/lp14-git/git"
chmod +x "$TMP/lp14-git/git"
: > "$TMP/lp14-arm"
PATH="$TMP/lp14-git:$PATH" _ST_RUN -M HEAD --text "LP14 C reworded"
_ST_EQ "a compare-and-swap beaten to its very target refuses" "$RC" "1"
_ST_OUT_LACKS "never reporting the move as its own" '^git-edit: ok'
_ST_EQ "nor journaling it" "$(cat "$(git rev-parse --git-common-dir)/git-edit-journal" 2>/dev/null | grep -c reword)" "0"
cd "$TMP/repo"
