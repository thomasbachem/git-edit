# A fold refused for taking in lines one later commit adds names their move into its target, a fixup
# split from that commit – which lands, the tip as it was – but not where two commits lost lines
_ST_SCENARIO "\e[1;96m[276] a fold taking in a later commit's lines names their move\e[0m"
local MV_X MV_Y MV_T MV_WT
# Writes `app.js`, `test.js`, `lib.js` and `other.js` as <name>'s commits make them,
# the fixup of `<name> x` left uncommitted – `<name> y` adding the line alone where <only> is given
_MV_REPO () {
	# Args: <name> [<only>]
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	print -l one two three > app.js && print -l setup run > test.js && print old > lib.js && git add . && git commit -qm "$1 a"
	print -l one call three > app.js && git commit -qam "$1 x" && MV_X=$(git rev-parse HEAD)
	print -l setup load-gui run > test.js && { [ -n "$2" ] || print y > other.js; } && git add . && git commit -qm "$1 y" && MV_Y=$(git rev-parse HEAD)
	print -l one call three-w > app.js && git commit -qam "$1 w"
	print -l one call-gui three-w > app.js
}
export GIT_EDIT_NO_SELF_RESOLVE=1 GIT_EDIT_ACTOR=mv-1
_MV_REPO mv
_ST_RUN --commit --text "fixup! mv x" -- app.js
MV_T=$(git rev-parse 'HEAD^{tree}')
_ST_RUN -s=auto
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" test.js "$(print -l setup load-gui run)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_EQ "a squash's stop taking in a later commit's line refuses" "$RC" "1"
_ST_OUT_HAS "naming their move into its target" "Where this squash makes ${MV_X:0:7} (mv x) depend on lines ${MV_Y:0:7} (mv y) adds, move them into it as a fixup first: git edit --split=${MV_Y:0:12} --text 'fixup! mv x', its pause left holding those lines alone – then this squash again, that fixup in it."
_ST_RUN --abort
# Followed, the line lands in its target and the tip stays as it was
_ST_RUN --split="${MV_Y:0:12}" --text 'fixup! mv x'
MV_WT=$(_ST_PZ_WT)
git -C "${MV_WT:-$ST_NO_WT}" rm -q other.js
_ST_RUN --continue
_ST_RUN -s=auto
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_EQ "followed, the squash lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:mv w|mv y|mv x|mv a|"
_ST_EQ "the line in its target, the tip as it was" \
	"$(git show "$(git log -1 --format=%H --grep='^mv x$'):test.js" | tr '\n' ' ')$(git rev-parse 'HEAD^{tree}')" "setup load-gui run $MV_T"
# An --amend-into's names the squash of that fixup before the fold again
_MV_REPO mf
git add app.js
_ST_RUN --amend-into="$MV_X" -- app.js
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" test.js "$(print -l setup load-gui run)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_OUT_HAS "a fold's refusal the same" "Where this fold makes ${MV_X:0:7} (mf x) depend on lines ${MV_Y:0:7} (mf y) adds"
_ST_OUT_HAS "its squash before the fold again" "its pause left holding those lines alone – then 'git edit -s=auto' and this fold again."
_ST_RUN --abort
git restore --staged app.js && git checkout -q -- app.js
# A named squash's the same
_MV_REPO mt
_ST_RUN --commit --text "fixup! mt x" -- app.js
_ST_RUN -s="$MV_X" "$(git rev-parse HEAD)"
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" test.js "$(print -l setup load-gui run)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_OUT_HAS "a named squash's refusal the same" "Where this squash makes ${MV_X:0:7} (mt x) depend on lines ${MV_Y:0:7} (mt y) adds"
_ST_RUN --abort
# Two later commits losing lines to it name no move
_MV_REPO mn
git checkout -q -- app.js
print -l setup load-gui run load-net > test.js && print z > net.js && git add . && git commit -qm "mn z"
print -l one call-gui three-w > app.js
_ST_RUN --commit --text "fixup! mn x" -- app.js
_ST_RUN -s=auto
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" test.js "$(print -l setup load-gui run load-net)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_EQ "two commits' lines taken in refuse" "$RC" "1"
_ST_OUT_HAS "as a resolution taking them in" "A resolution took in what a later commit changes"
_ST_OUT_LACKS "naming no move" "Where this squash makes"
_ST_RUN --abort
# Nor a line a stop past the target took in
_MV_REPO mp
_ST_RUN --commit --text "fixup! mp x" -- app.js
print -l setup load-gui run load-net > test.js && print v > net.js && git add . && git commit -qm "mp v"
_ST_RUN -s=auto
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" test.js "$(print -l setup load-gui run load-net)"
_ST_RUN --continue
_ST_OUT_HAS "a later stop's take refuses" "held at the stop for $(git log -1 --format=%h --grep='^mp w$') (mp w)"
_ST_OUT_LACKS "naming no move into it" "Where this squash makes"
_ST_RUN --abort
# Nor a line a later commit rewrote, whose old text the commits between still read
_MV_REPO mr
git checkout -q -- app.js
print new > lib.js && print r > net.js && git add . && git commit -qm "mr r"
print -l one call-gui three-w > app.js
_ST_RUN --commit --text "fixup! mr x" -- app.js
_ST_RUN -s=auto
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" lib.js new
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_OUT_HAS "a rewrite taken in refuses" "its line \"new\" held at the stop for ${MV_X:0:7} (mr x)"
_ST_OUT_LACKS "naming no move of it" "Where this squash makes"
_ST_RUN --abort
# Nor a commit whose whole change it took, which no split can take apart
_MV_REPO me only
_ST_RUN --commit --text "fixup! me x" -- app.js
_ST_RUN -s=auto
MV_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three)"
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" test.js "$(print -l setup load-gui run)"
_ST_RUN --continue
_ST_RESOLVE "${MV_WT:-$ST_NO_WT}" app.js "$(print -l one call-gui three-w)"
_ST_RUN --continue
_ST_OUT_HAS "a commit emptied whole refuses" "me y – test.js (left out as emptied)"
_ST_OUT_LACKS "naming no split of it" "Where this squash makes"
_ST_RUN --abort
unset GIT_EDIT_NO_SELF_RESOLVE GIT_EDIT_ACTOR
