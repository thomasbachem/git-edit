# A squash resolves its stops through a fixup changing several files as through one changing one:
# • At the fixup's own step, a stop in one of its files
# • At a later commit's step, taking the replacements of fixups of one file and of two
# • Where that fixup deletes another file's first line too
_ST_SCENARIO "\e[1;96m[280] a squash resolves its stops through a fixup of several files\e[0m"
# Commits `g` and `f`, the target T rewriting `g`'s `a`, then L rewriting its `d`
_SF_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l a b c d e f g h > g && print -l p q > f && git add . && git commit -qm "$1 base"
	print -l A b c d e f g h > g && git commit -qam "$1 T"
	print -l A b c D e f g h > g && git commit -qam "$1 L"
}
_SF_REPO sf
print -l A b c D E f g h > g && print -l P q > f && git commit -qam "fixup! sf T"
_ST_RUN -s=auto HEAD
_ST_EQ "a two-file fixup's stop resolves" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:g | tr '\n' ' ')$(git show HEAD~1:f | tr '\n' ' ')" "0:sf L|sf T|sf base|:A b c d E f g h P q "
_ST_OUT_HAS "by its replacements" "Made the fixups' line replacements at "
_SF_REPO sm
print -l A b C D e f g h > g && git commit -qam "fixup! sm T"
print -l A b C D e f g H > g && print -l P q > f && git commit -qam "fixup! sm T"
_ST_RUN -s=auto HEAD~1 HEAD
_ST_EQ "a later commit's stop takes both fixups' replacements" \
	"$RC:$(git show HEAD~1:g | tr '\n' ' ')|$(git show HEAD:g | tr '\n' ' ')" "0:A b C d e f g H |A b C D e f g H "
_SF_REPO sd
print -l A b c D E f g h > g && print -l q > f && git commit -qam "fixup! sd T"
_ST_RUN -s=auto HEAD
_ST_EQ "one deleting another file's first line too" \
	"$RC:$(git show HEAD~1:f | tr '\n' ' ')|$(git show HEAD~1:g | tr '\n' ' ')" "0:q |A b c d E f g h "
