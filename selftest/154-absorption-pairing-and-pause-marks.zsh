# A resolution is refused as absorbing a later commit's change only where that commit's lost lines
# sit in a stop's commit – a drop, an edit or a replant emptying the change lands – each replayed
# commit pairs with its own original in replay order, a hand-finished squash reads every member,
# and a pause re-taken alike or replaced meanwhile is told apart by each run that took it up
_ST_SCENARIO "\e[1;96m[154] absorption reads moved lines, pairs keep replay order, a pause is told by its mark\e[0m"
local AB_T AB_B AB_D AB_P AB_WT AB_SF AB_REAL
local -i AB_W
# Writes a `git` stand-in to <dir> that, armed by <dir>/arm, runs <script> once – disarming first –
# when a call's arguments open with <words>, then runs the real git
_AB_GIT_HOOK () {
	# Args: <dir> <script> <words>
	mkdir -p "$1"
	AB_REAL=${commands[git]}
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \"\$*\" in ${(q)3}*) if [ -e ${(q)1}/arm ]; then mv ${(q)1}/arm ${(q)1}/fired; sh ${(q)2}; fi ;; esac"
		print -r -- "exec ${(q)AB_REAL} \"\$@\""
	} > "$1/git"
	chmod +x "$1/git"
}
# A drop whose later commit's change the drop itself emptied lands
_ST_PZ_NEW ab1
print -l 1 2 3 4 5 6 7 8 9 > f.txt && git add f.txt && git commit -qm "AB1 base"
print -l 1 2 DEBUG 3 4 5 6 7 8 9 > f.txt && git commit -qam "AB1 Y add debug"
print -l 1 2 DEBUG 3z 4 5 6 7 8 9 > f.txt && git commit -qam "AB1 Z edit line 3"
print -l 1 2 3z 4 5 6 7 8 9 > f.txt && print g > g.txt && git add -A && git commit -qm "AB1 W remove debug, add g"
_ST_RUN -d -y HEAD~2
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "a drop emptying a later commit's change lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt | tr '\n' ' ')" \
	"0:AB1 W remove debug, add g|AB1 Z edit line 3|AB1 base|:1 2 3z 4 5 6 7 8 9 "
# As does a drop whose later commit took out what the dropped one added
_ST_PZ_NEW ab2
print -l 1 2 3 > f && print g0 > g && git add -A && git commit -qm "AB2 base"
print -l 1 2 L 3 > f && git commit -qam "AB2 A adds L"
print -l 1 2 L 3b > f && git commit -qam "AB2 B edits 3"
print g1 > g && git commit -qam "AB2 C edits g"
print -l 1 2 3b > f && print g2 > g && git commit -qam "AB2 Z removes L, edits g"
_ST_RUN -d -y HEAD~3
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f "$(print -l 1 2 3b)"
_ST_RUN --continue
_ST_EQ "and one whose later commit removed the dropped line" "$RC:$(git log --format=%s | wc -l | tr -d ' ')" "0:4"
# An edit making early the fix a later commit makes
_ST_PZ_NEW ab3
print -l 1 2 typo 4 5 6 7 8 9 > f.txt && git add f.txt && git commit -qm "AB3 X base with typo"
print -l 1 2 typo 4z 5 6 7 8 9 > f.txt && git commit -qam "AB3 Z edit line 4"
print -l 1 2 fixed 4z 5 6 7 8 9 > f.txt && print g > g.txt && git add -A && git commit -qm "AB3 W fix typo, add g"
_ST_RUN HEAD~2
print -l 1 2 fixed 4 5 6 7 8 9 > "${$(_ST_PZ_WT):-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2 fixed 4z 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "an edit making a later commit's fix early lands" "$RC:$(git show HEAD~2:f.txt | sed -n 3p):$(git log --format=%s | wc -l | tr -d ' ')" "0:fixed:3"
# A replant onto an upstream already holding part of a later commit's change
_ST_PZ_NEW ab4
print -l 1 2 3 4 5 6 7 8 9 > f.txt && git add f.txt && git commit -qm "AB4 base" && git branch up
print -l 1 2z 3 4 5 6 7 8 9 > f.txt && git commit -qam "AB4 Z line 2"
print -l 1 2z 3 4 5 6 7 8w 9 > f.txt && print h > h.txt && git add -A && git commit -qm "AB4 W line 8, add h"
git checkout -q up && print -l 1 2u 3 4 5 6 7 8w 9 > f.txt && git commit -qam "AB4 U line 2, line 8 as W" && git checkout -q main
_ST_RUN --onto=up
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2z 3 4 5 6 7 8w 9)"
_ST_RUN --continue
_ST_EQ "a replant onto an upstream holding part of a later change lands" "$RC:$(git log --format=%s | tr '\n' '|')" \
	"0:AB4 W line 8, add h|AB4 Z line 2|AB4 U line 2, line 8 as W|AB4 base|"
# A fold's stop taking in one hunk of a later commit, which still changes the file, refuses – while
# one resolved to the target's own content lands
_ST_PZ_NEW ab5
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 13 14 > f.txt && git add f.txt && git commit -qm "AB5 base"
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 13 T14 > f.txt && git commit -qam "AB5 target"
AB_B=$(git rev-parse HEAD)
print -l -- 1 2 3 4 5 6 7 a8 9 10 11 a12 13 T14 > f.txt && print g > g.txt && git add -A && git commit -qm "AB5 later"
AB_T=$(git rev-parse HEAD)
print -l -- 1 2 3 4 5 6 7 a8 E9 10 11 a12 13 T14 > f.txt
_ST_RUN --amend-into="$AB_B" --whole -- f.txt
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 5 6 7 a8 E9 10 11 12 13 T14)"
_ST_RUN --continue
_ST_EQ "a fold's stop taking in a later commit's hunk refuses" "$RC:$(git rev-parse HEAD)" "1:$AB_T"
_ST_OUT_HAS "naming that commit, though it still changes the file" 'AB5 later – f.txt'
_ST_RUN --abort
git checkout -q -- f.txt && print -l -- 1 2 3 4 5 6 7 a8 E9 10 11 a12 13 T14 > f.txt
_ST_RUN --amend-into="$AB_B" --whole -- f.txt
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 5 6 7 8 E9 10 11 12 13 T14)"
_ST_RUN --continue
_ST_EQ "one resolved to the target's own content lands, the later commit whole" \
	"$RC:$(git diff HEAD~1 HEAD -- f.txt | grep -c '^[-+][0-9a]'):$(git show HEAD:f.txt | tr '\n' ' ')" "0:4:1 2 3 4 5 6 7 a8 E9 10 11 a12 13 T14 "
# Commits sharing author, date and subject pair each with its original – a drop among them lands,
# while a stop taking in one's change to the file refuses, the commit left standing by another file
_ST_PZ_NEW ab6
AB_D="@1760000000 +0000"
print -l 1 2 3 4 5 6 7 8 9 > f.txt && git add f.txt && git commit -qm "AB6 base"
print -l 1 2 Y 3 4 5 6 7 8 9 > f.txt && GIT_AUTHOR_DATE=$AB_D GIT_COMMITTER_DATE=$AB_D git commit -qam "AB6 Y"
print -l 1 2 Y 3z 4 5 6 7 8 9 > f.txt && GIT_AUTHOR_DATE=$AB_D GIT_COMMITTER_DATE=$AB_D git commit -qam "wip"
print -l 1 2 Y 3z 4 5 6 7 8 9z > f.txt && print w > w.txt && git add w.txt && GIT_AUTHOR_DATE=$AB_D GIT_COMMITTER_DATE=$AB_D git commit -qam "wip"
print g > g.txt && git add g.txt && GIT_AUTHOR_DATE=$AB_D GIT_COMMITTER_DATE=$AB_D git commit -qm "wip"
AB_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~3
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "a drop among commits of one second and subject lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt | tr '\n' ' ')" \
	"0:wip|wip|wip|AB6 base|:1 2 3z 4 5 6 7 8 9z "
git reset -q --hard "$AB_T"
_ST_RUN -d -y HEAD~3
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9z)"
_ST_RUN --continue
_ST_EQ "while its stop taking in the next one's change refuses" "$RC:$(git rev-parse HEAD):$(grep -c -e 'wip – f.txt' <<<"$OUT")" "1:$AB_T:1"
_ST_RUN --abort
# A hand finish among them reads each commit against its own original's markers
git reset -q --hard "$AB_T~1"
print -r -- $'Install\n=======' > README.rst && git add README.rst && GIT_AUTHOR_DATE=$AB_D GIT_COMMITTER_DATE=$AB_D git commit -qm "wip"
print h > h.txt && git add h.txt && GIT_AUTHOR_DATE=$AB_D GIT_COMMITTER_DATE=$AB_D git commit -qm "wip"
AB_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~4
AB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${AB_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9)"
GIT_EDITOR=true git -C "${AB_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a hand finish among them, one adding an underline of its own, lands" "$RC:$(git log --format=%s | wc -l | tr -d ' ')" "0:5"
# A squash finished by hand lands a member applied past the stop with its own underline, while one
# finished with its markers staged refuses
_ST_PZ_NEW ab7
_ST_PZ_C f.txt $'1\n2\n3' "AB7 base" && _ST_PZ_C t.txt t "AB7 Target" && _ST_PZ_C f.txt $'1\n2m\n3' "AB7 Middle"
_ST_PZ_C f.txt $'1\n2m\n3f' "AB7 Fix" && _ST_PZ_C README.rst $'Install\n=======' "AB7 Docs"
AB_T=$(git rev-parse HEAD)
_ST_RUN -s HEAD~3 HEAD~1 HEAD
AB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${AB_WT:-$ST_NO_WT}" f.txt $'1\n2\n3f'
GIT_EDITOR=true git -C "${AB_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RESOLVE "${AB_WT:-$ST_NO_WT}" f.txt $'1\n2m\n3f'
GIT_EDITOR=true git -C "${AB_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a squash finished by hand, a member bringing an underline, lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:README.rst | tail -1)" \
	"0:AB7 Middle|AB7 Target|AB7 base|:======="
# A repo of its own, where no recorded resolution resolves the second stop
_ST_PZ_NEW ab7m
_ST_PZ_C f.txt $'1\n2\n3' "AB7 base" && _ST_PZ_C t.txt t "AB7 Target" && _ST_PZ_C f.txt $'1\n2m\n3' "AB7 Middle"
_ST_PZ_C f.txt $'1\n2m\n3f' "AB7 Fix" && _ST_PZ_C README.rst $'Install\n=======' "AB7 Docs"
AB_T=$(git rev-parse HEAD)
_ST_RUN -s HEAD~3 HEAD~1 HEAD
AB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${AB_WT:-$ST_NO_WT}" f.txt $'1\n2\n3f'
GIT_EDITOR=true git -C "${AB_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
git -C "${AB_WT:-$ST_NO_WT}" add -A && GIT_EDITOR=true git -C "${AB_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "one finished with its markers committed refuses" "$RC:$(git rev-parse HEAD)" "1:$AB_T"
_ST_OUT_HAS "naming them" 'committed conflict markers'
_ST_RUN --abort
# A squash's later fixup stop is named by the commit it folds into, not git's interim message
_ST_PZ_NEW ab8
_ST_PZ_C f.txt $'1\n2\n3' "AB8 base" && _ST_PZ_C t.txt t "AB8 Target" && _ST_PZ_C g.txt g "AB8 Fix one"
_ST_PZ_C f.txt $'1\n2x\n3' "AB8 Middle" && _ST_PZ_C f.txt $'1\n2xy\n3' "AB8 Fix two" && _ST_PZ_C z.txt z "AB8 top"
_ST_RUN -s HEAD~4 HEAD~3 HEAD~1
_ST_OUT_HAS "a later fixup's stop names the chain's pick" 'This stop folds into [0-9a-f]* AB8 Target itself'
_ST_OUT_LACKS "never the squash template's comment lines" 'This stop folds into [0-9a-f]* #'
_ST_RUN --abort
# Another label's status names the pause by its action, as its refusal does
_ST_PZ_NEW ab9
_ST_PZ_C f.txt $'1\n2\n3' "AB9 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "AB9 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "AB9 c3"
GIT_EDIT_ACTOR=ab-alice _ST_RUN -d -y HEAD~1
GIT_EDIT_ACTOR=ab-bob _ST_RUN --status
AB_T=$(git rev-parse HEAD~1)
AB_T=${AB_T:0:7}
_ST_EQ "another label's status trailer says drop" "$([[ "${OUT##*$'\n'}" == "git-edit: paused – drop $AB_T is "* ]] && echo drop)" "drop"
# A status whose pause is replaced as it reads ends on what it read, never on the ownership refusal
AB_SF="$(git rev-parse --git-common-dir)/git-edit-state"
cp "$AB_SF" "$TMP/ab-sf"
print -r -- "sed 's/^nonce=.*/nonce=replaced/' ${(q)AB_SF} > ${(q)AB_SF}.x && mv ${(q)AB_SF}.x ${(q)AB_SF}" > "$TMP/ab-replace"
_AB_GIT_HOOK "$TMP/ab-gw1" "$TMP/ab-replace" "-C "
: > "$TMP/ab-gw1/arm"
PATH="$TMP/ab-gw1:$PATH" _ST_RUN --status
_ST_EQ "a status reading a pause replaced meanwhile ends on it" "$([ -e "$TMP/ab-gw1/fired" ] && echo fired):${${OUT##*$'\n'}%% –*}" "fired:git-edit: conflict"
_ST_OUT_LACKS "never on the ownership refusal" 'ended by another run'
cp "$TMP/ab-sf" "$AB_SF"
# An abort whose pause is re-taken alike as it starts cancels nothing of that pause
AB_WT=$(_ST_PZ_WT)
print -r -- "sed 's/^nonce=.*/nonce=retaken/' ${(q)AB_SF} > ${(q)AB_SF}.x && mv ${(q)AB_SF}.x ${(q)AB_SF}" > "$TMP/ab-retake"
_AB_GIT_HOOK "$TMP/ab-gw2" "$TMP/ab-retake" "log -1 --pretty=format:%s"
: > "$TMP/ab-gw2/arm"
GIT_EDIT_ACTOR= PATH="$TMP/ab-gw2:$PATH" _ST_RUN --abort
_ST_EQ "an abort of a pause re-taken alike meanwhile cancels nothing" "$RC:$([ -f "$AB_SF" ] && echo kept):$([ -d "${AB_WT:-$ST_NO_WT}" ] && echo wt)" "1:kept:wt"
_ST_OUT_HAS "saying so" 'ended by another run meanwhile – nothing was cancelled'
cp "$TMP/ab-sf" "$AB_SF"
GIT_EDIT_ACTOR= _ST_RUN --abort
# A resume holds its `-C` path, so an abort and a new run there both refuse while
# its gate runs – and a pause re-taken alike meanwhile, its nonce alone telling it
# apart, it lands nothing of, leaving it
_ST_PZ_NEW ab10
_ST_PZ_C f $'1\n2\n3' "AB10 A" && _ST_PZ_C f $'1\n2b\n3' "AB10 B" && _ST_PZ_C f $'1\n2c\n3' "AB10 C"
AB_T=$(git rev-parse HEAD)
AB_B=$(git rev-parse HEAD~1)
AB_P="$TMP/ab10-wt"
AB_SF="$(git rev-parse --git-common-dir)/git-edit-state"
GIT_EDIT_ACTOR=ab-a _ST_RUN -C "$AB_P" -d -y "$AB_B"
_ST_RESOLVE "$AB_P" f $'1\n2c\n3'
{
	print -r -- '#!/bin/sh'
	print -r -- "[ -e ${(q)TMP}/ab-once ] && exit 0"
	print -r -- ": > ${(q)TMP}/ab-once"
	print -r -- "cd ${(q)TMP}/pz-ab10 || exit 0"
	print -r -- 'unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE'
	print -r -- "GIT_EDIT_ACTOR= GIT_EDIT_NO_AUTO_OPEN=1 ${(q)SELF} --abort </dev/null >${(q)TMP}/ab10-abort 2>&1"
	print -r -- "GIT_EDIT_ACTOR=ab-c GIT_EDIT_NO_AUTO_OPEN=1 ${(q)SELF} -C ${(q)AB_P} -d -y $AB_B </dev/null >${(q)TMP}/ab10-new 2>&1"
	print -r -- "sed 's/^nonce=.*/nonce=retaken/' ${(q)AB_SF} > ${(q)AB_SF}.x && mv ${(q)AB_SF}.x ${(q)AB_SF}"
	print -r -- 'exit 0'
} > "$TMP/ab-gate"
chmod +x "$TMP/ab-gate"
GIT_EDIT_ACTOR=ab-a _ST_RUN --continue --verify="$TMP/ab-gate"
_ST_EQ "a resume whose pause was re-taken alike meanwhile lands nothing" "$RC:$(git rev-parse HEAD)" "1:$AB_T"
_ST_OUT_HAS "saying so" 'ended by another run meanwhile'
# Its gate runs both, so the abort names the resume as the run it runs under
_ST_EQ "an abort and a new run on its -C path refuse while it runs" \
	"$(grep -c '^git-edit: error.*held by the run this one runs under' "$TMP/ab10-abort"):$(grep -c '^git-edit: error' "$TMP/ab10-new")" "1:1"
_ST_EQ "the re-taken pause is left to its run" "$(sed -n 's/^nonce=//p' "$AB_SF" 2>/dev/null):$(_ST_PZ_WT)" "retaken:$AB_P"
GIT_EDIT_ACTOR=ab-a _ST_RUN --continue
_ST_EQ "which resumes it as its own" "$RC:$(git log --format=%s | tr '\n' '|')" "0:AB10 C|AB10 A|"
# Enter at a prompt whose pause another run moves on as it stages stages nothing of the next stop
_ST_PZ_NEW ab11
printf '1\n2\n3\n' > f.txt && print g > g.txt && git add -A && git commit -qm "AB11 c1"
printf '1\n2x\n3\n' > f.txt && print g2 > g.txt && git add -A && git commit -qm "AB11 c2"
_ST_PZ_C f.txt $'1\n2xy\n3' "AB11 c3" && git rm -q f.txt g.txt && git commit -qm "AB11 c4"
AB_T=$(git rev-parse HEAD)
print -r -- "cd ${(q)TMP}/pz-ab11 && GIT_EDIT_NO_AUTO_OPEN=1 ${(q)SELF} --continue </dev/null >/dev/null 2>&1" > "$TMP/ab-peer"
_AB_GIT_HOOK "$TMP/ab-gw3" "$TMP/ab-peer" "-C "
_ST_TTY_START "PATH=$TMP/ab-gw3:$PATH" -- -d -y HEAD~2
if _ST_TTY_AT 'Resolve the conflicts in'; then
	AB_WT=$(_ST_PZ_WT)
	_ST_RESOLVE "${AB_WT:-$ST_NO_WT}" f.txt $'1\n2y\n3'
	: > "$TMP/ab-gw3/arm"
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "Enter as another run moves the pause on does nothing" "$RC:$(git rev-parse HEAD):$([ -e "$TMP/ab-gw3/fired" ] && echo fired)" "1:$AB_T:fired"
_ST_OUT_HAS "saying the pause it showed is no longer pending" 'no longer pending'
_ST_EQ "leaving the next stop's files unmerged" "$(git -C "${AB_WT:-$ST_NO_WT}" ls-files -u -- f.txt g.txt | wc -l | tr -d ' ')" "4"
_ST_RUN --abort
# A fold's stop taking a later commit's binary content whole refuses, one keeping the fold's lands
_ST_PZ_NEW ab12
printf 'v0\0x\n' > bin.dat && git add bin.dat && git commit -qm "AB12 base"
printf 'v1\0x\n' > bin.dat && git commit -qam "AB12 target"
AB_B=$(git rev-parse HEAD)
printf 'v2\0x\n' > bin.dat && print g > g.txt && git add -A && git commit -qm "AB12 later"
AB_T=$(git rev-parse HEAD)
printf 'v3\0x\n' > bin.dat
_ST_RUN --amend-into="$AB_B" --whole -- bin.dat
AB_WT=$(_ST_PZ_WT)
[ -d "${AB_WT:-$ST_NO_WT}" ] && printf 'v2\0x\n' > "$AB_WT/bin.dat" && git -C "$AB_WT" add bin.dat
_ST_RUN --continue
_ST_EQ "a fold's stop taking a later commit's binary content refuses" "$RC:$(git rev-parse HEAD)" "1:$AB_T"
_ST_OUT_HAS "naming that commit" 'AB12 later – bin.dat'
_ST_RUN --abort
printf 'v3\0x\n' > bin.dat
_ST_RUN --amend-into="$AB_B" --whole -- bin.dat
AB_WT=$(_ST_PZ_WT)
[ -d "${AB_WT:-$ST_NO_WT}" ] && printf 'v3\0x\n' > "$AB_WT/bin.dat" && git -C "$AB_WT" add bin.dat
_ST_RUN --continue
_ST_EQ "one holding the fold's own content lands" "$RC:$(git show HEAD~1:bin.dat | head -c 2)" "0:v3"
# An abort meeting a resume at its ref move refuses, the resume holding the pause's worktree – never
# cancelling a pause that lands under it
_ST_PZ_NEW ab13
_ST_PZ_C f.txt $'1\n2\n3' "AB13 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "AB13 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "AB13 c3"
AB_T=$(git rev-parse HEAD)
AB_SF="$(git rev-parse --git-common-dir)/git-edit-state"
_ST_RUN -d -y HEAD~1
_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt $'1\n2y\n3'
{
	print -r -- "( cd ${(q)TMP}/pz-ab13 && GIT_EDIT_ACTOR= GIT_EDIT_NO_AUTO_OPEN=1 ${(q)SELF} --abort >${(q)TMP}/ab-race.out 2>&1; : > ${(q)TMP}/ab-race.done ) </dev/null >/dev/null 2>&1 &"
	print -r -- "i=0; while [ ! -e ${(q)TMP}/ab-race.done ] && [ \$i -lt 30 ]; do sleep 0.1; i=\$((i+1)); done"
} > "$TMP/ab-race"
_AB_GIT_HOOK "$TMP/ab-gw4" "$TMP/ab-race" "update-ref -m git edit: drop"
: > "$TMP/ab-gw4/arm"
PATH="$TMP/ab-gw4:$PATH" _ST_RUN --continue
AB_W=0
until [ -e "$TMP/ab-race.done" ] || (( ++AB_W > 300 )); do sleep 0.1; done
_ST_EQ "the resume lands, its abort raced in at the move" "$RC:$([ "$(git rev-parse HEAD)" != "$AB_T" ] && echo moved):$([ -e "$TMP/ab-gw4/fired" ] && echo fired):$([ -f "$AB_SF" ] && echo state)" "0:moved:fired:"
OUT=$(<"$TMP/ab-race.out")
_ST_OUT_LACKS "the abort never says the branch was untouched" 'never touched'
# Raced in from the move's own `git`, the abort runs under the resume, and names it as that
_ST_EQ "but that a run in flight holds it" "$([[ "$OUT" == *'held by the run this one runs under'* ]] && echo told)" "told"
unfunction _AB_GIT_HOOK
cd "$TMP/repo"
