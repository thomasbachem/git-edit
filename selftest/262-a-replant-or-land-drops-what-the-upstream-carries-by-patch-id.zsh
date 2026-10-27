# A replant or land leaves out what the upstream carries by patch id, as its triage says,
# however the upstream changed it since – where the rebase tells a duplicate only against the fork:
# • A line the upstream rewrote since stops nothing
# • A part it reverted since stays reverted
# • A land's copy by another author goes as well, past a copy guard reading author and date
# • A span of nothing else moves the branch onto the upstream
_ST_SCENARIO "\e[1;96m[262] a replant or land drops what the upstream carries by patch id\e[0m"
local PD_X
# Builds X, rewriting two lines, and Y on `topic` – main takes X as its own copy, then changes it
_PD_REPO () {
	# Args: <name> <rewrite|revert> [<1 for a branch of X alone>]
	_ST_PZ_NEW "$1"
	print -l l1 l2 l3 l4 l5 l6 l7 l8 l9 l10 > f && git add f && git commit -qm "PD base"
	git checkout -q -b topic
	print -l L1 l2 l3 l4 l5 l6 l7 l8 l9 L10 > f && git commit -qam "PD X"
	PD_X=$(git rev-parse HEAD)
	[ -n "$3" ] || _ST_PZ_C g g1 "PD Y"
	git checkout -q main
	_ST_PZ_C h h1 "PD main"
	git cherry-pick -n "$PD_X" >/dev/null
	GIT_AUTHOR_NAME=Q GIT_AUTHOR_EMAIL=q@x.invalid GIT_AUTHOR_DATE="1700000000 +0000" git commit -qm "PD X, as main took it"
	if [ "$2" = rewrite ]; then
		print -l "L1 again" l2 l3 l4 l5 l6 l7 l8 l9 L10 > f
	else
		print -l L1 l2 l3 l4 l5 l6 l7 l8 l9 l10 > f
	fi
	git commit -qam "PD main ${2}s it"
}
_PD_REPO pd-rewrite rewrite
git checkout -q topic
_ST_RUN --onto=main
_ST_EQ "a replant drops a commit the upstream took and rewrote since, stopping nowhere" \
	"$RC:$(git log --format=%s main..topic | paste -sd'|' -):$(git show topic:f | paste -sd' ' -)" "0:PD Y:L1 again l2 l3 l4 l5 l6 l7 l8 l9 L10"
_ST_OUT_HAS "as its triage said" '^1 commit(s) are already on main and will be dropped:$'
_ST_OUT_HAS "and its summary counts" '^1 commit(s) were dropped as already upstream\.$'
_PD_REPO pd-revert revert
git checkout -q topic
_ST_RUN --onto=main
_ST_EQ "one whose part the upstream reverted since goes too, the revert standing" \
	"$RC:$(git log --format=%s main..topic | paste -sd'|' -):$(git show topic:f | paste -sd' ' -)" "0:PD Y:L1 l2 l3 l4 l5 l6 l7 l8 l9 l10"
_PD_REPO pd-land revert
_ST_RUN --land=topic
_ST_EQ "a land drops it alike, onto the checked-out target" \
	"$RC:$(git log --format=%s -2 | paste -sd'|' -):$(git show main:f | paste -sd' ' -)" "0:PD Y|PD main reverts it:L1 l2 l3 l4 l5 l6 l7 l8 l9 l10"
_ST_OUT_HAS "counted as on the target" '^1 commit(s) were dropped as already on main\.$'
_PD_REPO pd-only revert 1
git checkout -q topic
_ST_RUN --onto=main
_ST_EQ "a branch of such commits alone moves onto the upstream" "$RC:$(git rev-parse topic)" "0:$(git rev-parse main)"
unfunction _PD_REPO
cd "$TMP/repo"
