# A squash given no message follows the `amend!` and `squash!` markers it folds in, as git's
# autosquash does – on either route and across a pause:
# • An `amend!` naming the target takes its place, a `squash!` adds its body, spaces after either
#   stripped as git strips them
# • A marker naming another commit leaves the target's message, as `--text` overrides every marker
_ST_SCENARIO "\e[1;96m[241] a squash follows amend! and squash! markers\e[0m"
local MK_T MK_M
# The rebase route, a commit between, and the plumbing one, the marker right above its target
local MK_BETWEEN
for MK_BETWEEN in 1 ""; do
	_ST_PZ_NEW "mk${MK_BETWEEN:+-between}"
	_ST_PZ_C a a "MK target" && MK_T=$(git rev-parse HEAD)
	[ -n "$MK_BETWEEN" ] && _ST_PZ_C b b "MK between"
	print a2 > a && git commit -qam "amend! MK target" -m "MK target reworded" -m "With a body of its own" && MK_M=$(git rev-parse HEAD)
	_ST_RUN -s="$MK_T" "$MK_M"
	_ST_EQ "${MK_BETWEEN:+between: }an amend! takes the target's message" \
		"$RC:$(git log -1 --format=%B "HEAD${MK_BETWEEN:+~1}")" "0:MK target reworded"$'\n\n'"With a body of its own"
	_ST_OUT_HAS "${MK_BETWEEN:+between: }saying it followed the marker" "The message follows amend! ${MK_M:0:7}, as git's autosquash would"
done
_ST_PZ_NEW mk-squash
_ST_PZ_C a a "MK target" && MK_T=$(git rev-parse HEAD)
print a2 > a && git commit -qam "squash! MK target" -m "MK adds a note" && MK_M=$(git rev-parse HEAD)
_ST_RUN -s="$MK_T" "$MK_M"
_ST_EQ "a squash! adds its body to the target's" "$RC:$(git log -1 --format=%B HEAD)" "0:MK target"$'\n\n'"MK adds a note"
# Spaces after a marker stripped as git strips them
_ST_PZ_NEW mk-spaced
_ST_PZ_C a a "MK target"
MK_T=$(git rev-parse HEAD)
print a2 > a && git commit -qam "amend!  MK target" -m "MK target reworded past a space" && MK_M=$(git rev-parse HEAD)
_ST_RUN -s="$MK_T" "$MK_M"
_ST_EQ "an amend! with spaces after it still names its target" "$RC:$(git log -1 --format=%B HEAD)" "0:MK target reworded past a space"
# One naming another commit, and `--text`, leave the markers aside
_ST_PZ_NEW mk-other
_ST_PZ_C a a "MK target" && MK_T=$(git rev-parse HEAD)
_ST_PZ_C b b "MK other"
print a2 > a && git commit -qam "amend! MK other" -m "MK other reworded" && MK_M=$(git rev-parse HEAD)
_ST_RUN -s="$MK_T" "$MK_M"
_ST_EQ "an amend! naming another commit leaves the target's message" "$RC:$(git log -1 --format=%B HEAD~1)" "0:MK target"
_ST_OUT_LACKS "following no marker" 'The message follows'
_ST_PZ_NEW mk-text
_ST_PZ_C a a "MK target" && MK_T=$(git rev-parse HEAD)
print a2 > a && git commit -qam "amend! MK target" -m "MK target reworded" && MK_M=$(git rev-parse HEAD)
_ST_RUN -s="$MK_T" "$MK_M" --text "MK given"
_ST_EQ "--text overrides an amend!" "$RC:$(git log -1 --format=%B HEAD)" "0:MK given"
# Across a pause – the target and a later commit both stopping,
# each on a line beside the other's, their stops left to the resolver
export GIT_EDIT_NO_SELF_RESOLVE=1
_ST_PZ_NEW mk-pause
print -l 1 2 > f && git add f && git commit -qm "MK base"
print -l t 2 > f && git commit -qam "MK target" && MK_T=$(git rev-parse HEAD)
print -l t l > f && git commit -qam "MK later"
print -l a l > f && git commit -qam "amend! MK target" -m "MK target reworded across a pause" && MK_M=$(git rev-parse HEAD)
_ST_RUN -s="$MK_T" "$MK_M"
local MK_WT=$(_ST_PZ_WT) MK_I MK_STOPS=0
local -a MK_STEPS=("a 2" "a l")
for MK_I in 1 2; do
	[[ "${OUT##*$'\n'}" == "git-edit: conflict"* ]] || break
	MK_STOPS=$MK_I
	print -l ${=MK_STEPS[MK_I]} > "${MK_WT:-$ST_NO_WT}/f" && git -C "${MK_WT:-$ST_NO_WT}" add f
	_ST_RUN --continue
done
_ST_EQ "an amend! squashed across its pauses takes the target's message" \
	"$MK_STOPS:$RC:$(git log --format=%s | tr '\n' '|'):$(git log -1 --format=%B HEAD~1)" \
	"2:0:MK later|MK target reworded across a pause|MK base|:MK target reworded across a pause"
unset GIT_EDIT_NO_SELF_RESOLVE
cd "$TMP/repo"
