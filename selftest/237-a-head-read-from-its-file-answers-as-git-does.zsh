# A run reads `HEAD` off its file where it knows the checkout's git dir, each answer git's own –
# a form it can't read goes to git – and asks a held fact again once its directory is remade:
# • A branch, a subdirectory, unborn, detached, bare, a linked worktree either way, a link to a link
# • Hand-written under files alone, reftable's `HEAD` in its tables – `ref:` without its space, a
#   stray space, no final newline, a CRLF, a symlink, a name ending in a dot, a part in `.lock`
_ST_SCENARIO "\e[1;96m[237] a HEAD read from its file answers as git does\e[0m"
local HR="$TMP/hr237" HR_TR="$TMP/hr237-trace" HR_A HR_B HR_HELD HR_D HR_RT=""
local -a HR_DIFF HR_ASKED
local -i HR_N=0
# Makes a repository at <dir> with one commit on `main`
_HR237_REPO () {
	# Args: <dir> [git init options]...
	git init -q -b main "${@:2}" "$1" && git -C "$1" config user.email h@x.invalid && git -C "$1" config user.name H && \
		print a > "$1/a" && git -C "$1" add a && git -C "$1" commit -qm a
}
# Reads `HEAD` in <dir> as a run does and as git does, naming <label> in `HR_DIFF` where they differ
_HR237_CMP () {
	# Args: <label> <dir>
	local MINE GIT
	local -i RM RG
	HR_N+=1
	cd "$2" 2>/dev/null || { HR_DIFF+=("$1: no directory"); return; }
	_FACTS=()
	_HEAD_REF MINE 2>/dev/null; RM=$?
	GIT=$(git symbolic-ref -q HEAD 2>/dev/null); RG=$?
	[ "$MINE:$RM" = "$GIT:$RG" ] || HR_DIFF+=("$1: $MINE:$RM, git $GIT:$RG")
}
if (( ! ${+builtins[zstat]} )); then
	ECHO_E "\e[0;90m  skipped – this zsh has no zsh/stat, so a run keeps no answers\e[0m"
else
	# The suite's runner keeps no answers – here alone it keeps them, as a run does
	{
		_FACTS_OFF="" _FACTS=()
		_HR237_REPO "$HR/n" && mkdir -p "$HR/n/sub/deep"
		[[ "$(<"$HR/n/.git/HEAD")" == *.invalid ]] && HR_RT=1
		_HR237_CMP "a branch" "$HR/n"
		_HR237_CMP "from a subdirectory" "$HR/n/sub/deep"
		git init -q -b fresh "$HR/u" && _HR237_CMP "an unborn branch" "$HR/u"
		_HR237_REPO "$HR/d" && git -C "$HR/d" checkout -q --detach && _HR237_CMP "a detached HEAD" "$HR/d"
		git -C "$HR/n" worktree add -q -b x "$HR/wx" && _HR237_CMP "a linked worktree's branch" "$HR/wx"
		git -C "$HR/n" worktree add -q --detach "$HR/wd" && _HR237_CMP "a linked worktree detached" "$HR/wd"
		_HR237_REPO "$HR/c" && git -C "$HR/c" symbolic-ref refs/heads/alias refs/heads/main && \
			git -C "$HR/c" symbolic-ref HEAD refs/heads/alias && _HR237_CMP "a link to a link" "$HR/c"
		git init -q --bare "$HR/b.git" && _HR237_CMP "a bare repository" "$HR/b.git"
		if [ -z "$HR_RT" ]; then
			_HR237_REPO "$HR/l" && rm -f "$HR/l/.git/HEAD" && ln -s refs/heads/main "$HR/l/.git/HEAD" && _HR237_CMP "a symlink" "$HR/l"
			for HR_D in 'ref:refs/heads/main' 'ref: refs/heads/main ' $'ref: refs/heads/main\r' 'ref: refs/heads/foo.' \
				'ref: refs/heads/a.lock/b' 'ref: refs/heads/a.b/c'; do
				_HR237_REPO "$HR/f$HR_N" && print -r -- "$HR_D" > "$HR/f$HR_N/.git/HEAD" && _HR237_CMP "${(q+)HR_D}" "$HR/f$HR_N"
			done
			_HR237_REPO "$HR/nl" && printf 'ref: refs/heads/main' > "$HR/nl/.git/HEAD" && _HR237_CMP "no final newline" "$HR/nl"
		fi
		_ST_EQ "every form read as git reads it" "${HR_N}:${(j:, :)HR_DIFF}" "$(( ${#HR_RT} ? 8 : 16 )):"
		# Under files the common forms ask git nothing – reftable's file a placeholder, which goes to git
		if [ -z "$HR_RT" ]; then
			for HR_D in "$HR/n" "$HR/d" "$HR/wx"; do
				cd "$HR_D" && _FACTS=() && rm -f "$HR_TR" && GIT_TRACE=$HR_TR _HEAD_REF HR_A 2>/dev/null
				grep -q 'symbolic-ref' "$HR_TR" 2>/dev/null && HR_ASKED+=("${HR_D:t}")
			done
			_ST_EQ "a branch, a detached HEAD and a linked worktree read off the file" "${(j: :)HR_ASKED}" ""
		fi
		# A worktree remade for another repository – its `.git` file names another git dir either way
		_HR237_REPO "$HR/r1" && _HR237_REPO "$HR/r2" && git -C "$HR/r1" worktree add -q -b w1 "$HR/w"
		cd "$TMP" && _FACTS=()
		_FACT HR_A -C "$HR/w" rev-parse --path-format=absolute --git-common-dir
		HR_HELD=$(_FACT_HELD -C "$HR/w" rev-parse --path-format=absolute --git-common-dir && print held)
		git -C "$HR/r1" worktree remove --force "$HR/w" && git -C "$HR/r2" worktree add -q -b w2 "$HR/w"
		HR_HELD+=:$(_FACT_HELD -C "$HR/w" rev-parse --path-format=absolute --git-common-dir && print held)
		_FACT HR_B -C "$HR/w" rev-parse --path-format=absolute --git-common-dir
		_ST_EQ "a held answer asked again once its worktree is remade for another repository" \
			"${HR_HELD}:${HR_A:t2}:${HR_B:t2}" "held::r1/.git:r2/.git"
	} always {
		_FACTS_OFF=1 _FACTS=()
		cd "$TMP"
	}
fi
