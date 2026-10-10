# The terminal sync's two-tree merge runs on a copy of the index under its lock, each path checked
# there first, so a peer staging in a landed path's way keeps it, named, never "came along"
# Every stop a hand `git rebase --continue` passed counts for the absorption and marker guards
# A hand finish whose last pick git left out as emptied is judged by the replay record, no refusal
# offering a hard reset past the guards
# No resume prints the record step's `Executing:` line
_ST_SCENARIO "\e[1;96m[165] the sync merges under the index lock, stops passed by hand count for the guards\e[0m"
local HP_REAL HP_BIN HP_T HP_WT HP_L
HP_REAL=$(whence -p git)

# A peer staging a file `d` where a terminal drop lands d/x.txt, and P/u.txt where it
# lands a file P, after the sync read the checkout – once, the unlocked merge deleted
# both, files and all, and named them as come along
_ST_PZ_NEW hp1
_ST_PZ_C a.txt a "HP1 base"
mkdir d && print -r -- x > d/x.txt && print -r -- notes > P && git add -A && git commit -qm "HP1 add d/x.txt, P"
git rm -rq d P && git commit -qm "HP1 rm d, P"
_ST_PZ_C t.txt t "HP1 tip"
HP_BIN="$TMP/hp1-bin" && mkdir -p "$HP_BIN"
# Stages them as a peer on the sync's first read of the index flags, past its read of the checkout
cat > "$HP_BIN/git" <<EOF
#!/bin/sh
case " \$* " in *" ls-files -v "*)
  if [ ! -e "$PWD/.git/hp1-mark" ]; then
    : > "$PWD/.git/hp1-mark"
    ( unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE; cd "$PWD" && echo 'PEER d' > d && mkdir -p P && echo 'peer u' > P/u.txt && "$HP_REAL" add d P/u.txt ) >/dev/null 2>&1
  fi ;;
esac
exec "$HP_REAL" "\$@"
EOF
chmod +x "$HP_BIN/git"
_ST_TTY PATH="$HP_BIN:$PATH" -- -d -y HEAD~1
_ST_EQ "a peer's staging in a landed path's way after the sync's read stays, files and all" \
	"$RC:$([ -e .git/hp1-mark ] && echo fired):$(git show :d):$(git show :P/u.txt):$(<d):$(<P/u.txt)" "0:fired:PEER d:peer u:PEER d:peer u"
_ST_OUT_HAS "each named as left, with what is in its way" 'd/x.txt – d staged where its directory goes'
_ST_OUT_HAS "a file's place too" 'P – files staged under it where the rewrite put a file'
_ST_OUT_LACKS "and neither said to have come along" 'came along'
# While with no peer the same drop brings both along
_ST_PZ_NEW hp1b
_ST_PZ_C a.txt a "HP1b base"
mkdir d && print -r -- x > d/x.txt && print -r -- notes > P && git add -A && git commit -qm "HP1b add d/x.txt, P"
git rm -rq d P && git commit -qm "HP1b rm d, P"
_ST_PZ_C t.txt t "HP1b tip"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "with no peer, the merge brings both along" "$RC:$(<d/x.txt):$(<P):$(git status --porcelain | wc -l | tr -d ' ')" "0:x:notes:0"
_ST_OUT_HAS "named as come along" 'came along – now as they landed: P, d/x.txt'

# Makes a fresh repo `pz-<name>` where a drop of Y stops at Z on f.txt and then at Q on g.txt,
# H after it changing g.txt's last line – `HP_T` its tip
_HP_SEED () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l 1 2 3 4 5 6 7 8 9 > f.txt && print -l a b c d e f g h > g.txt && git add -A && git commit -qm "HP2 base"
	print -l 1 2 DEBUG 3 4 5 6 7 8 9 > f.txt && print -l a b DBG c d e f g h > g.txt && git commit -qam "HP2 Y debug"
	print -l 1 2 DEBUG 3z 4 5 6 7 8 9 > f.txt && git commit -qam "HP2 Z edit 3"
	print -l a b DBG cq d e f g h > g.txt && git commit -qam "HP2 Q edit c"
	print -l a b DBG cq d e f g h2 > g.txt && git commit -qam "HP2 H edit h"
	_ST_PZ_C t.txt t "HP2 top"
	HP_T=$(git rev-parse HEAD)
}
# Starts the drop and resolves its first stop to Z's own content,
# a hand continue taking it on to the second
_HP_TO_SECOND () {
	_ST_RUN -d -y HEAD~4
	HP_WT=$(_ST_PZ_WT)
	_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" f.txt $'1\n2\n3z\n4\n5\n6\n7\n8\n9'
	GIT_EDITOR=true git -C "${HP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
}

# A drop's second stop reached by a hand `git rebase --continue`, resolved taking in a later
# commit's whole change before the resume – once, it landed, the victim named as emptied by the drop
_HP_SEED hp2
_HP_TO_SECOND
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" g.txt $'a\nb\ncq\nd\ne\nf\ng\nh2'
_ST_RUN --continue
_ST_EQ "a stop reached by a hand continue counts for the absorption guard" "$RC:$(git rev-parse HEAD)" "1:$HP_T"
_ST_OUT_HAS "naming the commit whose change it took in" 'HP2 H edit h – g\.txt (left out as emptied)'
_ST_RUN --abort
# While the same stop resolved to its own commit lands, the later one replaying on top
_HP_SEED hp2b
_HP_TO_SECOND
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" g.txt $'a\nb\ncq\nd\ne\nf\ng\nh'
_ST_RUN --continue
_ST_EQ "while one resolved to its own commit lands, the later one replayed" "$RC:$(git log -1 --format=%s HEAD~1):$(git show HEAD~1:g.txt | tail -1)" "0:HP2 H edit h:h2"
# A hand finish past that stop is judged alike
_HP_SEED hp2c
_HP_TO_SECOND
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" g.txt $'a\nb\ncq\nd\ne\nf\ng\nh2'
GIT_EDITOR=true git -C "${HP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a hand finish past a stop it reached by hand counts it too" "$RC:$(git rev-parse HEAD)" "1:$HP_T"
_ST_OUT_HAS "naming the commit" 'HP2 H edit h – g\.txt (left out as emptied)'
_ST_RUN --abort
# Markers a hand continue committed at a stop it passed refuse, as a hand finish's do
_HP_SEED hp2m
_ST_RUN -d -y HEAD~4
HP_WT=$(_ST_PZ_WT)
git -C "${HP_WT:-$ST_NO_WT}" add f.txt
GIT_EDITOR=true git -C "${HP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" g.txt $'a\nb\ncq\nd\ne\nf\ng\nh'
_ST_RUN --continue
_ST_EQ "markers a hand continue committed at a stop it passed refuse" "$RC:$(git rev-parse HEAD)" "1:$HP_T"
_ST_OUT_HAS "named as committed by the hand continue" 'continued by hand in .* committed conflict markers'
_ST_RUN --abort
# A resume running the replay record's step prints no line of it
_HP_SEED hp4
_ST_RUN -d -y HEAD~4
HP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" f.txt $'1\n2\n3z\n4\n5\n6\n7\n8\n9'
_ST_RUN --continue
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" g.txt $'a\nb\ncq\nd\ne\nf\ng\nh'
_ST_RUN --continue
_ST_EQ "a resume through the record step lands" "$RC:$(git log -1 --format=%s HEAD~1)" "0:HP2 H edit h"
_ST_OUT_HAS "having run the rebase on" 'Successfully rebased'
_ST_OUT_LACKS "printing no line of git-edit's own step" 'Executing: .*git-edit-replayed'

# A hand finish whose last pick git left out as emptied – once refused as stopped short, its hint a
# hard reset landing the worktree past every guard
_ST_PZ_NEW hp3
print -l 1 2 3 4 5 6 7 8 9 > f.txt && print -l a b c > g.txt && git add -A && git commit -qm "HP3 base"
print -l 1 2 DEBUG 3 4 5 6 7 8 9 > f.txt && print -l a b c DBG > g.txt && git commit -qam "HP3 Y debug"
print -l 1 2 DEBUG 3z 4 5 6 7 8 9 > f.txt && git commit -qam "HP3 Z edit 3"
print -l a b c > g.txt && git commit -qam "HP3 X undebug g"
_ST_RUN -d -y HEAD~2
HP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" f.txt $'1\n2\n3z\n4\n5\n6\n7\n8\n9'
GIT_EDITOR=true git -C "${HP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a hand finish whose last pick the drop emptied lands" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:HP3 Z edit 3 HP3 base "
_ST_OUT_HAS "that pick named as emptied" 'emptied: .* HP3 X undebug g'
_ST_PZ_NEW hp3b
print -l 1 2 3 4 5 6 7 8 9 > f.txt && git add -A && git commit -qm "HP3b base"
print -l 1 2 DEBUG 3 4 5 6 7 8 9 > f.txt && git commit -qam "HP3b Y debug"
print -l 1 2 DEBUG 3z 4 5 6 7 8 9 > f.txt && git commit -qam "HP3b Z edit 3"
print -l 1 2 DEBUG 3z 4 5 6 7 8 9V > f.txt && git commit -qam "HP3b V edit 9"
HP_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~2
HP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" f.txt $'1\n2\n3z\n4\n5\n6\n7\n8\n9V'
GIT_EDITOR=true git -C "${HP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "while one whose stop took in that pick's change refuses" "$RC:$(git rev-parse HEAD)" "1:$HP_T"
_ST_OUT_HAS "naming it" 'HP3b V edit 9 – f\.txt (left out as emptied)'
_ST_OUT_LACKS "offering no hard reset past the guards" 'reset -q --hard'
_ST_RUN --abort
# And a hand quit there still refuses as stopped short, no record saved
_ST_RUN -d -y HEAD~2
HP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${HP_WT:-$ST_NO_WT}" f.txt $'1\n2\n3z\n4\n5\n6\n7\n8\n9'
git -C "${HP_WT:-$ST_NO_WT}" rebase --quit >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a hand quit past the stop still refuses" "$RC:$(git rev-parse HEAD)" "1:$HP_T"
_ST_OUT_HAS "as stopped short of the pick it never made" 'stopped short of its last 2 commit'
_ST_OUT_LACKS "again with no hard reset offered" 'reset -q --hard'
_ST_RUN --abort
cd "$TMP/repo"
