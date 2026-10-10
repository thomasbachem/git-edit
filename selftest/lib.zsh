#!/bin/zsh
# `git-edit`'s end-to-end test suite, sourced by `git edit --selftest` – this file's setup,
# helpers and summary around the scenarios, one file each beside it, `<id>-<name>.zsh`.
#
# It is not run directly: every helper it uses – `ECHO_E`, `PRINT_TEXT`, `MKTEMP_DIR`
# – belongs to `git-edit`, which sources this file once, for that one mode. The
# suite drives the tool the way a caller does, by re-invoking the script as a
# subprocess (`$SELF`), so what it exercises is the shipped behavior rather
# than its internals. `$SELF` is also what the structural checks grep, so it
# must stay pointed at `git-edit` itself, never at these files.
#
# Scenarios share one scratch repo, in order – a fixture can collide with an
# earlier scenario's leftovers, which reads as a tool failure but isn't. Each id
# is zero-padded in its file's name, so the names sort in suite order.
# `--selftest=<ids>` runs a few alone, with the ones each names by `# needs <ids>`
# on its `_ST_SCENARIO` line – so a scenario reading another's state or locals
# says so there, and a helper two of them call sits up here with the others.

# No `emulate` here: the sourcing script has put every option back to zsh's default before
# these files are read, and a reset in here would take its `set -o pipefail` down with it
# for every check that follows – scenario 82 pins that

# Builds a scratch repo with a fake pushed remote and exercises every mode through real
# sub-invocations of `git-edit` – reword, fold, split, replant, drop, squash, reorder,
# move, exec, the pushed guards, stale-SHA resolution, merge topology, undo and status
GIT_SELFTEST () {
	local SELF=$1
	local TMP
	TMP=$(MKTEMP_DIR git-edit-selftest) || exit 1
	_CLEANUP_HOOK="rm -rf ${(q-)TMP}"
	# The temp files and worktrees every run of the script makes stay inside the scratch dir, so
	# suites running side by side – `--jobs`, or a platform each – never count each other's
	export TMPDIR=$TMP/tmp
	mkdir -p "$TMPDIR"
	local PASS=0
	local FAIL=0
	local OUT RC

	# A pause that never came leaves its worktree path empty, and a write through
	# it would land at the filesystem root – this sends it nowhere instead, so a
	# missed pause fails the scenario's assertions and nothing else
	local ST_NO_WT=/nonexistent/git-edit-selftest

	# A caller's label would close every reflog message the checks compare – set empty rather than
	# unset, so a startup file filling in a default only where it is unset leaves it alone
	export GIT_EDIT_ACTOR=

	# Deterministic clock – every git call takes a unique ascending timestamp via the `:-`
	# fallbacks, since real-time fixtures landed up to 8 commits per wall-clock second and
	# those ties swung stock runs between 35 and 65 failures where pinned runs were identical
	local ST_TICK=1112911993
	git () {
		ST_TICK=$((ST_TICK+60))
		GIT_AUTHOR_DATE="${GIT_AUTHOR_DATE:-@$ST_TICK +0000}" GIT_COMMITTER_DATE="${GIT_COMMITTER_DATE:-@$ST_TICK +0000}" command git "$@"
	}

	# Fails a run ending past its trailer, the line a caller's `| tail -1` reads – a prompt or a note
	# printed after it hides it there
	_ST_TRAILER_LAST () {
		[[ "${OUT##*$'\n'}" == git-edit:* ]] && return 0
		[[ "$*" == (-h|--help|--version)* ]] && return 0
		FAIL=$((FAIL+1))
		ECHO_E "  \e[1;31mFAIL\e[0m 'git edit $*' ends past its trailer"
		print -r -- "$OUT" | tail -3 | sed 's/^/       | /'
	}
	# Sub-invocations run non-TTY (stdin </dev/null) for deterministic agent
	# behavior even when the selftest itself runs from a terminal
	_ST_RUN () {
		OUT=$(GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" "$@" </dev/null 2>&1)
		RC=$?
		_ST_TRAILER_LAST "$@"
		# A prose line that lost its `#` is still a valid command invocation, so `zsh -n` accepts
		# it and only the runtime complains – checking here makes every scenario a detector for
		# that whole class of slip, rather than relying on one test to walk the affected line
		if [[ "$OUT" == *"command not found"* || "$OUT" == *"no matches found"* || \
		      "$OUT" == *"bad substitution"* || "$OUT" == *"parse error"* ]]; then
			FAIL=$((FAIL+1))
			ECHO_E "  \e[1;31mFAIL\e[0m shell noise from 'git edit $*'"
			echo "$OUT" | grep -E 'command not found|no matches found|bad substitution|parse error' \
				| head -3 | sed 's/^/       | /'
		fi
	}
	# Runs <command> with the checkout reading as halfway through a cherry-pick sequence, so a landing
	# leaves it as it was and names the carry, as one whose sync can't run does – for a scenario
	# needing a checkout left on the old content, as a peer's write from a stale buffer leaves it
	_ST_UNSYNCED () {
		# Args: <command> <arg>...
		local GD=$(command git rev-parse --absolute-git-dir 2>/dev/null) MADE="" RCU
		[ -n "$GD" ] && [ ! -d "$GD/sequencer" ] && mkdir "$GD/sequencer" && MADE=1
		"$@"
		RCU=$?
		[ -n "$MADE" ] && rmdir "$GD/sequencer"
		return $RCU
	}
	_ST_RUN_UNSYNCED () {
		_ST_UNSYNCED _ST_RUN "$@"
	}
	# Feeds <stdin> as the first argument, otherwise as `_ST_RUN`, for the records form
	# form of reword (`-M --text -`) which reads its targets from stdin
	_ST_RUN_IN () {
		local INPUT=$1; shift
		OUT=$(GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" "$@" <<<"$INPUT" 2>&1)
		RC=$?
		_ST_TRAILER_LAST "$@"
		if [[ "$OUT" == *"command not found"* || "$OUT" == *"no matches found"* || \
		      "$OUT" == *"bad substitution"* || "$OUT" == *"parse error"* ]]; then
			FAIL=$((FAIL+1))
			ECHO_E "  \e[1;31mFAIL\e[0m shell noise from 'git edit $*'"
			echo "$OUT" | grep -E 'command not found|no matches found|bad substitution|parse error' \
				| head -3 | sed 's/^/       | /'
		fi
	}
	_ST_CHECK () {
		local DESC=$1; shift
		if "$@" >/dev/null 2>&1; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | tail -16 | sed 's/^/       | /'
		fi
	}
	# Contains fallout – an operation a scenario left paused would cascade
	# "in flight" errors through every scenario after it – abort it loudly so
	# one flake reads as one scenario's failure, not fifteen
	_ST_SCENARIO () {
		local GCD=$(git rev-parse --git-common-dir 2>/dev/null)
		if [ -n "$GCD" ] && [ -f "$GCD/git-edit-state" ]; then
			ECHO_E "  \e[1;33mNOTE\e[0m stray in-flight operation left behind – aborting it"
			"$SELF" --abort >/dev/null 2>&1 </dev/null
		fi
		ECHO_E "$@"
	}
	# `-e` throughout: a pattern of ours often starts with `--`, which grep reads as its own
	# options otherwise – a `LACKS` check on one then passes however wrong the output is
	# A `LACKS` is only as good as the proof that the run reached the code that would have
	# printed it, so pair one with a positive from the same output rather than trusting it alone
	_ST_OUT_HAS () {
		local DESC=$1
		local PATTERN=$2
		if grep -q -e "$PATTERN" <<<"$OUT"; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | tail -16 | sed 's/^/       | /'
		fi
	}
	_ST_OUT_LACKS () {
		local DESC=$1
		local PATTERN=$2
		# A here-string, since a pipe's writer dies once `grep -q` has its match, and on a long
		# `$OUT` the failed pipeline passed this check
		if grep -q -e "$PATTERN" <<<"$OUT"; then
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | grep -e "$PATTERN" | head -3 | sed 's/^/       | /'
		else
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		fi
	}
	_ST_EQ () {
		local DESC=$1
		if [ "$2" = "$3" ]; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC ('$2' != '$3')"
			echo "$OUT" | tail -16 | sed 's/^/       | /'
		fi
	}
	# Writes a conflict resolution and stages it, verifying the stage took – the dance once
	# failed silently under `2>/dev/null` and resurfaced two continues later as a
	# mis-narrated empty step, while a missing worktree stays quiet since its pause already failed
	_ST_RESOLVE () {
		# Args: <worktree> <file> <content>
		[ -d "$1" ] || return 1
		local ERR
		if ! ERR=$( { print -r -- "$3" > "$1/$2" && git -C "$1" add -- "$2" } 2>&1 ); then
			ECHO_E "  \e[1;33mNOTE\e[0m resolving $2 failed: $ERR"
			return 1
		fi
		if [ -n "$(git -C "$1" ls-files -u -- "$2" 2>/dev/null)" ]; then
			ECHO_E "  \e[1;33mNOTE\e[0m staging $2 left it unmerged"
			return 1
		fi
	}
	# Composes in a private index from `HEAD`'s own entries, as a caller would, into a commit on
	# `HEAD`, which pins the tip it was composed on – what `--amend-into --tree` takes
	_ST_COMPOSE () {
		# Args: <path> <content>... – prints the commit carrying `HEAD`'s tree with each <path>
		# replaced, at the mode `HEAD` holds it at
		local IDX="$TMP/compose-index"
		rm -f "$IDX"
		GIT_INDEX_FILE=$IDX git read-tree HEAD
		while [ $# -ge 2 ]; do
			GIT_INDEX_FILE=$IDX git update-index --add --cacheinfo "$(git ls-tree HEAD -- "$1" | cut -d' ' -f1),$(printf '%s\n' "$2" | git hash-object -w --stdin),$1"
			shift 2
		done
		git commit-tree "$(GIT_INDEX_FILE=$IDX git write-tree)" -p HEAD -m "composed"
	}
	_ST_REWRITE () {
		# Args: <worktree> <file> <content> – the temp-file write that drops the executable bit
		printf '%s\n' "$3" > "$1/$2.tmp" && mv "$1/$2.tmp" "$1/$2" && git -C "$1" add -- "$2"
	}
	# Makes and enters a fresh repo `pz-<name>` under `$TMP` – `_ST_PZ_C` commits there, and
	# `_ST_PZ_WT` names the worktree a pause recorded
	_ST_PZ_NEW () {
		cd "$TMP" && rm -rf "pz-$1" && git init -q -b main "pz-$1" && cd "pz-$1" && git config user.email p@x.invalid && git config user.name P
	}
	_ST_PZ_C () {
		# Args: <path> <content> <subject>
		print -r -- "$2" > "$1" && git add -- "$1" && git commit -qm "$3"
	}
	_ST_PZ_WT () {
		sed -n 's/^worktree=//p' "$(git rev-parse --git-common-dir)/git-edit-state" 2>/dev/null
	}
	# Answers whether this git's merge-tree takes `--merge-base`, as `--snapshot` needs – asked here
	# rather than of the tool, whose probe broken would turn its checks into the refusal's
	_ST_MERGE_BASE_OK () {
		[[ "$(LC_ALL=C command git merge-tree -h 2>&1)" == *merge-base* ]]
	}
	# Answers whether this git's sparse-checkout takes `check-rules` (2.42), so the tool reads a
	# sparse checkout's patterns rather than taking every path it adds as outside them
	_ST_SPARSE_RULES_OK () {
		[[ "$(LC_ALL=C command git sparse-checkout -h 2>&1)" == *check-rules* ]]
	}
	# Answers whether this git's `mv` takes `--sparse`, which it then needs to move a file out of the
	# cone in a run's worktree, as that worktree is sparse too
	_ST_MV_SPARSE_OK () {
		# Newer gits list it as `--[no-]sparse`
		[[ "$(LC_ALL=C command git mv -h 2>&1)" == *sparse* ]]
	}
	# Answers whether this git takes `--attr-source` (2.40), so a merge reads
	# the attributes the edits were made under
	_ST_ATTR_SOURCE_OK () {
		LC_ALL=C command git --attr-source=HEAD version >/dev/null 2>&1
	}
	# Runs git edit on a pseudo-terminal as a person at one would – stdin and stdout a TTY, no agent
	# or CI marker – leaving `OUT` and `RC` as `_ST_RUN` does
	_ST_TTY () {
		# Args: [<name>=<value>...] -- <arg>...
		_ST_TTY_START "$@" && _ST_TTY_END
	}
	# `_ST_TTY` in steps, for a run awaiting keys – `_ST_TTY_AT` waits for its prompt, then
	# `zpty -wn ST_TTY <key>` answers it
	_ST_TTY_START () {
		# Args: [<name>=<value>...] -- <arg>...
		local -a ENVS=()
		while [ $# -gt 0 ] && [ "$1" != "--" ]; do ENVS+=("$1"); shift; done
		shift
		rm -f "$TMP/tty-out" "$TMP/tty-rc"
		: >"$TMP/tty-out"
		zmodload zsh/zpty || return 1
		# A home of its own, as a git before 2.32 reads the caller's global config past
		# `GIT_CONFIG_GLOBAL` – no color, pager or suite config pins, and an INT trap so a Ctrl-C sent
		# to the pty, which reaches this shell too, still lets it note the run's status
		zpty ST_TTY "trap : INT; unset CLAUDECODE CI GIT_EDIT_ACTOR GIT_CONFIG_PARAMETERS; env HOME=${(q)TMP} XDG_CONFIG_HOME=${(q)TMP} GIT_EDIT_NO_AUTO_OPEN=1 NO_COLOR=1 PAGER=cat GIT_PAGER=cat ${(j: :)${(@q)ENVS}} ${(q)SELF} ${(j: :)${(@q)@}} 2>&1; print -r -- \$? >${(q)TMP}/tty-rc"
	}
	# Takes what the run wrote to its terminal since, its CRs dropped
	_ST_TTY_PUMP () {
		local C
		while zpty -rt ST_TTY C 2>/dev/null; do print -rn -- "${C//$'\r'/}" >>"$TMP/tty-out"; done
		return 0
	}
	_ST_TTY_AT () {
		# Args: <text the output reaches> [<how many times>] – fails where the run ends or 120s pass first
		local -i W=0
		until _ST_TTY_PUMP; (( $(LC_ALL=C grep -acF -e "$1" "$TMP/tty-out" 2>/dev/null) >= ${2:-1} )); do
			{ [ -s "$TMP/tty-rc" ] || (( ++W > 1200 )); } && return 1
			sleep 0.1
		done
	}
	_ST_TTY_END () {
		local -i W=0
		until _ST_TTY_PUMP; [ -s "$TMP/tty-rc" ] || (( ++W > 1200 )); do sleep 0.1; done
		_ST_TTY_PUMP
		zpty -d ST_TTY
		OUT=$(<"$TMP/tty-out")
		RC=$(<"$TMP/tty-rc")
	}
	# Runs a terminal `git edit <commit>`, writing <content> to <file> at its prompt, then Enter
	_ST_TTY_EDIT () {
		# Args: <commit> <file> <content>
		local WT
		_ST_TTY_START -- "$1" || return 1
		if _ST_TTY_AT 'Make your changes in'; then
			WT=$(_ST_PZ_WT)
			[ -n "$WT" ] && print -r -- "$3" > "$WT/$2"
			zpty -wn ST_TTY $'\r'
			# A pause the resume reaches prompts in turn – left paused there, as a caller's run is
			_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
		fi
		_ST_TTY_END
	}

	PRINT_TEXT "Selftest scratch repo: %s" 36 "$TMP"
	# Holds a hook or a check open until the test releases it, past its signal – a fixed sleep there
	# closes the window early on a machine stalling the test longer
	printf '#!/bin/sh\ni=0\nwhile [ ! -e "$1" ] && [ $i -lt 1200 ]; do sleep 0.1; i=$((i+1)); done\n' > "$TMP/st-hold"
	chmod +x "$TMP/st-hold"
	unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

	# Hermetic maintenance – from git 2.54 every commit's auto-maintenance runs `rerere gc`
	# detached, and its `MERGE_RR.lock` kills an op's rebase reaching its next conflict, so
	# the continue wedges on "staged changes" with the stop's bookkeeping never written
	export GIT_CONFIG_GLOBAL=$TMP/gitconfig
	# Nor a machine's own system config – scenario 123 is where a caller's settings are tried
	export GIT_CONFIG_NOSYSTEM=1
	printf '[maintenance]\n\tauto = false\n[gc]\n\tauto = 0\n' > "$GIT_CONFIG_GLOBAL"
	# No editor from the caller – one an agent's environment exports hid a run reaching for
	# `$EDITOR`, which a plain terminal or a server then opened
	unset GIT_EDITOR GIT_SEQUENCE_EDITOR VISUAL
	export EDITOR=false

	# --- Scratch repo: A, B pushed to a bare origin; C, D, E unpushed ---
	git init -q -b main "$TMP/repo" || { PRINT_ERR "Cannot init scratch repo"; exit 1; }
	cd "$TMP/repo" || exit 1
	git config user.email "selftest@git-edit"
	git config user.name "git-edit selftest"
	git config commit.gpgsign false
	echo "alpha" > a.txt && git add a.txt && git commit -qm "A commit"
	echo "beta"  > b.txt && git add b.txt && git commit -qm "B commit"
	git init -q --bare "$TMP/origin.git"
	git remote add origin "$TMP/origin.git"
	git push -q -u origin main 2>/dev/null
	echo "line1" > c.txt && git add c.txt && git commit -qm "C commit"
	echo "line2" > c.txt && git add c.txt && git commit -qm "D commit"
	echo "epsilon" > e.txt && git add e.txt && git commit -qm "E commit"
	local SHA_A=$(git rev-parse HEAD~4)
	local SHA_B=$(git rev-parse HEAD~3)
	local SHA_C=$(git rev-parse HEAD~2)

	# Sources each scenario file into this function, so what one leaves,
	# its locals too, is there for the ones after it
	local ST_FILE ST_ERR
	for ST_FILE in "${SELFTEST_FILES[@]}"; do
		# One failing to parse would run up to its error and pass, so it parses first, running none of
		# it – as a function body, where a stray `else` or `fi` shows, and in an `if false`, where no
		# later `{` balances a stray `}` – `zsh -n` reads a `$(<file)`
		if ! ST_ERR=$( { eval "_ST_PARSE () { $(<"$ST_FILE")"$'\n}' && eval "if false; then $(<"$ST_FILE")"$'\nfi'; } 2>&1); then
			FAIL=$((FAIL+1))
			ECHO_E "  \e[1;31mFAIL\e[0m ${ST_FILE:t} does not parse"
			print -r -- "$ST_ERR" | head -3 | sed 's/^/       | /'
			continue
		fi
		# A label one scenario set would close every reflog message the next compares
		export GIT_EDIT_ACTOR=
		source "$ST_FILE"
	done

	# --- Summary ---
	local TOTAL=$((PASS+FAIL))
	echo ""
	if [ $FAIL -eq 0 ]; then
		PRINT_TEXT "%s" 32 "Selftest: all $TOTAL checks passed."
		# A passing run leaves nothing to inspect, so it takes the scratch repo and every temp
		# worktree anchored to it along, or each run seeds the debris the sweep above cleans up
		# `-C $TMP/repo`, not `$TMP` – a level too high enumerated nothing and collected none
		local WT
		git -C "$TMP/repo" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | \
		while IFS= read -r WT; do
			if [ "$WT" != "$TMP/repo" ]; then
				rm -rf "$WT" 2>/dev/null
			fi
		done
		cd /
		rm -rf "$TMP" 2>/dev/null
		echo "git-edit: ok – selftest $PASS/$TOTAL passed${SELFTEST_SCOPE:+ – $SELFTEST_SCOPE}"
		_STATUS_EMITTED=true
		return 0
	else
		PRINT_TEXT "%s" 31 "Selftest: $FAIL of $TOTAL checks FAILED."
		# A failing run keeps both, that tree being the evidence – the keep is disarming the cleanup
		# hook registered at the start, or the exit trap would remove it right after this promise
		_CLEANUP_HOOK=""
		PRINT_TEXT "Scratch repo kept for inspection: %s" 33 "$TMP"
		# A scenario can pass in sequence and fail alone, starting from state an earlier one left
		if [ -n "$SELFTEST_SCOPE" ]; then
			PRINT_TEXT "Only %s ran – one that passes in the full suite may need an earlier one, named with %s on its %s line" 33 "$SELFTEST_SCOPE" "# needs <ids>" "_ST_SCENARIO"
		fi
		echo "git-edit: error – selftest $FAIL/$TOTAL failed${SELFTEST_SCOPE:+ – $SELFTEST_SCOPE}"
		_STATUS_EMITTED=true
		return 1
	fi
}
