# A printed merge step keeps its sides in a temp dir of its own, names no fixed path in the git dir
# and removes nothing:
# • A carry's merge of edits in place and of ones a rename left at the old path, a whole-file
#   guard's merge into a new name and its staging rebuild each land run as printed in zsh, bash
#   and sh – from the top and from a subdirectory, with names and the checkout's path holding
#   spaces and both quotes
# • Two copies run at once each merge their own file's sides
_ST_SCENARIO "\e[1;96m[201] printed merge steps keep their sides apart and remove nothing\e[0m"
local P201_WHERE P201_SH P201_TOP P201_OLD P201_STEP P201_PID P201_REAL=${commands[git]} P201_S P201_T
local P201_F1="s d/a'1 \"x.txt" P201_F2="s d/b'2 \"y.txt" P201_F3="s d/c'3 \"z.txt" P201_F4="s d/d'4 \"w.txt"
local P201_R1="s d/r'1 \"x.txt" P201_R2="s d/r'2 \"x.txt" P201_D="s d/d'o \"c"
local P201_EDITS='{"s d/d'\''o \"c": [["doc line 4\n", "doc line 4 cy\n"]]}'
local -a P201_STEPS
local -i P201_I

# Runs <step> in <shell> where the caller stands, as one pasted there would
_P201_IN () {
	# Args: <shell> <step>
	case $1 in
		zsh) zsh -f -c "$2" ;;
		bash) bash --norc --noprofile -c "$2" ;;
		sh) sh -c "$2" ;;
	esac >/dev/null 2>&1
}
# Prints each of <top>'s three merged files as its conflict count and the sides it holds
_P201_SIDES () {
	# Args: <top>
	local F
	for F in "$P201_F1" "$P201_F2" "$P201_F4"; do
		print -rn -- "$(grep -c '^<<<<<<< ' "$1/$F") ${(j: :)${(@f)$(grep -e '^MINE' -e '^THEIRS' "$1/$F" | LC_ALL=C sort)}}|"
	done
}
# Puts back what the checkout held before a carry's merge ran
_P201_MINE () {
	print -l 1 2 MINE1 4 5 6 > "$P201_F1" && print -l 1 2 MINE2 4 5 6 > "$P201_F2" && print -l 1 2 MINE3 4 5 6 > "$P201_F3"
}
# Makes repo <name>: a landing changed two files' third line and renamed a third with that line
# changed, while the checkout changed it in each – the branch moved as one made elsewhere moves it
_P201_CARRY_SETUP () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	mkdir 's d'
	print -l 1 2 3 4 5 6 > "$P201_F1" && print -l 1 2 3 4 5 6 > "$P201_F2" && print -l 1 2 3 4 5 6 > "$P201_F3"
	git add -A && git commit -qm "P201 base" && P201_OLD=$(git rev-parse HEAD)
	git checkout -q -b topic && git mv "$P201_F3" "$P201_F4"
	print -l 1 2 THEIRS1 4 5 6 > "$P201_F1" && print -l 1 2 THEIRS2 4 5 6 > "$P201_F2" && print -l 1 2 THEIRS4 4 5 6 > "$P201_F4"
	git add -A && git commit -qm "P201 topic" && git checkout -q main
	_P201_MINE
	git update-ref refs/heads/main topic "$P201_OLD"
}

# A carry's merges – edits in place, and edits a rename left at the old path
for P201_WHERE in top sub; do
	_P201_CARRY_SETUP "p201 c'$P201_WHERE\""
	P201_TOP=$PWD
	[ $P201_WHERE = sub ] && cd 's d'
	_ST_RUN --carry="$P201_OLD"
	P201_STEPS=("${(@f)$(sed -n 's/^  \(.* git merge-file -- .*\)$/\1/p' <<<"$OUT")}")
	_ST_EQ "a carry's conflicts each print a merge opening on a temp dir of its own ($P201_WHERE)" \
		"$RC:${#P201_STEPS}:$(print -rl -- "${P201_STEPS[@]}" | grep -c 'T=\$(mktemp -d) && git cat-file --filters ')" "1:3:3"
	_ST_EQ "going to the top first only from a subdirectory ($P201_WHERE)" "$(print -rl -- "${P201_STEPS[@]}" | grep -c '^cd ')" "$([ $P201_WHERE = sub ] && print 3 || print 0)"
	_ST_OUT_LACKS "removing nothing ($P201_WHERE)" '\(^\|[ ;&|(]\)rm '
	_ST_OUT_LACKS "naming no fixed path in the git dir ($P201_WHERE)" 'git-edit-\(base\|landed\|staged\)'
	for P201_SH in zsh bash sh; do
		( cd "$P201_TOP" && _P201_MINE && print -l 1 2 THEIRS4 4 5 6 > "$P201_F4" )
		for P201_STEP in "${P201_STEPS[@]}"; do _P201_IN $P201_SH "$P201_STEP"; done
		_ST_EQ "which, run as printed in $P201_SH from the $P201_WHERE, merge each file, markers and all" \
			"$(_P201_SIDES "$P201_TOP")" "1 MINE1 THEIRS1|1 MINE2 THEIRS2|1 MINE3 THEIRS4|"
	done
	_ST_EQ "leaving nothing in the git dir ($P201_WHERE)" "$(ls -a "$P201_TOP/.git" | grep -c '^git-edit-\(base\|landed\|staged\)')" "0"
	cd "$P201_TOP"
done

# Two copies at once – the first held just before its merge until the second has run through
mkdir -p "$TMP/p201-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- "if [ \"\$1\" = merge-file ] && [ -e ${(q)TMP}/p201-arm ]; then rm -f ${(q)TMP}/p201-arm; : > ${(q)TMP}/p201-in; ${(q)TMP}/st-hold ${(q)TMP}/p201-go; fi"
	print -r -- "exec ${(q)P201_REAL} \"\$@\""
} > "$TMP/p201-bin/git"
chmod +x "$TMP/p201-bin/git"
_P201_MINE && print -l 1 2 THEIRS4 4 5 6 > "$P201_F4"
cd 's d'
: > "$TMP/p201-arm"
( PATH="$TMP/p201-bin:$PATH" sh -c "${P201_STEPS[1]:-false}" >/dev/null 2>&1 ) &
P201_PID=$!
P201_I=0; until [ -e "$TMP/p201-in" ] || ! kill -0 $P201_PID 2>/dev/null || (( ++P201_I > 1200 )); do sleep 0.1; done
PATH="$TMP/p201-bin:$PATH" sh -c "${P201_STEPS[2]:-false}" >/dev/null 2>&1
: > "$TMP/p201-go"
wait $P201_PID
cd "$P201_TOP"
_ST_EQ "two copies run at once each merge their own file's sides" "$([ -e "$TMP/p201-in" ] && print held):${$(_P201_SIDES "$P201_TOP")%|*|}|" \
	"held:1 MINE1 THEIRS1|1 MINE2 THEIRS2|"

# A whole-file guard's merge into a file this commit renames, read before a landing on its old name
for P201_WHERE in top sub; do
	_ST_PZ_NEW "p201 r'$P201_WHERE\""
	P201_TOP=$PWD
	mkdir 's d' && printf 'n%s\n' {1..8} > "$P201_R1" && git add -A && git commit -qm "P201R base"
	cp "$P201_R1" "$TMP/p201r-stale"
	GIT_EDIT_ACTOR=p201-peer _ST_RUN --exec -- sh -c 'sed "s/^n3\$/P3/" "$1" > t && mv t "$1" && git commit -qam "P201R land"' sh "$P201_R1"
	sed 's/^n7$/C7/' "$TMP/p201r-stale" > "$P201_R2" && rm -f "$P201_R1"
	P201_T=$(git rev-parse HEAD)
	if [ $P201_WHERE = sub ]; then
		cd 's d'
		GIT_EDIT_ACTOR=p201-self _ST_RUN --commit --text "P201R rename" -- "${P201_R1#s d/}" "${P201_R2#s d/}"
	else
		GIT_EDIT_ACTOR=p201-self _ST_RUN --commit --text "P201R rename" -- "$P201_R1" "$P201_R2"
	fi
	P201_STEPS=("${(@f)$(sed -n 's/^  Merge what landed into the new name with: //p' <<<"$OUT")}")
	_ST_EQ "a rename made on stale content refuses with a merge of its own ($P201_WHERE)" \
		"$RC:$(git rev-parse HEAD):${#P201_STEPS}:$(print -rl -- "${P201_STEPS[@]}" | grep -c 'T=\$(mktemp -d) && git show ')" "1:$P201_T:1:1"
	_ST_OUT_LACKS "removing nothing ($P201_WHERE)" '\(^\|[ ;&|(]\)rm '
	_ST_OUT_LACKS "naming no fixed path in the git dir ($P201_WHERE)" 'git-edit-\(base\|landed\|staged\)'
	for P201_SH in zsh bash sh; do
		sed 's/^n7$/C7/' "$TMP/p201r-stale" > "$P201_TOP/$P201_R2"
		_P201_IN $P201_SH "${P201_STEPS[1]:-false}"
		_ST_EQ "which, run as printed in $P201_SH from the $P201_WHERE, merges what landed in" \
			"$(sed -n '3p;7p' "$P201_TOP/$P201_R2" | tr '\n' ' ')" "P3 C7 "
	done
	cd "$P201_TOP"
done

# A staged fold's rebuild of the staging alone, another caller's line in the checkout file
for P201_WHERE in top sub; do
	_ST_PZ_NEW "p201 s'$P201_WHERE\""
	P201_TOP=$PWD
	mkdir 's d' && print -l "doc line "{1..40} > "$P201_D" && chmod +x "$P201_D" && print -r -- x > t && git add -A && git commit -qm "P201S base"
	print -l "doc line "{1..29} "doc line 30 bob" "doc line "{31..40} > "$P201_D" && git add -- "$P201_D"
	print -l "doc line "{1..9} "doc line 10 alice" "doc line "{11..29} "doc line 30 bob" "doc line "{31..40} > "$P201_D"
	GIT_EDIT_ACTOR=p201-cy _ST_RUN --commit --text "P201S cy" --edits "$P201_EDITS"
	# The target past the landing, which a fold below it would apply again
	print -r -- y > t && git commit -qm "P201S target" -- t && P201_T=$(git rev-parse HEAD)
	P201_S=$(git rev-parse ":$P201_D")
	if [ $P201_WHERE = sub ]; then
		cd 's d'
		GIT_EDIT_ACTOR=p201-bob _ST_RUN --amend-into="$P201_T" -- "${P201_D#s d/}"
	else
		GIT_EDIT_ACTOR=p201-bob _ST_RUN --amend-into="$P201_T" -- "$P201_D"
	fi
	P201_STEPS=("${(@f)$(sed -n "s/^  Then rebuild the staging of .*, which 'git add' would take in too: \\(.*\\) – and run this again.*\$/\\1/p" <<<"$OUT")}")
	_ST_EQ "a staged fold without the landing refuses, rebuilding the staging in a temp dir of its own ($P201_WHERE)" \
		"$RC:${#P201_STEPS}:$(print -rl -- "${P201_STEPS[@]}" | grep -c 'T=\$(mktemp -d) && git cat-file blob ')" "1:1:1"
	_ST_OUT_LACKS "removing nothing ($P201_WHERE)" '\(^\|[ ;&|(]\)rm '
	_ST_OUT_LACKS "naming no fixed path in the git dir ($P201_WHERE)" 'git-edit-\(base\|landed\|staged\)'
	for P201_SH in zsh bash sh; do
		git -C "$P201_TOP" update-index --cacheinfo "100755,$P201_S,$P201_D"
		_P201_IN $P201_SH "${P201_STEPS[1]:-false}"
		_ST_EQ "which, run as printed in $P201_SH from the $P201_WHERE, stages the landing beside the staging alone" \
			"$(git -C "$P201_TOP" ls-files -s -- ":(literal)$P201_D" | cut -c1-6):$(git -C "$P201_TOP" show ":$P201_D" | grep -c -e ' cy$' -e ' bob$'):$(git -C "$P201_TOP" show ":$P201_D" | grep -c alice)" "100755:2:0"
	done
	cd "$P201_TOP"
done
cd "$TMP"
