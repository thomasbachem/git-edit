# A fold's or squash's replacement lands only on the lines its hunk changed, traced into the stop's
# content through a diff – never on the same text a commit wrote elsewhere, nor changed words on
# a neighboring line holding them – so such a stop pauses, where it once landed content nobody wrote
_ST_SCENARIO "\e[1;96m[260] a replacement lands only on the lines its hunk changed\e[0m"
local LH_A
# Commits a line a later commit rewrites, writing its text on another line, then one beside
_LH_RELOCATED () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l 1 foo 3 4 baz 6 > f && git add f && git commit -qm "LH target"
	LH_A=$(git rev-parse HEAD)
	print -l 1 bar 3 4 foo 6 > f && git commit -qam "LH relocates"
	_ST_PZ_C g g1 "LH beside"
}
_LH_RELOCATED lh-fold
print -l 1 bar 3 4 qux 6 > f
_ST_RUN --amend-into="$LH_A" --whole -- f
_ST_EQ "a fold of the relocated line pauses at the target" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U):$(git rev-parse HEAD~2):$(git show HEAD~2:f | tr '\n' '|')" \
	"2:f:$LH_A:1|foo|3|4|baz|6|"
_ST_RUN --abort
_LH_RELOCATED lh-squash
print -l 1 bar 3 4 qux 6 > f && git commit -qam "LH fix"
_ST_RUN -s="$LH_A" HEAD
_ST_EQ "as does a squash of it" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# Changed words held by a neighboring line too
_ST_PZ_NEW lh-words
print -l 1 "p alpha beta delta q" "z alpha beta gamma w" 4 > f && git add f && git commit -qm "LH target"
LH_A=$(git rev-parse HEAD)
print -l 1 "p alpha beta gamma q" "z alpha beta gamma w" 4 > f && git commit -qam "LH rewords"
_ST_PZ_C g g1 "LH beside"
print -l 1 "p alpha BETA gamma q" "z alpha beta gamma w" 4 > f
_ST_RUN --amend-into="$LH_A" --whole -- f
_ST_EQ "a fold's changed words found on the neighbor pause" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
unfunction _LH_RELOCATED
cd "$TMP/repo"
