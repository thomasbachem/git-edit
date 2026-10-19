# A long `-h` topic opens with its usage lines: a long mode's entry has its forms under its tag and
# its paragraphs after, as the man page does
_ST_SCENARIO "\e[1;96m[234] long -h topics open with their usage lines\e[0m"
local OB_T OB_U

for OB_T in --commit --amend-into --land --carry --exec --onto -e -M --split; do
	OB_U=$("$SELF" -h "$OB_T" 2>/dev/null | grep -m1 -A1 -E -- "^${OB_T}[ =,[]|^${OB_T}\$" | tail -1)
	_ST_CHECK "-h $OB_T opens with a usage line under its tag" test "${OB_U:0:8}" = "    git "
done
_ST_CHECK "-h --commit's first form is the plain commit of whole files" \
	grep -qE -- '^    git edit --commit --text <msg> -- <path>\.\.\. +# files wholly yours' <<<"$("$SELF" -h --commit 2>/dev/null)"
_ST_CHECK "its paragraphs follow, the first as before" \
	grep -qE -- '^  Commit each <path> as it stands in the checkout on top of the tip' <<<"$("$SELF" -h --commit 2>/dev/null)"
