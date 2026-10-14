# A file holding a landed block beside edits of its own comes along without a second copy:
# • The sync of an `--edits` commit adding an entry keeps the checkout's removal of those above it
# • A landing the checkout can't come along with names such a file as edited on, not as reverting
_ST_SCENARIO "\e[1;96m[225] a file holding a landed block beside its own edits takes no second copy\e[0m"
local S225_OLD S225_NEW

# Prints entry <name> at version <v>
_S225_ENTRY () {
	# Args: <name> <v>
	printf '  %s: {\n    v: %s,\n    dev: true\n  },\n' "$1" "$2"
}
# Writes <file> holding each <name>:<v> entry, then the closing `d`
_S225_FILE () {
	# Args: <file> <name>:<v>...
	local F=$1 E
	shift
	{ print '{'; for E in "$@"; do _S225_ENTRY "${E%%:*}" "${E#*:}"; done; print '  d: 4'; print '}'; } > "$F"
}

# The caller removed entries a and b and added c, committing c alone
_S225_FILE s225-a.txt a:1 b:2
git add s225-a.txt && git commit -qm "S225 base"
_S225_FILE s225-a.txt c:3
GIT_EDIT_ACTOR=s225 _ST_RUN --commit --text "S225 c added" \
	--edits '{"s225-a.txt": [["    dev: true\n  },\n  d: 4\n", "    dev: true\n  },\n  c: {\n    v: 3,\n    dev: true\n  },\n  d: 4\n"]]}'
_ST_EQ "an --edits commit of an entry beside the checkout's removal lands it" \
	"$RC:$(git show HEAD:s225-a.txt | grep -c 'c: {')" "0:1"
_ST_EQ "the checkout takes no second copy, its removal staying uncommitted" \
	"$(grep -c 'c: {' s225-a.txt):$(git diff --numstat HEAD -- s225-a.txt | cut -f1-2 | tr '\t' ' ')" "1:0 8"
git checkout -q -- s225-a.txt

# The same file shape in a checkout a landing of the entry can't come along with
_S225_FILE s225-b.txt a:1 b:2
git add s225-b.txt && git commit -qm "S225 reconcile base"
S225_OLD=$(git rev-parse HEAD)
git worktree add -q --detach "$TMP/s225-side" HEAD
_S225_FILE "$TMP/s225-side/s225-b.txt" a:1 b:2 c:3
git -C "$TMP/s225-side" commit -qam "S225 c landed"
S225_NEW=$(git -C "$TMP/s225-side" rev-parse HEAD)
git worktree remove --force "$TMP/s225-side"
_S225_FILE s225-b.txt c:3
_ST_RUN_UNSYNCED --exec --base="$S225_OLD" --no-verify -- git reset -q --hard "$S225_NEW"
_ST_EQ "a landing the checkout can't come along with lands" "$RC:$(git rev-parse HEAD)" "0:$S225_NEW"
_ST_OUT_LACKS "naming a file holding its entry beside other edits as no revert" 'back there: s225-b.txt'
_ST_OUT_HAS "but as edited on" 'your own): s225-b.txt'
git reset -q --hard
