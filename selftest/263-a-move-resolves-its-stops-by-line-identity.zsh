# A move's stops the placement's replacements leave are resolved by line identity:
# • Moved later, a crossed commit keeps its edits beside the moved lines, and its edits to them,
#   or to a file the moved commit adds, land with the commit that wrote them – named
# • Moved earlier, the moved commit's edits to a crossed commit's lines land with that one
# • The step that must build the tree the moved lines built where they stood proves it is that
#   step's own change and the edits carried to it – after a stop resolved by hand, it pauses
#   there showing what it takes in beyond, and a continue takes that
# • A hunk mixing moved and older lines goes with the moved ones while they are at least half of
#   it, else pauses, inserted lines stay where they are written – and a line whose place or
#   writer is not sure, or a file in no plain content conflict, pauses
_ST_SCENARIO "\e[1;96m[263] a move resolves its stops by line identity\e[0m"
local MI_M MI_S MI_OLD=""
# Below git 2.50 no least change is sure, so whatever line identity resolves pauses there
[[ "$(git --version)" =~ '^git version 2\.([0-9]+)\.' ]] && (( match[1] < 50 )) && MI_OLD=1
# Prints <rev>'s `f` on one line
_MI_AT () {
	# Args: <rev>
	git show "$1:f" | tr '\n' ' '
}
# Commits <subject> holding `f`'s <line>s
_MI_C () {
	# Args: <subject> <line>...
	print -l -- "${@:2}" > f && git add f && git commit -qm "$1"
}
# Checks a move landed as <want> holds – below git 2.50, that it paused, then aborts it
_MI_LANDS () {
	# Args: <description> <got> <want>
	if [ -n "$MI_OLD" ]; then
		_ST_EQ "$1 – paused before git 2.50" "$RC" "2"
		_ST_RUN --abort
	else
		_ST_EQ "$1" "$2" "$3"
	fi
}
# Moved later past a commit editing beside its lines, and one editing them
_ST_PZ_NEW mi-beside
_MI_C "MI base" a b c d e f g h
_MI_C "MI M" a m1 m2 b c d e f g h && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a m1 m2 B c d e f g H && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "a move later past a commit editing beside its lines lands, each keeping its own" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" \
	"0:MI beside|MI M|MI S|MI base|:a B c d e f g H :a m1 m2 B c d e f g H "
_ST_PZ_NEW mi-absorb
_MI_C "MI base" a b c d e f g h
_MI_C "MI M" a m1 m2 b c d e f g h && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a M1 m2 b c d e f g H && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "an edit of a moved line lands with the moved commit" "$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" \
	"0:a b c d e f g H :a M1 m2 b c d e f g H "
[ -n "$MI_OLD" ] || _ST_OUT_HAS "naming it" "(MI S)'s edits to lines in f land with [0-9a-f]* (MI M)"

# A rework adding a function a sweep then edits – inside, beside and elsewhere
_ST_PZ_NEW mi-rework
_MI_C "MI base" "head" "f1 () {" "	one" "}" "" "tail"
_MI_C "MI rework" "head" "f1 () {" "	one" "}" "" "f2 () {" "	two" "	three" "}" "" "tail" && MI_M=$(git rev-parse HEAD)
_MI_C "MI sweep" "head v2" "f1 () {" "	ONE" "}" "" "f2 () {" "	two" "	THREE" "}" "" "tail v2" && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "a sweep's edits beside an inserted function stay, those inside land with the rework" \
	"$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" \
	"0:head v2 f1 () { 	ONE }  tail v2 :head v2 f1 () { 	ONE }  f2 () { 	two 	THREE }  tail v2 "

# A block's commits each take the edits made to the lines they wrote
_ST_PZ_NEW mi-block
_MI_C "MI base" a b c d e
_MI_C "MI M1" a b m1 c d e
_MI_C "MI M2" a b m1 c d n1 e
_MI_C "MI S" A b M1 c d N1 e && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move=HEAD~3..HEAD~2 --after="$MI_S"
_MI_LANDS "a block moved later lands, each commit taking the edits of its own lines" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_MI_AT HEAD~3):$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" \
	"0:MI beside|MI M2|MI M1|MI S|MI base|:A b c d e :A b M1 c d e :A b M1 c d N1 e "

# As do lines edited in place beside each other, no word crossing between them
_ST_PZ_NEW mi-block-split
_MI_C "MI base" "a x" "b x" "c x"
_MI_C "MI M1" "a x" "m1 y" "b x" "c x"
_MI_C "MI M2" "a x" "m1 y" "b x" "n1 y" "c x"
_MI_C "MI S" "A x" "M1 y" "b x" "N1 y" "c x" && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move=HEAD~3..HEAD~2 --after="$MI_S"
_MI_LANDS "lines each edited in place beside a moved one go their own ways" \
	"$RC:$(_MI_AT HEAD~3):$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" \
	"0:A x b x c x :A x M1 y b x c x :A x M1 y b x N1 y c x "

# Moved earlier, its edits to lines a crossed commit wrote land with that commit,
# its own line inserted beside one placed where it stands among the lines there
_ST_PZ_NEW mi-earlier
_MI_C "MI base" a b c && MI_S=$(git rev-parse HEAD)
_MI_C "MI C" a c1 c2 b c
_MI_C "MI M" a C1 c2 m b C
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move=HEAD~1 --after="$MI_S"
_MI_LANDS "a move earlier lands, the edit of a line a crossed commit wrote landing there" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" \
	"0:MI beside|MI C|MI M|MI base|:a m b C :a C1 c2 m b C "
[ -n "$MI_OLD" ] || _ST_OUT_HAS "naming it" "(MI M)'s edits to lines in f land with [0-9a-f]* (MI C)"

# A file the moved commit adds takes every edit a crossed commit makes to it
_ST_PZ_NEW mi-file
_MI_C "MI base" a b
print -l n1 n2 > n && git add n && git commit -qm "MI M adds n" && MI_M=$(git rev-parse HEAD)
print -l n1 N2 > n && git add n && _MI_C "MI S" a B && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_ST_EQ "a file the moved commit adds takes a crossed commit's edits to it" \
	"$RC:$(git show HEAD~2 --stat --format= | grep -c ' n '):$(git show HEAD~1:n | tr '\n' ' ')" "0:0:n1 N2 "

# A pause at a crossed commit keeps what it carried for the moved commit's step, a resume in a
# new run taking it there – while a resolution by hand that loses a crossed commit's own change
# pauses at that step, showing what it takes in beyond its own change, which a continue takes
for MI_S in right wrong; do
	_ST_PZ_NEW "mi-pause-$MI_S"
	print -l p x q > g && git add g && _MI_C "MI base" a b c d e
	print -l p q > g && git add g && _MI_C "MI M" a m1 b c d e && MI_M=$(git rev-parse HEAD)
	print -l p s q > g && git add g && _MI_C "MI S" a M1 b c d E
	_ST_PZ_C x x1 "MI beside"
	_ST_RUN --move="$MI_M" --after=HEAD~1
	if [ -n "$MI_OLD" ]; then
		_ST_EQ "a stop left to resolve pauses – before git 2.50 too" "$RC" "2"
		_ST_RUN --abort
		continue
	fi
	_ST_EQ "a stop it can't take wholly pauses, the rest of it resolved" \
		"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U | tr '\n' ' ')" "2:g "
	if [ "$MI_S" = right ]; then
		print -l p x s q > "$(_ST_PZ_WT)/g" && git -C "$(_ST_PZ_WT)" add g
		_ST_RUN --continue
		_ST_EQ "its resume lands what it carried with the moved commit" \
			"$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1):$(git show HEAD~1:g | tr '\n' ' ')" "0:a b c d E :a M1 b c d E :p s q "
	else
		print -l p x q > "$(_ST_PZ_WT)/g" && git -C "$(_ST_PZ_WT)" add g
		_ST_RUN --continue
		_ST_EQ "while one losing the crossed commit's own change pauses at the moved commit's step" "$RC" "2"
		_ST_OUT_HAS "showing what it takes in" "g: 1 line(s) added and 0 dropped beyond its own change"
		_ST_RUN --continue
		_ST_EQ "which a continue takes as staged" "$RC:$(git show HEAD~2:g | tr '\n' ' '):$(git show HEAD~1:g | tr '\n' ' ')" "0:p x q :p s q "
	fi
done

# Doubtful, as a line comes back where another was added once it was gone, or a crossed
# commit replacing the moved lines alone would be left empty – the replay pauses as before
_ST_PZ_NEW mi-gap
_MI_C "MI base" a b c
_MI_C "MI M" a c && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a s c && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_ST_EQ "a line inserted where a moved commit's removed one stood pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW mi-split
_MI_C "MI base" a b c d e f g h
_MI_C "MI M" a m1 m2 b c d e f g h && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a X b c d e f g h && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_ST_EQ "as does a crossed commit whose whole change goes to the moved one" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# A change among lines alike reads several ways – going on where every reading
# gives the same, pausing where one reads a moved line another reads as older
_ST_PZ_NEW mi-alike
_MI_C "MI base" a b c "}" "}" "}" d e
_MI_C "MI M" a m b c "}" "}" "}" d e && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a m B c "}" "}" d e && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "a change whose readings all agree lands" "$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" "0:a B c } } d e :a m B c } } d e "
_ST_PZ_NEW mi-alike-moved
_MI_C "MI base" a "}" b c
_MI_C "MI M" a "}" "}" b c && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a "}" B c && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_ST_EQ "while one whose readings differ on a moved line pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
[ -n "$MI_OLD" ] || _ST_OUT_HAS "saying so" "meets lines whose writer aligns more than one least way"
_ST_RUN --abort

# Lines a crossed commit inserts among the moved ones stay with it – where they could stand in more
# than one place among moved lines alike, a pause rather than the stretch carried whole
for MI_S in sure slide; do
	_ST_PZ_NEW "mi-among-$MI_S"
	_MI_C "MI base" a b c
	_MI_C "MI M" a P x Q b c && MI_M=$(git rev-parse HEAD)
	if [ "$MI_S" = sure ]; then _MI_C "MI C" a P x n Q b C2; else _MI_C "MI C" a P x n x Q b C2; fi
	_ST_PZ_C g g1 "MI tip"
	_ST_RUN --move="$MI_M" --after=HEAD~1
	if [ "$MI_S" = sure ]; then
		_MI_LANDS "a line inserted among moved ones stays with the commit inserting it" \
			"$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" "0:a n b C2 :a P x n Q b C2 "
	else
		_ST_EQ "one whose place among moved lines alike reads more than one way pauses" \
			"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
		_ST_RUN --abort
	fi
done

# Lines abutting a run one commit rewrote go that side of its old lines, a gap two made pausing
_ST_PZ_NEW mi-edge
_MI_C "MI base" a x y b c
_MI_C "MI M" a X b c && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a X s b X && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "lines inserted after a run the moved commit rewrote land after its old lines" \
	"$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" "0:a x y s b X :a X s b X "
_ST_PZ_NEW mi-edge-two
_MI_C "MI base" x a b && MI_S=$(git rev-parse HEAD)
_MI_C "MI C2" a b
_MI_C "MI C3" y a b
_MI_C "MI M" m y a b
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move=HEAD~1 --after="$MI_S"
_ST_EQ "while a line dropped and one written there by two commits pauses, at the moved one's step" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U):$(git -C "$(_ST_PZ_WT)" log -1 --format=%s REBASE_HEAD)" "2:f:MI M"
_ST_RUN --abort

# The proving step compares content no line holds whole
# – a hand resolution losing the moved commit's binary change pauses there, named
_ST_PZ_NEW mi-binary
printf 'h0\0\n' > h && git add h && _MI_C "MI base" a b c d e
printf 'hM\0\n' > h && git add h && _MI_C "MI M" a m b c d e && MI_M=$(git rev-parse HEAD)
_MI_C "MI C1" a M2 b c d E
printf 'hC\0\n' > h && git add h && git commit -qm "MI C2" && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
if [ -n "$MI_OLD" ]; then
	_ST_EQ "a binary stop pauses – before git 2.50 too" "$RC" "2"
	_ST_RUN --abort
else
	printf 'hC\0\n' > "$(_ST_PZ_WT)/h" && git -C "$(_ST_PZ_WT)" add h
	_ST_RUN --continue
	_ST_EQ "a hand resolution dropping the moved commit's binary change pauses at its step" "$RC" "2"
	_ST_OUT_HAS "naming it" "h: its binary content is not its commit's change"
	_ST_RUN --abort
fi

# A file in no plain content conflict pauses – here one whose mode the moved commit changes
_ST_PZ_NEW mi-mode
_MI_C "MI base" a b c d e
print -l a m b c d e > f && chmod +x f && git add f && git commit -qm "MI M" && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a m B c d e && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_ST_EQ "a stop on a file whose mode the moved commit changes pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_OUT_HAS "saying so" "f: it is in no plain content conflict"
_ST_RUN --abort

# A hunk rewrapping moved lines with older ones goes with the moved
# ones while they are at least half of it, named – one fewer pauses
_ST_PZ_NEW mi-mixed-half
_MI_C "MI base" a "b one" c d e f g
_MI_C "MI M" a "b one" "m two" c d e f g && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a "b one m" "two" c d e f G && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "a hunk half of whose lines are moved ones lands whole with the moved commit" \
	"$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" "0:a b one c d e f G :a b one m two c d e f G "
[ -n "$MI_OLD" ] || _ST_OUT_HAS "naming it" "mixes 1 line(s) [0-9a-f]* wrote with 1 older one(s)"
_ST_PZ_NEW mi-mixed-under
_MI_C "MI base" a "b one" "c three" d e f g
_MI_C "MI M" a "b one" "m two" "c three" d e f g && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a "b one m" "two c" "three" d e f G && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_ST_EQ "one with fewer moved lines than older ones pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
[ -n "$MI_OLD" ] || _ST_OUT_HAS "saying so" "changes fewer lines still to be written than older ones"
_ST_RUN --abort
# Lines inserted between two moved ones stay with the commit inserting them
_ST_PZ_NEW mi-inside
_MI_C "MI base" a b c d e f g
_MI_C "MI M" a m1 m2 b c d e f g && MI_M=$(git rev-parse HEAD)
_MI_C "MI S" a m1 s m2 b c d e f G && MI_S=$(git rev-parse HEAD)
_ST_PZ_C x x1 "MI beside"
_ST_RUN --move="$MI_M" --after="$MI_S"
_MI_LANDS "lines inserted between two moved ones stay with the commit inserting them" \
	"$RC:$(_MI_AT HEAD~2):$(_MI_AT HEAD~1)" "0:a s b c d e f G :a m1 s m2 b c d e f G "
unfunction _MI_AT _MI_C _MI_LANDS
cd "$TMP/repo"
