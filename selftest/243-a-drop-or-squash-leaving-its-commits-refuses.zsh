# A drop or squash whose replay leaves its commits in the branch refuses – here a rebase begun
# by hand from the run's own base after its own was aborted, which the resume reads as its own
_ST_SCENARIO "\e[1;96m[243] a drop or squash leaving its commits in the branch refuses\e[0m"
local LC_MODE LC_WT LC_TIP LC_GD
for LC_MODE in squash drop; do
	_ST_PZ_NEW "lc-$LC_MODE"
	print -l x a b > f && git add f && git commit -qm "LC base"
	print -l x1 a b > f && git commit -qam "LC target"
	print -l y1 a b > f && git commit -qam "LC later"
	print -l y1z a b > f && git commit -qam "LC member"
	_ST_PZ_C g g "LC top"
	LC_TIP=$(git rev-parse HEAD)
	if [ "$LC_MODE" = squash ]; then
		_ST_RUN -s="$(git rev-parse HEAD~3)" "$(git rev-parse HEAD~1)"
	else
		_ST_RUN -d -y "$(git rev-parse HEAD~2)"
	fi
	LC_WT=$(_ST_PZ_WT)
	LC_GD=$(git -C "${LC_WT:-$ST_NO_WT}" rev-parse --path-format=absolute --git-path rebase-merge 2>/dev/null)
	# Its own rebase aborted, one begun from the same base keeping every pick, stopped at its first
	git -C "${LC_WT:-$ST_NO_WT}" rebase --abort >/dev/null 2>&1
	GIT_SEQUENCE_EDITOR="sed -i.bak '1s/^pick/edit/'" git -C "${LC_WT:-$ST_NO_WT}" rebase -i "$(git rev-parse HEAD~4)" >/dev/null 2>&1
	_ST_EQ "$LC_MODE: the hand rebase stands where the run's own did" "$([ -d "$LC_GD" ] && echo running)" "running"
	_ST_RUN --continue
	_ST_EQ "$LC_MODE: a resume driving it to the end refuses, the branch untouched" "$RC:$(git rev-parse HEAD)" "1:$LC_TIP"
	_ST_OUT_HAS "$LC_MODE: naming the commits it would leave" "^git-edit: error – The $LC_MODE would leave 1 of its 1 commit(s) in the branch"
	_ST_OUT_LACKS "$LC_MODE: never claiming them folded" 'squashed into'
	_ST_RUN --abort
done
cd "$TMP/repo"
