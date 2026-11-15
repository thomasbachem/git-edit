# A fold deleting a file's first lines still resolves its stops by replacement – that hunk,
# `-1,<n> +0,0`, derived as removing them, never as putting the whole file in their place:
# • A stop in another file resolves, the deletion landing at the target
# • A stop in that file resolves, the deletion made there too
_ST_SCENARIO "\e[1;96m[279] a fold deleting a file's first lines resolves its stops\e[0m"
local LD_T
# Commits `f` and `g`, the target T adding `w` to `g`, then L rewriting `g`'s `x` beside the fold's
# `y` – and with <in-f>, `f`'s `c` too, beside the fold's other change there – sets `LD_T`
_LD_REPO () {
	# Args: <name> [<in-f>]
	_ST_PZ_NEW "$1"
	print -l h1 h2 a b c > f && print -l x y z > g && git add . && git commit -qm "$1 base"
	print -l x y z w > g && git commit -qam "$1 T" && LD_T=$(git rev-parse HEAD)
	print -l x2 y z w > g && { [ -z "$2" ] || print -l h1 h2 a b c2 > f; } && git commit -qam "$1 L"
}
_LD_REPO ld
print -l x2 y2 z w > g && print -l h2 a b c > f && git add f g
_ST_RUN --amend-into="$LD_T" -- f g
_ST_EQ "a fold deleting a file's first line resolves a stop in another file" \
	"$RC:$(git show HEAD~1:f | tr '\n' ' ')|$(git show HEAD~1:g | tr '\n' ' ')" "0:h2 a b c |x y2 z w "
_ST_OUT_HAS "by its replacements" "Made the fold's line replacements in the 2 commit(s)"
_LD_REPO lf in-f
print -l h2 a b B2 c2 > f && git add f
_ST_RUN --amend-into="$LD_T" -- f
_ST_EQ "and one in that file, the deletion made there" \
	"$RC:$(git show HEAD~1:f | tr '\n' ' ')|$(git show HEAD:f | tr '\n' ' ')" "0:h2 a b B2 c |h2 a b B2 c2 "
