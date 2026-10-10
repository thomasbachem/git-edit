# A cherry-pick or revert in progress refuses whatever the ref backend – under reftable it leaves
# no `CHERRY_PICK_HEAD` or `REVERT_HEAD` file, only the pseudoref:
# • A whole-file `--commit`, a composed `--commit --edits` and `--carry` in the checkout holding one
# • An `--exec` whose command leaves one stopped in its worktree, and a `-C` path holding one
# • Each checkout read alone – one stopped in another worktree blocks nothing here
# • A branch named as the pseudoref is none in progress, while a real one beside it still counts
_ST_SCENARIO "\e[1;96m[195] a pick in progress is read under either ref backend\e[0m"
local RT_FMT RT_FLAG="" RT_C1 RT_WT RT_TIP RT_KIND RT_NAME RT_WHAT
local -a RT_FMTS=(files)
# A git that knows no `--ref-format` keeps every repository in files
if command git init -q --ref-format=reftable "$TMP/rt195-probe" >/dev/null 2>&1; then
	RT_FLAG=1 RT_FMTS+=(reftable)
else
	ECHO_E "\e[0;90m  reftable skipped – this git makes no reftable repository\e[0m"
fi
# Starts a conflicting <kind> – cherry-pick or revert – in <checkout>
_RT195_STOP () {
	# Args: <checkout> <kind>
	if [ "$2" = cherry-pick ]; then
		git -C "$1" cherry-pick rt-side >/dev/null 2>&1
	else
		git -C "$1" revert --no-edit "$RT_C1" >/dev/null 2>&1
	fi
}
for RT_FMT in "${RT_FMTS[@]}"; do
	cd "$TMP" && rm -rf "rt-$RT_FMT"
	git init -q -b main ${RT_FLAG:+--ref-format=$RT_FMT} "rt-$RT_FMT" && cd "rt-$RT_FMT" || continue
	git config user.email p@x.invalid && git config user.name P && git config rerere.enabled false
	print -r -- a > f.txt && print -r -- o > o.txt && git add f.txt o.txt && git commit -qm "RT base"
	git checkout -q -b rt-side && print -r -- s > f.txt && git commit -qam "RT side" && git checkout -q main
	print -r -- b > f.txt && git commit -qam "RT c1" && RT_C1=$(git rev-parse HEAD)
	print -r -- c > f.txt && git commit -qam "RT c2"
	for RT_KIND in cherry-pick revert; do
		RT_NAME=${${RT_KIND:u}//-/_}_HEAD
		RT_WHAT="[$RT_FMT] mid-$RT_KIND"
		_RT195_STOP . "$RT_KIND"
		_ST_EQ "$RT_WHAT: the $RT_KIND stopped on its conflict" "$(git rev-parse -q --verify "$RT_NAME" >/dev/null && echo stopped)" "stopped"
		RT_TIP=$(git rev-parse HEAD)
		print -r -- o2 > o.txt
		_ST_RUN --commit --text "x" -- o.txt
		_ST_EQ "$RT_WHAT a whole-file --commit refuses" "$RC:$(git rev-parse HEAD)" "1:$RT_TIP"
		_ST_OUT_HAS "$RT_WHAT naming it" "A $RT_KIND is in progress – finish it with git commit before taking files whole"
		_ST_RUN --commit --text "x" --edits '{"o.txt": [["o\n", "o3\n"]]}'
		_ST_EQ "$RT_WHAT a composed --commit refuses" "$RC:$(git rev-parse HEAD)" "1:$RT_TIP"
		_ST_OUT_HAS "$RT_WHAT naming it" "A $RT_KIND is in progress – finish it with git commit before committing your own changes apart"
		_ST_RUN --carry=HEAD
		_ST_OUT_HAS "$RT_WHAT --carry refuses, naming it" "Your checkout is halfway through a $RT_KIND – finish or abort it first"
		git checkout -q -- o.txt
		git "$RT_KIND" --abort
		# One an `--exec` command leaves stopped in its worktree, exiting 0
		if [ "$RT_KIND" = cherry-pick ]; then
			_ST_RUN --exec -- sh -c 'git cherry-pick rt-side >/dev/null 2>&1; exit 0'
		else
			_ST_RUN --exec -- sh -c "git revert --no-edit $RT_C1 >/dev/null 2>&1; exit 0"
		fi
		_ST_EQ "[$RT_FMT] an --exec leaving a $RT_KIND stopped lands nothing" "$RC:$(git rev-parse HEAD)" "1:$RT_TIP"
		_ST_OUT_HAS "[$RT_FMT] naming its $RT_NAME" "The command exited 0 with $RT_NAME left in its worktree"
		# One stopped in another worktree is that one's alone
		RT_WT="$TMP/rt-$RT_FMT-wt"
		git worktree add -q --detach "$RT_WT" HEAD
		_RT195_STOP "$RT_WT" "$RT_KIND"
		print -r -- "o-$RT_KIND" > o.txt
		_ST_RUN --commit --text "RT beside a $RT_KIND elsewhere" -- o.txt
		_ST_EQ "[$RT_FMT] a $RT_KIND in another worktree blocks no whole-file --commit here" "$RC:$(git log -1 --format=%s)" "0:RT beside a $RT_KIND elsewhere"
		RT_TIP=$(git rev-parse HEAD)
		_ST_RUN -C="$RT_WT" -d -y HEAD
		_ST_EQ "[$RT_FMT] a -C path holding a $RT_KIND refuses" "$RC:$(git rev-parse HEAD)" "1:$RT_TIP"
		_ST_OUT_HAS "[$RT_FMT] naming the -C path's $RT_NAME" "path '$RT_WT' has $RT_NAME in progress – finish it there"
		_ST_EQ "[$RT_FMT] its $RT_KIND left going" "$(git -C "$RT_WT" rev-parse -q --verify "$RT_NAME" >/dev/null && echo going)" "going"
		git -C "$RT_WT" "$RT_KIND" --abort
		git worktree remove --force "$RT_WT"
	done
	# A branch named as either pseudoref is none in progress
	git update-ref refs/heads/CHERRY_PICK_HEAD rt-side && git update-ref refs/heads/REVERT_HEAD rt-side
	print -r -- o4 > o.txt
	_ST_RUN --commit --text "RT beside branches named as pseudorefs" -- o.txt
	_ST_EQ "[$RT_FMT] branches named CHERRY_PICK_HEAD and REVERT_HEAD block no whole-file --commit" "$RC:$(git log -1 --format=%s)" "0:RT beside branches named as pseudorefs"
	_ST_RUN --commit --text "RT composed beside them" --edits '{"o.txt": [["o4\n", "o5\n"]]}'
	_ST_EQ "[$RT_FMT] nor a composed one" "$RC:$(git show HEAD:o.txt)" "0:o5"
	git checkout -q -- o.txt
	_ST_RUN --carry=HEAD
	_ST_EQ "[$RT_FMT] nor --carry" "$RC" "0"
	_ST_OUT_LACKS "[$RT_FMT] which says nothing of a pick" 'halfway through'
	# While a real one beside such a branch still counts
	_RT195_STOP . cherry-pick
	RT_TIP=$(git rev-parse HEAD)
	print -r -- o6 > o.txt
	_ST_RUN --commit --text "x" -- o.txt
	_ST_EQ "[$RT_FMT] a cherry-pick in progress beside a branch of its name still refuses" "$RC:$(git rev-parse HEAD)" "1:$RT_TIP"
	_ST_OUT_HAS "[$RT_FMT] naming the cherry-pick" "A cherry-pick is in progress"
	git checkout -q -- o.txt
	git cherry-pick --abort
	git update-ref -d refs/heads/CHERRY_PICK_HEAD && git update-ref -d refs/heads/REVERT_HEAD
done
cd "$TMP/repo"
