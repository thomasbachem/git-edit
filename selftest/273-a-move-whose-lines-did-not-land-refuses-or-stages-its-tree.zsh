# A move whose lines its own resolution broke refuses its run – a lying `git hash-object` adds a
# line to what a stop's resolution writes – rerere's records of it forgotten for a clean rerun,
# while one a stop resolved by hand left otherwise stages the tree the move began with
_ST_SCENARIO "\e[1;96m[273] a move whose lines did not land refuses, or after a hand stop stages its tree\e[0m"
local LC_A LC_B LC_D LC_TIP LC_TREE LC_WT

# Below git 2.50 no line identity is sure, so a move resolves no stop of its own to begin with
if [[ ! "$(git --version)" =~ '^git version 2\.([0-9]+)\.' ]] || (( match[1] >= 50 )); then
	# Prints `f.js` with the call's finders as given, and above its function the definition given
	_LC_F () {
		# Args: <finders> [<definition>]
		print -l -- ${2:+"$2"} "function check(source) {" "	for(const v of [$1].sort()) {" "		report(v);" "	}" "}"
	}
	# B's edit touches A's words, so it is carried to A, past which A is moved
	_ST_PZ_NEW lc1
	_LC_F "...findNested(), ...findMarkers(), ...findNumbers()" > f.js
	git add f.js && git commit -qm "LC base"
	_LC_F "...findNested(), ...findCostly(), ...findMarkers(), ...findNumbers()" > f.js
	git commit -qam "LC A adds the costly finder" && LC_A=$(git rev-parse HEAD)
	_LC_F "...findNested(), ...findCostly(), ...findUnbalanced(), ...findMarkers(), ...findNumbers()" "const findUnbalanced = () => [];" > f.js
	git commit -qam "LC B adds the unbalanced finder" && LC_B=$(git rev-parse HEAD)
	print x > g.js && git add g.js && git commit -qm "LC C" && LC_TIP=$(git rev-parse HEAD)
	mkdir -p "$TMP/lc-shim"
	cat > "$TMP/lc-shim/git" <<SHIM
#!/bin/sh
for A in "\$@"; do LAST=\$A; done
case "\$*" in *"hash-object -w "*/git-edit-move.*/r) [ -e "$TMP/lc.fired" ] || { echo "injected();" >> "\$LAST"; : > "$TMP/lc.fired"; } ;; esac
exec "$(whence -p git)" "\$@"
SHIM
	chmod +x "$TMP/lc-shim/git"
	PATH="$TMP/lc-shim:$PATH" _ST_RUN --move="$LC_A" --after="$LC_B"
	_ST_EQ "a move its own resolution broke refuses, the branch untouched" "$RC:$(git rev-parse HEAD)" "1:$LC_TIP"
	_ST_OUT_HAS "its trailer naming the file and the rerun" \
		"^git-edit: error – The move's lines did not land as its commits wrote them at ${LC_A:0:7} – a resolution of its own before it changed what they hold, so nothing was applied – f\.js – run it again under GIT_EDIT_NO_SELF_RESOLVE=1 to resolve its stops by hand$"
	_ST_OUT_HAS "forgetting what rerere kept of the run" '^Forgot 1 resolution(s) rerere recorded of this run.s own'
	_ST_RUN --status
	_ST_OUT_HAS "leaving nothing in flight" 'no operation in flight'
	GIT_EDIT_NO_SELF_RESOLVE=1 _ST_RUN --move="$LC_A" --after="$LC_B"
	LC_WT=$(_ST_PZ_WT)
	_ST_EQ "its rerun stops on the conflict's markers, nothing pre-filled" \
		"$RC:$(( $(grep -c '^<<<<<<<' "${LC_WT:-$ST_NO_WT}/f.js") > 0 )):$(grep -c 'injected' "${LC_WT:-$ST_NO_WT}/f.js")" "2:1:0"
	_ST_RUN --abort

	# A crossed commit rewriting the moved line with two older ones is left to the hand, resolved
	# there without that line – the moved commit's step then stages the tree the move began with
	_ST_PZ_NEW lc2
	_LC_F "...findNested(), ...findMarkers(), ...findNumbers()" > f.js && print -l p q r s > g.txt
	git add f.js g.txt && git commit -qm "LC2 base"
	_LC_F "...findNested(), ...findCostly(), ...findMarkers(), ...findNumbers()" > f.js && print -l p m q r s > g.txt
	git commit -qam "LC2 A adds the costly finder and m" && LC_A=$(git rev-parse HEAD)
	_LC_F "...findNested(), ...findCostly(), ...findUnbalanced(), ...findMarkers(), ...findNumbers()" "const findUnbalanced = () => [];" > f.js
	git commit -qam "LC2 B adds the unbalanced finder"
	print -l p M Q R s > g.txt && git commit -qam "LC2 D capitalizes" && LC_D=$(git rev-parse HEAD)
	print x > h.txt && git add h.txt && git commit -qm "LC2 C" && LC_TREE=$(git rev-parse "HEAD^{tree}")
	_ST_RUN --move="$LC_A" --after="$LC_D"
	_ST_EQ "the crossed commit rewriting the moved line with older ones stops" "$RC:$(grep -c 'This stop builds .* LC2 D capitalizes' <<<"$OUT")" "2:1"
	_ST_RESOLVE "$(_ST_PZ_WT)" g.txt $'p\nQ\nR\ns'
	_ST_RUN --continue
	_ST_EQ "resolved by hand, the moved commit's step pauses" "$RC" "2"
	_ST_OUT_HAS "staging the tree the move began with" \
		"^${LC_A:0:7} (LC2 A adds the costly finder and m) staged as the tree the move began with, beyond what it and the edits carried to it change – resolved by hand before it:$"
	_ST_OUT_HAS "taking it as staged on a continue" 'Check it, then git edit --continue takes it as staged'
	_ST_OUT_LACKS "never refused as its own resolution's doing" 'did not land as its commits wrote them'
	_ST_RUN --continue
	_ST_EQ "which lands in the new order, the tip's tree unchanged" \
		"$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse "HEAD^{tree}")" \
		"0:LC2 C|LC2 A adds the costly finder and m|LC2 D capitalizes|LC2 B adds the unbalanced finder|LC2 base|:$LC_TREE"
	unfunction _LC_F
fi
