# A drop, edit or squash asks again for a pause on the repository once it holds its `-C` path, or
# before it makes its temp worktree – one recorded meanwhile refuses it, never stranded by its
# landing – and a move whose stop took in what a later commit changes refuses, as a fold's does,
# a commit emptied whole too, lines the stop's own change undoes counting for neither side
_ST_SCENARIO "\e[1;96m[168] late pauses and moves taking a later change refuse\e[0m"
local ZK_P ZK_T ZK_A ZK_B ZK_PID ZK_WT
local -i ZK_I
# Writes `<dir>/<command>` standing in for the real one, running <script> first where <dir>/arm is
# there and <case pattern> takes the call's arguments
_ZK_STAND_IN () {
	# Args: <dir> <command> <case pattern> <script>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \" \$* \" in $3) if [ -e ${(q)1}/arm ]; then $4; fi ;; esac"
		print -r -- "exec ${(q)commands[$2]} \"\$@\""
	} > "$1/$2"
	chmod +x "$1/$2"
}
# Waits for <file>, or for <pid> to end – bounded
_ZK_WAIT () {
	# Args: <file> <pid>
	ZK_I=0
	until [ -e "$1" ] || ! kill -0 "$2" 2>/dev/null || (( ++ZK_I > 1200 )); do sleep 0.1; done
}
# Writes f.txt's lines and commits them
_ZK_C () {
	# Args: <subject> <line>...
	print -l -- "${@:2}" > f.txt && git add f.txt && git commit -qm "$1"
}

# A -C drop past its first look at the pause slot, an edit pausing elsewhere on the branch before
# the drop holds its path, refuses as in flight – the pause then lands what was done there
_ST_PZ_NEW zk1
_ST_PZ_C a.txt a1 "ZK1 a" && _ST_PZ_C b.txt b1 "ZK1 b" && _ST_PZ_C c.txt c1 "ZK1 c"
ZK_P="$TMP/zk1-wt" ZK_T=$(git rev-parse HEAD)
git worktree add -q --detach "$ZK_P" HEAD
_ZK_STAND_IN "$TMP/zk1-git" git "*\" -C $ZK_P rev-parse --show-toplevel \"*" "mv ${(q)TMP}/zk1-git/arm ${(q)TMP}/zk1-in; ${(q)TMP}/st-hold ${(q)TMP}/zk1-go"
: > "$TMP/zk1-git/arm"
( PATH="$TMP/zk1-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -C "$ZK_P" -d -y "$ZK_T" </dev/null > "$TMP/zk1.b" 2>&1; print -r -- $? > "$TMP/zk1.brc" ) &
ZK_PID=$!
_ZK_WAIT "$TMP/zk1-in" $ZK_PID
_ST_RUN HEAD~1
_ST_EQ "an edit pauses on the branch meanwhile" "$RC" "2"
ZK_WT=$(_ST_PZ_WT)
print -r -- b2 > "${ZK_WT:-$ST_NO_WT}/b.txt"
git -C "${ZK_WT:-$ST_NO_WT}" commit -qa --amend --no-edit
: > "$TMP/zk1-go"
wait $ZK_PID
OUT=$(<"$TMP/zk1.b")
_ST_EQ "a -C drop that took its path past that pause refuses, the branch kept" "$(<"$TMP/zk1.brc"):$(git rev-parse HEAD)" "1:$ZK_T"
_ST_OUT_HAS "as an operation in flight on it" 'Another git-edit operation is in flight on main, paused for its resolution'
_ST_RUN --continue
_ST_EQ "and the pause lands what was done there" "$RC:$(git show HEAD~1:b.txt)" "0:b2"
_ST_RUN -C "$ZK_P" -d -y HEAD
_ST_EQ "while a -C drop with no pause about lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:ZK1 b|ZK1 a|"

# The same for a drop in a temp worktree, the pause recorded past its first look
_ST_PZ_NEW zk2
_ST_PZ_C a.txt a1 "ZK2 a" && _ST_PZ_C b.txt b1 "ZK2 b" && _ST_PZ_C c.txt c1 "ZK2 c"
ZK_T=$(git rev-parse HEAD)
_ZK_STAND_IN "$TMP/zk2-git" git "*\" rev-list --count $ZK_T \"*" "mv ${(q)TMP}/zk2-git/arm ${(q)TMP}/zk2-in; ${(q)TMP}/st-hold ${(q)TMP}/zk2-go"
: > "$TMP/zk2-git/arm"
( PATH="$TMP/zk2-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d -y "$ZK_T" </dev/null > "$TMP/zk2.b" 2>&1; print -r -- $? > "$TMP/zk2.brc" ) &
ZK_PID=$!
_ZK_WAIT "$TMP/zk2-in" $ZK_PID
_ST_RUN HEAD~1
_ST_EQ "an edit pauses meanwhile" "$RC" "2"
: > "$TMP/zk2-go"
wait $ZK_PID
OUT=$(<"$TMP/zk2.b")
_ST_EQ "a drop in a temp worktree past that pause refuses, the branch kept" "$(<"$TMP/zk2.brc"):$(git rev-parse HEAD)" "1:$ZK_T"
_ST_OUT_HAS "as an operation in flight" 'Another git-edit operation is in flight on main'
_ST_RUN --abort
_ST_RUN -d -y HEAD
_ST_EQ "while one with no pause about lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:ZK2 b|ZK2 a|"

# A move of a commit below the one it builds on, its stop resolved to the file as it holds it –
# the final step resolving itself empties the other into it – refuses, naming it, and offers the squash
_ST_PZ_NEW zk3
git config rerere.enabled false
_ZK_C "ZK3 base" 1 2 3 4 5 6 7 8
_ZK_C "ZK3 A edit 4" 1 2 3 4a 5 6 7 8 && ZK_A=$(git rev-parse HEAD)
_ZK_C "ZK3 B edit 4a" 1 2 3 4b 5 6 7 8 && ZK_B=$(git rev-parse HEAD)
_ST_RUN --move="$ZK_B" --before="$ZK_A"
_ST_EQ "a move below what it builds on stops" "$RC" "2"
ZK_WT=$(_ST_PZ_WT)
git -C "${ZK_WT:-$ST_NO_WT}" show "$ZK_B:f.txt" > "${ZK_WT:-$ST_NO_WT}/f.txt" && git -C "${ZK_WT:-$ST_NO_WT}" add f.txt
_ST_RUN --continue
_ST_EQ "resolved to what its commit holds, emptying the other, it refuses" "$RC:$(git rev-parse HEAD)" "1:$ZK_B"
_ST_OUT_HAS "naming the commit it emptied" 'ZK3 A edit 4 – f\.txt (left out as emptied)'
_ST_OUT_HAS "and offering to squash the two" "git edit -s=${ZK_A:0:12} ${ZK_B:0:12}"
_ST_OUT_LACKS "never landing under ok" '^git-edit: ok'
_ST_RUN --abort
_ST_RUN -s="$ZK_A" "$ZK_B"
_ST_EQ "the squash it offers lands" "$RC:$(git rev-list --count HEAD):$(git show HEAD:f.txt | sed -n 4p)" "0:2:4b"

# A partial take counts too – the later commit keeping a change elsewhere, its change to the stop's
# file gone into the stop's commit
_ST_PZ_NEW zk4
git config rerere.enabled false
_ZK_C "ZK4 base" 1 2 3 4 5 6 7 8
print -r -- g1 > g.txt && git add g.txt && _ZK_C "ZK4 A edit 4" 1 2 3 4a 5 6 7 8 && ZK_A=$(git rev-parse HEAD)
_ZK_C "ZK4 B edit 4a" 1 2 3 4b 5 6 7 8 && ZK_B=$(git rev-parse HEAD)
_ST_RUN --move="$ZK_B" --before="$ZK_A"
ZK_WT=$(_ST_PZ_WT)
git -C "${ZK_WT:-$ST_NO_WT}" show "$ZK_B:f.txt" > "${ZK_WT:-$ST_NO_WT}/f.txt" && git -C "${ZK_WT:-$ST_NO_WT}" add f.txt
_ST_RUN --continue
_ST_EQ "a move whose stop took part of a later commit's change refuses" "$RC:$(git rev-parse HEAD)" "1:$ZK_B"
_ST_OUT_HAS "naming that commit and file" 'ZK4 A edit 4 – f\.txt$'
_ST_RUN --abort

# Its neighbour: abutting edits that build on nothing of each other, the stop resolved to its own
# change alone, land in the new order
_ST_PZ_NEW zk5
git config rerere.enabled false
_ZK_C "ZK5 base" 1 2 3 4 5 6 7 8
_ZK_C "ZK5 A edit 4" 1 2 3 4a 5 6 7 8 && ZK_A=$(git rev-parse HEAD)
_ZK_C "ZK5 B edit 5" 1 2 3 4a 5b 6 7 8 && ZK_B=$(git rev-parse HEAD)
_ST_RUN --move="$ZK_B" --before="$ZK_A"
_ST_EQ "a move of abutting edits stops" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2\n3\n4\n5b\n6\n7\n8'
_ST_RUN --continue
_ST_EQ "while one resolved to its own change alone lands, both kept" "$RC:$(git log --format=%s | tr '\n' '|')" "0:ZK5 A edit 4|ZK5 B edit 5|ZK5 base|"
_ST_EQ "on the tree it began with" "$(git rev-parse 'HEAD^{tree}')" "$(git rev-parse "$ZK_B^{tree}")"

# And a commit the new order cancels – a line it adds that the stop's own commit removes, nothing
# taken in – lands as dropped
_ST_PZ_NEW zk6
git config rerere.enabled false
_ZK_C "ZK6 base" 1 2 3 4 5
_ZK_C "ZK6 A add x" 1 2 3 x 4 5 && ZK_A=$(git rev-parse HEAD)
_ZK_C "ZK6 B drop x, edit 4" 1 2 3 4b 5 && ZK_B=$(git rev-parse HEAD)
_ST_RUN --reorder "$ZK_B" "$ZK_A"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2\n3\n4b\n5'
_ST_RUN --continue
_ST_EQ "a commit the new order cancels lands as dropped" "$RC:$(git log --format=%s | tr '\n' '|')" "0:ZK6 B drop x, edit 4|ZK6 base|"
_ST_OUT_HAS "named so" 'dropped: .*ZK6 A add x'
