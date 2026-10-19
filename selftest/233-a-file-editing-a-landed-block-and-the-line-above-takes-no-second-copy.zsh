# A file holding its own version of a peer's fresh block where the landing's merge adds it again –
# edited or stale alike – refuses whole or as --edits, naming the diff to read before --base, never
# the carry, which, like a sync, leaves the file as it is with its record kept:
# • A file lacking the block, or one copy of two, still takes the carry, and a sync merges it in
# • A line the file lacks landing beside the block, or after it, changes none of that
# • The refusal names the landing on its trailer, the --base line above the way keeping it
_ST_SCENARIO "\e[1;96m[233] a file editing a landed block and the line above it takes no second copy\e[0m"
local DD_OLD DD_TIP DD_TRAILER
local -i DD_K=0

# Prints the file as <variant> has it – `base`, `tip` the peer's blocks landed on it, `above` and
# `inside` the tip edited there alone, `both` in both places, `drop` and `dropexit` that without a
# landed line, `shaped` the line above edited beside blocks shaped like the peer's, `near` beside
# its own copy of them three lines differing, `shifted` beside theirs a line down, `stale` without,
# `tip2` the tip and a line a second landing appends
_DD_LINES () {
	# Args: <variant>
	local V=$1
	print -l -- 'case "disk-step":' $'\tlet step = lowDiskStep()'
	if [[ "$V" == (base|tip|tip2|inside) ]]; then print -r -- $'\tprint(step.post)'; else print -r -- $'\tprint(step.post + step.withdraw)'; fi
	print -r -- $'\texit(0)'
	[ "$V" = shifted ] && print -r -- 'case "disk-free":'
	if [ "$V" = shaped ]; then
		print -l -- 'case "usage-notices":' $'\t// the notices\' passes' $'\tlet passes = usageNoticePasses()' $'\tfor lines in pass.logs {' \
			$'\t\tprint(lines)' $'\t}' $'\texit(0)' 'case "usage-shares":' $'\t// the shares buttons' $'\tprint("shares")' $'\texit(0)'
	elif [ "$V" = near ]; then
		print -l -- 'case "usage-notice":' $'\t// misc' $'\tlet x = 1' $'\tfor line in pass.log {' $'\t\tprint(line)' $'\t}' \
			$'\texit(0)' 'case "usage-shared":' $'\t// the shared button' $'\trun()' $'\texit(0)'
	elif [[ "$V" != (base|stale) ]]; then
		print -r -- 'case "usage-notice":'
		if [[ "$V" == (inside|both|drop|dropexit) ]]; then print -r -- $'\t// the notice\'s pass and what it takes back'; else print -r -- $'\t// the notice\'s pass'; fi
		print -l -- $'\tlet pass = usageNoticePass()' $'\tfor line in pass.log {' $'\t\tprint(line)' $'\t}'
		[[ "$V" == (inside|both|drop|dropexit) ]] && print -l -- $'\tfor instance in pass.withdraw {' $'\t\tprint(instance)' $'\t}'
		[ "$V" = dropexit ] || print -r -- $'\texit(0)'
		print -l -- 'case "usage-shared":' $'\t// the shared button'
		[ "$V" = drop ] || print -r -- $'\tprint("share")'
		print -r -- $'\texit(0)'
	fi
	[ "$V" = shifted ] || print -r -- 'case "disk-free":'
	print -l -- $'\tprint(free)' $'\texit(0)'
	[ "$V" = tip2 ] && print -r -- '// peer two'
	return 0
}
# Commits a fresh file as `base` unjournaled, then lands the peer's blocks on it – setting `DD_OLD`
# and `DD_TIP` to the tips around that landing
_DD_LAND () {
	DD_K+=1
	_DD_LINES base > "dd$DD_K.swift" && git add "dd$DD_K.swift" && git commit -qm "DD base $DD_K"
	DD_OLD=$(git rev-parse HEAD)
	_DD_LINES tip > "dd$DD_K.swift"
	GIT_EDIT_ACTOR=dd-peer _ST_RUN --commit --text "DD peer lands $DD_K" -- "dd$DD_K.swift"
	DD_TIP=$(git rev-parse HEAD)
}
# Lands the peer's blocks on a fresh file, then commits it whole as <variant>
_DD_TRY () {
	# Args: <variant>
	_DD_LAND
	_DD_LINES "$1" > "dd$DD_K.swift"
	_ST_RUN --commit --text "DD caller $DD_K" -- "dd$DD_K.swift"
}
# Checks the last commit landed the file as <variant> has it, right on the peer's landing
_DD_LANDED () {
	# Args: <description> <variant>
	_ST_EQ "$1" "$RC:$(git show "HEAD:dd$DD_K.swift" | cmp -s - <(_DD_LINES "$2") && print same):$(git rev-parse HEAD~1)" "0:same:$DD_TIP"
}
# Checks the last run refused, the branch unmoved, and puts the file back
_DD_REFUSED () {
	# Args: <description>
	_ST_EQ "$1" "$RC:$(git rev-parse HEAD)" "1:$DD_TIP"
	git checkout -q -- "dd$DD_K.swift"
}
# Checks the last run refused with the remedy for a file holding its own version of the block
_DD_OWN () {
	# Args: <description>
	_ST_EQ "$1" "$RC:$(git rev-parse HEAD):$(grep -c -e 'holds its own version of what landed, beside which a' <<<"$OUT"):$(grep -c -e '--carry=' <<<"$OUT")" "1:$DD_TIP:1:0"
}
_ST_PZ_NEW dd
_ST_PZ_C init.txt i "DD init"
export GIT_EDIT_ACTOR=dd-self

_DD_TRY both
_DD_OWN "a whole file editing the landed block and the line above it refuses, naming its own version"
DD_TRAILER="git-edit: error – Committed whole, 1 file(s) would take back what another caller landed: dd$DD_K.swift (dd-peer's commit run ${DD_OLD:0:7}..${DD_TIP:0:7})"
_ST_EQ "naming the landing on its trailer" "${OUT##*$'\n'}" "$DD_TRAILER"
_ST_OUT_HAS "and the diff to read before --base" "look at 'git diff ${DD_TIP:0:12} -- <path>': pass --base as above only where it shows nothing but your own edits"
_ST_EQ "the --base line above that remedy" "$(print -r -- "$OUT" | tail -3 | head -1 | grep -c -e "Pass --base=${DD_TIP:0:12} where taking it back is the point")" 1
_ST_RUN --carry="$DD_OLD"
_ST_EQ "the carry it never names leaves the file as it is" "$RC:$(_DD_LINES both | cmp -s - "dd$DD_K.swift" && print kept)" "1:kept"
_ST_OUT_HAS "naming why" "dd$DD_K.swift – its own version of a block that landed, which a merge would add a second time"
_ST_RUN --status
_ST_OUT_HAS "its record kept, the status naming the same remedy" "holding its own version of a block that landed, which a carry or merge would add a second time: dd$DD_K.swift – look at 'git diff ${DD_TIP:0:12} -- <path>': commit it with --base=${DD_TIP:0:12} only where"
_ST_OUT_LACKS "never the carry" '--carry='
_ST_RUN --commit --text "DD caller $DD_K" -- "dd$DD_K.swift"
_DD_OWN "so committing it whole still refuses"
_ST_RUN --commit --text "DD caller $DD_K" --base="$DD_TIP" -- "dd$DD_K.swift"
_DD_LANDED "while the tip as --base lands it" both
_DD_LAND
cat > "$TMP/dd-edits.json" <<EOF
{"dd$DD_K.swift": [
	["\\tprint(step.post)\\n", "\\tprint(step.post + step.withdraw)\\n"],
	["\\t// the notice's pass\\n", "\\t// the notice's pass and what it takes back\\n"],
	["\\t\\tprint(line)\\n\\t}\\n", "\\t\\tprint(line)\\n\\t}\\n\\tfor instance in pass.withdraw {\\n\\t\\tprint(instance)\\n\\t}\\n"]
]}
EOF
_ST_RUN --commit --text "DD caller $DD_K" --edits="$TMP/dd-edits.json"
_DD_OWN "as do those edits made by --edits"
_ST_OUT_HAS "naming what the pairs compose, not the checkout file" "What --edits compose in dd$DD_K.swift holds its own version of what landed, beside which a merge would add it a second time – pass --base as above only where the pairs or hunks rewriting the landed lines are your own edits of the block"
_ST_OUT_LACKS "nor its diff" 'git diff '
_DD_LINES both > "$TMP/dd-put"
_ST_RUN --commit --text "DD caller $DD_K" --put "dd$DD_K.swift=$TMP/dd-put"
_DD_OWN "and that file put whole"
_ST_OUT_HAS "naming the file put" "What you put as dd$DD_K.swift holds its own version of what landed, beside which a merge would add it a second time – pass --base as above only where it is the tip with your own edits of the block, else rebuild it from the tip"
_DD_TRY above
_DD_LANDED "as before, one editing the line above alone lands" above
_DD_TRY inside
_DD_LANDED "as does one editing inside the block alone" inside
for DD_V in drop shaped near dropexit; do
	_DD_TRY "$DD_V"
	_DD_OWN "one holding its own version of the block refuses alike ($DD_V)"
	git checkout -q -- "dd$DD_K.swift"
done
_DD_TRY shifted
_DD_REFUSED "and one holding the block as landed, but a line down"
_DD_TRY stale
_ST_OUT_HAS "while a stale file lacking the block is pointed at the carry" "Merge your edits onto what landed with 'git edit --carry=${DD_OLD:0:12}', then run this again\."
_ST_EQ "the carry printed last, the --base line above it" "$(print -r -- "$OUT" | tail -3 | head -1 | grep -c -e 'Pass --base=')" 1
_ST_RUN --carry="$DD_OLD"
_ST_EQ "which brings the block in once" "$RC:$(_DD_LINES above | cmp -s - "dd$DD_K.swift" && print merged)" "0:merged"
git checkout -q -- "dd$DD_K.swift"

# A peer's sync leaves a checkout file holding its own version of the block as it is, recorded
DD_K+=1
_DD_LINES base > "dd$DD_K.swift" && git add "dd$DD_K.swift" && git commit -qm "DD base $DD_K"
DD_OLD=$(git rev-parse HEAD)
_DD_LINES tip > "dd$DD_K.swift" && git diff -- "dd$DD_K.swift" > "$TMP/dd-peer.patch"
_DD_LINES both > "dd$DD_K.swift"
GIT_EDIT_ACTOR=dd-peer _ST_RUN --commit --text "DD peer lands $DD_K" --patch "$TMP/dd-peer.patch"
DD_TIP=$(git rev-parse HEAD)
_ST_EQ "a peer landing the block the checkout holds edited leaves the file as it is" \
	"$RC:$(git show "HEAD:dd$DD_K.swift" | cmp -s - <(_DD_LINES tip) && print landed):$(_DD_LINES both | cmp -s - "dd$DD_K.swift" && print kept)" "0:landed:kept"
_ST_OUT_HAS "saying why" "hold their own version of a block that landed, which a merge would add a second time – left as they were, as changes to it: dd$DD_K.swift"
_ST_RUN --status
_ST_OUT_HAS "its record kept" "holding its own version of a block that landed, which a carry or merge would add a second time: dd$DD_K.swift"
_ST_RUN --commit --text "DD caller $DD_K" -- "dd$DD_K.swift"
_DD_OWN "and the file committed whole then refuses"
git checkout -q -- "dd$DD_K.swift"

# A landing adding a block in two places lacked once by a file holding the first, which a sync
# brings in and the refusal points the carry at
DD_K+=1
print -l a b c d e f g h i j > "dd$DD_K.txt" && git add "dd$DD_K.txt" && git commit -qm "DD base $DD_K"
DD_OLD=$(git rev-parse HEAD)
print -l a b c '  "retry": 3,' '  "jitter": true,' d e f g h '  "retry": 3,' '  "jitter": true,' i j > "$TMP/dd-two.tip"
cp "$TMP/dd-two.tip" "dd$DD_K.txt" && git diff -- "dd$DD_K.txt" > "$TMP/dd-two.patch"
print -l a b c '  "retry": 3,' '  "jitter": true,' d e f g h i j > "$TMP/dd-two.ours"
cp "$TMP/dd-two.ours" "dd$DD_K.txt"
GIT_EDIT_ACTOR=dd-peer _ST_RUN --commit --text "DD peer lands $DD_K" --patch "$TMP/dd-two.patch"
DD_TIP=$(git rev-parse HEAD)
_ST_EQ "a sync brings a block landed twice into a file holding it once" "$RC:$(cmp -s "dd$DD_K.txt" "$TMP/dd-two.tip" && print merged)" "0:merged"
cp "$TMP/dd-two.ours" "dd$DD_K.txt"
_ST_RUN --commit --text "DD caller $DD_K" -- "dd$DD_K.txt"
_ST_OUT_HAS "while that file committed whole is pointed at the carry" "--carry=${DD_OLD:0:12}"
_ST_OUT_LACKS "never at its own version" 'holds its own version of what landed'
_ST_EQ "the branch unmoved" "$RC:$(git rev-parse HEAD)" "1:$DD_TIP"
git checkout -q -- "dd$DD_K.txt"

# A second landing appending a line takes no carry or sync either – the block the file holds its
# own version of decides – nor does a fold, its record kept until --base or a rebuild from the tip
DD_K+=1
_DD_LINES base > "dd$DD_K.swift" && _DD_LINES base > "dd${DD_K}b.swift"
git add "dd$DD_K.swift" "dd${DD_K}b.swift" && git commit -qm "DD base $DD_K"
DD_OLD=$(git rev-parse HEAD)
_DD_LINES tip > "$TMP/dd-tip1" && _DD_LINES tip2 > "$TMP/dd-tip2"
_DD_LINES both > "dd$DD_K.swift" && _DD_LINES both > "dd${DD_K}b.swift"
GIT_EDIT_ACTOR=dd-peer _ST_RUN --commit --text "DD peer lands $DD_K" --put "dd$DD_K.swift=$TMP/dd-tip1" \
	--put "dd${DD_K}b.swift=$TMP/dd-tip1" --base="$DD_OLD"
GIT_EDIT_ACTOR=dd-peer2 _ST_RUN --commit --text "DD peer appends to $DD_K" --put "dd$DD_K.swift=$TMP/dd-tip2" \
	--put "dd${DD_K}b.swift=$TMP/dd-tip2" --base="$(git rev-parse HEAD)"
DD_TIP=$(git rev-parse HEAD)
_ST_EQ "a second landing leaves the checkout files as they are" "$RC:$(git show "HEAD:dd$DD_K.swift" | cmp -s - "$TMP/dd-tip2" && print landed):$(
	_DD_LINES both | cmp -s - "dd$DD_K.swift" && _DD_LINES both | cmp -s - "dd${DD_K}b.swift" && print kept)" "0:landed:kept"
_ST_RUN --status
_ST_OUT_HAS "their records kept" "holding its own version of a block that landed, which a carry or merge would add a second time: dd$DD_K.swift"
_ST_OUT_HAS "each" "would add a second time: dd${DD_K}b.swift"
_ST_RUN --commit --text "DD caller $DD_K" -- "dd$DD_K.swift"
_DD_OWN "the file committed whole refuses"
_ST_RUN --commit --text "DD caller $DD_K" --base="$DD_TIP" -- "dd$DD_K.swift"
_ST_EQ "until the tip as --base lands it, the block once" "$RC:$(git show "HEAD:dd$DD_K.swift" | grep -c 'case \"usage-notice\"')" "0:1"
git show "HEAD:dd${DD_K}b.swift" > "dd${DD_K}b.swift"
_ST_RUN --status
_ST_OUT_LACKS "while the other rebuilt from the tip takes its record along" "would add a second time: dd${DD_K}b.swift"
DD_K+=1
_DD_LINES base > "dd$DD_K.swift" && git add "dd$DD_K.swift" && git commit -qm "DD base $DD_K"
DD_OLD=$(git rev-parse HEAD)
_DD_LINES tip2 > "dd$DD_K.swift"
GIT_EDIT_ACTOR=dd-peer _ST_RUN --commit --text "DD peer lands $DD_K" -- "dd$DD_K.swift"
_DD_LINES both > "dd$DD_K.swift"
print -r -- "own $DD_K" > "dd$DD_K-own.txt"
_ST_RUN --commit --text "DD own commit $DD_K" -- "dd$DD_K-own.txt"
DD_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "DD caller $DD_K" -- "dd$DD_K.swift"
_DD_OWN "one landing adding the block and a line besides refuses the same"
_ST_RUN --carry="$DD_OLD"
_ST_EQ "its carry leaving the file as it is" "$RC:$(_DD_LINES both | cmp -s - "dd$DD_K.swift" && print kept)" "1:kept"
_ST_RUN --amend-into="$DD_TIP" --whole -- "dd$DD_K.swift"
_DD_OWN "as does a fold of the file whole"
git checkout -q -- "dd$DD_K.swift"
export GIT_EDIT_ACTOR=
cd "$TMP/repo"
