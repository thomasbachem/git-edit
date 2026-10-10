# Pauses, waits and values are named as they stand:
# • An undo blocked by another caller's pause names whose it is and to wait or ask its owner,
#   never that caller's continue or abort – the caller's own pause still takes those
# • A paused placement is named as one in the actor refusals and `--status`, never as a reorder
# • An empty value for a flag naming a commit refuses in two lines, no usage – a drop with no
#   commit suggests `-d`
# • An edit's continue with a new subject names the commit as landed under it
# • A replant whose every pick was skipped ends its line with a full stop
# • A wait that runs out reports its bound, never more
# • Files taken whole from a subdirectory still refuse mid-cherry-pick
_ST_SCENARIO "\e[1;96m[194] pauses, waits and values are named as they stand\e[0m"
local NS_WT NS_ANCHOR NS_EDIT NS_OLD
# Runs `git edit <arg>...` as caller <label>
_N194_AS () {
	# Args: <label> <arg>...
	export GIT_EDIT_ACTOR=$1
	shift
	_ST_RUN "$@"
	export GIT_EDIT_ACTOR=
}

# A placement pauses on its conflict – c2 rewrote the line it changes again
_ST_PZ_NEW ns1
git config rerere.enabled false
_ST_PZ_C f.txt x "NS1 base" && _ST_PZ_C a.txt a "NS1 c1" && NS_ANCHOR=$(git rev-parse --short HEAD)
_ST_PZ_C f.txt y "NS1 c2" && _ST_PZ_C b.txt b "NS1 c3"
# A run on record, which an undo would take back
_ST_RUN -M --text "NS1 c3 reworded" HEAD
print -r -- z > f.txt
_N194_AS n-alice --commit --text "NS1 placed" --after="$NS_ANCHOR" -- f.txt
_ST_EQ "a placement pauses on its conflict" "$RC" "2"
_N194_AS n-bob --continue
_ST_OUT_HAS "another caller's continue names it as the placement it is" "The paused commit placed after $NS_ANCHOR is n-alice's – refusing to continue it as n-bob"
_N194_AS n-bob --status
_ST_OUT_HAS "as its status trailer does for another caller" "^git-edit: paused – commit placed after $NS_ANCHOR is n-alice's, not yours"
OUT=$(env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=n-bob "$SELF" -M --text="NS1 c3 x" --wait=1 HEAD </dev/null 2>&1)
_ST_OUT_HAS "as a run waiting on it does" "^Waiting up to 1s for n-alice's paused commit placed after $NS_ANCHOR on main (paused"
_N194_AS n-bob --undo
_ST_EQ "an undo beside another caller's pause refuses" "$RC:$(git log -1 --format=%s)" "1:NS1 c3 reworded"
_ST_OUT_HAS "naming whose pause it is" "paused for its resolution – n-alice's, not yours – nothing was undone"
_ST_OUT_HAS "and to wait for it or ask its owner" "Wait for it to clear, then undo ('git edit --status' shows it) – or ask its owner to finish it"
_ST_OUT_LACKS "never to continue or abort it" "finish it with --continue or --abort"
_N194_AS n-alice --undo
_ST_OUT_HAS "while its own caller's undo is told to finish it first" "Your operation is in flight on main – finish it with --continue or --abort before undoing"
_N194_AS n-alice --abort
_ST_EQ "the placement aborts" "$RC" "0"
git checkout -q -- f.txt

# Empty values from a lookup that found nothing – `$(git log …)` – and a drop missing its commit
for NS_OLD in --amend-into= --move=:--after=HEAD~1 --after=:--commit:--text=x:--:a.txt --before=:--exec:--:true; do
	_ST_RUN ${(s.:.)NS_OLD}
	# The banner, the error, its hint and the trailer
	_ST_EQ "$NS_OLD refuses in two lines, no usage" "$RC:$(print -r -- "$OUT" | grep -c 'usage: git edit'):$(print -r -- "$OUT" | grep -c .)" "1:0:4"
	_ST_OUT_HAS "naming the flag and its empty value" "error – ${${NS_OLD%%:*}%=}'s value is empty – it names a commit, and nothing was done"
done
_ST_RUN -d -y
_ST_OUT_HAS "a drop with no commit suggests a drop" "Missing <commit> – name the commit to act on (e.g. 'git edit -d <sha>')"
_ST_RUN -M --subject=x
_ST_OUT_HAS "while a reword's still suggests a reword" "(e.g. 'git edit -M --subject=\"…\" $(git log -1 --format=%h)')"

# An edit's continue with a new subject names the commit as landed, the old subject apart
_ST_PZ_NEW ns2
_ST_PZ_C a.txt a "NS2 a" && _ST_PZ_C b.txt b "NS2 b" && _ST_PZ_C c.txt c "NS2 c"
_ST_RUN HEAD~1
NS_WT=$(_ST_PZ_WT)
print -r -- b2 > "${NS_WT:-$ST_NO_WT}/b.txt"
_ST_RUN --continue --subject "NS2 b renamed"
_ST_EQ "an edit's continue with --subject lands" "$RC:$(git log -1 --format=%s HEAD~1)" "0:NS2 b renamed"
_ST_OUT_HAS "naming the landed commit and its new subject" "^  edited: $(git log -1 --format=%h HEAD~1) NS2 b renamed\$"
_ST_OUT_HAS "and the subject it replaced" "^  replaced: NS2 b\$"
_ST_RUN HEAD~1
NS_WT=$(_ST_PZ_WT)
print -r -- b3 > "${NS_WT:-$ST_NO_WT}/b.txt"
_ST_RUN --continue
_ST_OUT_HAS "a continue keeping the subject names the landed commit too" "^  edited: $(git log -1 --format=%h HEAD~1) NS2 b renamed\$"
_ST_OUT_LACKS "replacing none" "^  replaced: "

# A replant whose picks were all skipped has nothing to list
_ST_PZ_NEW ns3
git config rerere.enabled false
_ST_PZ_C a.txt base "NS3 A" && _ST_PZ_C b.txt base "NS3 B"
git checkout -q -b up && _ST_PZ_C a.txt up "NS3 UP a" && _ST_PZ_C b.txt up "NS3 UP b" && git checkout -q main
_ST_PZ_C a.txt mine "NS3 X a" && _ST_PZ_C b.txt mine "NS3 Z b"
_ST_RUN --onto=up
_ST_RUN --skip
_ST_RUN --skip
_ST_OUT_HAS "a replant that skipped every pick ends its line with a full stop" "^Replanted 0 of 2 commit(s) onto up\.\$"

# A wait running out reports its bound – here a nap outlasting it, as a loaded machine's may
_ST_PZ_NEW ns4
_ST_PZ_C a.txt a "NS4 a" && _ST_PZ_C b.txt b "NS4 b" && _ST_PZ_C c.txt c "NS4 c"
_N194_AS n-alice HEAD~1
mkdir -p "$TMP/ns4-nap" && print -l '#!/bin/sh' 'exec /bin/sleep 2.05' > "$TMP/ns4-nap/sleep" && chmod +x "$TMP/ns4-nap/sleep"
OUT=$(env -u GIT_EDIT_SELFTEST_DEPTH PATH="$TMP/ns4-nap:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=n-bob "$SELF" -M --text="NS4 c2" --wait=1 HEAD </dev/null 2>&1)
_ST_OUT_HAS "a wait running out reports its bound, not the nap past it" "still in flight on main after waiting 1s, paused for its resolution – n-alice's – nothing ran"
_N194_AS n-alice --abort

# Files taken whole from a subdirectory refuse mid-cherry-pick, its prefix and state read at once
_ST_PZ_NEW ns5
mkdir -p d && _ST_PZ_C d/f.txt f "NS5 f" && _ST_PZ_C g.txt g "NS5 g"
git update-ref CHERRY_PICK_HEAD HEAD
print -r -- f2 > d/f.txt
NS_OLD=$PWD
cd d && _ST_RUN --commit --text x -- f.txt
cd "$NS_OLD"
_ST_OUT_HAS "files taken whole from a subdirectory refuse mid-cherry-pick" "A cherry-pick is in progress – finish it with git commit before taking files whole"
git update-ref -d CHERRY_PICK_HEAD
cd "$TMP/repo"
