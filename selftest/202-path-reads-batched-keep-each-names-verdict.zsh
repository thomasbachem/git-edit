# Paths read in one git call per kind keep each name's verdict – a space, a quote, a tab, a leading
# dash and non-ASCII alike:
# • `--commit` takes them whole, deleted or staged before, refusing one unmerged, ignored, outside a
#   sparse checkout, holding markers, changed since `--base` or lacking a peer's landing
# • A staged fold re-syncs them, refuses one a later commit adds and one holding markers
# • `--carry` merges and brings them past a tip moved on since – one opening on a quote, one ending
#   in a CR, which a line-reading git call can't take, among them
# • A run on twice the paths starts none more of those reads
_ST_SCENARIO "\e[1;96m[202] path reads batched keep each name's verdict\e[0m"
local BP_T BP_P BP_MODE BP_B BP_U BP_OLD BP_NEW BP_REAL=${commands[git]} BP_MK
local -a BP_ODD BP_ALL BP_GOT
local -i BP_K BP_C1 BP_C2
BP_ODD=("sp ace.txt" 'q"uote.txt' $'ta\tb.txt' "-dash.txt" "ünï.txt")

# Commits a tree holding each <path> as <content> on `HEAD`, moving the branch alone – the checkout
# and its index left behind, as an agent's run leaves them
BP_LAND () {
	# Args: <subject> <content> <path>...
	local S=$1 C=$2 B
	shift 2
	B=$(print -r -- "$C" | git hash-object -w --stdin)
	GIT_INDEX_FILE=$TMP/bp-idx git read-tree HEAD
	for BP_P in "$@"; do GIT_INDEX_FILE=$TMP/bp-idx git update-index --add --cacheinfo "100644,$B,$BP_P"; done
	git update-ref refs/heads/main "$(git commit-tree "$(GIT_INDEX_FILE=$TMP/bp-idx git write-tree)" -p HEAD -m "$S")"
	rm -f "$TMP/bp-idx"
}

# A whole-file commit – staged before, deleted, unmerged, ignored, sparse
_ST_PZ_NEW bp1
for BP_P in "${BP_ODD[@]}" o.txt; do print -r -- base > "$BP_P"; done
git add -A && git commit -qm "BP1 base"
for BP_P in "${BP_ODD[@]}"; do print -r -- staged > "$BP_P"; done
git add -A
for BP_P in "${BP_ODD[@]}"; do print -r -- whole > "$BP_P"; done
_ST_RUN --commit --text "BP1 whole" -- "${BP_ODD[@]}"
_ST_EQ "files with odd names commit whole" "$RC:$(for BP_P in "${BP_ODD[@]}"; do git show "HEAD:$BP_P"; done | tr '\n' ' ')" \
	"0:whole whole whole whole whole "
_ST_EQ "their earlier staging taken over" "$(git diff --cached --name-only | wc -l | tr -d ' ')" "0"
rm -f -- "${BP_ODD[@]}"
_ST_RUN --commit --text "BP1 gone" -- "${BP_ODD[@]}"
_ST_EQ "and gone from the checkout, commit as removed" "$RC:$(git ls-tree -z --name-only HEAD | tr '\0' '\n')" "0:o.txt"
BP_B=$(print -r -- u | git hash-object -w --stdin)
BP_U=$'ta\tb.um'
print -r -- u > "$BP_U" && mkdir -p "sp dir" && print -r -- u > "sp dir/f.um"
printf '100644 %s 1\t%s\n100644 %s 2\t%s\n100644 %s 1\tsp dir/f.um\n100644 %s 2\tsp dir/f.um\n' "$BP_B" "$BP_U" "$BP_B" "$BP_U" "$BP_B" "$BP_B" | \
	git update-index --index-info
print -r -- more >> o.txt
_ST_RUN --commit --text x -- o.txt "$BP_U" /bp-outside
_ST_OUT_HAS "an unmerged odd name refuses ahead of a later name outside the repository" "$BP_U is unmerged"
_ST_RUN --commit --text x -- /bp-outside "$BP_U"
_ST_OUT_HAS "which, named first, refuses first" '/bp-outside names no file inside the repository'
_ST_RUN --commit --text x -- "sp dir"
_ST_OUT_HAS "a directory holding an unmerged file refuses as unmerged" 'sp dir is unmerged'
git rm -q --cached -- "$BP_U" "sp dir/f.um" && rm -rf -- "$BP_U" "sp dir"
print -r -- '*.ign' >> .git/info/exclude
for BP_P in 'q"uote.ign' "ünï.new" $'ta\tb.new' "-dash.new"; do print -r -- n > "$BP_P"; done
_ST_RUN --commit --text x -- "ünï.new" 'q"uote.ign'
_ST_OUT_HAS "an ignored odd name the tip lacks refuses" 'q"uote.ign is ignored'
_ST_RUN --commit --text "BP1 new" -- "ünï.new" $'ta\tb.new' "-dash.new"
_ST_EQ "while odd names not ignored commit" "$RC:$(git ls-tree -z --name-only HEAD | tr '\0' '\n' | grep -c '\.new$')" "0:3"
mkdir -p in out && print -r -- i > "in/sp ace.txt" && print -r -- o > "out/-dash.txt"
git add -A && git commit -qm "BP1 cone"
git sparse-checkout set in 2>/dev/null
_ST_RUN --commit --text x -- "out/-dash.txt"
_ST_OUT_HAS "an odd name outside a sparse checkout refuses" 'out/-dash.txt lies outside the sparse checkout'
rm -f "in/sp ace.txt"
_ST_RUN --commit --text "BP1 cone gone" -- "in/sp ace.txt"
_ST_EQ "while one inside it lands as removed" "$RC:$(git cat-file -e 'HEAD:in/sp ace.txt' 2>/dev/null && echo kept)" "0:"
git sparse-checkout disable 2>/dev/null

# Markers at each file's own size, new ones only – whole or staged
print -r -- '*.big conflict-marker-size=9' > .gitattributes && git add .gitattributes && git commit -qm "BP1 attrs"
BP_MK=$'<<<<<<< ours\nx\n=======\ny\n>>>>>>> theirs'
BP_ALL=("sp ace.mk" 'q"uote.mk' $'ta\tb.mk' "-dash.mk" "ünï.mk" "ünï.big")
for BP_P in "${BP_ALL[@]}"; do print -r -- "$BP_MK" > "$BP_P"; done
BP_T=$(git rev-parse HEAD)
_ST_RUN --commit --text x -- "${BP_ALL[@]}"
_ST_EQ "files with odd names holding a conflict refuse" "$RC:$(git rev-parse HEAD)" "1:$BP_T"
_ST_OUT_HAS "each named, one whose marker size is larger passing" \
	"Conflict markers in 5 file(s) taken whole – nothing landed: sp ace.mk, q\"uote.mk, ta	b.mk, -dash.mk, ünï.mk"
git add -- "ünï.mk" && git commit -qm "BP1 markers at the tip"
print -r -- tail >> "ünï.mk"
_ST_RUN --commit --text "BP1 markers kept" -- "ünï.mk" "ünï.big"
_ST_EQ "markers the tip holds already pass" "$RC" "0"
git add -- "-dash.mk"
_ST_RUN --amend-into=HEAD -- "-dash.mk"
_ST_OUT_HAS "a staged one refuses too" 'Conflict markers in 1 file(s) as staged – nothing landed: -dash.mk'
git rm -q --cached -- "-dash.mk" && rm -f -- "sp ace.mk" 'q"uote.mk' $'ta\tb.mk' "-dash.mk"

# Guarded against what changed since `--base`, and against a labeled peer's landing
_ST_PZ_NEW bp2
for BP_P in "${BP_ODD[@]}"; do print -l l1 l2 l3 > "$BP_P"; done
git add -A && git commit -qm "BP2 lines"
BP_T=$(git rev-parse HEAD)
print -l l1 l2 L3 > 'q"uote.txt' && git commit -qam "BP2 later"
print -l M1 l2 l3 > 'q"uote.txt' && print -l M1 l2 l3 > "ünï.txt"
_ST_RUN --commit --text x --base="$BP_T" -- "ünï.txt" 'q"uote.txt'
_ST_OUT_HAS "a file changed since --base refuses, named alone" "they would take that back: q\"uote.txt"
_ST_RUN --commit --text "BP2 based" --base="$BP_T" -- "ünï.txt"
_ST_EQ "while one unchanged since lands" "$RC" "0"
print -r -- "printf 'l1\\nPEER\\nl3\\n' > \"\$(printf 'ta\\tb.txt')\" && git commit -qam 'BP2 peer'" > "$TMP/bp-peer.sh"
export GIT_EDIT_ACTOR=bp-peer
_ST_RUN --exec -- sh "$TMP/bp-peer.sh"
export GIT_EDIT_ACTOR=bp-self
print -l M1 l2 l3 > $'ta\tb.txt' && print -l M1 l2 l3 > "-dash.txt"
BP_T=$(git rev-parse HEAD)
_ST_RUN --commit --text x -- "-dash.txt" $'ta\tb.txt'
_ST_EQ "a file lacking a peer's landing refuses" "$RC:$(git rev-parse HEAD)" "1:$BP_T"
_ST_OUT_HAS "naming it alone" $'ta\tb.txt – bp-peer\'s exec run'
_ST_OUT_LACKS "never the file beside it" '^ *-dash.txt – '
print -l M1 PEER l3 > $'ta\tb.txt'
_ST_RUN --commit --text "BP2 on the peer's" -- "-dash.txt" $'ta\tb.txt'
_ST_EQ "while one holding it lands" "$RC" "0"
export GIT_EDIT_ACTOR=

# A staged fold re-syncs its odd names, a CR-ending one too, and refuses one a later commit adds
_ST_PZ_NEW bp3
BP_ALL=("${BP_ODD[@]}" $'cr\r')
for BP_P in "${BP_ALL[@]}"; do print -l l1 l2 l3 > "$BP_P"; done
git add -A && git commit -qm "BP3 base"
BP_T=$(git rev-parse HEAD)
print -r -- o > o.txt && git add o.txt && git commit -qm "BP3 o"
print -r -- n > "ünï.late" && git add -- "ünï.late" && git commit -qm "BP3 late"
for BP_P in "${BP_ALL[@]}"; do print -l l1 l2 l3 fold > "$BP_P"; done
git add -A
_ST_RUN --amend-into="$BP_T"
_ST_EQ "a staged fold over odd names lands in its target" \
	"$RC:$(for BP_P in "${BP_ALL[@]}"; do git show "HEAD~2:$BP_P" | tail -1; done | tr '\n' ' ')" "0:fold fold fold fold fold fold "
_ST_EQ "re-syncing each" "$(git diff --cached --name-only | wc -l | tr -d ' ')" "0"
_ST_OUT_LACKS "none left staged" 'Left staged'
_ST_OUT_LACKS "nor read as new to the target" 'does not exist'
print -r -- n2 > "ünï.late" && git add -- "ünï.late"
_ST_RUN --amend-into="$(git rev-parse HEAD~2)"
_ST_OUT_HAS "one a later commit adds refuses" 'ünï.late – arrives in'
git reset -q -- "ünï.late" && git checkout -q -- "ünï.late"

# A carry merges and brings odd names – onto the rewrite, and past a tip moved on since
_ST_PZ_NEW bp4
BP_ALL=("${BP_ODD[@]}" '"lead.txt' $'cr\r')
for BP_P in "${BP_ALL[@]}" o.txt; do print -l l1 l2 l3 > "$BP_P"; done
git add -A && git commit -qm "BP4 base"
BP_OLD=$(git rev-parse HEAD)
BP_LAND "BP4 rewrite" "$(print -l l1 l2 L3)" "${BP_ALL[@]}"
BP_NEW=$(git rev-parse HEAD)
for BP_P in "${(@)BP_ALL[1,3]}" '"lead.txt'; do print -l E1 l2 l3 > "$BP_P"; done
_ST_RUN --carry="$BP_OLD"
BP_GOT=()
for BP_P in "${BP_ALL[@]}"; do BP_GOT+=("$(tr '\n' ' ' < "$BP_P")"); done
_ST_EQ "a carry merges edited odd names and brings the rest" "$RC:${(j:|:)BP_GOT}" \
	"0:E1 l2 L3 |E1 l2 L3 |E1 l2 L3 |l1 l2 L3 |l1 l2 L3 |E1 l2 L3 |l1 l2 L3 "
_ST_EQ "their entries taking what landed" "$(git diff --cached --name-only | wc -l | tr -d ' '):$(git diff --name-only | wc -l | tr -d ' ')" "0:4"
_ST_OUT_HAS "naming the merged" 'Carried onto the new content: "lead.txt, q"uote.txt, sp ace.txt, ta	b.txt$'
_ST_PZ_NEW bp5
for BP_P in "${BP_ALL[@]}" o.txt; do print -l l1 l2 l3 > "$BP_P"; done
git add -A && git commit -qm "BP5 base"
BP_OLD=$(git rev-parse HEAD)
BP_LAND "BP5 rewrite" "$(print -l l1 l2 L3)" "${BP_ALL[@]}"
BP_NEW=$(git rev-parse HEAD)
printf '%s refs/heads/main %s %s exec\n' "$(date +%s)" "$BP_OLD" "$BP_NEW" >> .git/git-edit-journal
BP_LAND "BP5 later" "$(print -l l1 LATER L3)" "sp ace.txt" o.txt
for BP_P in "${(@)BP_ALL[1,3]}"; do print -l E1 l2 l3 > "$BP_P"; done
_ST_RUN --carry
BP_GOT=()
for BP_P in "${BP_ALL[@]}"; do BP_GOT+=("$(tr '\n' ' ' < "$BP_P")"); done
_ST_EQ "past a tip moved on since, it carries as onto the rewrite" "$RC:${(j:|:)BP_GOT}" \
	"1:E1 l2 l3 |E1 l2 L3 |E1 l2 L3 |l1 l2 L3 |l1 l2 L3 |l1 l2 L3 |l1 l2 L3 "
_ST_OUT_HAS "leaving one changed again there, named" 'sp ace.txt – changed again since the rewrite'

# Twice the paths start no more of those reads – counted through a git standing in for the real one
mkdir -p "$TMP/bp-si"
{
	print -r -- '#!/bin/sh'
	print -r -- 'bp_log () { while :; do case "$1" in -C|-c) shift 2 ;; --*) shift ;; *) break ;; esac; done'
	print -r -- "	printf '%s %s\\n' \"\$1\" \"\$2\" >> ${(q)TMP}/bp-si/log; }"
	print -r -- 'bp_log "$@"'
	print -r -- "exec ${(q)BP_REAL} \"\$@\""
} > "$TMP/bp-si/git"
chmod +x "$TMP/bp-si/git"
# Prints how many reads of <kind pattern> a <mode> over <n> files starts
BP_COUNT () {
	# Args: commit|fold|carry <n> <kind pattern>
	local M=$1 N=$2 F
	local -a FS
	_ST_PZ_NEW "bp-$M$N"
	for (( BP_K = 1; BP_K <= 40; BP_K++ )); do print -l l1 l2 l3 > "f$BP_K.txt"; done
	git add -A && git commit -qm "BP base" && print -r -- o > o.txt && git add o.txt && git commit -qm "BP o"
	FS=(f{1..$N}.txt)
	case $M in
		commit) for F in "${FS[@]}"; do print -r -- more >> "$F"; done ;;
		fold) for F in "${FS[@]}"; do print -r -- more >> "$F"; done; git add -A ;;
		carry)
			BP_OLD=$(git rev-parse HEAD)
			BP_LAND "BP rewrite" "$(print -l l1 l2 L3)" "${FS[@]}"
			for F in "${(@)FS[1,N/2]}"; do print -l E1 l2 l3 > "$F"; done
			;;
	esac
	: > "$TMP/bp-si/log"
	case $M in
		commit) PATH="$TMP/bp-si:$PATH" _ST_RUN --commit --text "BP whole" -- "${FS[@]}" ;;
		fold) PATH="$TMP/bp-si:$PATH" _ST_RUN --amend-into=HEAD ;;
		carry) PATH="$TMP/bp-si:$PATH" _ST_RUN --carry="$BP_OLD" ;;
	esac
	REPLY=$RC:$(grep -c -E "$3" "$TMP/bp-si/log")
}
# Each mode's runs on 8 files and on 16, as "<rc>:<reads>" – a read a path adds 8 more
for BP_MODE in "commit:^(ls-tree|ls-files|check-attr|cat-file|rev-parse) " "fold:^(ls-tree|ls-files|check-attr|cat-file|rev-parse) " \
	"carry:^(ls-tree|rev-parse|cat-file -e) "; do
	BP_COUNT "${BP_MODE%%:*}" 8 "${BP_MODE#*:}"
	BP_GOT=("$REPLY")
	BP_COUNT "${BP_MODE%%:*}" 16 "${BP_MODE#*:}"
	BP_GOT+=("$REPLY")
	BP_C1=${BP_GOT[1]#*:} BP_C2=${BP_GOT[2]#*:}
	_ST_EQ "a ${BP_MODE%%:*} of twice the files lands, starting no more reads a path ($BP_C1, $BP_C2)" \
		"${BP_GOT[1]%%:*}:${BP_GOT[2]%%:*}:$(( BP_C2 - BP_C1 < 4 ))" "0:0:1"
done
cd "$TMP/repo"
