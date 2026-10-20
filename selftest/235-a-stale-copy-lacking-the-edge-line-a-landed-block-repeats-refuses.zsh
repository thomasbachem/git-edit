# A stale file holding an exact copy of a peer's fresh block a line higher, the edge line the block
# repeats – a `},` – lacked there, reads as its own version of the block, the merge adding it again:
# • Whole, as --edits or put it refuses, naming the diff to read before --base, never the carry
# • Its sync leaves the file as it is with its record kept, the carry likewise
# • Lines taken out beyond the block's reach land as the caller's own – an entry above it, a repeat
#   far off – while a repeat the block may slide over refuses, nothing telling it from a stale copy
# • A blank line it may slide over lands, taken out as the caller's spacing
_ST_SCENARIO "\e[1;96m[235] a stale copy lacking the edge line a landed block repeats refuses\e[0m"
local SC_OLD SC_TIP SC_F SC_WIDE
local -i SC_K=0

# Prints the list as <variant> has it – `base`, `tip` the peer's entry appended, `stale` that entry
# a line higher without the line closing the one above, `own` the tip without that one – each entry
# a line longer under `SC_WIDE`
_SC_JS () {
	# Args: <variant>
	print -l -- 'const routes = [' '  {' '    path: "/x",' '  },'
	[ "$1" = own ] || print -l -- '  {' '    path: "/a",'
	[ -n "$SC_WIDE" ] && [ "$1" != own ] && print -r -- '    auth: true,'
	[[ "$1" == (base|tip) ]] && print -r -- '  },'
	if [ "$1" != base ]; then
		print -l -- '  {' '    path: "/b",' '    auth: false,'
		[ -n "$SC_WIDE" ] && print -r -- '    rate: 10,'
		print -r -- '  },'
	fi
	print -r -- '];'
}
# Prints the switch as <variant> has it – `base`, `tip` the peer's case landed on it, `above` the
# line above it edited, `far` that and the last case's `exit(0)` removed, `near` that and the
# `exit(0)` right above the landed case removed
_SC_SW () {
	# Args: <variant>
	print -r -- 'case "disk-step":'
	if [[ "$1" == (base|tip) ]]; then print -r -- $'\tprint(step.post)'; else print -r -- $'\tprint(step.post + step.withdraw)'; fi
	[ "$1" = near ] || print -r -- $'\texit(0)'
	[ "$1" = base ] || print -l -- 'case "usage-notice":' $'\tlet pass = usageNoticePass()' $'\tprint(pass)' $'\texit(0)'
	print -l -- 'case "disk-free":' $'\tprint(free)'
	[ "$1" = far ] || print -r -- $'\texit(0)'
	return 0
}
# Prints the module as <variant> has it – `base`, `tip` the peer's function landed on it, `above`
# without the blank line above it
_SC_PY () {
	# Args: <variant>
	print -l -- 'def a():' '    return 1'
	[ "$1" = above ] || print -r -- ''
	[ "$1" = base ] || print -l -- 'def b():' '    return 2' ''
	print -l -- 'def c():' '    return 3'
}
# Commits <gen>'s `base` as a fresh file unjournaled, then lands its `tip` as a peer – setting
# `SC_OLD` and `SC_TIP` to the tips around that landing and `SC_F` to the file
_SC_LAND () {
	# Args: <gen>
	SC_K+=1 SC_F=sc$SC_K.txt
	$1 base > "$SC_F" && git add "$SC_F" && git commit -qm "SC base $SC_K"
	SC_OLD=$(git rev-parse HEAD)
	$1 tip > "$SC_F"
	GIT_EDIT_ACTOR=sc-peer _ST_RUN --commit --text "SC peer lands $SC_K" -- "$SC_F"
	SC_TIP=$(git rev-parse HEAD)
}
# Lands <gen>'s peer change on a fresh file, then commits it whole as <variant>
_SC_TRY () {
	# Args: <gen> <variant>
	_SC_LAND "$1"
	$1 "$2" > "$SC_F"
	_ST_RUN --commit --text "SC caller $SC_K" -- "$SC_F"
}
# Checks the last run refused with the remedy for a file holding its own version of the block
_SC_OWN () {
	# Args: <description>
	_ST_EQ "$1" "$RC:$(git rev-parse HEAD):$(grep -c -e 'holds its own version of what landed, beside which a' <<<"$OUT"):$(grep -c -e '--carry=' <<<"$OUT")" "1:$SC_TIP:1:0"
}
# Checks the last commit landed the file as <gen> has <variant>, right on the peer's landing
_SC_LANDED () {
	# Args: <description> <gen> <variant>
	_ST_EQ "$1" "$RC:$(git show "HEAD:$SC_F" | cmp -s - <($2 "$3") && print same):$(git rev-parse HEAD~1)" "0:same:$SC_TIP"
}
_ST_PZ_NEW sc
_ST_PZ_C init.txt i "SC init"
export GIT_EDIT_ACTOR=sc-self

for SC_WIDE in "" 1; do
	_SC_TRY _SC_JS stale
	_SC_OWN "a whole file holding a stale copy of the entry without the line closing the one above refuses${SC_WIDE:+ (longer entries)}"
	_ST_OUT_HAS "naming the diff to read before --base" "look at 'git diff ${SC_TIP:0:12} -- <path>': pass --base as above only where it shows nothing but your own edits"
	[ -n "$SC_WIDE" ] || git checkout -q -- "$SC_F"
done
_ST_RUN --carry="$SC_OLD"
_ST_EQ "the carry it never names leaves the file as it is" "$RC:$(_SC_JS stale | cmp -s - "$SC_F" && print kept)" "1:kept"
_ST_RUN --commit --text "SC caller $SC_K" --base="$SC_TIP" -- "$SC_F"
_SC_LANDED "while the tip as --base lands it" _SC_JS stale
SC_WIDE=""
_SC_LAND _SC_JS
cat > "$TMP/sc-edits.json" <<EOF
{"$SC_F": [["    path: \"/a\",\\n  },\\n  {\\n", "    path: \"/a\",\\n  {\\n"]]}
EOF
_ST_RUN --commit --text "SC caller $SC_K" --edits="$TMP/sc-edits.json"
_SC_OWN "as do pairs taking that line out of the tip"
_SC_JS stale > "$TMP/sc-put"
_ST_RUN --commit --text "SC caller $SC_K" --put "$SC_F=$TMP/sc-put"
_SC_OWN "and that file put whole"

# A peer's sync leaves a checkout file holding the stale copy as it is, recorded
SC_K+=1 SC_F=sc$SC_K.txt
_SC_JS base > "$SC_F" && git add "$SC_F" && git commit -qm "SC base $SC_K"
_SC_JS tip > "$SC_F" && git diff -- "$SC_F" > "$TMP/sc-peer.patch"
_SC_JS stale > "$SC_F"
GIT_EDIT_ACTOR=sc-peer _ST_RUN --commit --text "SC peer lands $SC_K" --patch "$TMP/sc-peer.patch"
SC_TIP=$(git rev-parse HEAD)
_ST_EQ "a peer landing the entry the checkout holds a stale copy of leaves the file as it is" \
	"$RC:$(git show "HEAD:$SC_F" | cmp -s - <(_SC_JS tip) && print landed):$(_SC_JS stale | cmp -s - "$SC_F" && print kept)" "0:landed:kept"
_ST_OUT_HAS "saying why" "hold their own version of a block that landed, which a merge would add a second time – left as they were, as changes to it: $SC_F"
_ST_RUN --status
_ST_OUT_HAS "its record kept" "holding its own version of a block that landed, which a carry or merge would add a second time: $SC_F"
_ST_RUN --commit --text "SC caller $SC_K" -- "$SC_F"
_SC_OWN "and the file committed whole then refuses"
git checkout -q -- "$SC_F"

# Lines the caller took out of its own beside the landed block
_SC_TRY _SC_JS own
_SC_LANDED "a whole file holding the entry, the one above it removed, lands" _SC_JS own
_SC_TRY _SC_SW above
_SC_LANDED "as does one editing the line above the landed case" _SC_SW above
_SC_TRY _SC_SW far
_SC_LANDED "and one taking out a repeated line of its own far off besides" _SC_SW far
_SC_TRY _SC_SW near
_SC_OWN "while one taking out the repeat right above refuses, read as a stale copy"
git checkout -q -- "$SC_F"
_SC_TRY _SC_PY above
_SC_LANDED "but one taking out the blank line right above a landed function lands" _SC_PY above
export GIT_EDIT_ACTOR=
cd "$TMP/repo"
