#!/bin/zsh
# `git-edit`'s end-to-end test suite, sourced by `git edit --selftest`.
#
# It is not run directly: every helper it uses – `ECHO_E`, `PRINT_TEXT`, `MKTEMP_DIR`
# – belongs to `git-edit`, which sources this file once, for that one mode. The
# suite drives the tool the way a caller does, by re-invoking the script as a
# subprocess (`$SELF`), so what it exercises is the shipped behavior rather
# than its internals. `$SELF` is also what the structural checks grep, so it
# must stay pointed at `git-edit` itself, never at this file.
#
# Scenarios share one scratch repo, in order – a fixture can collide with an
# earlier scenario's leftovers, which reads as a tool failure but isn't.

# Builds a scratch repo with a fake pushed remote and exercises every mode through real
# sub-invocations of `git-edit` – reword, fold, split, replant, drop, squash, reorder,
# move, exec, the pushed guards, stale-SHA resolution, merge topology, undo and status
GIT_SELFTEST () {
	local SELF=$1
	local TMP=$(MKTEMP_DIR git-edit-selftest)
	_CLEANUP_HOOK="rm -rf '$TMP'"
	local PASS=0
	local FAIL=0
	local OUT RC

	# A pause that never came leaves its worktree path empty, and a write through
	# it would land at the filesystem root – this sends it nowhere instead, so a
	# missed pause fails the scenario's assertions and nothing else
	local ST_NO_WT=/nonexistent/git-edit-selftest

	# Deterministic clock – every git call takes a unique ascending timestamp via the `:-`
	# fallbacks, since real-time fixtures landed up to 8 commits per wall-clock second and
	# those ties swung stock runs between 35 and 65 failures where pinned runs were identical
	local ST_TICK=1112911993
	git () {
		ST_TICK=$((ST_TICK+60))
		GIT_AUTHOR_DATE="${GIT_AUTHOR_DATE:-@$ST_TICK +0000}" GIT_COMMITTER_DATE="${GIT_COMMITTER_DATE:-@$ST_TICK +0000}" command git "$@"
	}

	# Sub-invocations run non-TTY (stdin </dev/null) for deterministic agent
	# behavior even when the selftest itself runs from a terminal
	_ST_RUN () {
		OUT=$(GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" "$@" </dev/null 2>&1)
		RC=$?
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
	# Feeds <stdin> as the first argument, otherwise as `_ST_RUN`, for the records form
	# form of reword (`-M --text -`) which reads its targets from stdin
	_ST_RUN_IN () {
		local INPUT=$1; shift
		OUT=$(GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" "$@" <<<"$INPUT" 2>&1)
		RC=$?
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
	_ST_OUT_HAS () {
		local DESC=$1
		local PATTERN=$2
		if print -r -- "$OUT" | grep -q "$PATTERN"; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | tail -16 | sed 's/^/       | /'
		fi
	}
	_ST_OUT_LACKS () {
		local DESC=$1
		local PATTERN=$2
		if print -r -- "$OUT" | grep -q "$PATTERN"; then
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | grep "$PATTERN" | head -3 | sed 's/^/       | /'
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

	PRINT_TEXT "Selftest scratch repo: %s" 36 "$TMP"
	unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

	# Hermetic maintenance – from git 2.54 every commit's auto-maintenance runs `rerere gc`
	# detached, and its `MERGE_RR.lock` kills an op's rebase reaching its next conflict, so
	# the continue wedges on "staged changes" with the stop's bookkeeping never written
	export GIT_CONFIG_GLOBAL=$TMP/gitconfig
	printf '[maintenance]\n\tauto = false\n[gc]\n\tauto = 0\n' > "$GIT_CONFIG_GLOBAL"

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

	# --- 1. Reword (-M --text): plumbing, tree-identical, trailer ---
	_ST_SCENARIO "\e[1;96m[1] reword (-M --text)\e[0m"
	local PRE_HEAD=$(git rev-parse HEAD)
	local PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN -M --text="C reworded" "$SHA_C"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok – refs/heads/main moved'
	_ST_OUT_HAS "states tree identity" 'Trees unchanged'
	_ST_OUT_HAS "echoes the resulting subject" '[0-9a-f]\{7\} C reworded'
	# A symbolic target resolves once, so the summary has to name what it
	# replaced – otherwise rewording the wrong commit reads as success
	_ST_OUT_HAS "names the subject it replaced" 'replaced:.*C commit'
	_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
	_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
	_ST_EQ "message applied" "$(git log --format=%s -3 | tail -1)" "C reworded"

	# --- 2. Undo: reverts the reword, CAS-guarded ---
	_ST_SCENARIO "\e[1;96m[2] undo\e[0m"
	_ST_RUN --undo
	_ST_EQ "exits 0" "$RC" "0"
	_ST_EQ "HEAD restored" "$(git rev-parse HEAD)" "$PRE_HEAD"

	# --- 3. Pushed guard: refuse B, allow with --allow-pushed ---
	_ST_SCENARIO "\e[1;96m[3] pushed guard\e[0m"
	_ST_RUN -M --text="B reworded" "$SHA_B"
	_ST_CHECK "refuses pushed commit" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'already pushed'
	_ST_RUN --allow-pushed -M --text="B reworded" "$SHA_B"
	_ST_EQ "--allow-pushed overrides" "$RC" "0"
	_ST_RUN --undo
	_ST_EQ "undo restores" "$(git rev-parse HEAD)" "$PRE_HEAD"

	# --- 4. Fold (--amend-into) clean: a.txt change into C ---
	_ST_SCENARIO "\e[1;96m[4] amend-into (clean)\e[0m"
	echo "alpha folded" > a.txt
	git add a.txt
	_ST_RUN --amend-into="$SHA_C"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok – refs/heads/main moved'
	_ST_OUT_HAS "prints folded summary" 'Folded'
	_ST_OUT_HAS "reports the leftover checkout state" 'Index now empty'
	_ST_EQ "change landed in C" "$(git show 'HEAD~2:a.txt')" "alpha folded"
	_ST_CHECK "index clean afterwards" git diff --cached --quiet
	_ST_CHECK "no fixup commit on branch" test -z "$(git log --format=%s | grep '^fixup!')"

	# --- 5. Fold conflict -> status -> abort: branch + staged intact ---
	_ST_SCENARIO "\e[1;96m[5] amend-into conflict + abort\e[0m"
	PRE_HEAD=$(git rev-parse HEAD)
	local SHA_C2=$(git rev-parse HEAD~2)
	echo "line1-conflict" > c.txt
	git add c.txt
	_ST_RUN --amend-into="$SHA_C2"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	_ST_OUT_HAS "emits conflict trailer" '^git-edit: conflict – resolve in'
	# The resolver's next question is which later steps touch the file, since
	# the resolution is the state before they replay – so the pause answers it,
	# naming D (which touches c.txt) and not E (which doesn't)
	_ST_OUT_HAS "flags the later steps touching a conflicted file" 'Remaining steps also touch a conflicted file'
	_ST_OUT_HAS "names the step that touches it" '[0-9a-f]\{7\} D commit'
	_ST_OUT_LACKS "leaves out a step touching other files" '[0-9a-f]\{7\} E commit'
	_ST_EQ "branch untouched during pause" "$(git rev-parse HEAD)" "$PRE_HEAD"
	_ST_RUN --status
	_ST_OUT_HAS "status reports the conflict" '^git-edit: conflict – resolve in'
	_ST_RUN --abort
	_ST_EQ "abort exits 0" "$RC" "0"
	_ST_EQ "branch still untouched" "$(git rev-parse HEAD)" "$PRE_HEAD"
	_ST_CHECK "staged change preserved" sh -c "git diff --cached --name-only | grep -q c.txt"

	# --- 6. Fold conflict -> resolve -> continue (with cascade) ---
	_ST_SCENARIO "\e[1;96m[6] amend-into conflict + continue\e[0m"
	_ST_RUN --amend-into="$SHA_C2"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	local ROUNDS=0
	while [ "$RC" = "2" ] && [ $ROUNDS -lt 4 ]; do
		ROUNDS=$((ROUNDS+1))
		local CONFLICT_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
		if [ -z "$CONFLICT_WT" ] || [ ! -d "$CONFLICT_WT" ]; then
			break
		fi
		if [ $ROUNDS -eq 1 ]; then
			echo "line1-resolved" > "${CONFLICT_WT:-$ST_NO_WT}/c.txt"
		else
			echo "line2" > "${CONFLICT_WT:-$ST_NO_WT}/c.txt"
		fi
		git -C "$CONFLICT_WT" add c.txt
		_ST_RUN --continue
	done
	_ST_EQ "continue completes" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok – refs/heads/main moved'
	_ST_EQ "resolution in C" "$(git show 'HEAD~2:c.txt')" "line1-resolved"
	_ST_EQ "tip keeps D's content" "$(git show 'HEAD:c.txt')" "line2"
	_ST_CHECK "index clean afterwards" git diff --cached --quiet
	_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"

	# --- 6b. Conflict resolved manually in the worktree, staged WIP survives ---
	_ST_SCENARIO "\e[1;96m[6b] manual worktree completion + parallel staged WIP\e[0m"
	PRE_HEAD=$(git rev-parse HEAD)
	local SHA_C3=$(git rev-parse HEAD~2)
	echo "line1-again" > c.txt
	git add c.txt
	_ST_RUN --amend-into="$SHA_C3"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	# A parallel session stages an unrelated file mid-pause
	echo "parallel" > w.txt
	git add w.txt
	# The agent resolves and drives the rebase manually inside the worktree
	local MANUAL_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	_ST_RESOLVE "$MANUAL_WT" c.txt "line1-again"
	local MROUNDS=0
	while [ $MROUNDS -lt 4 ]; do
		MROUNDS=$((MROUNDS+1))
		GIT_EDIT_NO_AUTO_OPEN=1 git -C "$MANUAL_WT" -c core.editor=true rebase --continue >/dev/null 2>&1 && break
		_ST_RESOLVE "$MANUAL_WT" c.txt "line2"
	done
	_ST_RUN --continue
	_ST_EQ "continue applies the manual result" "$RC" "0"
	_ST_OUT_HAS "notes manual completion" 'already completed'
	_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
	_ST_CHECK "parallel staged WIP survived" sh -c "git diff --cached --name-only | grep -q w.txt"
	_ST_CHECK "folded path reports clean" sh -c "! git diff --cached --name-only | grep -q c.txt"
	git reset -q -- w.txt && rm -f w.txt

	# --- 6c. Standalone commands refuse stray arguments ---
	_ST_SCENARIO "\e[1;96m[6c] stray-argument refusal\e[0m"
	_ST_RUN --undo "$(git rev-parse HEAD)"
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'take no arguments'

	# --- 7. Drop (auto-isolated, non-TTY) ---
	_ST_SCENARIO "\e[1;96m[7] drop\e[0m"
	_ST_RUN -d "$(git rev-parse HEAD)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_CHECK "dropped commit's file gone" sh -c "! git cat-file -e 'HEAD:e.txt'"

	# --- 8. Squash (implicit, plumbing route) ---
	_ST_SCENARIO "\e[1;96m[8] squash (plumbing)\e[0m"
	PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	local PRE_COUNT=$(git rev-list --count HEAD)
	_ST_RUN --text="C and D combined" "$(git rev-parse HEAD~1)" "$(git rev-parse HEAD)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree identical'
	_ST_EQ "one commit fewer" "$(git rev-list --count HEAD)" "$((PRE_COUNT-1))"
	_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
	_ST_EQ "combined message" "$(git log --format=%s -1)" "C and D combined"

	# --- 9. Reorder: swap two independent tip commits ---
	_ST_SCENARIO "\e[1;96m[9] reorder\e[0m"
	echo "ex" > x.txt && git add x.txt && git commit -qm "X commit"
	echo "why" > y.txt && git add y.txt && git commit -qm "Y commit"
	PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree identical'
	_ST_OUT_HAS "lists the new order oldest-first" 'new order (oldest-first)'
	_ST_EQ "order swapped" "$(git log --format=%s -2 | tr '\n' ' ')" "X commit Y commit "
	_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"

	# --- 10. Edit mode pauses in non-TTY instead of prompting ---
	_ST_SCENARIO "\e[1;96m[10] edit-mode non-TTY pause\e[0m"
	_ST_RUN "$(git rev-parse HEAD)"
	_ST_EQ "pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "paused trailer names the worktree" 'git-edit: paused'
	_ST_RUN --abort
	_ST_EQ "abort clears it" "$RC" "0"

	# --- 11. Exec: amend via isolated worktree ---
	_ST_SCENARIO "\e[1;96m[11] exec\e[0m"
	_ST_RUN --exec -- git commit --amend -m "amended via exec"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_EQ "amend applied" "$(git log --format=%s -1)" "amended via exec"

	# --- 12. Exec pushed-orphan guard ---
	_ST_SCENARIO "\e[1;96m[12] exec pushed-orphan guard\e[0m"
	PRE_HEAD=$(git rev-parse HEAD)
	_ST_RUN --exec -- git reset --hard "$SHA_A"
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'pushed history'
	_ST_EQ "branch unchanged" "$(git rev-parse HEAD)" "$PRE_HEAD"

	# --- 13. Undo refuses after the branch moved on ---
	_ST_SCENARIO "\e[1;96m[13] undo CAS guard\e[0m"
	echo "zeta" > z.txt && git add z.txt && git commit -qm "Z commit"
	_ST_RUN --undo
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'has moved since'

	# --- 14. Status: idle report ---
	_ST_SCENARIO "\e[1;96m[14] status (idle)\e[0m"
	_ST_RUN --status
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "reports idle" '^git-edit: ok – no operation in flight'

	# --- 15. amend-into=auto: consensus target, new file follows ---
	_ST_SCENARIO "\e[1;96m[15] amend-into=auto\e[0m"
	echo "em" > m.txt && git add m.txt && git commit -qm "M commit"
	echo "en" > n.txt && git add n.txt && git commit -qm "N commit"
	echo "em2" > m.txt && git add m.txt
	echo "new" > p.txt && git add p.txt
	_ST_RUN --amend-into=auto
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "names auto-target" 'auto-target'
	_ST_EQ "fold landed in M" "$(git show 'HEAD~1:m.txt')" "em2"
	_ST_CHECK "new file followed consensus" git cat-file -e 'HEAD~1:p.txt'

	# --- 16. auto refuses ambiguous targets ---
	_ST_SCENARIO "\e[1;96m[16] auto ambiguity refusal\e[0m"
	echo "em3" > m.txt && echo "en3" > n.txt
	git add m.txt n.txt
	_ST_RUN --amend-into=auto
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "lists candidates" 'different commits'
	git reset -q && git checkout -q -- m.txt n.txt

	# --- 17. auto refuses pushed-only history ---
	_ST_SCENARIO "\e[1;96m[17] auto pushed-history refusal\e[0m"
	echo "beta2" > b.txt && git add b.txt
	_ST_RUN --amend-into=auto
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'pushed commit'
	git reset -q && git checkout -q -- b.txt

	# --- 18. split by pathspec ---
	_ST_SCENARIO "\e[1;96m[18] split\e[0m"
	echo "s1" > s1.txt && echo "s2" > s2.txt
	git add s1.txt s2.txt && git commit -qm "S mixed commit"
	PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN --split="$(git rev-parse HEAD)" --text="S extracted" -- s1.txt
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree identical'
	_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
	_ST_EQ "tip keeps original message" "$(git log --format=%s -1)" "S mixed commit"
	_ST_EQ "extracted commit below it" "$(git log --format=%s -2 | tail -1)" "S extracted"
	_ST_CHECK "extracted has s1" git cat-file -e 'HEAD~1:s1.txt'
	_ST_CHECK "extracted lacks s2" sh -c "! git cat-file -e 'HEAD~1:s2.txt'"
	_ST_RUN --split="$(git rev-parse HEAD)" --text="x" -- nomatch.txt
	_ST_CHECK "refuses non-matching pathspec" test "$RC" != "0"
	_ST_RUN --split="$(git rev-parse HEAD~1)" --text="x" -- s1.txt
	_ST_CHECK "refuses whole-commit pathspec" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'covers every change'
	_ST_OUT_HAS "single-file split points at the content form" 'drop the pathspec and split by content'

	# --- 19. empty-step pause: guidance + skip, plus graceful no-op continue ---
	_ST_SCENARIO "\e[1;96m[19] empty-step guidance\e[0m"
	echo "f1" > f1.txt && echo "v1" > f2.txt && git add f1.txt f2.txt && git commit -qm "R0 base"
	echo "f1x" > f1.txt && echo "v2" > f2.txt && git add f1.txt f2.txt && git commit -qm "R1 commit"
	echo "v1" > f2.txt && git add f2.txt && git commit -qm "R2 revert"
	PRE_HEAD=$(git rev-parse HEAD)
	# Moving the revert before the commit it reverts makes it empty
	_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	_ST_OUT_HAS "explains the empty step" 'became empty'
	_ST_OUT_HAS "names the skip escape" 'rebase --skip'
	local EMPTY_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	git -C "$EMPTY_WT" rebase --skip >/dev/null 2>&1
	_ST_RUN --continue
	_ST_EQ "continue applies the result" "$RC" "0"
	_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
	_ST_EQ "revert dropped, R1 content kept" "$(git show 'HEAD:f2.txt')" "v2"
	_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
	# Graceful no-op: a manually-aborted worktree rebase reports unchanged
	echo "v2b" > f2.txt && git add f2.txt && git commit -qm "R3 commit"
	echo "v1" > f2.txt && git add f2.txt && git commit -qm "R4 revert"
	PRE_HEAD=$(git rev-parse HEAD)
	_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	EMPTY_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	git -C "$EMPTY_WT" rebase --abort >/dev/null 2>&1
	_ST_RUN --continue
	_ST_EQ "no-op continue exits 0" "$RC" "0"
	_ST_OUT_HAS "reports unchanged" '^git-edit: ok – .* unchanged'
	_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$PRE_HEAD"
	_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"

	# --- 20. tag-orphan warning on rewrites beneath a tag ---
	_ST_SCENARIO "\e[1;96m[20] tag-orphan warning\e[0m"
	echo "t1" > t1.txt && git add t1.txt && git commit -qm "T1 commit"
	echo "t2" > t2.txt && git add t2.txt && git commit -qm "T2 commit"
	git tag marker
	# Rewriting below the tag orphans it – expect the warning + exact re-point
	_ST_RUN -M --text="T1 reworded" "$(git rev-parse HEAD~1)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "warns about the tag" 'points into the rewritten span'
	_ST_OUT_HAS "suggests exact counterpart" 'git tag -f marker .*same subject'
	git tag -f marker >/dev/null 2>&1   # re-point to current `HEAD` for the next check
	# Rewriting above the tag leaves it reachable – expect no warning
	git tag -f marker "$(git rev-parse HEAD~1)" >/dev/null 2>&1
	_ST_RUN -M --text="T2 reworded" "$(git rev-parse HEAD)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_LACKS "no warning for safe tag" 'points into the rewritten span'
	git tag -d marker >/dev/null 2>&1
	# Two tags in the span warn independently, and a tag on a non-commit
	# object is neither flagged nor trips the --merged walks
	git tag markerA "$(git rev-parse HEAD~1)"
	git tag markerB
	git tag blobmark "$(echo blob | git hash-object -w --stdin)"
	_ST_RUN -M --text="T1 reworded again" "$(git rev-parse HEAD~1)"
	_ST_EQ "exits 0 with a blob tag present" "$RC" "0"
	_ST_OUT_HAS "warns about the lower tag" 'Tag markerA points into'
	_ST_OUT_HAS "and the upper tag" 'Tag markerB points into'
	_ST_OUT_LACKS "blob tag never flagged" 'blobmark'
	git tag -d markerA markerB blobmark >/dev/null 2>&1

	# --- 21. auto-target resolves from a subdirectory ---
	_ST_SCENARIO "\e[1;96m[21] auto-target from subdirectory\e[0m"
	mkdir -p subd
	echo "sd" > subd/sd.txt && git add subd/sd.txt && git commit -qm "SD commit"
	cd subd
	echo "sd2" > sd.txt && git add sd.txt
	_ST_RUN --amend-into=auto
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "names auto-target" 'auto-target'
	cd "$TMP/repo"
	_ST_EQ "fold landed in SD" "$(git show 'HEAD:subd/sd.txt')" "sd2"

	# --- 22. man page exists and documents every mode (drift guard vs. USAGE) ---
	_ST_SCENARIO "\e[1;96m[22] man page coverage\e[0m"
	local MANPAGE="$(dirname "$SELF")/man/man1/git-edit.1"
	local READMEFILE="$(dirname "$SELF")/README.md"
	_ST_CHECK "man page present" test -f "$MANPAGE"
	if [ -f "$MANPAGE" ]; then
		# Derive the flags from the parser itself – a hardcoded list drifts the moment a mode is
		# added, which is the very drift this check exists to catch
		# Anchored on `^if ! zparseopts` so the match can only ever be the parser
		local -a DOCFLAGS
		local ZLINE=$(command grep -m1 '^if ! zparseopts' "$SELF")
		local ztok zname
		for ztok in ${(z)ZLINE}; do
			[[ "$ztok" != *"=OPT_"* ]] && continue
			ztok=${ztok%%=OPT_*}
			ztok=${ztok%%:*}
			ztok=${ztok//[\{\}]/}
			for zname in ${(s:,:)ztok}; do
				[[ "$zname" == -* ]] && DOCFLAGS+=("-$zname")
			done
		done
		_ST_CHECK "flag list derived from the parser" test ${#DOCFLAGS[@]} -ge 20
		# Strip roff backslash escapes so flag spellings match, with no man or mandoc dep
		local mflag missing="" rmissing=""
		local MANTEXT=$(sed 's/\\//g' "$MANPAGE")
		for mflag in "${DOCFLAGS[@]}"; do
			[ -z "$mflag" ] && continue
			echo "$MANTEXT" | grep -q -- "$mflag" || missing="$missing $mflag"
			[ -f "$READMEFILE" ] && { grep -q -- "$mflag" "$READMEFILE" || rmissing="$rmissing $mflag" }
		done
		if [ -z "$missing" ]; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m man page documents every mode"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m man page missing:$missing"
		fi
		if [ -z "$rmissing" ]; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m README documents every mode"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m README missing:$rmissing"
		fi
	fi

	# --- 23. stale (rewritten) SHAs are refused, never silently no-op'd ---
	_ST_SCENARIO "\e[1;96m[23] stale SHA handling\e[0m"
	echo "stale" > stale.txt && git add stale.txt && git commit -qm "Stale target"
	local STALE_SHA=$(git rev-parse HEAD)
	# Fold into it: the SHA changes, the subject survives for the counterpart hint
	echo "stale2" > stale.txt && git add stale.txt
	_ST_RUN --amend-into="$STALE_SHA"
	local STALE_HEAD=$(git rev-parse HEAD)
	local STALE_COUNT=$(git rev-list --count HEAD)
	_ST_RUN -d -y "$STALE_SHA"
	_ST_EQ "drop refuses a stale SHA" "$RC" "1"
	_ST_OUT_HAS "explains it was rewritten" 'likely rewritten'
	_ST_OUT_HAS "names the counterpart" 'counterpart on HEAD'
	_ST_EQ "HEAD untouched" "$(git rev-parse HEAD)" "$STALE_HEAD"
	_ST_EQ "nothing dropped" "$(git rev-list --count HEAD)" "$STALE_COUNT"
	_ST_RUN -d -y deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
	_ST_EQ "nonexistent SHA refused" "$RC" "1"
	_ST_OUT_HAS "reports it does not exist" 'does not exist'
	# A commit only rebuilt as a descendant keeps its diff, so it resolves outright
	echo "tip" > tip.txt && git add tip.txt && git commit -qm "Tip commit"
	local SHIFTED=$(git rev-parse HEAD)
	echo "stale3" > stale.txt && git add stale.txt
	_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
	_ST_RUN -M --text="Tip reworded" "$SHIFTED"
	_ST_EQ "stale descendant auto-resolves" "$RC" "0"
	_ST_OUT_HAS "reports the substitution" 'current identity'
	_ST_EQ "reword hit the right commit" "$(git log -1 --format=%s)" "Tip reworded"
	export GIT_EDIT_NO_RESOLVE=1
	_ST_RUN -M --text="Opted out" "$SHIFTED"
	unset GIT_EDIT_NO_RESOLVE
	_ST_EQ "GIT_EDIT_NO_RESOLVE opts out" "$RC" "1"
	# --amend-into and --split take their target as an option value, not a
	# positional, so they need the guard wired in separately
	echo "anchor" > anchor.txt && git add anchor.txt && git commit -qm "Anchor commit"
	local ANCHOR=$(git rev-parse HEAD)
	echo "opt" > opt.txt && git add opt.txt && git commit -qm "Option-value target"
	local OPTVAL=$(git rev-parse HEAD)
	echo "shift" > shift.txt && git add shift.txt && git commit -qm "Shifter"
	# Fold below the target so it is only rebuilt – its own diff, and so its
	# patch id, must survive for the resolution to be provable
	echo "anchor2" > anchor.txt && git add anchor.txt
	_ST_RUN --amend-into="$ANCHOR"
	echo "folded" > folded.txt && git add folded.txt
	_ST_RUN --amend-into="$OPTVAL"
	_ST_EQ "--amend-into resolves a stale target" "$RC" "0"
	_ST_OUT_HAS "--amend-into reports the substitution" 'current identity'
	_ST_EQ "fold landed on the resolved commit" "$(git show 'HEAD~1:folded.txt' 2>/dev/null)" "folded"
	# A resolved match on pushed history is named, never acted on – not even
	# under --allow-pushed, which consents to the named commit and not this one
	# A cherry-pick keeps both author date and diff, so it is the twin to beat
	git rm -q b.txt && git commit -qm "Remove beta"
	git cherry-pick "$(git rev-parse origin/main)" >/dev/null 2>&1
	local TWIN=$(git rev-parse HEAD)
	# Dropping the twin leaves the pushed original as the sole commit with that
	# diff, so the stale SHA resolves uniquely onto shared history
	_ST_RUN -d -y "$TWIN"
	local TWIN_HEAD=$(git rev-parse HEAD)
	_ST_RUN -M --text="Should not land" --allow-pushed "$TWIN"
	_ST_EQ "pushed match refused under --allow-pushed" "$RC" "1"
	_ST_OUT_HAS "names the pushed match" 'already pushed'
	_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$TWIN_HEAD"

	# --- 24. merge topology: plumbing rebuilds preserve it, rebase modes refuse ---
	_ST_SCENARIO "\e[1;96m[24] merge topology\e[0m"
	echo "l1" > l1.txt && git add l1.txt && git commit -qm "Low one"
	local LOW1=$(git rev-parse HEAD)
	echo "l2" > l2.txt && git add l2.txt && git commit -qm "Low two"
	local LOW2=$(git rev-parse HEAD)
	echo "db" > db.txt && git add db.txt && git commit -qm "Diamond base"
	local DBASE=$(git rev-parse HEAD)
	git checkout -q -b d-side
	echo "ds" > ds.txt && git add ds.txt && git commit -qm "Diamond side"
	local DSIDE=$(git rev-parse HEAD)
	git checkout -q main
	echo "dm" > dm.txt && git add dm.txt && git commit -qm "Diamond main"
	local DMAIN=$(git rev-parse HEAD)
	git merge -q --no-ff -m "Diamond merge" d-side >/dev/null 2>&1
	echo "dt" > dt.txt && git add dt.txt && git commit -qm "Diamond tip"
	# Mid-leg reword: the side leg does not descend from it, so it must
	# survive byte-identical while the merge is rebuilt with the new parent
	_ST_RUN -M --text="Diamond main reworded" "$DMAIN"
	_ST_EQ "reword below a merge exits 0" "$RC" "0"
	_ST_EQ "merge topology preserved" "$(git rev-list --merges --count HEAD)" "1"
	_ST_CHECK "untouched side leg kept as-is" git merge-base --is-ancestor "$DSIDE" HEAD
	echo "dbx" >> db.txt && git add db.txt
	_ST_RUN --amend-into="$DBASE"
	_ST_EQ "--amend-into refuses across a merge" "$RC" "1"
	_ST_OUT_HAS "names the flatten hazard" 'flatten'
	git reset -q && git checkout -q -- db.txt
	_ST_RUN -d -y "$DBASE"
	_ST_EQ "drop refuses across a merge" "$RC" "1"
	# A merge-free range below the merge routes to plumbing and stays legal
	_ST_RUN -s -y --text="Lows combined" "$LOW1" "$LOW2"
	_ST_EQ "squash below the merge auto-routes to plumbing" "$RC" "0"
	_ST_EQ "merge survived the squash" "$(git rev-list --merges --count HEAD)" "1"
	git branch -q -D d-side

	# --- 25. move mode: reposition one commit via derived span reorder ---
	_ST_SCENARIO "\e[1;96m[25] move mode\e[0m"
	for MC in m1 m2 m3 m4; do
		echo "$MC" > "$MC.txt" && git add "$MC.txt" && git commit -qm "Move $MC"
	done
	local MV_FIRST=$(git rev-parse HEAD~3)
	local MV_TIP=$(git rev-parse HEAD)
	_ST_RUN --move="$MV_TIP" --after="$MV_FIRST"
	_ST_EQ "backward move exits 0" "$RC" "0"
	_ST_EQ "span reordered as asked" "$(git log --format=%s -4 | tr '\n' ' ')" "Move m3 Move m2 Move m4 Move m1 "
	local MV_M4=$(git log --format='%H %s' -4 | awk '$3=="m4"{print $1}')
	_ST_RUN --move="$MV_M4" --after="$(git rev-parse HEAD)"
	_ST_EQ "forward move exits 0" "$RC" "0"
	_ST_EQ "restored original order" "$(git log --format=%s -4 | tr '\n' ' ')" "Move m4 Move m3 Move m2 Move m1 "
	_ST_RUN --move="$(git rev-parse HEAD)" --after="$(git rev-parse HEAD~1)"
	_ST_EQ "in-position move is a no-op" "$RC" "0"
	_ST_OUT_HAS "no-op reports unchanged" 'unchanged'
	_ST_RUN --move="$(git rev-parse HEAD)" --after="$(git rev-parse HEAD~2)" --before="$(git rev-parse HEAD~3)"
	_ST_EQ "both anchors refused" "$RC" "1"
	# Swapping two commits whose hunks abut conflicts on both steps – the first rebuilds an
	# intermediate that never existed and is authored, while the last is fully determined,
	# so the hint must name it there and only there
	printf 'mv-base\n' > mv.txt && git add mv.txt && git commit -qm "MV base"
	printf 'mv-base\nmv-A\n' > mv.txt && git add mv.txt && git commit -qm "MV A"
	local MV_A=$(git rev-parse HEAD)
	printf 'mv-base\nmv-B\nmv-A\n' > mv.txt && git add mv.txt && git commit -qm "MV B"
	local MV_B=$(git rev-parse HEAD)
	local MV_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN --move="$MV_A" --after="$MV_B"
	_ST_EQ "abutting swap conflicts" "$RC" "2"
	_ST_OUT_LACKS "no final-step hint on an intermediate step" 'Final step'
	_ST_OUT_HAS "intermediate step says author it" 'rebuilds a state that never existed'
	_ST_OUT_HAS "intermediate step rules out --3way" 'cannot work here'
	local MV_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	printf 'mv-base\nmv-B\n' > "${MV_WT:-$ST_NO_WT}/mv.txt" && git -C "$MV_WT" add mv.txt
	# The final step is fully determined, so it resolves itself rather than
	# handing back a command the tool already derived
	_ST_RUN --continue
	_ST_EQ "final step needs no second continue" "$RC" "0"
	_ST_OUT_HAS "says it auto-resolved the final step" 'Final step auto-resolved'
	_ST_OUT_LACKS "no homework left for the caller" 'Final step – a reorder preserves'

	_ST_EQ "tree preserved by the reorder" "$(git rev-parse 'HEAD^{tree}')" "$MV_TREE"
	_ST_EQ "commits swapped" "$(git log --format=%s -2 | tr '\n' ' ')" "MV A MV B "

	# --- 26. explicit-target squash: same-second span, short SHAs ---
	# The rebuilt-commit case: descendants of one rewrite all share a committer
	# second, so timestamp sorts tie – the span must sort from `HEAD`'s history,
	# and short SHAs must normalize for that sort's exact match to hit
	_ST_SCENARIO "\e[1;96m[26] explicit-target squash ordering\e[0m"
	local QN
	for QN in q1 q2 q3 q4; do
		echo "$QN" > q.txt && git add q.txt
		GIT_COMMITTER_DATE="2026-01-02T03:04:05+00:00" git commit -qm "Q $QN"
	done
	local QT=$(git rev-parse --short HEAD~3)
	_ST_RUN -s="$QT" -y --text="Q combined" "$(git rev-parse --short HEAD)" "$(git rev-parse --short HEAD~1)" "$(git rev-parse --short HEAD~2)"
	_ST_EQ "same-second short-SHA squash exits 0" "$RC" "0"
	_ST_OUT_HAS "routed to plumbing" 'commit-tree'
	_ST_EQ "one combined commit" "$(git log -1 --format=%s)" "Q combined"
	_ST_EQ "content is the newest version" "$(git show HEAD:q.txt)" "q4"
	# A tree-identical rewrite (non-adjacent squash of separate-file commits,
	# forced onto the rebase path) needs no checkout reconcile – the hint must
	# say so instead of prescribing the stash/reset dance
	echo "r1" > r1.txt && git add r1.txt && git commit -qm "R gap1"
	echo "r2" > r2.txt && git add r2.txt && git commit -qm "R gap2"
	echo "r3" > r3.txt && git add r3.txt && git commit -qm "R gap3"
	_ST_RUN -s="$(git rev-parse HEAD~2)" -y --text="R gap1+3" "$(git rev-parse HEAD)"
	_ST_EQ "non-adjacent pure squash exits 0" "$RC" "0"
	_ST_OUT_HAS "reconcile hint suppressed" 'checkout is already current'
	_ST_OUT_LACKS "no stash dance prescribed" "stash push -u -m 'wip before git-edit'"

	# --- 27. rebase-path conflicts pause into --continue/--abort ---
	# Dropping a commit whose successor edits the same line conflicts, and the
	# isolated rebase must pause like the plumbing modes rather than bail
	_ST_SCENARIO "\e[1;96m[27] rebase-path conflict pause\e[0m"
	printf 'x\nb\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ base"
	printf 'x\nMID\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ mid"
	printf 'x\nTIP\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ tip"
	local PZ_TIP=$(git rev-parse HEAD)
	_ST_RUN -d -y HEAD~1
	_ST_EQ "conflicting drop pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "names the action" 'Conflict during drop'
	_ST_EQ "branch untouched while paused" "$(git rev-parse HEAD)" "$PZ_TIP"
	local PZ_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	printf 'x\nTIP\nz\n' > "${PZ_WT:-$ST_NO_WT}/pz.txt" && git -C "$PZ_WT" add pz.txt
	_ST_RUN --continue
	_ST_EQ "continue completes the drop" "$RC" "0"
	_ST_EQ "dropped commit is gone" "$(git log --format=%s -2 | tr '\n' ' ')" "PZ tip PZ base "
	_ST_CHECK "state cleared after continue" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	printf 'x\nMID2\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ mid2"
	printf 'x\nTIP2\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ tip2"
	local PZ_TIP2=$(git rev-parse HEAD)
	_ST_RUN -d -y HEAD~1
	_ST_EQ "second conflicting drop pauses" "$RC" "2"
	_ST_RUN --abort
	_ST_EQ "abort exits 0" "$RC" "0"
	_ST_OUT_HAS "abort reports nothing to roll back" 'never touched'
	_ST_EQ "abort leaves the branch untouched" "$(git rev-parse HEAD)" "$PZ_TIP2"

	# --- 28. auto-target follows the edited lines, not the file ---
	_ST_SCENARIO "\e[1;96m[28] blame-aware auto-target\e[0m"
	printf 'bl1\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\n' > bl.txt
	git add bl.txt && git commit -qm "BL base"
	printf 'bl1\nBL-A original\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\n' > bl.txt
	git add bl.txt && git commit -qm "BL add A"
	printf 'bl1\nBL-A original\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B original\n' > bl.txt
	git add bl.txt && git commit -qm "BL add B"
	printf 'bl1\nBL-A original\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B refined\n' > bl.txt
	git add bl.txt && git commit -qm "BL refine B"
	# The newest commit touching bl.txt is "BL refine B", but the edited line
	# belongs to "BL add A" – the file-level guess would fold into the wrong one
	printf 'bl1\nBL-A EDITED\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B refined\n' > bl.txt
	git add bl.txt
	_ST_RUN --amend-into=auto
	_ST_EQ "line-level auto exits 0" "$RC" "0"
	_ST_OUT_HAS "reports the line-level basis" 'last touched the staged lines'
	_ST_EQ "folded into the line's owner" "$(git log --format=%s -S 'BL-A EDITED' | head -1)" "BL add A"
	_ST_EQ "later commit left alone" "$(git log --format=%s -1)" "BL refine B"
	# Lines owned by two different commits – refuse rather than pick one
	printf 'bl1\nBL-A TWICE\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B TWICE\n' > bl.txt
	git add bl.txt
	_ST_RUN --amend-into=auto
	_ST_EQ "split line ownership refused" "$RC" "1"
	_ST_OUT_HAS "names the competing commits" 'different commits'
	git reset -q --hard HEAD

	# --- 29. non-interactive edit mode: pause, author, continue ---
	_ST_SCENARIO "\e[1;96m[29] edit mode (agent flow)\e[0m"
	# Reconcile the scratch checkout so later commits carry no phantom reverts
	git reset -q --hard
	printf 'e1\nEDIT-ME\ne2\n' > ed.txt && git add ed.txt && git commit -qm "ED target"
	local ED_TARGET=$(git rev-parse HEAD)
	echo "ed-later" > ed2.txt && git add ed2.txt && git commit -qm "ED later"
	local ED_TIP=$(git rev-parse HEAD)
	_ST_RUN "$ED_TARGET"
	_ST_EQ "edit pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "emits a paused trailer" 'git-edit: paused'
	_ST_EQ "branch untouched while authoring" "$(git rev-parse HEAD)" "$ED_TIP"
	local ED_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \(.*\); then.*/\1/p')
	_ST_CHECK "worktree sits at the target" test "$(git -C "$ED_WT" rev-parse HEAD)" = "$ED_TARGET"
	_ST_RUN --status
	_ST_OUT_HAS "status names the authoring phase" 'Authoring phase'
	_ST_RUN --continue
	_ST_EQ "empty continue refused" "$RC" "1"
	_ST_OUT_HAS "explains nothing to amend" 'Nothing to amend'
	printf 'e1\nEDITED\ne2\n' > "${ED_WT:-$ST_NO_WT}/ed.txt"
	# A commit landing on the branch during authoring must be absorbed
	echo "mid" > ed-mid.txt && git add ed-mid.txt && git commit -qm "ED mid-pause"
	_ST_RUN --continue --text "ED target, edited"
	_ST_EQ "continue completes the edit" "$RC" "0"
	_ST_OUT_HAS "prints the net history change" 'Net history change'
	local ED_NEW=$(git log --format='%H %s' | grep 'ED target, edited' | cut -d' ' -f1)
	_ST_CHECK "reword applied" test -n "$ED_NEW"
	_ST_EQ "content edited at the target" "$(git show "${ED_NEW}:ed.txt" 2>/dev/null | sed -n 2p)" "EDITED"
	_ST_CHECK "mid-pause commit absorbed" sh -c "git log --format=%s | grep -q 'ED mid-pause'"
	_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	# Abort leaves everything untouched
	git reset -q --hard
	local ED_TIP2=$(git rev-parse HEAD)
	_ST_RUN "$(git rev-parse HEAD~1)"
	_ST_RUN --abort
	_ST_EQ "abort exits 0" "$RC" "0"
	_ST_EQ "abort leaves the branch untouched" "$(git rev-parse HEAD)" "$ED_TIP2"

	# --- 30. content split: pause, author the split point, continue ---
	_ST_SCENARIO "\e[1;96m[30] content split (same-file halves)\e[0m"
	git reset -q --hard
	printf 'first\nsecond\n' > cs.txt && git add cs.txt && git commit -qm "CS base"
	printf 'FIRST\nsecond\nthird\n' > cs.txt && git add cs.txt && git commit -qm "CS mixed commit"
	local CS_TARGET=$(git rev-parse HEAD)
	echo "cs-later" > cs2.txt && git add cs2.txt && git commit -qm "CS later"
	local CS_TIP=$(git rev-parse HEAD)
	local CS_TIP_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN --split="$CS_TARGET"
	_ST_EQ "pathspec-less split pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "emits a paused trailer" 'git-edit: paused – split'
	_ST_EQ "branch untouched while authoring" "$(git rev-parse HEAD)" "$CS_TIP"
	local CS_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – split [0-9a-f]* in \(.*\); then.*/\1/p')
	_ST_CHECK "worktree sits at the target" test "$(git -C "$CS_WT" rev-parse HEAD)" = "$CS_TARGET"
	_ST_RUN --status
	_ST_OUT_HAS "status names the authoring phase" 'Authoring phase'
	_ST_OUT_HAS "status reports it as paused, not conflicted" 'git-edit: paused – split'
	_ST_RUN --continue
	_ST_EQ "continue without a message refused" "$RC" "1"
	_ST_OUT_HAS "asks for --text" 'needs a message'
	_ST_RUN --continue --text "CS extracted"
	_ST_EQ "unedited worktree refused" "$RC" "1"
	_ST_OUT_HAS "names the empty remainder" 'remainder commit would be empty'
	echo "debris" > "${CS_WT:-$ST_NO_WT}/cs-stray.txt"
	_ST_RUN --continue --text "CS extracted"
	_ST_EQ "stray path refused" "$RC" "1"
	_ST_OUT_HAS "names the stray path" 'cs-stray.txt'
	rm -f "$CS_WT/cs-stray.txt"
	printf 'first\nsecond\n' > "${CS_WT:-$ST_NO_WT}/cs.txt"
	_ST_RUN --continue --text "CS extracted"
	_ST_EQ "worktree back at the parent refused" "$RC" "1"
	_ST_OUT_HAS "names the empty extraction" 'extracted commit would be empty'
	# The real split point: the uppercase half only, third line left for the remainder
	printf 'FIRST\nsecond\n' > "${CS_WT:-$ST_NO_WT}/cs.txt"
	# A commit landing on the branch during authoring must be absorbed
	echo "cs-mid" > cs-mid.txt && git add cs-mid.txt && git commit -qm "CS mid-pause"
	# Run the final continue from inside the worktree – its detached `HEAD` must
	# not stand in for the branch as the trailer's "before"
	local CS_PRE=$(git rev-parse HEAD)
	OUT=$(cd "$CS_WT" && GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue --text "CS extracted" </dev/null 2>&1)
	RC=$?
	_ST_EQ "continue completes the split" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree identical'
	_ST_OUT_HAS "trailer anchors on the branch, not the worktree HEAD" "moved $CS_PRE"
	# The resumed path reaches the same summary as the pathspec one
	_ST_EQ "names the commit it split within a 'tail -3'" \
		"$(print -r -- "$OUT" | tail -3 | grep -c 'split: ')" "1"
	_ST_CHECK "mid-pause commit absorbed" sh -c "git log --format=%s | grep -q 'CS mid-pause'"
	local CS_KEPT=$(git log --format='%H %s' | grep 'CS mixed commit' | cut -d' ' -f1)
	_ST_EQ "extracted commit sits below the remainder" "$(git log --format=%s -1 "$CS_KEPT^")" "CS extracted"
	_ST_EQ "extracted carries only the first half" "$(git show "$CS_KEPT^:cs.txt")" "$(printf 'FIRST\nsecond')"
	_ST_EQ "remainder carries the rest" "$(git show "${CS_KEPT}:cs.txt")" "$(printf 'FIRST\nsecond\nthird')"
	_ST_CHECK "descendants rebuilt" git cat-file -e 'HEAD:cs2.txt'
	_ST_CHECK "worktree cleaned up" test ! -d "$CS_WT"
	_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	# The tip tree is only unchanged relative to the pre-split tip, so compare
	# against the commit that was `HEAD` before the mid-pause commit landed
	_ST_EQ "pre-split tip tree preserved" "$(git rev-parse 'HEAD~1^{tree}')" "$CS_TIP_TREE"

	# --- 31. argument mistakes name the right form instead of dead-ending ---
	_ST_SCENARIO "\e[1;96m[31] argument-error guidance\e[0m"
	_ST_RUN -M "Some prose that is a message, not a commit"
	_ST_EQ "prose in the <commit> slot refused" "$RC" "1"
	_ST_OUT_HAS "points at --text" 'pass it as --text'
	_ST_RUN -M --text="Some subject"
	_ST_EQ "missing commit refused" "$RC" "1"
	_ST_OUT_HAS "names the missing argument" 'Missing <commit>'
	# The retry is always a bare `HEAD`, so the error has to show what that is
	_ST_OUT_HAS "and says what HEAD currently is" 'HEAD is currently'
	_ST_OUT_HAS "with its subject, not just a sha" \
		"HEAD is currently [0-9a-f]\{7\} ."
	_ST_RUN --amend-into=HEAD -M
	_ST_EQ "--amend-into + -M refused" "$RC" "1"
	_ST_OUT_HAS "points at the reword form" 'To reword only'
	_ST_RUN
	_ST_EQ "bare invocation still exits 1" "$RC" "1"
	_ST_OUT_HAS "bare invocation still shows usage" 'usage: git edit'

	# --- 32. scoped fold: a pathspec keeps the rest of the index out ---
	_ST_SCENARIO "\e[1;96m[32] scoped --amend-into\e[0m"
	git reset -q --hard
	echo "sc1" > sc.txt && echo "other" > sc-other.txt && git add sc.txt sc-other.txt && git commit -qm "SC base"
	local SC_TARGET=$(git rev-parse HEAD)
	echo "sc-later" > sc-later.txt && git add sc-later.txt && git commit -qm "SC later"
	echo "sc1-folded" > sc.txt && git add sc.txt
	echo "sc-other-parallel" > sc-other.txt && git add sc-other.txt   # a parallel session's staging
	_ST_RUN --amend-into="$SC_TARGET" -- sc.txt
	_ST_EQ "scoped fold exits 0" "$RC" "0"
	_ST_OUT_HAS "reports what stayed staged" 'outside the pathspec'
	# A count can't say whose leftovers these are, so the caller has to guess
	_ST_OUT_HAS "names the leftover path" 'outside the pathspec.*sc-other\.txt'
	# Agents overwhelmingly read this through `| tail -N`, so the summary has
	# to survive the truncation rather than be padded out of reach
	_ST_EQ "non-TTY output carries no blank lines" "$(echo "$OUT" | grep -c '^$')" "0"
	_ST_EQ "summary survives a tail -5" "$(echo "$OUT" | tail -5 | grep -c 'outside the pathspec')" "1"
	local SC_NEW=$(git log --format='%H %s' | grep 'SC base' | cut -d' ' -f1)
	_ST_EQ "pathspec change folded" "$(git show "${SC_NEW}:sc.txt")" "sc1-folded"
	_ST_EQ "out-of-pathspec change NOT folded" "$(git show "${SC_NEW}:sc-other.txt")" "other"
	_ST_CHECK "out-of-pathspec change still staged" sh -c "git diff --cached --name-only | grep -q sc-other.txt"
	_ST_CHECK "history never saw it" sh -c "! git log -p --all | grep -q sc-other-parallel"
	_ST_RUN --amend-into="$SC_NEW" -- nosuch.txt
	_ST_EQ "empty pathspec match refused" "$RC" "1"
	_ST_OUT_HAS "names the empty match" 'No staged changes under'
	git reset -q --hard
	# --- 33. a reorder step resolved to empty must not vanish under an `ok` ---
	_ST_SCENARIO "\e[1;96m[33] dropped-commit reporting\e[0m"
	git reset -q --hard
	printf 'd1\nd2\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR base"
	printf 'd1\nDX\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR one"
	printf 'd1\nDY\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR two"
	local DR_TIP=$(git rev-parse HEAD)
	_ST_RUN --reorder "$DR_TIP" "$(git rev-parse HEAD~1)"
	_ST_EQ "reordering abutting edits conflicts" "$RC" "2"
	local DR_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	printf 'd1\nDY\nd3\n' > "${DR_WT:-$ST_NO_WT}/dr.txt" && git -C "$DR_WT" add dr.txt
	# The final step restores the pre-op blobs by itself, which leaves the
	# replayed commit empty and the rebase drops it
	_ST_RUN --continue
	_ST_EQ "resolution completes in one continue" "$RC" "0"
	_ST_OUT_HAS "continue path prints the new order too" 'new order (oldest-first)'
	_ST_OUT_HAS "reports the dropped commit" 'resolved to empty and were dropped'
	_ST_OUT_HAS "and names it" 'dropped: .*DR one'
	_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	git reset -q --hard

	# The dissolution workflow rests on the same drop staying silent at the
	# rebase: an edit that reproduces a later commit's change empties the husk,
	# the replay drops it without a pause, and the summary names it
	printf 'h1\n' > hk.txt && git add hk.txt && git commit -qm "HK origin"
	printf 'h1\nh2\n' > hk.txt && git add hk.txt && git commit -qm "HK husk"
	local HK_COUNT=$(git rev-list --count HEAD)
	_ST_RUN "$(git rev-parse HEAD~1)"
	local HK_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	printf 'h1\nh2\n' > "${HK_WT:-$ST_NO_WT}/hk.txt"
	_ST_RUN --continue
	_ST_EQ "the dissolution applies without a pause" "$RC" "0"
	_ST_OUT_HAS "the emptied husk is counted" 'resolved to empty and were dropped'
	_ST_OUT_HAS "and named" 'dropped: .*HK husk'
	_ST_OUT_HAS "with the tip tree proven untouched" 'Tip tree identical'
	_ST_EQ "the husk is gone from history" "$(git rev-list --count HEAD)" "$((HK_COUNT - 1))"
	_ST_EQ "and the identity line stays within a 'tail -3'" \
		"$(echo "$OUT" | tail -3 | grep -c 'edited: ')" "1"
	git reset -q --hard

	# Duplicate subjects cancel by count, so the husk is named and its twin is not
	printf 'p1\n' > dp.txt && git add dp.txt && git commit -qm "DP origin"
	printf 'p1\np2\n' > dp.txt && git add dp.txt && git commit -qm "DP twin"
	printf 'p1\np2\np3\n' > dp.txt && git add dp.txt && git commit -qm "DP twin"
	local DP_HUSK=$(git rev-parse --short HEAD~1)
	_ST_RUN "$(git rev-parse HEAD~2)"
	local DP_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	printf 'p1\np2\n' > "${DP_WT:-$ST_NO_WT}/dp.txt"
	_ST_RUN --continue
	_ST_EQ "the twin-subject dissolution applies" "$RC" "0"
	_ST_EQ "exactly one commit is named" "$(print -r -- "$OUT" | grep -c 'dropped: ')" "1"
	_ST_OUT_HAS "and it is the husk, not its surviving twin" "dropped: $DP_HUSK"
	_ST_EQ "the surviving twin kept its content" "$(git show HEAD:dp.txt | tail -1)" "p3"
	git reset -q --hard

	# A reword in the same run leaves a subject with no counterpart – that is no
	# drop, so the naming stands down while the count stays
	printf 'r1\n' > rw.txt && git add rw.txt && git commit -qm "RW origin"
	printf 'r1\nr2\n' > rw.txt && git add rw.txt && git commit -qm "RW husk"
	_ST_RUN "$(git rev-parse HEAD~1)"
	local RW_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	printf 'r1\nr2\n' > "${RW_WT:-$ST_NO_WT}/rw.txt"
	_ST_RUN --continue --text "RW origin reworded"
	_ST_EQ "the reworded dissolution applies" "$RC" "0"
	_ST_OUT_HAS "the drop is still counted" 'resolved to empty and were dropped'
	_ST_OUT_LACKS "but nothing is named on ambiguous subjects" 'dropped: '
	git reset -q --hard

	# Subjects are shell text, and this repo's own are full of backticks – an
	# arithmetic subscript would execute them while counting
	printf 'b1\n' > bt.txt && git add bt.txt && git commit -qm 'BT origin'
	printf 'b1\nb2\n' > bt.txt && git add bt.txt && git commit -qm 'BT `rules` husk $(echo PWNED)'
	_ST_RUN "$(git rev-parse HEAD~1)"
	local BT_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	printf 'b1\nb2\n' > "${BT_WT:-$ST_NO_WT}/bt.txt"
	_ST_RUN --continue
	_ST_EQ "a backticked subject dissolves cleanly" "$RC" "0"
	_ST_OUT_HAS "and is named verbatim" 'dropped: .*BT `rules` husk'
	_ST_OUT_HAS "with its substitution text intact, not executed" '(echo PWNED)'
	git reset -q --hard

	# --- 34. a staged resolution with conflict markers must not continue ---
	_ST_SCENARIO "\e[1;96m[34] conflict-marker guard\e[0m"
	git reset -q --hard
	printf 'm1\nm2\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK base"
	printf 'm1\nMT\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK target"
	local MK_TARGET=$(git rev-parse HEAD)
	printf 'm1\nML\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK later"
	printf 'm1\nMS\nm3\n' > mk.txt && git add mk.txt
	_ST_RUN --amend-into="$MK_TARGET"
	_ST_EQ "fold conflicts as set up" "$RC" "2"
	local MK_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	_ST_CHECK "worktree file carries markers" sh -c "grep -q '^<<<<<<<' '$MK_WT/mk.txt'"
	# The mistake this guards: a failed resolver, then a blanket `git add`
	git -C "$MK_WT" add mk.txt
	_ST_RUN --continue
	_ST_EQ "continue refused (exit 2)" "$RC" "2"
	_ST_OUT_HAS "names the marker problem" 'still contains conflict markers'
	_ST_CHECK "markers never reached history" sh -c "! git log -p --all | grep -q '^+<<<<<<< '"
	# A marker-free resolution is not blocked
	printf 'm1\nMS\nm3\n' > "${MK_WT:-$ST_NO_WT}/mk.txt" && git -C "$MK_WT" add mk.txt
	_ST_RUN --continue
	_ST_OUT_LACKS "clean resolution passes the guard" 'still contains conflict markers'
	_ST_RUN --abort
	_ST_CHECK "state cleared afterwards" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	git reset -q --hard

	# --- 35. the final-step auto-resolve must refuse when it can't prove itself ---
	_ST_SCENARIO "\e[1;96m[35] auto-resolve proof\e[0m"
	git reset -q --hard
	printf 'p1\n' > pa.txt && printf 'q1\n' > pb.txt && git add pa.txt pb.txt && git commit -qm "PR base"
	printf 'p1\npA\n' > pa.txt && git add pa.txt && git commit -qm "PR A"
	local PR_A=$(git rev-parse HEAD)
	printf 'p1\npB\npA\n' > pa.txt && git add pa.txt && git commit -qm "PR B"
	local PR_B=$(git rev-parse HEAD)
	_ST_RUN --move="$PR_A" --after="$PR_B"
	_ST_EQ "abutting swap conflicts" "$RC" "2"
	local PR_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	# Resolve step 1, but also touch a file neither commit changes – the final
	# step's pre-op blobs then cannot reproduce the pre-op tree, so the proof
	# fails and it must hand back rather than apply a resolution it can't verify
	printf 'p1\npB\n' > "${PR_WT:-$ST_NO_WT}/pa.txt"
	printf 'STRAY\n' > "${PR_WT:-$ST_NO_WT}/pb.txt"
	git -C "$PR_WT" add pa.txt pb.txt
	_ST_RUN --continue
	_ST_EQ "unprovable final step still pauses" "$RC" "2"
	_ST_OUT_LACKS "never claims an unproven auto-resolve" 'auto-resolved'
	_ST_RUN --abort
	_ST_CHECK "abort leaves no state" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	git reset -q --hard

	# --- 36. reporting must survive the shapes that break naive derivation ---
	_ST_SCENARIO "\e[1;96m[36] reporting under merges + scoped conflicts\e[0m"
	git reset -q --hard
	# (a) a merge in the reword span: commit count includes the side branch,
	# but `~N` walks first parents – deriving the commit by offset misses
	echo "rw1" > rw.txt && git add rw.txt && git commit -qm "RW target"
	local RW_TARGET=$(git rev-parse HEAD)
	git checkout -q -b rw-side "$RW_TARGET~1"
	echo "rwside" > rw-side.txt && git add rw-side.txt && git commit -qm "RW side"
	git checkout -q main
	git merge -q --no-ff rw-side -m "RW merge" >/dev/null 2>&1
	_ST_RUN -M --text="RW reworded" "$RW_TARGET"
	_ST_EQ "reword across a merge succeeds" "$RC" "0"
	_ST_OUT_HAS "echo names the reworded commit, not its parent" '[0-9a-f]\{7\} RW reworded'
	_ST_OUT_LACKS "result line does not name the wrong commit" '[0-9a-f]\{7\} RW target'
	_ST_CHECK "merge topology preserved" sh -c "test \$(git log --format=%P -1 HEAD | wc -w) -eq 2"
	git branch -q -D rw-side 2>/dev/null
	# (b) a scoped fold that conflicts: the scope must survive --continue, or
	# its intended leftovers get reported as an anomaly
	git reset -q --hard
	printf 'sc1\nsc2\nsc3\n' > sf.txt && printf 'keep\n' > sf-other.txt
	git add sf.txt sf-other.txt && git commit -qm "SF base"
	printf 'sc1\nSFT\nsc3\n' > sf.txt && git add sf.txt && git commit -qm "SF target"
	local SF_TARGET=$(git rev-parse HEAD)
	printf 'sc1\nSFL\nsc3\n' > sf.txt && git add sf.txt && git commit -qm "SF later"
	printf 'sc1\nSFS\nsc3\n' > sf.txt && git add sf.txt
	printf 'parallel\n' > sf-other.txt && git add sf-other.txt
	_ST_RUN --amend-into="$SF_TARGET" -- sf.txt
	_ST_EQ "scoped fold conflicts as set up" "$RC" "2"
	local SF_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	_ST_RESOLVE "$SF_WT" sf.txt $'sc1\nSFS\nsc3'
	_ST_RUN --continue
	# The final pick's staged-tree resolution would empty "SF later" – the
	# auto-resolve must decline that and leave the call with the resolver
	_ST_EQ "final step that would empty its commit still pauses" "$RC" "2"
	_ST_OUT_LACKS "and is not auto-resolved" 'auto-resolved'
	_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
	_ST_RESOLVE "$SF_WT" sf.txt $'sc1\nSFL\nsc3'
	_ST_RUN --continue
	_ST_OUT_HAS "scope survives the conflict pause" 'outside the pathspec'
	_ST_OUT_LACKS "no bogus not-folded warning" 'not folded'
	_ST_CHECK "out-of-scope file never folded" sh -c "test \"\$(git show \$(git log --format='%H %s' | grep 'SF target' | cut -d' ' -f1):sf-other.txt)\" = keep"
	git reset -q --hard

	# --- 37. edit mode must report the stale checkout it leaves behind ---
	_ST_SCENARIO "\e[1;96m[37] edit-mode checkout staleness\e[0m"
	git reset -q --hard
	printf 'ed1\nSTALE-ME\ned3\n' > stale.js && git add stale.js && git commit -qm "STALE target"
	local STALE_T=$(git rev-parse HEAD)
	echo "stale-later" > stale-later.txt && git add stale-later.txt && git commit -qm "STALE later" >/dev/null 2>&1
	_ST_EQ "target has a descendant to replay" "$(git rev-list --count ${STALE_T}..HEAD)" "1"
	_ST_RUN "$STALE_T"
	local STALE_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \(.*\); then.*/\1/p')
	printf 'ed1\nEDITED\ned3\n' > "${STALE_WT:-$ST_NO_WT}/stale.js"
	_ST_RUN --continue
	_ST_EQ "edit applies" "$RC" "0"
	# The trap: content was authored in the isolated worktree, so the main
	# checkout still has the old file – and staged as a revert of the edit
	_ST_CHECK "checkout really is stale" sh -c "test \"\$(sed -n 2p stale.js)\" = STALE-ME"
	_ST_OUT_HAS "warns the checkout is stale" 'still holds the pre-edit content'
	_ST_OUT_HAS "names the stale path" 'stale\.js'
	git restore --source=HEAD --staged --worktree -- stale.js
	_ST_CHECK "the printed reconcile fixes it" sh -c "test \"\$(sed -n 2p stale.js)\" = EDITED"
	_ST_CHECK "and clears the staged revert" sh -c "git diff --cached --quiet -- stale.js"
	# A message-only edit changes no content, so it must not cry wolf
	_ST_RUN "$(git rev-parse HEAD)"
	_ST_RUN --continue --text "STALE later, reworded"
	_ST_OUT_LACKS "no stale hint when content is unchanged" 'still holds the pre-edit content'
	git reset -q --hard

	# --- 38. a tree-changing rewrite reconciles per path, never by stashing ---
	_ST_SCENARIO "\e[1;96m[38] targeted checkout reconcile\e[0m"
	git reset -q --hard
	echo "tc-keep" > tc-keep.txt && git add tc-keep.txt && git commit -qm "TC base"
	echo "tc-drop" > tc-drop.txt && git add tc-drop.txt && git commit -qm "TC to drop"
	local TC_DROP=$(git rev-parse HEAD)
	echo "tc-later" > tc-later.txt && git add tc-later.txt && git commit -qm "TC later"
	echo "local wip" > tc-keep.txt   # unrelated WIP the advice must not disturb
	_ST_RUN -d -y "$TC_DROP"
	_ST_EQ "drop exits 0" "$RC" "0"
	_ST_OUT_HAS "names the dropped path" 'tc-drop\.txt'
	_ST_OUT_HAS "prescribes a targeted restore" 'restore --source=HEAD --staged --worktree'
	_ST_OUT_LACKS "never prescribes stashing a shared checkout" 'git stash push'
	_ST_OUT_LACKS "never prescribes a blanket reset" 'run git reset --hard'
	# A drop's leftover paths are exactly the dropped work, so the restore has to read as
	# an opt-in discard – calling it a reconcile invites destroying what was kept
	_ST_OUT_HAS "frames the leftovers as uncommitted work" 'dropped content is now uncommitted'
	_ST_OUT_HAS "offers the discard as a choice" 'Keep it, or discard those paths'
	_ST_OUT_LACKS "never calls a drop a reconcile" 'Reconcile those paths'
	git restore --source=HEAD --staged --worktree -- tc-drop.txt
	_ST_CHECK "and that discard does remove the file" sh -c "! test -f tc-drop.txt"
	_ST_EQ "unrelated WIP untouched" "$(cat tc-keep.txt)" "local wip"
	git reset -q --hard
	# A path with a space must come out shell-quoted, or the printed command
	# parses as several pathspecs and matches none of them
	echo "tc-b2" > tc-b2.txt && git add tc-b2.txt && git commit -qm "TC base2"
	mkdir -p "tc dir" && echo "spaced" > "tc dir/tc file.txt"
	git add "tc dir/tc file.txt" && git commit -qm "TC spaced drop"
	local TC_SP=$(git rev-parse HEAD)
	echo "tc-after" > tc-after.txt && git add tc-after.txt && git commit -qm "TC after"
	_ST_RUN -d -y "$TC_SP"
	_ST_EQ "drop with a spaced path exits 0" "$RC" "0"
	_ST_OUT_HAS "shell-quotes the spaced path" "restore.*'tc dir/tc file.txt'"
	git reset -q --hard

	# --- 39. --exec names the branch it moved, and reaches the reconcile hint ---
	_ST_SCENARIO "\e[1;96m[39] exec reports the branch it rewrote\e[0m"
	git reset -q --hard
	echo "xa" > xa.txt && git add xa.txt && git commit -qm "XA base"
	echo "xb" > xb.txt && git add xb.txt && git commit -qm "XB to reword"
	_ST_RUN --exec -- git commit --amend -m "XB reworded by exec"
	_ST_EQ "exec exits 0" "$RC" "0"
	_ST_EQ "the reword landed" "$(git log -1 --format=%s)" "XB reworded by exec"
	# A multi-arg `[ -n ... ]` here made every branch exec claim a detached `HEAD`,
	# and leaked the shell's own usage error into the output
	_ST_OUT_LACKS "no raw shell error leaks" 'too many arguments'
	_ST_OUT_LACKS "does not claim a detached HEAD" 'Detached HEAD updated'
	_ST_OUT_HAS "names the branch it rewrote" 'Branch.*rewritten'
	# Only a content-changing exec reaches the per-path hint
	echo "xc" > xc.txt && git add xc.txt && git commit -qm "XC to change"
	_ST_RUN --exec -- sh -c 'echo changed > xc.txt && git add xc.txt && git commit -q --amend --no-edit'
	_ST_EQ "content-changing exec exits 0" "$RC" "0"
	_ST_OUT_HAS "names the path to reconcile" 'xc\.txt'
	_ST_OUT_HAS "prescribes a targeted restore" 'restore --source=HEAD --staged --worktree'
	git reset -q --hard

	# --- 40. a continue names the untracked files it absorbs ---
	_ST_SCENARIO "\e[1;96m[40] untracked absorption is named\e[0m"
	git reset -q --hard
	echo "ua" > ua.txt && git add ua.txt && git commit -qm "UA base"
	echo "ub" > ub.txt && git add ub.txt && git commit -qm "UB target"
	local UA_TGT=$(git rev-parse HEAD)
	echo "uc" > uc.txt && git add uc.txt && git commit -qm "UC later"
	_ST_RUN "$UA_TGT"
	local UA_WT=$(echo "$OUT" | sed $'s/\e\\[[0-9;]*m//g' | grep -oE '/[^ ]*git-edit-edit\.[A-Za-z0-9]+' | head -1)
	echo "edited" >> "${UA_WT:-$ST_NO_WT}/ub.txt"
	echo "scratch" > "${UA_WT:-$ST_NO_WT}/ua-stray.txt"
	_ST_RUN --continue
	_ST_EQ "continue exits 0" "$RC" "0"
	_ST_OUT_HAS "names untracked files it absorbs" 'Absorbing.*untracked file'
	_ST_OUT_HAS "names the stray itself" 'ua-stray\.txt'
	_ST_CHECK "the stray really did land in the commit" \
		sh -c "git show --stat --format= HEAD~1 | grep -q ua-stray"
	git reset -q --hard
	# An edit touching only tracked files must not cry wolf
	echo "ud" > ud.txt && git add ud.txt && git commit -qm "UD target"
	_ST_RUN "$(git rev-parse HEAD)"
	local UA_WT2=$(echo "$OUT" | sed $'s/\e\\[[0-9;]*m//g' | grep -oE '/[^ ]*git-edit-edit\.[A-Za-z0-9]+' | head -1)
	echo "edited" >> "${UA_WT2:-$ST_NO_WT}/ud.txt"
	_ST_RUN --continue
	_ST_EQ "clean continue exits 0" "$RC" "0"
	_ST_OUT_LACKS "silent when nothing untracked is absorbed" 'Absorbing'
	git reset -q --hard

	# --- 41. a conflict resolution is recorded for rerere to replay ---
	_ST_SCENARIO "\e[1;96m[41] conflict resolutions reach rr-cache\e[0m"
	git reset -q --hard
	# Pinned: with rerere.enabled explicitly false the records are forgotten
	# at completion by design (scenario 58) – this scenario asserts the
	# recording machinery, so it must not inherit a machine's global opt-out
	git config rerere.enabled true
	local RR_DIR="$(git rev-parse --git-common-dir)/rr-cache"
	local RR_BEFORE=$(ls "$RR_DIR" 2>/dev/null | wc -l | tr -d ' ')
	printf 'rr line A\n' > rr.txt && git add rr.txt && git commit -qm "RR base"
	printf 'rr line B\n' > rr.txt && git add rr.txt && git commit -qm "RR middle"
	local RR_MID=$(git rev-parse HEAD)
	printf 'rr line C\n' > rr.txt && git add rr.txt && git commit -qm "RR top"
	_ST_RUN -d -y "$RR_MID"
	_ST_EQ "the drop conflicts as set up" "$RC" "2"
	_ST_OUT_LACKS "a marker conflict gets no marker-free flag" 'No conflict markers'
	local RR_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	if [ -n "$RR_WT" ] && [ -d "$RR_WT" ]; then
		printf 'rr line C\n' > "${RR_WT:-$ST_NO_WT}/rr.txt"
		git -C "$RR_WT" add rr.txt
		_ST_RUN --continue
		_ST_EQ "resolved drop completes" "$RC" "0"
	fi
	# The rebase start must carry `-c rerere.enabled=true`, not just `--continue`:
	# rerere stores the preimage when the conflict occurs, so enabling it only at
	# resolution time records nothing and a re-conflict can't replay the answer
	local RR_AFTER=$(ls "$RR_DIR" 2>/dev/null | wc -l | tr -d ' ')
	_ST_CHECK "the resolution was recorded for replay" sh -c "[ $RR_AFTER -gt $RR_BEFORE ]"
	git reset -q --hard
	# Edit mode records too – its conflict comes from replaying the descendants
	local RR_BEFORE_E=$(ls "$RR_DIR" 2>/dev/null | wc -l | tr -d ' ')
	printf 'ed line A\n' > ed.txt && git add ed.txt && git commit -qm "ED base"
	local ED_TARGET=$(git rev-parse HEAD)
	printf 'ed line B\n' > ed.txt && git add ed.txt && git commit -qm "ED later"
	_ST_RUN "$ED_TARGET"
	local ED_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [^ ]* in \([^;]*\);.*/\1/p' | head -1)
	if [ -n "$ED_WT" ] && [ -d "$ED_WT" ]; then
		printf 'ed line EDITED\n' > "${ED_WT:-$ST_NO_WT}/ed.txt"
		_ST_RUN --continue
		local ED_CWT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
		if [ -n "$ED_CWT" ] && [ -d "$ED_CWT" ]; then
			printf 'ed line B\n' > "${ED_CWT:-$ST_NO_WT}/ed.txt"
			git -C "$ED_CWT" add ed.txt
			_ST_RUN --continue
		fi
	fi
	_ST_CHECK "edit mode records its resolution too" \
		sh -c "[ $(ls "$RR_DIR" 2>/dev/null | wc -l | tr -d ' ') -gt $RR_BEFORE_E ]"
	git config --unset rerere.enabled
	git reset -q --hard
	# Structural, so a start that loses the flag is caught even where no scenario drives that
	# mode into a conflict – anchored to the start of a line, or the patterns would count the
	# assertion lines that carry them
	_ST_CHECK "every conflict-capable rebase start carries rerere" \
		sh -c "[ \$(grep -cE '^[[:space:]]*local CMD=\\(-c rerere.enabled=true rebase' '$SELF') -eq 6 ]"
	_ST_CHECK "and none was left without it" \
		sh -c "! grep -qE '^[[:space:]]*local CMD=\\(rebase' '$SELF'"

	# --- 42. a CAS refusal keeps the resolution instead of deleting it ---
	_ST_SCENARIO "\e[1;96m[42] CAS refusal preserves the worktree\e[0m"
	git reset -q --hard
	printf 'cas one\ncas two\n' > cas.txt && git add cas.txt && git commit -qm "CAS base"
	local CAS_TARGET=$(git rev-parse HEAD)
	printf 'cas one\ncas CHANGED\n' > cas.txt && git add cas.txt && git commit -qm "CAS later"
	printf 'cas one\ncas FOLDED\n' > cas.txt && git add cas.txt
	_ST_RUN --amend-into="$CAS_TARGET" -- cas.txt
	_ST_EQ "the fold conflicts" "$RC" "2"
	local CAS_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	# A parallel session lands a commit while the resolution is being worked out
	printf 'other work\n' > other.txt && git add other.txt && git commit -qm "CAS parallel commit"
	# The fold cascades onto the later commit, so resolve until it stops asking
	local CAS_ROUNDS=0
	while [ "$RC" = "2" ] && [ $CAS_ROUNDS -lt 4 ]; do
		CAS_ROUNDS=$((CAS_ROUNDS+1))
		local CAS_WT_NOW=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
		if [ -z "$CAS_WT_NOW" ] || [ ! -d "$CAS_WT_NOW" ]; then
			break
		fi
		CAS_WT=$CAS_WT_NOW
		_ST_RESOLVE "$CAS_WT" cas.txt $'cas one\ncas RESOLVED'
		_ST_RUN --continue
	done
	_ST_EQ "the CAS refuses the write" "$RC" "1"
	_ST_OUT_HAS "says the branch moved" 'moved during resolution'
	# A refusal must not fire the exit trap, which would delete the one copy of the work and
	# leave a state whose worktree is gone
	_ST_CHECK "the worktree survives the refusal" sh -c "[ -d '$CAS_WT' ]"
	_ST_CHECK "and still holds the resolution" sh -c "grep -q 'cas FOLDED' '$CAS_WT/cas.txt' && git -C '$CAS_WT' show 'HEAD~1:cas.txt' | grep -q 'cas RESOLVED'"
	_ST_OUT_HAS "points at the surviving worktree" 'resolution is intact'
	_ST_RUN --status
	_ST_OUT_LACKS "status is not orphaned" 'worktree is gone'
	_ST_CHECK "the parallel commit was not clobbered" \
		sh -c "git log --format=%s | grep -qx 'CAS parallel commit'"
	# Plumbing modes touch no worktree, so they once slipped the in-flight guard
	# and moved the branch under the paused operation
	_ST_RUN -M --text="sneaks past" HEAD
	_ST_EQ "a reword is refused while paused" "$RC" "1"
	_ST_OUT_HAS "and says why" 'operation is in flight'
	_ST_CHECK "the branch did not move" sh -c "git log -1 --format=%s | grep -qx 'CAS parallel commit'"
	_ST_RUN --amend-into=auto
	_ST_EQ "a fold is refused too" "$RC" "1"
	_ST_RUN --abort
	_ST_EQ "abort clears the operation" "$RC" "0"
	_ST_CHECK "and removes the worktree" sh -c "[ ! -d '$CAS_WT' ]"
	# ...and the guard lifts once nothing is in flight
	_ST_RUN -M --text="Reworded after abort" HEAD
	_ST_EQ "reword works again afterwards" "$RC" "0"
	git reset -q --hard

	# --- 43. the orphan sweep takes debris and nothing else ---
	_ST_SCENARIO "\e[1;96m[43] orphan worktree sweep\e[0m"
	git reset -q --hard
	local GCBASE=${TMPDIR:-/tmp}
	GCBASE=${GCBASE%/}
	# Provable debris: pointer dangles, and it has sat around for a day
	local GC_DEAD="$GCBASE/git-edit-gctest-dead.$$"
	mkdir -p "$GC_DEAD" && echo "gitdir: /nonexistent/repo/.git/worktrees/x" > "$GC_DEAD/.git"
	touch -t 202601010000 "$GC_DEAD"
	# Same dangling pointer but fresh – could be an operation starting right now
	local GC_FRESH="$GCBASE/git-edit-gctest-fresh.$$"
	mkdir -p "$GC_FRESH" && echo "gitdir: /nonexistent/repo/.git/worktrees/y" > "$GC_FRESH/.git"
	# Old, but its repo is still there – a paused resolution must never be swept
	local GC_LIVE="$GCBASE/git-edit-gctest-live.$$"
	mkdir -p "$GC_LIVE" && echo "gitdir: $(git rev-parse --absolute-git-dir)" > "$GC_LIVE/.git"
	touch -t 202601010000 "$GC_LIVE"
	# Any mutating invocation runs the sweep
	_ST_RUN -M --text="Sweep trigger" HEAD
	_ST_EQ "the run itself succeeds" "$RC" "0"
	_ST_CHECK "orphaned debris is swept" sh -c "[ ! -d '$GC_DEAD' ]"
	_ST_OUT_HAS "and the sweep is reported, never silent" 'Swept.*orphaned temp worktree'
	_ST_CHECK "a fresh one is left alone" sh -c "[ -d '$GC_FRESH' ]"
	_ST_CHECK "a registered worktree is never swept" sh -c "[ -d '$GC_LIVE' ]"
	rm -rf "$GC_FRESH" "$GC_LIVE"
	git reset -q --hard

	# --- 44. marker-free conflicts must still pause, with history intact ---
	_ST_SCENARIO "\e[1;96m[44] marker-free conflicts still pause\e[0m"
	git reset -q --hard
	# Neither of these carries conflict markers, so any attempt to decide a
	# conflict by inspecting the file auto-resolves them the wrong way – which
	# silently reverted a deletion and dropped the commit that made it
	printf 'md one\n' > md2.txt && git add md2.txt && git commit -qm "MD2 base"
	printf 'md two\n' > md2.txt && git add md2.txt && git commit -qm "MD2 middle"
	local MD2_MID=$(git rev-parse HEAD)
	git rm -q md2.txt && git commit -qm "MD2 deletes it"
	_ST_RUN -d -y "$MD2_MID"
	_ST_EQ "modify/delete pauses" "$RC" "2"
	_ST_OUT_HAS "and the marker-free state is flagged" 'No conflict markers in md2.txt'
	_ST_RUN --abort
	_ST_CHECK "its deleting commit survives" sh -c "git log --format=%s | grep -qx 'MD2 deletes it'"
	_ST_CHECK "and the file is still deleted at the tip" \
		sh -c "! git cat-file -e HEAD:md2.txt 2>/dev/null"
	git reset -q --hard
	# Binary: three stages, no markers, and rerere cannot resolve it either
	printf 'bin\000\001 v1\n' > bin.dat && git add bin.dat && git commit -qm "BIN base"
	printf 'bin\000\002 v2\n' > bin.dat && git add bin.dat && git commit -qm "BIN middle"
	local BIN_MID=$(git rev-parse HEAD)
	printf 'bin\000\003 v3\n' > bin.dat && git add bin.dat && git commit -qm "BIN top"
	_ST_CHECK "the fixture really is binary to git" \
		sh -c "git diff --numstat HEAD~1 HEAD -- bin.dat | grep -q '^-'"
	_ST_RUN -d -y "$BIN_MID"
	_ST_EQ "binary conflict pauses" "$RC" "2"
	_ST_OUT_HAS "the binary marker-free state is flagged too" 'No conflict markers in bin.dat'
	_ST_RUN --abort
	_ST_CHECK "no commit was dropped" sh -c "git log --format=%s | grep -qx 'BIN top'"
	git reset -q --hard

	_ST_SCENARIO "\e[1;96m[45] fold and reword in one run\e[0m"
	git reset -q --hard
	printf 'at one\n' > at.txt && git add at.txt && git commit -qm "AT base"
	printf 'at two\n' > at.txt && git add at.txt && git commit -qm "AT target"
	local AT_TARGET=$(git rev-parse HEAD)
	printf 'at three\n' > at-other.txt && git add at-other.txt && git commit -qm "AT descendant"
	printf 'at folded\n' > at.txt && git add at.txt
	_ST_RUN --amend-into="$AT_TARGET" --text='AT reworded by the fold'
	_ST_EQ "the run succeeds" "$RC" "0"
	_ST_OUT_HAS "names the subject it replaced" 'replaced:.*AT target'
	# The capture is a pipe, so this doubles as the check that color is gated
	_ST_OUT_LACKS "captured output carries no color" $'\e\\['
	_ST_CHECK "the message landed" sh -c "git log --format=%s | grep -qx 'AT reworded by the fold'"
	_ST_CHECK "and replaced the old one" sh -c "! git log --format=%s | grep -qx 'AT target'"
	_ST_CHECK "the fold landed in that same commit" \
		sh -c "git show HEAD~1:at.txt | grep -qx 'at folded'"
	_ST_CHECK "the descendant survives" sh -c "git log --format=%s | grep -qx 'AT descendant'"
	_ST_CHECK "nothing is left staged" sh -c "git diff --cached --quiet"
	# Without a message the fold must leave the subject exactly as it was
	git reset -q --hard
	printf 'at plain\n' > at.txt && git add at.txt
	_ST_RUN --amend-into=HEAD~1
	_ST_CHECK "a fold without --text keeps the subject" \
		sh -c "git log --format=%s | grep -qx 'AT reworded by the fold'"
	_ST_OUT_LACKS "and claims no replacement" 'replaced:'
	git reset -q --hard

	# A message is part of the fold's definition – the replay already carries
	# it, so one arriving at --continue has to be refused rather than dropped
	printf 'atc base\n' > atc.txt && git add atc.txt && git commit -qm "ATC base"
	printf 'atc mid\n' > atc.txt && git add atc.txt && git commit -qm "ATC target"
	local ATC_TARGET=$(git rev-parse HEAD)
	printf 'atc top\n' > atc.txt && git add atc.txt && git commit -qm "ATC top"
	printf 'atc folded\n' > atc.txt && git add atc.txt
	_ST_RUN --amend-into="$ATC_TARGET"
	_ST_EQ "a conflicting fold pauses" "$RC" "2"
	_ST_RUN --continue --text='too late'
	_ST_OUT_HAS "--text on --continue is refused, not ignored" 'takes --text up front'
	_ST_RUN --abort
	_ST_CHECK "abort leaves the branch intact" sh -c "git log --format=%s | grep -qx 'ATC top'"
	git reset -q --hard

	# A resolution that empties the replayed commit shortens the chain, so an
	# offset from the new tip names a commit the fold never touched
	printf 'ae base\n' > ae.txt && git add ae.txt && git commit -qm "AE base"
	printf 'ae mid\n' > ae.txt && git add ae.txt && git commit -qm "AE target"
	local AE_TARGET=$(git rev-parse HEAD)
	printf 'ae top\n' > ae.txt && git add ae.txt && git commit -qm "AE top"
	printf 'ae folded\n' > ae.txt && git add ae.txt
	_ST_RUN --amend-into="$AE_TARGET"
	local AE_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	local AE_ROUNDS=0
	while [ -n "$AE_WT" ] && [ -d "$AE_WT" ] && [ $AE_ROUNDS -lt 5 ]; do
		AE_ROUNDS=$((AE_ROUNDS+1))
		printf 'ae folded\n' > "${AE_WT:-$ST_NO_WT}/ae.txt"
		git -C "$AE_WT" add ae.txt
		_ST_RUN --continue
		AE_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	done
	_ST_EQ "the fold settles" "$RC" "0"
	_ST_CHECK "a commit really was dropped as empty" \
		sh -c "! git log --format=%s | grep -qx 'AE top'"
	_ST_OUT_HAS "the summary names the commit folded into" 'amended: .*AE target'
	_ST_OUT_LACKS "not the one below it" 'amended: .*AE base'
	git reset -q --hard

	_ST_SCENARIO "\e[1;96m[46] replanting a branch onto a moved upstream\e[0m"
	git reset -q --hard
	git checkout -q -B onto-main
	printf 'om base\n' > om.txt && git add om.txt && git commit -qm "OM base"
	git checkout -q -b onto-feature
	printf 'of one\n' > of1.txt && git add of1.txt && git commit -qm "OF one"
	printf 'of two\n' > of2.txt && git add of2.txt && git commit -qm "OF two"
	git checkout -q onto-main
	printf 'om next\n' > om2.txt && git add om2.txt && git commit -qm "OM next"
	git checkout -q onto-feature
	_ST_RUN --onto=onto-main
	_ST_EQ "the replant succeeds" "$RC" "0"
	_ST_CHECK "the branch now sits on the upstream tip" \
		sh -c "git merge-base --is-ancestor onto-main onto-feature"
	_ST_CHECK "and still carries its own commits" \
		sh -c "test \$(git rev-list --count onto-main..onto-feature) -eq 2"
	_ST_OUT_HAS "reports what landed" 'Replanted 2 of 2'
	# The branch moved under this checkout and a replant changes its content –
	# left stale, every commit the upstream gained reads as a local deletion
	_ST_CHECK "the checkout came along" sh -c "test -f om2.txt"
	_ST_CHECK "and reports nothing pending" sh -c "git diff --quiet && git diff --cached --quiet"
	_ST_OUT_HAS "which is stated, not left to be discovered" 'Checkout updated'
	_ST_RUN --onto=onto-main
	_ST_OUT_HAS "a second run is a no-op" 'Already on top of'

	# The case the manual flow exists for: a rewrite orphans the fork point,
	# so plain merge-base answers with a far older ancestor and would replay
	# commits the upstream already carries
	git checkout -q onto-main
	_ST_RUN -M --text='OM base, reworded' onto-main~1
	git checkout -q -B onto-orphan onto-feature
	_ST_CHECK "the fork point really is orphaned" \
		sh -c "! git merge-base --is-ancestor \$(git rev-parse onto-orphan~2) onto-main"
	_ST_RUN --onto=onto-main
	_ST_EQ "the orphaned replant succeeds" "$RC" "0"
	_ST_OUT_HAS "and says the fork was recovered" 'orphaned by a rewrite'
	_ST_OUT_LACKS "without claiming it guessed" 'could not answer'
	_ST_CHECK "no upstream commit was replayed onto the branch" \
		sh -c "test \$(git log --format=%s onto-main..onto-orphan | grep -c '^OM ') -eq 0"

	# A commit the upstream already carries by patch id is dropped, not lost –
	# and the summary has to say so, or the shorter branch reads as lost work
	git checkout -q -B onto-dup onto-main
	printf 'dup work\n' > dup.txt && git add dup.txt && git commit -qm "Dup on branch"
	printf 'own\n' > own.txt && git add own.txt && git commit -qm "Own work"
	git checkout -q onto-main
	printf 'dup work\n' > dup.txt && git add dup.txt && git commit -qm "Dup landed upstream"
	git checkout -q onto-dup
	_ST_RUN --onto=onto-main
	_ST_OUT_HAS "duplicates are named before the replay" 'already on onto-main'
	_ST_OUT_HAS "and counted afterwards" 'dropped as already upstream'
	_ST_CHECK "the branch keeps only its own commit" \
		sh -c "test \$(git rev-list --count onto-main..onto-dup) -eq 1"

	# A replant rewrites its whole span, so it owes the same guards every other
	# rewriting mode applies – it reached the branch without them at first
	git checkout -q -B onto-pushed onto-main
	printf 'op work\n' > op.txt && git add op.txt && git commit -qm "OP pushed"
	git push -q origin onto-pushed 2>/dev/null
	git checkout -q onto-main
	printf 'om third\n' > om3.txt && git add om3.txt && git commit -qm "OM third"
	git checkout -q onto-pushed
	_ST_RUN --onto=onto-main
	_ST_EQ "a pushed span is refused" "$RC" "1"
	_ST_OUT_HAS "naming the reason" 'already pushed'
	_ST_RUN --onto=onto-main --allow-pushed
	_ST_EQ "--allow-pushed overrides it" "$RC" "0"

	# A merge in the span would be flattened by the replay, silently
	git checkout -q -B onto-merge onto-main
	printf 'oms\n' > oms.txt && git add oms.txt && git commit -qm "OMS side"
	git checkout -q -B onto-mergebase onto-main~1
	printf 'omb\n' > omb.txt && git add omb.txt && git commit -qm "OMB base"
	git merge -q --no-ff -m "OMB merge" onto-merge 2>/dev/null
	git checkout -q onto-main
	printf 'om fourth\n' > om4.txt && git add om4.txt && git commit -qm "OM fourth"
	git checkout -q onto-mergebase
	_ST_RUN --onto=onto-main
	_ST_EQ "a merge in the span is refused" "$RC" "1"
	_ST_OUT_HAS "rather than flattened silently" 'contains a merge commit'

	# A replant that would strand the checkout must refuse before the CAS, not
	# move the branch and then decline to follow
	git checkout -q -B onto-dirty onto-main
	printf 'od branch\n' > od.txt && git add od.txt && git commit -qm "OD on branch"
	git checkout -q onto-main
	printf 'od upstream\n' > od.txt && git add od.txt && git commit -qm "OD upstream"
	git checkout -q onto-dirty
	local OD_BEFORE=$(git rev-parse onto-dirty)
	printf 'od uncommitted\n' > od.txt
	_ST_RUN --onto=onto-main
	_ST_EQ "a replant onto dirty paths is refused" "$RC" "1"
	_ST_OUT_HAS "naming the blocked path" 'od.txt'
	_ST_EQ "and the branch never moved" "$(git rev-parse onto-dirty)" "$OD_BEFORE"
	_ST_CHECK "with the uncommitted work intact" sh -c "grep -qx 'od uncommitted' od.txt"
	git checkout -q -- od.txt 2>/dev/null
	git reset -q --hard

	# Dirt on a path the replant does not touch is no reason to refuse – a fresh branch, since
	# `od.txt` differs on both sides and would conflict on its own merits, proving nothing
	git checkout -q -B onto-clean onto-main
	printf 'oc branch\n' > oc.txt && git add oc.txt && git commit -qm "OC on branch"
	git checkout -q onto-main
	printf 'om fifth\n' > om5.txt && git add om5.txt && git commit -qm "OM fifth"
	git checkout -q onto-clean
	printf 'oc unrelated\n' > oc-unrelated.txt
	_ST_RUN --onto=onto-main
	_ST_EQ "unrelated dirt does not block it" "$RC" "0"
	_ST_CHECK "and that file survives" sh -c "grep -qx 'oc unrelated' oc-unrelated.txt"
	rm -f oc-unrelated.txt
	git reset -q --hard

	# Without the upstream's reflog the fork point is only a merge base, which after a
	# content-changing rewrite sits below the real fork, taking in commits the upstream has
	# It must also have moved past the fork – `--fork-point` answers from the graph alone
	git checkout -q -B onto-noreflog onto-main
	printf 'onr branch\n' > onr.txt && git add onr.txt && git commit -qm "ONR on branch"
	git checkout -q onto-main
	printf 'onr up\n' > onr-up.txt && git add onr-up.txt && git commit -qm "ONR upstream"
	git checkout -q onto-noreflog
	git reflog expire --expire=now --all 2>/dev/null
	_ST_CHECK "the reflog can no longer answer" \
		sh -c "test -z \"\$(git merge-base --fork-point onto-main onto-noreflog 2>/dev/null)\""
	_ST_RUN --onto=onto-main
	_ST_OUT_HAS "a guessed fork point is flagged" 'could not answer'
	_ST_OUT_HAS "and warns the span may be too wide" 'may be too wide'

	# `--skip` belongs to this mode alone – elsewhere the paused commit is the point
	git checkout -q -B onto-skip onto-main
	_ST_RUN --skip
	_ST_EQ "a skip with nothing in flight is refused" "$RC" "1"
	git checkout -q onto-main
	git push -q origin --delete onto-pushed 2>/dev/null
	git branch -q -D onto-feature onto-orphan onto-dup onto-skip onto-pushed onto-merge onto-mergebase onto-dirty onto-clean onto-noreflog 2>/dev/null
	git checkout -q main
	git reset -q --hard

	_ST_SCENARIO "\e[1;96m[47] linking gitignored paths into a pause worktree\e[0m"
	git reset -q --hard
	printf 'wl one\n' > wl.txt && git add wl.txt && git commit -qm "WL one"
	printf 'wl two\n' > wl.txt && git add wl.txt && git commit -qm "WL two"
	mkdir -p node_modules/dep && printf 'installed\n' > node_modules/dep/index.js
	_ST_RUN HEAD~1
	local WL_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "nothing is linked without the config" sh -c "test ! -e '$WL_WT/node_modules'"
	_ST_RUN --abort

	printf 'node_modules\n' > .gitignore && git add .gitignore && git commit -qm "WL ignore"
	git config --add edit.worktreeLink node_modules
	# Target `HEAD`, not `HEAD~1:` the worktree checks out the commit being edited,
	# so its `.gitignore` is the one that decides whether the link is covered
	_ST_RUN HEAD
	WL_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_OUT_HAS "the link is reported" 'Linked into the worktree'
	_ST_CHECK "and resolves to the origin's copy" \
		sh -c "test -f '$WL_WT/node_modules/dep/index.js'"
	_ST_CHECK "as a symlink, not a copy" sh -c "test -L '$WL_WT/node_modules'"
	_ST_OUT_LACKS "an ignored path draws no notice" 'Not linking'
	_ST_RUN --abort

	# A directory pattern does not match the symlink standing in for it, so the link lands
	# untracked where the directory was ignored and the amend stages the worktree wholesale
	# Not creating it is the whole remedy, since an ignored link can never be staged
	printf 'node_modules/\n' > .gitignore && git add .gitignore && git commit -qm "WL slash"
	_ST_RUN HEAD
	_ST_OUT_HAS "a trailing-slash pattern is called out" 'Not linking'
	_ST_OUT_HAS "with the one-character remedy" 'Drop the trailing slash'
	local WL_WT2=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "and no link was created at all" \
		sh -c "test ! -e '$WL_WT2/node_modules'"
	printf 'wl edited\n' > "${WL_WT2:-$ST_NO_WT}/wl.txt"
	_ST_RUN --continue
	_ST_CHECK "so nothing about it reaches the commit" \
		sh -c "! git show HEAD --stat --format= | grep -q node_modules"
	_ST_CHECK "while the real edit landed" \
		sh -c "git show HEAD:wl.txt | grep -qx 'wl edited'"
	_ST_RUN --undo

	# A nested path needs its parent created, or the link silently never happens
	git config --unset-all edit.worktreeLink
	mkdir -p vendor/deps && printf 'dep\n' > vendor/deps/lib.js
	printf 'node_modules\nvendor/deps\n' > .gitignore && git add .gitignore && git commit -qm "WL nested ignore"
	git config --add edit.worktreeLink vendor/deps
	_ST_RUN HEAD
	local WL_WT3=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "a nested path is linked, not silently skipped" \
		sh -c "test -f '$WL_WT3/vendor/deps/lib.js'"
	_ST_OUT_LACKS "and reports no failure" 'Could not link'
	_ST_RUN --abort

	# A value added mid-pause reaches the already-created worktree on resume –
	# links are made at worktree setup, so --continue re-ensures them
	mkdir -p node_modules/dep && printf 'installed\n' > node_modules/dep/index.js
	_ST_RUN HEAD
	local WL_WT4=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "the later addition is not linked at setup" sh -c "test ! -e '$WL_WT4/node_modules'"
	git config --add edit.worktreeLink node_modules
	printf 'wl relinked\n' > "${WL_WT4:-$ST_NO_WT}/wl.txt"
	_ST_RUN --continue
	_ST_OUT_HAS "the mid-pause addition is linked on resume" 'Linked into the worktree: node_modules'
	_ST_CHECK "and stays out of the amended commit" \
		sh -c "! git show HEAD --stat --format= | grep -q node_modules"
	_ST_CHECK "while the edit landed" sh -c "git show HEAD:wl.txt | grep -qx 'wl relinked'"
	_ST_RUN --undo
	rm -rf vendor

	# The auto-isolated worktree (non-interactive drop/squash/edit) links too –
	# proven through a verify command needing the linked path, since the check
	# runs in that worktree before anything applies
	git config edit.verifyCmd 'test -e node_modules/dep/index.js'
	printf 'wl3\n' > wl3.txt && git add wl3.txt && git commit -qm "WL three"
	printf 'wl4\n' > wl4.txt && git add wl4.txt && git commit -qm "WL four"
	_ST_RUN -d HEAD~1 -y
	_ST_EQ "the drop applies with the gate on" "$RC" "0"
	_ST_OUT_HAS "after linking into the auto-isolated worktree" 'Linked into the worktree: node_modules'
	_ST_OUT_HAS "and verifying there" 'Verified 1 commit'

	# The reused --dir branch (reset --hard sync) must link too – one run to
	# create the worktree, strip the link, and the next has to restore it
	local WL_DIR=$TMP/wl-reuse
	# Disposable targets, so neither drop consumes the commit carrying the
	# bare ignore pattern the link depends on
	printf 'wl5\n' > wl5.txt && git add wl5.txt && git commit -qm "WL five"
	printf 'wl6\n' > wl6.txt && git add wl6.txt && git commit -qm "WL six"
	_ST_RUN -d HEAD~1 -y --dir="$WL_DIR"
	_ST_EQ "an explicit-dir drop applies" "$RC" "0"
	rm "$WL_DIR/node_modules"
	_ST_RUN -d HEAD~1 -y --dir="$WL_DIR"
	_ST_EQ "the reused-worktree drop applies" "$RC" "0"
	_ST_OUT_HAS "relinking what was removed on the reuse branch" 'Linked into the worktree: node_modules'
	_ST_OUT_HAS "and verifying in the reused worktree" 'Verified 1 commit'
	git worktree remove --force "$WL_DIR" 2>/dev/null
	git config --unset edit.verifyCmd

	git config --unset-all edit.worktreeLink
	rm -rf node_modules
	git reset -q --hard

	_ST_SCENARIO "\e[1;96m[48] documented guarantees that had no assertion\e[0m"
	git reset -q --hard
	printf 'dg one\n' > dg.txt && git add dg.txt && git commit -qm "DG one"
	printf 'dg two\n' > dg.txt && git add dg.txt && git commit -qm "DG two"
	printf 'dg three\n' > dg.txt && git add dg.txt && git commit -qm "DG three"

	# "no checkout, no stash, no rebase – the working tree is physically
	# untouched (file inodes and mtimes preserved)"
	local -a STATFMT
	if stat -f '%i' . >/dev/null 2>&1; then
		STATFMT=(-f '%i %m')
	else
		STATFMT=(-c '%i %Y')
	fi
	local DG_BEFORE=$(stat "${STATFMT[@]}" dg.txt 2>/dev/null)
	_ST_RUN -M --text='DG two reworded' HEAD~1
	_ST_EQ "reword leaves the file's inode and mtime alone" \
		"$(stat "${STATFMT[@]}" dg.txt 2>/dev/null)" "$DG_BEFORE"

	# "Every completed operation is attributed in the ref's own reflog"
	_ST_CHECK "the ref's reflog attributes the operation" \
		sh -c "git reflog -1 --format=%gs | grep -q '^git edit: reword '"

	# "Set `GIT_EDIT_NO_RESOLVE=1` to disable resolution entirely and have every unreachable
	# commit refused" – the sha has to be captured before the rewrite that orphans it, since
	# taken after it is simply current
	printf 'st one\n' > st.txt && git add st.txt && git commit -qm "ST one"
	printf 'st two\n' > st.txt && git add st.txt && git commit -qm "ST two"
	local ST_TARGET=$(git rev-parse HEAD)
	printf 'st three\n' > st.txt && git add st.txt && git commit -qm "ST three"
	_ST_RUN -M --text='ST two reworded' "$ST_TARGET"
	_ST_CHECK "the sha really is orphaned now" \
		sh -c "! git merge-base --is-ancestor $ST_TARGET HEAD 2>/dev/null"
	_ST_RUN -M --text='ST two v3' "$ST_TARGET"
	_ST_OUT_HAS "a stale sha resolves by default" 'was rewritten'
	_ST_RUN --undo
	OUT=$(GIT_EDIT_NO_RESOLVE=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text='ST two v3' "$ST_TARGET" </dev/null 2>&1)
	RC=$?
	_ST_EQ "GIT_EDIT_NO_RESOLVE refuses it instead" "$RC" "1"
	_ST_OUT_LACKS "and resolves nothing" 'using its current identity'

	# "`-C` is enabled automatically for the modes that would otherwise touch the main working
	# tree", and the plumbing modes are left alone – one file per commit, so a drop has
	# nothing to conflict over and cannot pause
	printf 'ai1\n' > ai1.txt && git add ai1.txt && git commit -qm "AI one"
	printf 'ai2\n' > ai2.txt && git add ai2.txt && git commit -qm "AI two"
	printf 'ai3\n' > ai3.txt && git add ai3.txt && git commit -qm "AI three"
	_ST_RUN -d -y HEAD~1
	_ST_EQ "the drop succeeds" "$RC" "0"
	_ST_OUT_HAS "a drop auto-isolates" 'auto-isolating'
	_ST_RUN --undo
	_ST_RUN -M --text='AI three reworded' HEAD
	_ST_OUT_LACKS "a reword does not" 'auto-isolating'
	_ST_RUN --undo
	OUT=$(GIT_EDIT_NO_AUTO_ISOLATE=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d -y HEAD~1 </dev/null 2>&1)
	_ST_OUT_LACKS "GIT_EDIT_NO_AUTO_ISOLATE opts out" 'auto-isolating'
	_ST_RUN --undo
	_ST_CHECK "and left nothing in flight" \
		sh -c "! test -f \"\$(git rev-parse --git-common-dir)/git-edit-state\""

	# "The guard is span-scoped, not repo-scoped: operating above the merge
	# stays legal"
	local MG_BASE=$(git rev-parse HEAD)
	git checkout -q -b dg-side HEAD~1
	printf 'dg side\n' > dg-side.txt && git add dg-side.txt && git commit -qm "DG side"
	git checkout -q main
	git merge -q --no-ff -m "DG merge" dg-side 2>/dev/null
	printf 'dg a\n' > dg-a.txt && git add dg-a.txt && git commit -qm "DG above one"
	printf 'dg b\n' > dg-b.txt && git add dg-b.txt && git commit -qm "DG above two"
	_ST_RUN -d -y HEAD~1
	_ST_EQ "a span above a merge stays legal" "$RC" "0"
	_ST_RUN --undo
	_ST_RUN -d -y "$MG_BASE"
	_ST_OUT_HAS "a span containing one is refused" 'contains a merge commit'
	git branch -q -D dg-side 2>/dev/null
	git reset -q --hard

	_ST_SCENARIO "\e[1;96m[49] which commit an operation landed in survives a short tail\e[0m"
	git reset -q --hard
	printf 'id base\n' > id.txt && git add id.txt && git commit -qm "ID base"
	# A target wide enough that its own stat block would bury a line printed
	# above it – the shape that hid which commit a fold had landed in
	local IDF
	for IDF in {1..14}; do printf 'id %s\n' "$IDF" > "id$IDF.txt"; done
	git add -A && git commit -qm "ID wide target"
	printf 'id staged\n' > id-staged.txt && git add id-staged.txt
	_ST_RUN --amend-into=HEAD
	_ST_EQ "the wide fold succeeds" "$RC" "0"
	_ST_OUT_HAS "names the commit folded into" 'amended: .*ID wide target'
	_ST_EQ "and names it within a 'tail -3'" \
		"$(echo "$OUT" | tail -3 | grep -c 'amended: ')" "1"

	printf 'id s1\n' > id-s1.txt && git add id-s1.txt && git commit -qm "ID squash one"
	printf 'id s2\n' > id-s2.txt && git add id-s2.txt && git commit -qm "ID squash two"
	_ST_RUN -s -y HEAD~1 HEAD
	_ST_EQ "the squash succeeds" "$RC" "0"
	_ST_OUT_HAS "and proves its tree-preserving invariant" 'Tip tree identical'
	_ST_EQ "its own summary lands within a 'tail -3' too" \
		"$(echo "$OUT" | tail -3 | grep -c 'squashed: ')" "1"

	# These lines are the mis-target signal, so a subject has to reach them
	# verbatim – routed through an `echo -e` a `\d` collapses to `d` and a `\n`
	# breaks the line, leaving a name that reads as a different commit
	printf 'id esc\n' > id-esc.txt && git add id-esc.txt
	git commit -qm 'ID esc \d and \n intact'
	printf 'id esc2\n' > id-esc2.txt && git add id-esc2.txt
	_ST_RUN --amend-into=HEAD
	_ST_EQ "a subject's backslash escapes reach the identity line intact" \
		"$(echo "$OUT" | grep -cF 'amended: ')" "1"
	# `print -r`, not `echo` – zsh's `echo` would interpret the escapes here in
	# the harness and report a mangling that never happened
	_ST_EQ "and are not interpreted on the way" \
		"$(print -r -- "$OUT" | grep -F 'amended: ' | grep -cF 'ID esc \d and \n intact')" "1"
	# The preamble names the same subject through a different path, so it needs
	# its own guard – `PRINT_ACTION` embeds it in a string `ECHO_E` interprets
	_ST_EQ "the preamble keeps them too" \
		"$(print -r -- "$OUT" | grep -F 'Amending staged changes' | grep -cF 'ID esc \d and \n intact')" "1"

	# A non-contiguous selection falls back to the rebase path, which has no
	# plumbing commit of its own to name – it names the destination instead
	printf 'id f1\n' > id-f1.txt && git add -A && git commit -qm 'ID fallback \d target'
	printf 'id f2\n' > id-f2.txt && git add -A && git commit -qm "ID fallback skipped"
	printf 'id f3\n' > id-f3.txt && git add -A && git commit -qm "ID fallback folded"
	_ST_RUN -s -y HEAD~2 HEAD
	_ST_EQ "the non-contiguous squash succeeds" "$RC" "0"
	_ST_EQ "it names its destination within a 'tail -3'" \
		"$(print -r -- "$OUT" | tail -3 | grep -c 'squashed into: ')" "1"
	_ST_EQ "with that subject's escapes intact" \
		"$(print -r -- "$OUT" | grep -F 'squashed into: ' | grep -cF 'ID fallback \d target')" "1"

	# A split's two halves keep their stats paired under their own subjects, so
	# it names the commit it split rather than moving those
	printf 'id p\n' > id-p.txt && printf 'id q\n' > id-q.txt
	git add -A && git commit -qm "ID split source"
	_ST_RUN --split HEAD --text='ID extracted' -- id-p.txt
	_ST_EQ "the split succeeds" "$RC" "0"
	_ST_OUT_HAS "it names the commit it split" 'split: .*ID split source'
	_ST_EQ "and does so within a 'tail -3'" \
		"$(echo "$OUT" | tail -3 | grep -c 'split: ')" "1"

	# A drop's hint lists every restored path, so the commit's own name has to
	# follow that list – it is the only mode whose tail named no commit at all
	printf 'id d1\n' > id-d1.txt && git add -A && git commit -qm 'ID drop \d target'
	_ST_RUN -d -y HEAD
	_ST_EQ "the drop succeeds" "$RC" "0"
	_ST_EQ "it names what it dropped within a 'tail -3'" \
		"$(print -r -- "$OUT" | tail -3 | grep -c 'dropped: ')" "1"
	_ST_EQ "with that subject's escapes intact" \
		"$(print -r -- "$OUT" | grep -F 'dropped: ' | grep -cF 'ID drop \d target')" "1"

	# An edit resumes in a later run, where the paused trailer's name is gone
	printf 'id e1\n' > id-e1.txt && git add -A && git commit -qm "ID edit target"
	_ST_RUN HEAD
	_ST_EQ "the edit pauses" "$RC" "2"
	local ID_WT=$(print -r -- "$OUT" | sed -n 's/^git-edit: paused – edit [^ ]* in \([^;]*\);.*/\1/p' | head -1)
	_ST_CHECK "it opened a worktree" test -d "$ID_WT"
	printf 'id e1 edited\n' > "${ID_WT:-$ST_NO_WT}/id-e1.txt"
	git -C "$ID_WT" add id-e1.txt
	_ST_RUN --continue
	_ST_EQ "the edit settles" "$RC" "0"
	_ST_EQ "and names what it edited within a 'tail -3'" \
		"$(print -r -- "$OUT" | tail -3 | grep -c 'edited: ')" "1"
	git reset -q --hard

	_ST_SCENARIO "\e[1;96m[50] SHA-keyed metadata across a plumbing rewrite\e[0m"
	git reset -q --hard
	git config notes.rewriteRef 'refs/notes/*'
	printf 'nt one\n' > nt.txt && git add nt.txt && git commit -qm "NT one"
	printf 'nt two\n' > nt.txt && git add nt.txt && git commit -qm "NT two"
	printf 'nt three\n' > nt.txt && git add nt.txt && git commit -qm "NT three"
	git notes --ref=ge-test add -m "meta on the target" HEAD~2
	git notes --ref=ge-test add -m "meta on a descendant" HEAD
	local NT_REACH='git log --format=%H | while read s; do git notes --ref=ge-test show $s 2>/dev/null; done | grep -c .'
	_ST_EQ "both notes reachable to begin with" "$(eval $NT_REACH)" "2"
	# `commit-tree` runs none of the machinery a rebase does, so these modes used
	# to orphan notes silently while `-d` and `--move` carried them
	_ST_RUN -M --text='NT one reworded' HEAD~2
	_ST_EQ "a plumbing reword carries them to the rebuilt commits" "$(eval $NT_REACH)" "2"
	_ST_RUN -S HEAD~1 HEAD
	_ST_EQ "a plumbing squash carries them too" "$(eval $NT_REACH)" "2"

	# The hook git fires for its own rewrites, with the same old->new map
	printf 'nt four\n' > nt.txt && git add nt.txt && git commit -qm "NT four"
	printf 'nt five\n' > nt.txt && git add nt.txt && git commit -qm "NT five"
	local NT_LOG=$(git rev-parse --git-path ge-rewrite.log)
	local NT_HOOK=$(git rev-parse --git-path hooks/post-rewrite)
	print -r -- '#!/bin/sh' > "$NT_HOOK"
	print -r -- "printf '%s\\n' \"\$1\" > '$NT_LOG'; cat >> '$NT_LOG'" >> "$NT_HOOK"
	chmod +x "$NT_HOOK"
	rm -f "$NT_LOG"
	_ST_RUN -M --text='NT three reworded' HEAD~2
	_ST_EQ "the hook is told which command rewrote" "$(head -1 "$NT_LOG" 2>/dev/null)" "rebase"
	_ST_EQ "and gets one old->new pair per rebuilt commit" \
		"$(tail -n +2 "$NT_LOG" 2>/dev/null | grep -c '^[0-9a-f]\{40\} [0-9a-f]\{40\}$')" "3"
	rm -f "$NT_HOOK" "$NT_LOG"

	# A fold that also rewords is two rewrites back to back, and the first one's
	# map names commits the second rebuilds – held to the CAS it would copy onto
	# intermediates nothing can reach, stranding the note it was meant to carry
	printf 'nt six\n' > nt.txt && git add nt.txt && git commit -qm "NT six"
	printf 'nt seven\n' > nt.txt && git add nt.txt && git commit -qm "NT seven"
	git notes --ref=ge-fold add -m "meta on the fold target" HEAD~1
	printf 'nt staged\n' > nt2.txt && git add nt2.txt
	_ST_RUN --amend-into=HEAD~1 --text='NT six, folded and reworded'
	_ST_EQ "the fold settles" "$RC" "0"
	_ST_EQ "a fold that also rewords keeps its note on live history" \
		"$(git log --format=%H | while read s; do git notes --ref=ge-fold show $s 2>/dev/null; done | grep -c .)" "1"

	# A repo that configures none of this must be unaffected
	git config --unset notes.rewriteRef
	_ST_RUN -M --text='NT five reworded' HEAD
	_ST_EQ "unconfigured repos still succeed" "$RC" "0"
	git reset -q --hard

	# "Color follows the same rule and also honors `NO_COLOR` and `TERM=dumb`" – a captured run
	# proves the pipe case, the other two only structurally, since no TTY is available here
	# The cleanup below enumerates worktrees for the temp ones outside `$TMP`, so assert the path
	_ST_CHECK "the cleanup can enumerate the scratch repo's worktrees" \
		sh -c "test \$(git -C '$TMP/repo' worktree list --porcelain 2>/dev/null | grep -c '^worktree ') -ge 1"

	# --- 51. a squash's --text has to outlive the conflicts it pauses on ---
	# The override applying it lasts one rebase invocation, so every `--continue`
	# spawned its own process without it and the fold silently kept git's default
	# combined message – a wrong result the run still reported as ok
	_ST_SCENARIO "\e[1;96m[51] --text survives a squash's conflict pauses\e[0m"
	git reset -q --hard
	local N
	for N in 1 2 3 4; do
		echo "tx$N" > tx.txt && git add tx.txt && git commit -qm "TX $N"
	done
	local TX_TARGET=$(git log --format=%H --grep='^TX 2$' -1)
	local TX_VICTIM=$(git log --format=%H --grep='^TX 4$' -1)
	_ST_RUN -s="$TX_TARGET" -y --text="$(printf 'TX folded subject\n\n• TX folded body')" "$TX_VICTIM"
	_ST_EQ "the squash pauses on a conflict" "$RC" "2"
	local TX_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	_ST_RESOLVE "$TX_WT" tx.txt "tx4"
	_ST_RUN --continue
	_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
	_ST_RESOLVE "$TX_WT" tx.txt "tx3"
	_ST_RUN --continue
	_ST_EQ "the resumed squash settles" "$RC" "0"
	_ST_EQ "the fold carries --text, not the combined default" \
		"$(git log --format=%s --skip=1 -1)" "TX folded subject"
	_ST_CHECK "including its body" \
		sh -c "git log --format=%B --skip=1 -1 | grep -q '• TX folded body'"
	_ST_CHECK "and no commit kept git's squash boilerplate" \
		sh -c "! git log --format=%B | grep -q 'This is a combination of'"
	_ST_EQ "the replayed commit keeps its own message" "$(git log --format=%s -1)" "TX 3"

	# Folding an older commit forward replays the commits it skipped first, and
	# a resume commits those too – each opening an editor the fold's message
	# must not answer, or an untouched commit silently takes the fold's subject
	git reset -q --hard
	for N in 1 2 3 4; do
		echo "tf$N" > tf.txt && git add tf.txt && git commit -qm "TF $N"
	done
	local TF_VICTIM=$(git log --format=%H --grep='^TF 2$' -1)
	local TF_TARGET=$(git log --format=%H --grep='^TF 4$' -1)
	_ST_RUN -s="$TF_TARGET" -y --text="TF folded subject" "$TF_VICTIM"
	_ST_EQ "folding forward pauses before reaching the fold" "$RC" "2"
	local TF_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	_ST_RESOLVE "$TF_WT" tf.txt "tf3"
	_ST_RUN --continue
	_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
	_ST_RESOLVE "$TF_WT" tf.txt "tf2"
	_ST_RUN --continue
	_ST_EQ "the forward fold settles" "$RC" "0"
	_ST_EQ "the fold still takes --text" "$(git log --format=%s -1)" "TF folded subject"
	_ST_EQ "the commit replayed ahead of it is untouched" "$(git log --format=%s --skip=1 -1)" "TF 3"
	git reset -q --hard

	# A fold must not edit the messages of the commits it replays past, and the message here
	# carries a `#` line, which is what makes that a real assertion – git's own rebase drops
	# those from any commit it stops on, and the fold's cleanup leaves `# Conflicts:` instead
	git reset -q --hard
	echo "tr1" > tr.txt && git add tr.txt && git commit -qm "TR 1"
	echo "tr2" > tr.txt && git add tr.txt && git commit -qm "TR 2 target"
	echo "tr3" > tr.txt && git add tr.txt
	git commit -q -F - <<-'TRMSG'
		TR 3 replayed

		refs:
		#77 belongs to this commit
	TRMSG
	echo "tr4" > tr.txt && git add tr.txt && git commit -qm "TR 4 victim"
	local TR_BEFORE=$(git log --format=%B --grep='^TR 3 replayed$' -1)
	_ST_RUN -s="$(git log --format=%H --grep='^TR 2 target$' -1)" -y --text="TR folded subject" \
		"$(git log --format=%H --grep='^TR 4 victim$' -1)"
	local TR_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	_ST_RESOLVE "$TR_WT" tr.txt "tr4"
	_ST_RUN --continue
	_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
	_ST_RESOLVE "$TR_WT" tr.txt "tr3"
	_ST_RUN --continue
	_ST_EQ "the replay settles" "$RC" "0"
	_ST_EQ "a replayed commit's message survives byte for byte" \
		"$(git log --format=%B --grep='^TR 3 replayed$' -1)" "$TR_BEFORE"
	_ST_EQ "its own '#' line included" \
		"$(git log --format=%B | grep -c '^#77 belongs to this commit$')" "1"
	_ST_CHECK "with none of git's conflict template in it" \
		sh -c "! git log --format=%B | grep -q 'Conflicts:'"
	git reset -q --hard

	# A conflict exits straight from the handler, past the `rm` that follows the
	# call – so the message file it wrote survived the run, once per pause
	local TX_TMP_BEFORE=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-squash-msg.*' 2>/dev/null | grep -c .)
	local TX_ED_BEFORE=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
	for N in 1 2 3 4; do
		echo "tl$N" > tl.txt && git add tl.txt && git commit -qm "TL $N"
	done
	_ST_RUN -s="$(git log --format=%H --grep='^TL 2$' -1)" -y --text="TL folded subject" \
		"$(git log --format=%H --grep='^TL 4$' -1)"
	_ST_EQ "the leak probe's fold pauses" "$RC" "2"
	_ST_RUN --abort
	local TX_TMP_AFTER=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-squash-msg.*' 2>/dev/null | grep -c .)
	_ST_EQ "a paused fold leaves no temp message behind" "$TX_TMP_AFTER" "$TX_TMP_BEFORE"
	# The stand-in is built inside a command substitution, so registering it for
	# cleanup there would only ever reach a subshell's copy of the list
	local TX_ED_AFTER=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
	_ST_EQ "nor the editor stand-in it built" "$TX_ED_AFTER" "$TX_ED_BEFORE"
	git reset -q --hard

	# --- 52. a resume's editor reaches the fold and nothing else ---
	# `-m` needs a TTY this suite can never present, so its guarantee is asserted
	# on the discriminator both message modes route through – driven directly,
	# the way git invokes an editor, against a fabricated rebase state
	_ST_SCENARIO "\e[1;96m[52] a resume's editor reaches the fold alone\e[0m"
	# Stand-ins built here would otherwise wait in `_TEMP_FILES` for the suite's
	# own exit – a killed run leaves them behind, so each goes with its last check
	local FE_ED_BEFORE=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
	local FE=$TMP/fold-editor
	rm -rf "$FE" && mkdir -p "$FE" && git -C "$FE" init -q
	local FE_REB=$(git -C "$FE" rev-parse --absolute-git-dir)/rebase-merge
	mkdir -p "$FE_REB"
	local FE_MSG=$FE/folded.txt
	local FE_DEST=$FE/COMMIT_EDITMSG
	print -r -- "FE folded subject" > "$FE_MSG"
	local FE_CMD=$(_FOLD_EDITOR_CMD "cp '$FE_MSG'" "$FE")

	# The step that conflicted is committed by the same resume, and its message
	# is already right – a stand-in reaching it rewords an untouched commit
	print -r -- "pick 1111111 # FE replayed" > "$FE_REB/done"
	print -r -- "FE replayed message" > "$FE_DEST"
	sh -c "$FE_CMD \"\$@\"" ge-editor "$FE_DEST"
	local FE_RC=$?
	_ST_EQ "a replayed step keeps its own message" "$(cat "$FE_DEST")" "FE replayed message"
	# A non-zero editor makes git abandon the commit, so the no-op must exit clean
	_ST_EQ "and the stand-in still exits clean" "$FE_RC" "0"

	print -r -- "squash 2222222 # FE victim" > "$FE_REB/done"
	sh -c "$FE_CMD \"\$@\"" ge-editor "$FE_DEST"
	_ST_EQ "the fold takes the supplied message" "$(cat "$FE_DEST")" "FE folded subject"
	print -r -- "fixup 3333333" > "$FE_REB/done"
	print -r -- "FE other message" > "$FE_DEST"
	sh -c "$FE_CMD \"\$@\"" ge-editor "$FE_DEST"
	_ST_EQ "a fixup step is the fold too" "$(cat "$FE_DEST")" "FE folded subject"

	# `-m` supplies an editor rather than a message, through the same guard
	local FE_LOG=$FE/opened.log
	local FE_STUB=$FE/stub-editor.sh
	{ echo '#!/bin/sh'; echo "echo opened >> '$FE_LOG'" } > "$FE_STUB"
	chmod +x "$FE_STUB"
	local FE_ED=$(_FOLD_EDITOR_CMD "$FE_STUB" "$FE")
	: > "$FE_LOG"
	print -r -- "pick 4444444" > "$FE_REB/done"
	sh -c "$FE_ED \"\$@\"" ge-editor "$FE_DEST"
	_ST_EQ "-m's editor stays shut on a replayed step" "$(grep -c . "$FE_LOG")" "0"
	print -r -- "squash 5555555" > "$FE_REB/done"
	sh -c "$FE_ED \"\$@\"" ge-editor "$FE_DEST"
	_ST_EQ "-m's editor opens on the fold" "$(grep -c . "$FE_LOG")" "1"
	_ST_CHECK "and the -m branch routes through the guard" \
		sh -c "command grep -q '_FOLD_EDITOR_CMD \"\$_REAL_EDITOR\"' '$SELF'"

	# `sh` parses the emitted command, so a repo living under an apostrophe used
	# to close the quote and leave a syntax error – which surfaces only as a
	# failed editor, git abandoning the commit and the operation wedging
	local FE2="$TMP/it's a \$repo"
	rm -rf "$FE2" && mkdir -p "$FE2" && git -C "$FE2" init -q
	local FE2_REB=$(git -C "$FE2" rev-parse --absolute-git-dir)/rebase-merge
	mkdir -p "$FE2_REB"
	print -r -- "squash 6666666" > "$FE2_REB/done"
	local FE2_MSG="$FE2/folded msg.txt"
	local FE2_DEST="$FE2/COMMIT_EDITMSG"
	print -r -- "FE quoted-path subject" > "$FE2_MSG"
	print -r -- "FE untouched" > "$FE2_DEST"
	local FE2_ED=$(_FOLD_EDITOR_CMD "cp ${(qq)FE2_MSG}" "$FE2")
	sh -c "$FE2_ED \"\$@\"" ge-editor "$FE2_DEST"
	local FE2_RC=$?
	_ST_EQ "a path with an apostrophe still applies the message" \
		"$(cat "$FE2_DEST")" "FE quoted-path subject"
	_ST_EQ "and parses cleanly rather than failing the editor" "$FE2_RC" "0"
	rm -rf "$FE" "$FE2"
	rm -f "$FE_CMD" "$FE_ED" "$FE2_ED"

	# The case above quotes the message path itself, so it pins the helper alone –
	# drive a real resume for the caller, which has to quote it just the same
	local QR="$TMP/quote'd repo"
	rm -rf "$QR"
	mkdir -p "$QR"
	git -C "$QR" init -q
	git -C "$QR" config user.email selftest@example.com
	git -C "$QR" config user.name "git-edit selftest"
	for N in 1 2 3 4; do
		echo "qr$N" > "$QR/qr.txt"
		git -C "$QR" add qr.txt
		git -C "$QR" commit -qm "QR $N"
	done
	cd "$QR"
	_ST_RUN -s="$(git log --format=%H --grep='^QR 2$' -1)" -y --text="QR folded subject" \
		"$(git log --format=%H --grep='^QR 4$' -1)"
	_ST_EQ "a repo under an apostrophe still pauses, not errors" "$RC" "2"
	local QR_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	_ST_RESOLVE "$QR_WT" qr.txt "qr4"
	_ST_RUN --continue
	_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
	_ST_RESOLVE "$QR_WT" qr.txt "qr3"
	_ST_RUN --continue
	_ST_EQ "its resume settles" "$RC" "0"
	_ST_EQ "and the fold carries --text" "$(git log --format=%s --skip=1 -1)" "QR folded subject"
	cd "$TMP/repo"
	rm -rf "$QR"

	# `-m` wants a TTY no sub-invocation here can present, so drive the branch that carried the
	# bug in-process – stub the runner and read back the editor and cleanup each mode
	# installs, with nothing executed so no editor can open
	local FE_SAVED=$(functions GIT_RUN_AND_HANDLE_CONFLICTS)
	GIT_RUN_AND_HANDLE_CONFLICTS () { _FE_CMD=$1; _FE_ED=$GIT_EDITOR; _FE_EDS+=("$GIT_EDITOR") }
	local -a _FE_EDS
	local FE_KEEP_ACTION=$ACTION
	local FE_KEEP_TEXT=$TEXT_VALUE
	local -a FE_KEEP_OPTM=("${OPT_MESSAGE[@]}")
	local FE_GUARD FE_CLEAN
	ACTION=squash

	TEXT_VALUE="FE inline message"
	OPT_MESSAGE=()
	GIT_REBASE_CONTINUE >/dev/null
	FE_GUARD=no
	[[ -x "$_FE_ED" ]] && grep -q 'rebase-merge/done' "$_FE_ED" && grep -q 'cp ' "$_FE_ED" && FE_GUARD=yes
	FE_CLEAN=no; [[ "$_FE_CMD" == *commit.cleanup=whitespace* ]] && FE_CLEAN=yes
	_ST_EQ "--text installs the stand-in around its message" "$FE_GUARD" "yes"
	# Safe only because the stand-in writes each replayed message back itself
	_ST_EQ "and the cleanup that keeps its '#' lines" "$FE_CLEAN" "yes"
	FE_GUARD=no; grep -q 'git log -1 --format=%B' "$_FE_ED" && FE_GUARD=yes
	_ST_EQ "every other step is restored from the commit replayed" "$FE_GUARD" "yes"

	TEXT_VALUE=""
	OPT_MESSAGE=(-m)
	GIT_REBASE_CONTINUE >/dev/null
	FE_GUARD=no
	[[ -x "$_FE_ED" ]] && grep -qF -- "$(_RESOLVE_EDITOR)" "$_FE_ED" && FE_GUARD=yes
	_ST_EQ "-m installs the stand-in around the real editor" "$FE_GUARD" "yes"
	# Its template is git's own, so that one message keeps the comment stripping
	FE_GUARD=no; grep -q 'stripspace --strip-comments' "$_FE_ED" && FE_GUARD=yes
	_ST_EQ "and strips the template git seeded it with" "$FE_GUARD" "yes"

	TEXT_VALUE="FE inline message"
	OPT_MESSAGE=(-m)
	GIT_REBASE_CONTINUE >/dev/null
	FE_GUARD=no; grep -q 'cp ' "$_FE_ED" && FE_GUARD=yes
	_ST_EQ "given both, --text wins as the initial run had it" "$FE_GUARD" "yes"

	ACTION=drop
	TEXT_VALUE=""
	OPT_MESSAGE=()
	GIT_REBASE_CONTINUE >/dev/null
	_ST_EQ "every other resume still silences the editor" "$_FE_ED" "true"

	eval "$FE_SAVED"
	ACTION=$FE_KEEP_ACTION
	TEXT_VALUE=$FE_KEEP_TEXT
	OPT_MESSAGE=("${FE_KEEP_OPTM[@]}")
	unset _REAL_EDITOR _FE_CMD _FE_ED
	# A silenced resume records `true`, which names no file to remove
	local FE_INSTALLED
	for FE_INSTALLED in "${_FE_EDS[@]}"; do
		[[ "$FE_INSTALLED" == */git-edit-fold-editor.* ]] && rm -f "$FE_INSTALLED"
	done
	unset _FE_EDS
	local FE_ED_AFTER=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
	_ST_EQ "and the scenario leaves no stand-in behind" "$FE_ED_AFTER" "$FE_ED_BEFORE"

	# --- 53. --text keeps the caller's own `#` lines ---
	# Comment stripping exists to drop the instructions git seeds an editor template with,
	# and nothing seeds `--text`, so a `#` line there is the caller's content – an issue
	# reference, a Markdown heading, a shell snippet – silently rewritten on every route
	_ST_SCENARIO "\e[1;96m[53] --text keeps the caller's own '#' lines\e[0m"
	git reset -q --hard
	local HM_BODY

	HM_BODY=$(printf 'HM reworded\n\nSee also:\n#123 route-reword')
	echo "hm1" > hm.txt && git add hm.txt && git commit -qm "HM base"
	_ST_RUN -M --text="$HM_BODY" HEAD
	_ST_EQ "a reword keeps them" "$(git log --format=%B | grep -c '^#123 route-reword$')" "1"

	HM_BODY=$(printf 'HM folded\n\nSee also:\n#123 route-plumbing')
	echo "hm2" > hm2.txt && git add hm2.txt && git commit -qm "HM one"
	echo "hm3" > hm3.txt && git add hm3.txt && git commit -qm "HM two"
	_ST_RUN -s="$(git rev-parse HEAD~1)" -y --text="$HM_BODY" "$(git rev-parse HEAD)"
	_ST_EQ "a plumbing fold keeps them" "$(git log --format=%B | grep -c '^#123 route-plumbing$')" "1"

	# Non-adjacent, so it falls to the rebase path where the message reaches the commit through
	# an editor – which route a fold takes turns on adjacency, not on anything the caller
	# said, so the two must not disagree here
	HM_BODY=$(printf 'HM gapped\n\nSee also:\n#123 route-rebase')
	echo "hm4" > hm4.txt && git add hm4.txt && git commit -qm "HM gap a"
	echo "hm5" > hm5.txt && git add hm5.txt && git commit -qm "HM gap b"
	echo "hm6" > hm6.txt && git add hm6.txt && git commit -qm "HM gap c"
	_ST_RUN -s="$(git rev-parse HEAD~2)" -y --text="$HM_BODY" "$(git rev-parse HEAD)"
	_ST_EQ "a rebase-path fold keeps them too" \
		"$(git log --format=%B | grep -c '^#123 route-rebase$')" "1"
	_ST_CHECK "and no template boilerplate rode along" \
		sh -c "! git log --format=%B | grep -qE 'This is a combination of|rebase in progress|^# Conflicts:'"

	# Whitespace-only input still has nothing to commit, so the guard stays live
	_ST_RUN -M --text='   ' HEAD
	_ST_EQ "a blank message is still refused" "$RC" "1"
	_ST_OUT_HAS "and says why" 'empty message'
	git reset -q --hard

	_ST_CHECK "the color gate covers NO_COLOR and TERM=dumb" \
		sh -c "command grep -q '^if \\[ ! -t 1 \\] || \\[ -n \"\\\$NO_COLOR\" \\] || \\[ \"\\\$TERM\" = \"dumb\" \\]; then' '$SELF'"

	# --- 54. a fold that lands nothing, or less than was staged, says so ---
	# The fold's correct tip is knowable up front, the pre-op tip plus the staged changes, so
	# a run falling short of it must not read as ok – nothing landed is refused with staging
	# intact, a dissolved hunk lands with a note, and an emptied replay gets its drop counted
	_ST_SCENARIO "\e[1;96m[54] fold landing guards\e[0m"
	local R54="$TMP/fold54"
	git init -q -b main "$R54"
	git -C "$R54" config user.email selftest@git-edit
	git -C "$R54" config user.name "git-edit selftest"
	cd "$R54"
	printf 'a1\n' > fa.txt
	printf 'x1\n' > fb.txt
	git add fa.txt fb.txt && git commit -qm "F base"
	printf 'x2\n' > fb.txt && git commit -qam "F advance"
	local F_BASE=$(git rev-parse HEAD~1)
	local F_TIP=$(git rev-parse HEAD)

	# Total dissolve: stage a revert of the later commit and fold it into base –
	# base already carries that content, so the fixup neutralizes cleanly
	printf 'x1\n' > fb.txt && git add fb.txt
	_ST_RUN --amend-into="$F_BASE"
	_ST_EQ "a fold landing nothing is refused" "$RC" "1"
	_ST_OUT_HAS "and names the cause" 'left history unchanged'
	_ST_OUT_HAS "with an error trailer" '^git-edit: error'
	_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$F_TIP"
	_ST_CHECK "staged change still staged" sh -c "git diff --cached --name-only | grep -q fb.txt"

	# Partial dissolve: one real hunk beside the same revert – the real hunk
	# lands, and the summary notes the tip fell short of what was staged
	printf 'a2\n' > fa.txt
	git add fa.txt fb.txt
	_ST_RUN --amend-into="$F_BASE"
	_ST_EQ "a partial fold still exits 0" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok'
	_ST_OUT_HAS "notes the dissolved hunk" 'tip tree differs from the staged result'
	# The note grows the block above the identity line, which must still land
	# where a `tail -3` reader looks for it
	_ST_EQ "and the identity line still lands within a 'tail -3'" \
		"$(echo "$OUT" | tail -3 | grep -c 'amended: ')" "1"
	_ST_EQ "the real hunk landed in base" "$(git show HEAD~1:fa.txt)" "a2"
	_ST_EQ "the later commit's content survives" "$(git show HEAD:fb.txt)" "x2"
	git reset -q --hard

	# A resolution that reproduces the next commit's content leaves that pick empty – blind
	# continues then drop it, and the summary must count the loss
	printf 'v1\n' > fc.txt && git add fc.txt && git commit -qm "F pick a"
	printf 'v2\n' > fc.txt && git commit -qam "F pick b"
	local F_COUNT=$(git rev-list --count HEAD)
	printf 'v9\n' > fc.txt && git add fc.txt
	_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
	_ST_EQ "same-line fold pauses" "$RC" "2"
	local ROUNDS54=0
	while [ "$RC" = "2" ] && [ $ROUNDS54 -lt 4 ]; do
		ROUNDS54=$((ROUNDS54+1))
		if print -r -- "$OUT" | grep -q 'current step became empty'; then
			# The pause an emptied pick surfaces as – continue drives through it
			_ST_RUN --continue
			continue
		fi
		local WT54=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
		if [ -z "$WT54" ] || [ ! -d "$WT54" ]; then
			break
		fi
		printf 'v2\n' > "$WT54/fc.txt"
		git -C "$WT54" add fc.txt
		_ST_RUN --continue
	done
	_ST_EQ "blind resolution completes" "$RC" "0"
	_ST_OUT_HAS "and the dropped commit is counted" 'resolved to empty and were dropped'
	_ST_EQ "history is one commit shorter" "$(git rev-list --count HEAD)" "$((F_COUNT-1))"

	# And an ordinary clean fold must trip neither guard (the partial fold
	# above rewrote F_BASE, so re-derive the target from the root)
	printf 'a3\n' > fa.txt && git add fa.txt
	_ST_RUN --amend-into="$(git rev-list --max-parents=0 HEAD)"
	_ST_EQ "clean fold exits 0" "$RC" "0"
	_ST_OUT_LACKS "no tree note on a faithful fold" 'tip tree differs'
	_ST_OUT_LACKS "no drop count on a faithful fold" 'resolved to empty'
	cd "$TMP/repo"

	# --- 55. a fold's final conflicted step resolves itself, mid steps pause ---
	# The finished tip is the pre-op tip plus the staged changes, so the final
	# step's resolution is provable (staged-tree identity) before anything is
	# committed – earlier steps have no such answer and must keep pausing
	_ST_SCENARIO "\e[1;96m[55] fold final-step auto-resolve\e[0m"
	local R55="$TMP/fold55"
	git init -q -b main "$R55"
	git -C "$R55" config user.email selftest@git-edit
	git -C "$R55" config user.name "git-edit selftest"
	cd "$R55"
	printf 'g1\n' > g.txt && git add g.txt && git commit -qm "G one"
	printf 'g2\n' > g.txt && git commit -qam "G two"
	printf 'g3\n' > g.txt && git commit -qam "G three"
	printf 'g9\n' > g.txt && git add g.txt
	local G_STAGED=$(git write-tree)

	# Fold into the root: the fixup conflicts (mid step – must pause)
	_ST_RUN --amend-into="$(git rev-parse HEAD~2)"
	_ST_EQ "fixup step pauses" "$RC" "2"
	local WT55=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
	_ST_CHECK "conflict worktree exists" test -d "$WT55"
	printf 'g9\n' > "$WT55/g.txt" && git -C "$WT55" add g.txt

	# "G two" replays next – still not the final step, so it pauses too
	_ST_RUN --continue
	_ST_EQ "mid pick still pauses" "$RC" "2"
	_ST_OUT_LACKS "and is not auto-resolved" 'auto-resolved'
	WT55=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
	printf 'g8\n' > "$WT55/g.txt" && git -C "$WT55" add g.txt

	# "G three" is the final step – its result is the staged tree, so this
	# continue resolves it itself and completes in one go
	_ST_RUN --continue
	_ST_EQ "final step completes without another pause" "$RC" "0"
	_ST_OUT_HAS "names the auto-resolution" 'auto-resolved'
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok'
	_ST_EQ "tip content is the staged content" "$(git show HEAD:g.txt)" "g9"
	_ST_EQ "tip tree is the staged tree" "$(git rev-parse 'HEAD^{tree}')" "$G_STAGED"
	_ST_EQ "no commit was lost" "$(git rev-list --count HEAD)" "3"
	_ST_OUT_LACKS "and no drop was counted" 'resolved to empty'
	cd "$TMP/repo"

	# --- 56. batch reword rewrites many messages in one pass from stdin records ---
	_ST_SCENARIO "\e[1;96m[56] batch reword (-M --text - records)\e[0m"
	cd "$TMP/repo"
	# Self-contained commits so an earlier fixture can't collide
	local _bw
	for _bw in bw1 bw2 bw3 bw4; do echo "$_bw" > "$_bw.txt"; git add "$_bw.txt"; git commit -qm "Batch $_bw"; done
	local BW_TIP0=$(git rev-parse HEAD)
	local BW_TREE0=$(git rev-parse 'HEAD^{tree}')
	local BW_COUNT0=$(git rev-list --count HEAD)
	local BW1=$(git rev-parse --short :/Batch\ bw1)
	local BW3=$(git rev-parse --short :/Batch\ bw3)
	# Dump the run's shape, edit two bodies, feed it straight back
	_ST_RUN_IN "$(printf -- '--- %s\nBatch bw1 reworded\n--- %s\nBatch bw3 reworded\n\nWith a body\n' "$BW1" "$BW3")" -M --text -
	_ST_EQ "batch reword exits 0" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok'
	_ST_OUT_HAS "reports the count" 'Reworded 2 commits'
	_ST_OUT_HAS "asserts the tree invariant" 'Trees unchanged'
	_ST_EQ "first target's message applied" "$(git log --format=%s | grep -c '^Batch bw1 reworded$')" "1"
	_ST_EQ "second target's message applied" "$(git log --format=%s | grep -c '^Batch bw3 reworded$')" "1"
	_ST_EQ "second target's body applied" "$(git log -1 --format=%b :/'Batch bw3 reworded' | grep -c 'With a body')" "1"
	_ST_EQ "untouched neighbour intact" "$(git log --format=%s | grep -c '^Batch bw2$')" "1"
	_ST_EQ "tip tree preserved (content unchanged)" "$(git rev-parse 'HEAD^{tree}')" "$BW_TREE0"
	_ST_EQ "commit count unchanged" "$(git rev-list --count HEAD)" "$BW_COUNT0"
	# The reflog top is the single CAS – not two, not one per commit
	_ST_EQ "exactly one ref update" "$(git reflog show main | head -1 | grep -c 'git edit: reword 2 commits')" "1"
	# Undo reverses the whole batch in one step
	_ST_RUN --undo
	_ST_EQ "undo restores the pre-batch tip" "$(git rev-parse HEAD)" "$BW_TIP0"

	# Re-apply, then exercise every rejection path against a stable tip
	_ST_RUN_IN "$(printf -- '--- %s\nBatch bw1 reworded\n' "$BW1")" -M --text -
	local BW_AFTER=$(git rev-parse HEAD)
	_ST_RUN_IN "$(printf -- '--- %s\nX\n--- %s\nY\n' "$(git rev-parse --short HEAD)" "$(git rev-parse --short HEAD)")" -M --text -
	_ST_EQ "duplicate target refused" "$RC" "1"
	_ST_OUT_HAS "names the duplicate" 'named by two records'
	_ST_EQ "duplicate left the tip untouched" "$(git rev-parse HEAD)" "$BW_AFTER"
	_ST_RUN_IN "$(printf -- '--- %s\n\n' "$(git rev-parse --short HEAD)")" -M --text -
	_ST_EQ "empty message refused" "$RC" "1"
	_ST_OUT_HAS "names the empty record" 'empty message'
	_ST_RUN_IN "$(printf -- '--- %s\nok\n--- deadbeefdeadbeef\nno\n' "$(git rev-parse --short HEAD)")" -M --text -
	_ST_EQ "unknown header refused" "$RC" "1"
	_ST_EQ "unknown header left the tip untouched" "$(git rev-parse HEAD)" "$BW_AFTER"
	# Every record already matches -> nothing to do, no ref move
	local BW_NOW=$(git rev-parse HEAD)
	_ST_RUN_IN "$(git log -1 --format='--- %h%n%B' HEAD)" -M --text -
	_ST_EQ "all-no-op exits 0" "$RC" "0"
	_ST_OUT_HAS "reports nothing to do" 'nothing to do'
	_ST_EQ "all-no-op moved no ref" "$(git rev-parse HEAD)" "$BW_NOW"
	# A stale SHA in a record resolves to its rewritten identity
	local BW_S1=$(git rev-parse HEAD)
	_ST_RUN -M --text="staled once" "$BW_S1"
	_ST_RUN_IN "$(printf -- '--- %s\nrecovered via stale sha\n' "${BW_S1:0:9}")" -M --text -
	_ST_EQ "stale sha resolved and applied" "$RC" "0"
	_ST_EQ "stale target's new message present" "$(git log --format=%s | grep -c '^recovered via stale sha$')" "1"
	# A target whose own message carries a `--- ` line is refused, that line being the record
	# separator, so its dump would mis-split – the single form has none to collide with
	printf 'Body with a separator\n\n--- probe\n' | git commit -q --allow-empty -F -
	local BW_MARK=$(git rev-parse HEAD)
	_ST_RUN_IN "$(printf -- '--- %s\nReworded marker body\n' "$(git rev-parse --short HEAD)")" -M --text -
	_ST_EQ "marker-body target refused" "$RC" "1"
	_ST_OUT_HAS "names the reserved separator" "reserves"
	_ST_EQ "marker refusal moved no ref" "$(git rev-parse HEAD)" "$BW_MARK"
	# A pushed target is refused via the bulk unpushed-set check, which falls back to
	# `_GUARD_UNPUSHED` for the message, and `origin/main` is pushed history
	local BW_TIP=$(git rev-parse HEAD)
	_ST_RUN_IN "$(printf -- '--- %s\nRewrite pushed history\n' "$(git rev-parse origin/main)")" -M --text -
	_ST_EQ "pushed target refused" "$RC" "1"
	_ST_OUT_HAS "names it as pushed" "already pushed"
	_ST_EQ "pushed refusal moved no ref" "$(git rev-parse HEAD)" "$BW_TIP"
	cd "$TMP/repo"


	# --- 57. the one-git-log rebuild walk preserves empty-message and merge commits ---
	# The walk packs each commit's fields into one NUL-separated `git log`, so an
	# empty message (a trailing empty field) and a merge (a multi-value parents
	# field) are the two shapes a format/index drift would corrupt silently
	_ST_SCENARIO "\e[1;96m[57] rebuild-walk field edges (empty message, merge parents)\e[0m"
	cd "$TMP/repo"
	local WE_BELOW=$(git rev-parse HEAD)
	echo we1 > we1.txt && git add we1.txt && git commit -qm "Walk edge base"
	git commit -q --allow-empty --allow-empty-message -m ""
	git checkout -q -b we-side; echo wes > wes.txt && git add wes.txt && git commit -qm "Walk edge side"
	git checkout -q main; echo wem > wem.txt && git add wem.txt
	GIT_AUTHOR_DATE='@1600009999 +0000' git -c user.name='Edge Main Author' -c user.email='edgemain@x' commit -qm "Walk edge main"
	local WE_AUTHOR=$(git log -1 --format='%an|%ae|%aI' :/Walk\ edge\ main)
	git merge -q --no-ff we-side -m "Walk edge merge" >/dev/null 2>&1
	local WE_TREE=$(git rev-parse 'HEAD^{tree}')
	# Reword the base below both – the walk climbs through the empty-message
	# commit and the merge, rebuilding each from its packed fields
	_ST_RUN -M --text="Walk edge base reworded" "$(git rev-parse :/Walk\ edge\ base)"
	_ST_EQ "walk-through reword exits 0" "$RC" "0"
	_ST_EQ "base was reworded" "$(git log --format='%s' "$WE_BELOW..HEAD" | grep -c '^Walk edge base reworded$')" "1"
	_ST_EQ "empty-message commit kept its empty message" "$(git log --format='%s' "$WE_BELOW..HEAD" | grep -c '^$')" "1"
	_ST_EQ "merge kept its two parents" "$(git rev-list --min-parents=2 --count "$WE_BELOW..HEAD")" "1"
	_ST_EQ "tip tree preserved (content unchanged)" "$(git rev-parse 'HEAD^{tree}')" "$WE_TREE"
	_ST_EQ "rebuilt descendant preserves its author (name, email, date)" "$(git log -1 --format='%an|%ae|%aI' :/Walk\ edge\ main)" "$WE_AUTHOR"
	git checkout -q main 2>/dev/null
	cd "$TMP/repo"

	# --- 58. rerere records are operation-scoped under an explicit opt-out ---
	# `rerere.enabled` false still records during the run, the cascade carry being the point,
	# but the records are forgotten once the operation ends, completed and aborted alike
	# Without the opt-out they persist, and an abort leaving fresh resolutions behind names them
	_ST_SCENARIO "\e[1;96m[58] rerere honors an explicit opt-out, operation-scoped\e[0m"
	git reset -q --hard
	git config rerere.enabled false
	local RR58_DIR="$(git rev-parse --git-common-dir)/rr-cache"
	local RR58_BEFORE=$(ls "$RR58_DIR" 2>/dev/null | wc -l | tr -d ' ')
	printf 'sc line A\n' > sc.txt && git add sc.txt && git commit -qm "SC base"
	printf 'sc line B\n' > sc.txt && git add sc.txt && git commit -qm "SC middle"
	local SC_MID=$(git rev-parse HEAD)
	printf 'sc line C\n' > sc.txt && git add sc.txt && git commit -qm "SC top"
	_ST_RUN -d -y "$SC_MID"
	_ST_EQ "the opt-out drop conflicts as set up" "$RC" "2"
	# The within-run carry substrate: recording still happens while live
	_ST_CHECK "the conflict is recorded while the run is paused" \
		sh -c "[ $(ls "$RR58_DIR" 2>/dev/null | wc -l | tr -d ' ') -gt $RR58_BEFORE ]"
	local SC_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	if [ -n "$SC_WT" ] && [ -d "$SC_WT" ]; then
		printf 'sc line C\n' > "${SC_WT:-$ST_NO_WT}/sc.txt"
		git -C "$SC_WT" add sc.txt
		_ST_RUN --continue
		_ST_EQ "the resolved opt-out drop completes" "$RC" "0"
	fi
	_ST_OUT_HAS "completion forgets the run's records, and says so" 'Forgot 1 resolution'
	_ST_CHECK "rr-cache is back to its baseline after completion" \
		sh -c "[ $(ls "$RR58_DIR" 2>/dev/null | wc -l | tr -d ' ') -eq $RR58_BEFORE ]"
	git reset -q --hard
	# Abort forgets too – here the sole record is preimage-only (no
	# resolution was recorded), so it is removed without a note
	printf 'sa line A\n' > sa.txt && git add sa.txt && git commit -qm "SA base"
	printf 'sa line B\n' > sa.txt && git add sa.txt && git commit -qm "SA middle"
	local SA_MID=$(git rev-parse HEAD)
	printf 'sa line C\n' > sa.txt && git add sa.txt && git commit -qm "SA top"
	_ST_RUN -d -y "$SA_MID"
	_ST_EQ "the abort rig conflicts" "$RC" "2"
	_ST_RUN --abort
	_ST_EQ "the abort exits 0" "$RC" "0"
	_ST_CHECK "the abort leaves rr-cache at its baseline" \
		sh -c "[ $(ls "$RR58_DIR" 2>/dev/null | wc -l | tr -d ' ') -eq $RR58_BEFORE ]"
	git config --unset rerere.enabled
	git reset -q --hard
	# Without the opt-out, records persist and an abort that strands a fresh
	# resolution reports it – two files, so the second conflict pauses after
	# the first resolution recorded its postimage on the continue
	local RR58K_BEFORE=$(ls "$RR58_DIR" 2>/dev/null | wc -l | tr -d ' ')
	printf 'k1 A\n' > k1.txt && printf 'k2 A\n' > k2.txt && git add k1.txt k2.txt && git commit -qm "K base"
	printf 'k1 B\n' > k1.txt && printf 'k2 B\n' > k2.txt && git add k1.txt k2.txt && git commit -qm "K middle"
	local K_MID=$(git rev-parse HEAD)
	printf 'k1 C\n' > k1.txt && git add k1.txt && git commit -qm "K third"
	printf 'k2 C\n' > k2.txt && git add k2.txt && git commit -qm "K fourth"
	_ST_RUN -d -y "$K_MID"
	_ST_EQ "the keep rig conflicts on the first file" "$RC" "2"
	local K_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	if [ -n "$K_WT" ] && [ -d "$K_WT" ]; then
		printf 'k1 C\n' > "${K_WT:-$ST_NO_WT}/k1.txt"
		git -C "$K_WT" add k1.txt
		_ST_RUN --continue
		_ST_EQ "the second file conflicts next" "$RC" "2"
	fi
	_ST_RUN --abort
	_ST_OUT_HAS "the abort names the resolutions it leaves behind" 'outlive this run'
	_ST_CHECK "the records persist without the opt-out" \
		sh -c "[ $(ls "$RR58_DIR" 2>/dev/null | wc -l | tr -d ' ') -gt $RR58K_BEFORE ]"
	# Take the leftovers back out so no later scenario inherits a prefill
	local RR58_E
	for RR58_E in "$RR58_DIR"/*(N/); do rm -rf "$RR58_E"; done
	git reset -q --hard

	# --- 60. --verify gates the CAS on the caller's own check ---
	# A rewrite can land semantically wrong yet green – a bad resolution, a fold that breaks a
	# later commit – so `--verify=<cmd>` or `edit.verifyCmd` runs the caller's check over the
	# built result before the CAS, primary plus tip by default, all of it under `--verify-span`
	_ST_SCENARIO "\e[1;96m[60] --verify gates the CAS, pausing on failure\e[0m"
	git reset -q --hard
	printf '#!/bin/sh\nif grep -q FORBIDDEN vf.txt; then echo VERIFY_SAW_FORBIDDEN; exit 1; fi\nexit 0\n' > "$TMP/verify.sh" && chmod +x "$TMP/verify.sh"
	git config edit.verifyCmd "$TMP/verify.sh"
	printf 'vf one\n' > vf.txt && git add vf.txt && git commit -qm "VF base"
	local VF_BASE=$(git rev-parse HEAD)
	printf 'vo\n' > vo.txt && git add vo.txt && git commit -qm "VF top"
	local VF_TOP=$(git rev-parse HEAD)
	# A clean fold passes at the amended commit and the tip
	printf 'vf one\nvf two\n' > vf.txt && git add vf.txt
	_ST_RUN --amend-into="$VF_BASE" -- vf.txt
	_ST_EQ "a clean fold passes verification" "$RC" "0"
	_ST_OUT_HAS "both tiers ran" 'Verified 2 commit(s)'
	# A fold that lands failing content pauses before the CAS
	local VF_TIP=$(git rev-parse HEAD)
	printf 'vf one\nvf two\nFORBIDDEN\n' > vf.txt && git add vf.txt
	_ST_RUN --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "a failing fold pauses" "$RC" "2"
	_ST_OUT_HAS "the pause is a verify pause" 'git-edit: paused – verify failed'
	_ST_OUT_HAS "the failing commit is named" 'Verification failed at'
	_ST_OUT_HAS "the run's exit status and duration are printed" 'exit 1,'
	_ST_OUT_HAS "the trailer names the saved output" '; output in '
	local VF_LOG=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in [^;]*; output in \([^;]*\);.*/\1/p' | head -1)
	_ST_CHECK "the named file is there" test -f "$VF_LOG"
	_ST_CHECK "it holds the failing run's own output" sh -c "grep -q VERIFY_SAW_FORBIDDEN '$VF_LOG'"
	_ST_CHECK "headed by the exit status" sh -c "grep -q '^exit: 1' '$VF_LOG'"
	_ST_CHECK "and by the command that produced it" sh -c "grep -q '^command: ' '$VF_LOG'"
	_ST_EQ "the branch has not moved" "$(git rev-parse HEAD)" "$VF_TIP"
	_ST_CHECK "the staged change is untouched" sh -c "! git diff --cached --quiet -- vf.txt"
	# --status reports the verify pause as what it is, not as a bare conflict
	_ST_RUN --status
	_ST_OUT_HAS "status names the verify pause" 'paused – verify failed at'
	_ST_OUT_LACKS "and reports no empty conflict" 'git-edit: conflict'
	_ST_OUT_HAS "and still names the saved output" '; output in '
	# Plain --continue re-verifies and pauses again
	_ST_RUN --continue
	_ST_EQ "a plain continue re-verifies and pauses" "$RC" "2"
	# --abort cancels the paused verdict with nothing consumed
	_ST_RUN --abort
	_ST_EQ "the verify pause aborts clean" "$RC" "0"
	_ST_CHECK "the saved output goes with the state" sh -c "[ ! -f '$VF_LOG' ]"
	_ST_EQ "the abort left the branch alone" "$(git rev-parse HEAD)" "$VF_TIP"
	_ST_CHECK "and the staged change is still staged" sh -c "! git diff --cached --quiet -- vf.txt"
	# The same failing fold pauses again, and `--no-verify --continue` applies it – after
	# following the inspect hint, whose checkout moves the worktree off the built result, so
	# the resume must restore it or the failing commit lands as the tip
	_ST_RUN --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "the retried fold pauses again" "$RC" "2"
	local VP_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
	local VP_BAD=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at \([0-9a-f]*\) in .*/\1/p' | head -1)
	if [ -n "$VP_WT" ] && [ -n "$VP_BAD" ]; then
		git -C "$VP_WT" checkout -q "$VP_BAD" 2>/dev/null
	fi
	_ST_RUN --no-verify --continue
	_ST_EQ "the override applies the fold" "$RC" "0"
	_ST_OUT_HAS "after restoring the inspected-away worktree" 'restoring'
	_ST_EQ "the whole chain survived" "$(git rev-list --count HEAD)" "$(git rev-list --count $VF_TIP)"
	_ST_CHECK "the overridden content landed at the base" \
		sh -c "git show \"\$(git rev-parse ':/VF base'):vf.txt\" | grep -q FORBIDDEN"
	# --no-verify up front skips the gate entirely
	printf 'vf one\nvf two\nFORBIDDEN\nmore FORBIDDEN\n' > vf.txt && git add vf.txt
	_ST_RUN --no-verify --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "--no-verify skips the gate up front" "$RC" "0"
	_ST_OUT_LACKS "and the check never ran" 'Verified'
	# The flag outranks the config
	git config edit.verifyCmd "false"
	printf 'vf flag\n' >> vf.txt && git add vf.txt
	_ST_RUN --verify=true --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "--verify=<cmd> overrides edit.verifyCmd" "$RC" "0"
	git config edit.verifyCmd "$TMP/verify.sh"
	# The span tier runs the command once per rebuilt commit
	printf '#!/bin/sh\necho x >> %s/vcount\n' "$TMP" > "$TMP/count.sh" && chmod +x "$TMP/count.sh"
	rm -f "$TMP/vcount"
	printf 'vf span\n' >> vf.txt && git add vf.txt
	_ST_RUN --verify="$TMP/count.sh" --verify-span --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "the span fold applies" "$RC" "0"
	_ST_EQ "every rebuilt commit was verified" "$(wc -l < "$TMP/vcount" | tr -d ' ')" "$(git rev-list --count "$(git rev-parse ':/VF base')^..HEAD")"
	# --verify-span without any command is refused loudly
	printf 'vf refuse\n' >> vf.txt && git add vf.txt
	git config --unset edit.verifyCmd
	_ST_RUN --verify-span --amend-into="$(git rev-parse HEAD)" -- vf.txt
	_ST_EQ "--verify-span without a command refuses" "$RC" "1"
	git reset -q -- vf.txt && git checkout -q -- vf.txt
	# The other rebase modes run the same gate – a reorder verifies its tip
	# (a pass-through command: vf.txt legitimately carries "FORBIDDEN" by now)
	git config edit.verifyCmd "true"
	printf 'ra\n' > ra.txt && git add ra.txt && git commit -qm "VR one"
	printf 'rb\n' > rb.txt && git add rb.txt && git commit -qm "VR two"
	_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
	_ST_EQ "a reorder passes through verification" "$RC" "0"
	_ST_OUT_HAS "and verified its result" 'Verified 1 commit(s)'
	_ST_OUT_LACKS "with no skip note from a repo-pathless command" 'Verify skipped'
	# Plumbing modes have nothing to verify – a reword must not run the check
	_ST_RUN -M --text="VR two reworded" "$(git rev-parse HEAD)"
	_ST_EQ "a reword still completes" "$RC" "0"
	_ST_OUT_LACKS "without running verification" 'Verified'
	# A split authors an intermediate tree no commit carried, so the gate covers
	# it – here the tip passes by construction while the extracted half does not
	printf 'sa\n' > sa.txt && printf 'sb\n' > sb.txt && git add sa.txt sb.txt
	git commit -qm "SP both files"
	local SP_TIP=$(git rev-parse HEAD)
	local SP_COUNT=$(git rev-list --count HEAD)
	# The check lives outside the repo, so it names no path the skip heuristic
	# could exempt – the absence of sb.txt is the failure, not a missing target
	printf '#!/bin/sh\ntest -f sb.txt\n' > "$TMP/spcheck.sh" && chmod +x "$TMP/spcheck.sh"
	git config edit.verifyCmd "$TMP/spcheck.sh"
	_ST_RUN --split="$SP_TIP" --text "SP extracted sa" -- sa.txt
	_ST_EQ "the split is refused on its broken intermediate" "$RC" "1"
	_ST_OUT_HAS "saying nothing was applied" 'the split was not applied'
	_ST_EQ "and the branch never moved" "$(git rev-parse HEAD)" "$SP_TIP"
	git config edit.verifyCmd "true"
	_ST_RUN --split="$SP_TIP" --text "SP extracted sa" -- sa.txt
	_ST_EQ "a passing check lets the same split through" "$RC" "0"
	_ST_EQ "and it really split" "$(git rev-list --count HEAD)" "$((SP_COUNT + 1))"
	# A command that cannot survive the state file is refused, not truncated
	printf 'nl\n' > nl.txt && git add nl.txt && git commit -qm "NL base"
	local NL_TIP=$(git rev-parse HEAD)
	printf 'nl2\n' > nl.txt && git add nl.txt
	_ST_RUN --verify=$'echo one\necho two' --amend-into="$NL_TIP" -- nl.txt
	_ST_EQ "a multi-line verify command is refused" "$RC" "1"
	_ST_OUT_HAS "naming the reason" 'spans multiple lines'
	_ST_EQ "with the branch untouched" "$(git rev-parse HEAD)" "$NL_TIP"
	_ST_CHECK "and the staged change still staged" sh -c "! git diff --cached --quiet -- nl.txt"
	git reset -q -- nl.txt && git checkout -q -- nl.txt
	# Completed runs still take their worktrees with them – the interrupt-safety
	# rule keeps one only while resumable state is on disk
	_ST_EQ "no worktree outlives a finished run" "$(git worktree list | wc -l | tr -d ' ')" "1"
	# A target predating the verify command's own files skips, not fails – each
	# command token naming a file at the result tip is required at a verified
	# commit, so the note replaces a false MODULE_NOT_FOUND-style failure
	printf '#!/bin/sh\nexit 0\n' > runner.sh && git add runner.sh && git commit -qm "VS runner"
	git config edit.verifyCmd "sh runner.sh"
	printf 'vf skip\n' >> vf.txt && git add vf.txt
	_ST_RUN --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "a fold into a pre-runner commit applies" "$RC" "0"
	_ST_OUT_HAS "the absent target is skipped, not failed" 'Verify skipped at'
	_ST_OUT_HAS "the note names what is missing" "doesn't exist at this commit"
	_ST_OUT_HAS "and the tip still verified" 'Verified 1 of 2 commit(s)'
	# The span tier verifies what exists and skips the rest
	printf 'vf skip span\n' >> vf.txt && git add vf.txt
	_ST_RUN --verify-span --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
	_ST_EQ "the span fold applies across the gap" "$RC" "0"
	local VS_TOTAL=$(git rev-list --count "$(git rev-parse ':/VF base')^..HEAD")
	local VS_WITH=$(git rev-list --count "$(git rev-parse ':/VS runner')^..HEAD")
	_ST_OUT_HAS "the span verified only where the runner exists" "Verified $VS_WITH of $VS_TOTAL commit(s)"
	# The drop/squash dispatch path records the result too – a spanned drop
	# whose worktree was inspected away still applies whole on the override
	printf '#!/bin/sh\n! grep -q BAD vd.txt\n' > "$TMP/vdcheck.sh" && chmod +x "$TMP/vdcheck.sh"
	git config edit.verifyCmd "$TMP/vdcheck.sh"
	printf 'vd\n' > vd.txt && git add vd.txt && git commit -qm "VD one"
	printf 'x\n' > vdx.txt && git add vdx.txt && git commit -qm "VD two"
	printf 'vd\nBAD\n' > vd.txt && git add vd.txt && git commit -qm "VD three"
	printf 'vd\n' > vd.txt && git add vd.txt && git commit -qm "VD four"
	local VD_COUNT=$(git rev-list --count HEAD)
	_ST_RUN -d -y --verify-span "$(git rev-parse ':/VD two')"
	_ST_EQ "the spanned drop pauses on the mid-span failure" "$RC" "2"
	local VD_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
	local VD_BAD=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at \([0-9a-f]*\) in .*/\1/p' | head -1)
	if [ -n "$VD_WT" ] && [ -n "$VD_BAD" ]; then
		git -C "$VD_WT" checkout -q "$VD_BAD" 2>/dev/null
	fi
	_ST_RUN --no-verify --continue
	_ST_EQ "the override applies the drop" "$RC" "0"
	_ST_OUT_HAS "after restoring this worktree too" 'restoring'
	_ST_EQ "nothing above the drop was truncated" "$(git rev-list --count HEAD)" "$((VD_COUNT - 1))"
	_ST_EQ "the tip is the last commit, not the failing one" "$(git log -1 --format=%s)" "VD four"
	# A recorded result that no longer resolves refuses the resume, since falling back to
	# worktree `HEAD` would reopen the truncation trap – a tip fold has no replays, so the
	# pause is guaranteed to be verify's rather than a conflict
	git config edit.verifyCmd false
	printf 'vd\nstale\n' > vd.txt && git add vd.txt
	_ST_RUN --amend-into="$(git rev-parse HEAD)" -- vd.txt
	_ST_EQ "the doomed tip fold pauses" "$RC" "2"
	_ST_OUT_HAS "as a verify pause" 'git-edit: paused – verify failed'
	local VD_SF=$(git rev-parse --git-dir)/git-edit-state
	sed 's/^verify_result=.*/verify_result=ffffffffffffffffffffffffffffffffffffffff/' "$VD_SF" > "$VD_SF.tmp" && mv "$VD_SF.tmp" "$VD_SF"
	_ST_RUN --continue
	_ST_EQ "a vanished recorded result refuses the resume" "$RC" "1"
	_ST_OUT_HAS "and names what happened" 'no longer resolves'
	_ST_RUN --abort
	_ST_EQ "while abort still cancels clean" "$RC" "0"
	git reset -q -- vd.txt && git checkout -q -- vd.txt
	# A verify pause discards worktree edits, so a continue refuses while any are present rather
	# than swallowing them – the content-edit pause invites exactly the opposite instinct,
	# and a tip fold has no replays, so the pause is verify's for certain
	printf 'vd\ndirty\n' > vd.txt && git add vd.txt
	_ST_RUN --amend-into="$(git rev-parse HEAD)" -- vd.txt
	_ST_EQ "the tip fold pauses on verification" "$RC" "2"
	_ST_OUT_HAS "and warns that editing there is not the repair" 'not the repair'
	local VE_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
	_ST_CHECK "the pause named a worktree" sh -c "[ -d '$VE_WT' ]"
	# Untracked files are the command's own litter and the linked deps – only
	# tracked edits are work the caller would lose
	printf 'log\n' > "${VE_WT:-$ST_NO_WT}/verify-run.log"
	_ST_RUN --continue
	_ST_EQ "untracked litter does not block the resume" "$RC" "2"
	_ST_OUT_HAS "which re-verifies as usual" 'git-edit: paused – verify failed'
	rm -f "$VE_WT/verify-run.log"
	printf 'hand-edited\n' >> "${VE_WT:-$ST_NO_WT}/vd.txt"
	_ST_RUN --continue
	_ST_EQ "a continue over worktree edits refuses" "$RC" "1"
	_ST_OUT_HAS "naming what would have been lost" 'carries edits'
	_ST_OUT_HAS "and the repair path" 'no-verify --continue'
	_ST_RUN --no-verify --continue
	_ST_EQ "the override refuses too, while they are still there" "$RC" "1"
	git -C "$VE_WT" checkout -- . 2>/dev/null
	_ST_RUN --no-verify --continue
	_ST_EQ "and applies once they are gone" "$RC" "0"
	git reset -q -- vd.txt && git checkout -q -- vd.txt

	# A flag-only --verify survives the pause – with no standing config, a
	# resume that forgot it would apply the result with no verification at all
	git config --unset edit.verifyCmd
	printf 'vd\nflagkeep\n' > vd.txt && git add vd.txt
	_ST_RUN --verify=false --amend-into="$(git rev-parse HEAD)" -- vd.txt
	_ST_EQ "the flag-only verify pauses" "$RC" "2"
	_ST_RUN --continue
	_ST_EQ "the resume still verifies – the flag survived the pause" "$RC" "2"
	_ST_OUT_HAS "as a verify pause again" 'git-edit: paused – verify failed'
	_ST_RUN --abort
	git reset -q -- vd.txt && git checkout -q -- vd.txt
	# The span tier survives too – a plain continue must re-verify the whole
	# span, not silently downgrade to primary+tip
	printf 'vs1\n' > vs.txt && git add vs.txt && git commit -qm "VS span one"
	printf 'vs1\nmid\n' > vs.txt && git add vs.txt && git commit -qm "VS span two"
	printf 'vs1\nmid\nend\n' > vs.txt && git add vs.txt && git commit -qm "VS span three"
	printf 'vd\nspankeep\n' > vd.txt && git add vd.txt
	_ST_RUN --verify=false --verify-span --amend-into="$(git rev-parse ':/VS span one')" -- vd.txt
	_ST_EQ "the spanned fold pauses" "$RC" "2"
	_ST_RUN --continue
	_ST_EQ "and the resume re-pauses" "$RC" "2"
	_ST_OUT_HAS "verifying the span, not just primary+tip" '# verify 3 commit(s)'
	_ST_RUN --abort
	git reset -q -- vd.txt && git checkout -q -- vd.txt
	git config --unset edit.verifyCmd
	git reset -q --hard

	# An explicit `--verify` on a mode with no gate refuses up front, since ignoring it would
	# promise a gate the run never keeps – the standing config stays exempt, so a reword
	# under `edit.verifyCmd` must land untouched
	local XM_TIP=$(git rev-parse HEAD)
	_ST_RUN --verify=false -M "$XM_TIP" --text="XM reworded"
	_ST_EQ "an explicit --verify on -M refuses" "$RC" "1"
	_ST_OUT_HAS "naming the reason" 'cannot gate this mode'
	_ST_EQ "with the branch untouched" "$(git rev-parse HEAD)" "$XM_TIP"
	_ST_RUN --verify-span --exec -- true
	_ST_EQ "--verify-span on --exec refuses too" "$RC" "1"
	git config edit.verifyCmd "false"
	_ST_RUN -M "$XM_TIP" --text="XM reworded quietly"
	_ST_EQ "a standing config leaves the reword alone" "$RC" "0"
	git config --unset edit.verifyCmd

	# A split whose verify worktree cannot open fails closed – applying it
	# unverified under an `ok` trailer would read as gated when nothing ran
	printf 'vw1\n' > vw1.txt && printf 'vw2\n' > vw2.txt && git add vw1.txt vw2.txt && git commit -qm "VW both"
	git config edit.verifyCmd "true"
	local VW_TIP=$(git rev-parse HEAD)
	mkdir -p "$TMP/shim"
	# `whence -p` resolves the real binary – the tick wrapper shadows `git`, so
	# `command -v` names the function and the shim would exec itself forever
	printf '#!/bin/zsh\nif [[ "$1" == "worktree" && "$2" == "add" && "$*" == *git-edit-verify* ]]; then exit 1; fi\nexec %s "$@"\n' "$(whence -p git)" > "$TMP/shim/git"
	chmod +x "$TMP/shim/git"
	PATH="$TMP/shim:$PATH" _ST_RUN --split="$VW_TIP" --text="VW extracted" -- vw1.txt
	_ST_EQ "a split with no verify worktree refuses" "$RC" "1"
	_ST_OUT_HAS "naming the failure" 'Could not open a worktree to verify the split'
	_ST_EQ "with the branch untouched" "$(git rev-parse HEAD)" "$VW_TIP"
	PATH="$TMP/shim:$PATH" _ST_RUN --no-verify --split="$VW_TIP" --text="VW extracted" -- vw1.txt
	_ST_EQ "and --no-verify is the stated escape" "$RC" "0"
	git config --unset edit.verifyCmd

	# A failure raises two questions the report has to answer – whether the rewrite caused it,
	# and where the span heals, so the fold below needs a line a later commit adds, failing at
	# the amended commit and passing again at the commit carrying that line
	printf '#!/bin/sh\ngrep -q USE nv_app.txt 2>/dev/null || exit 0\ngrep -q NEEDED nv_boot.txt\n' > "$TMP/need.sh"
	chmod +x "$TMP/need.sh"
	git config edit.verifyCmd "$TMP/need.sh"
	printf 'base\n' > nv_app.txt && printf 'boot\n' > nv_boot.txt
	git add nv_app.txt nv_boot.txt && git commit -qm "NV base"
	local NV_BASE=$(git rev-parse HEAD)
	printf 'boot\nNEEDED\n' > nv_boot.txt && git commit -qam "NV bootstrap line"
	printf 'nv\n' > nv_late.txt && git add nv_late.txt && git commit -qm "NV later work"
	printf 'USE\n' > nv_app.txt && git add nv_app.txt
	_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
	_ST_EQ "the fold pauses at the amended commit" "$RC" "2"
	_ST_OUT_HAS "the walk names the commit that heals it" 'first green: [0-9a-f]* NV bootstrap line'
	_ST_OUT_LACKS "and does not disown the failure" 'not this operation'
	_ST_RUN --abort
	# A check already failing at the commit being replaced is not this
	# rewrite's doing – saying so is what keeps the gate worth reading
	git config edit.verifyCmd "false"
	_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
	_ST_EQ "the always-failing check pauses too" "$RC" "2"
	_ST_OUT_HAS "disowning it without overclaiming" 'pre-existing, or the check cannot run'
	_ST_OUT_HAS "naming the counterpart" 'counterpart: [0-9a-f]* NV base'
	_ST_OUT_LACKS "and skipping the walk it would mislead with" 'first green'
	_ST_RUN --abort
	# The default tier states what it left out, and the standing config raises
	# it – a bare "Verified 2 commit(s)" over a span of four reads as verified
	git config edit.verifyCmd "true"
	_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
	_ST_EQ "the passing fold applies" "$RC" "0"
	_ST_OUT_HAS "naming the unverified middle" 'rebuilt commit(s) in between went unverified'
	_ST_OUT_HAS "and the tier that covers it" 'verify-span'
	git config edit.verifySpan true
	printf 'USE\nagain\n' > nv_app.txt && git add nv_app.txt
	_ST_RUN --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
	_ST_EQ "the config-raised span applies" "$RC" "0"
	_ST_OUT_HAS "verifying the whole span" 'Verified 3 commit(s)'
	_ST_OUT_LACKS "so nothing is reported unverified" 'went unverified'
	# The config names a tier, not a check – with no command it has to stay
	# inert, or setting it would refuse every operation in the repo
	git config --unset edit.verifyCmd
	printf 'USE\nonce more\n' > nv_app.txt && git add nv_app.txt
	_ST_RUN --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
	_ST_EQ "the tier config alone verifies nothing" "$RC" "0"
	_ST_OUT_LACKS "and refuses nothing" 'needs a command'
	# Nor may it turn a pause into a dead end – a recorded tier no command can
	# serve would refuse every resume of an operation already underway, leaving
	# an abort as the only way out of a fold that was going fine
	printf 'boot\nrewritten\n' > nv_boot.txt && git add nv_boot.txt
	_ST_RUN --amend-into="$(git rev-parse ':/NV base')" -- nv_boot.txt
	_ST_EQ "the fold conflicts under the tier config" "$RC" "2"
	local NV_SF=$(git rev-parse --git-dir)/git-edit-state
	_ST_CHECK "and the pause records no tier it cannot serve" sh -c "! grep -q verify_span '$NV_SF'"
	local NV_ROUNDS=0
	while [ "$RC" = "2" ] && [ $NV_ROUNDS -lt 4 ]; do
		NV_ROUNDS=$((NV_ROUNDS+1))
		local NV_WT=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
		[ -z "$NV_WT" ] && break
		printf 'boot\nNEEDED\n' > "${NV_WT:-$ST_NO_WT}/nv_boot.txt"
		git -C "$NV_WT" add nv_boot.txt
		_ST_RUN --continue
	done
	_ST_EQ "the resume completes instead of refusing" "$RC" "0"
	_ST_OUT_LACKS "with no demand for a command" 'needs a command'
	git config --unset edit.verifySpan
	# An explicit zero budget turns the climb off – the wait is the caller's,
	# and the same fold climbs again once the budget is back to its default
	printf 'nb\n' > nb_app.txt && printf 'nb\n' > nb_boot.txt
	git add nb_app.txt nb_boot.txt && git commit -qm "NB base"
	local NB_BASE=$(git rev-parse HEAD)
	printf 'nb\nREADY\n' > nb_boot.txt && git commit -qam "NB bootstrap line"
	printf '#!/bin/sh\ngrep -q USE nb_app.txt 2>/dev/null || exit 0\ngrep -q READY nb_boot.txt\n' > "$TMP/need2.sh"
	chmod +x "$TMP/need2.sh"
	git config edit.verifyCmd "$TMP/need2.sh"
	git config edit.verifyBudget 0
	printf 'USE\n' > nb_app.txt && git add nb_app.txt
	_ST_RUN --amend-into="$NB_BASE" -- nb_app.txt
	_ST_EQ "the failing fold still pauses" "$RC" "2"
	_ST_OUT_LACKS "with no climb to report" 'first green'
	_ST_RUN --abort
	git config --unset edit.verifyBudget
	_ST_RUN --amend-into="$NB_BASE" -- nb_app.txt
	_ST_EQ "the same fold pauses on the default budget" "$RC" "2"
	_ST_OUT_HAS "and climbs to the commit that heals it" 'first green: [0-9a-f]* NB bootstrap line'
	_ST_RUN --abort
	git config --unset edit.verifyCmd
	git reset -q --hard

	# --- 61. a rewrite that lands a mode change says so ---
	# A diffstat shows line counts only, so a dropped executable bit on a
	# file that also changed content rides invisibly – the completion
	# summary names it, tip vs pre-op tip
	_ST_SCENARIO "\e[1;96m[61] mode changes land with a note\e[0m"
	git reset -q --hard
	printf '#!/bin/sh\necho mc\n' > mc.sh && chmod +x mc.sh && git add mc.sh && git commit -qm "MC base"
	local MC_BASE=$(git rev-parse HEAD)
	printf 'mo\n' > mo.txt && git add mo.txt && git commit -qm "MC top"
	printf '#!/bin/sh\necho mc CHANGED\n' > mc.sh && chmod -x mc.sh && git add mc.sh
	_ST_RUN --amend-into="$MC_BASE" -- mc.sh
	_ST_EQ "the mode-dropping fold lands" "$RC" "0"
	_ST_OUT_HAS "and names the mode change" 'mode change 100755 => 100644'
	_ST_CHECK "the mode really changed at HEAD" sh -c "git ls-tree HEAD mc.sh | grep -q '^100644'"
	# A mode-neutral fold stays silent
	printf '#!/bin/sh\necho mc AGAIN\n' > mc.sh && git add mc.sh
	_ST_RUN --amend-into="$(git rev-parse ':/MC base')" -- mc.sh
	_ST_EQ "the mode-neutral fold lands" "$RC" "0"
	_ST_OUT_LACKS "with no mode note" 'Mode changes landed'
	git reset -q --hard


	# --- 62. --exec's result guard refuses to orphan a remote ref ---
	# --exec can't know its targets up front, so the pushed guard runs on
	# the result – a remote ref reachable from the old tip but not the new
	# one refuses the apply
	_ST_SCENARIO "\e[1;96m[62] exec result guard\e[0m"
	echo "xg" > xg.txt && git add xg.txt && git commit -qm "XG commit"
	git update-ref refs/remotes/guard/main HEAD
	local XG_TIP=$(git rev-parse HEAD)
	_ST_RUN --exec -- git commit --amend -m "XG amended"
	_ST_EQ "exec orphaning a remote ref refuses" "$RC" "1"
	_ST_OUT_HAS "naming the ref" 'rewrote pushed history.*guard/main'
	_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$XG_TIP"
	_ST_RUN --allow-pushed --exec -- git commit --amend -m "XG amended"
	_ST_EQ "--allow-pushed overrides" "$RC" "0"
	git update-ref -d refs/remotes/guard/main


	# --- 63. the pause hint reads a todo's object, not its second word ---
	# `amend!` autosquashes into `fixup -C <sha>`, whose second word is a flag –
	# read as the object it drops that step from the hint, and hands `git log`
	# its own copy-detection flag on the way
	_ST_SCENARIO "\e[1;96m[63] conflict hint parses every todo command\e[0m"
	git reset -q --hard
	printf 'ah\n' > ah.txt && git add ah.txt && git commit -qm "AH base"
	local AH_BASE=$(git rev-parse HEAD)
	printf 'ah\nmid\n' > ah.txt && git commit -qam "AH middle"
	printf 'ax\n' > ax.txt && git add ax.txt
	git commit -q -m "amend! AH middle" -m "AH middle, reworded"
	printf 'ah\nmid\ntip\n' > ah.txt && git commit -qam "AH tip"
	printf 'ah\nfolded\n' > ah.txt && git add ah.txt
	_ST_RUN --amend-into="$AH_BASE" -- ah.txt
	_ST_EQ "the fold conflicts as set up" "$RC" "2"
	_ST_OUT_HAS "the hint reaches the steps touching the file" 'Remaining steps also touch'
	_ST_OUT_HAS "naming the one below the amend!" '[0-9a-f]\{7\} AH middle'
	_ST_OUT_HAS "and the one above it" '[0-9a-f]\{7\} AH tip'
	_ST_OUT_LACKS "while the amend! step, touching another file, stays out" '[0-9a-f]\{7\} amend! AH middle'
	_ST_RUN --abort
	git reset -q --hard

	# --- 64. a reword names what it discarded: message body, signature ---
	# Both summary lines above are subjects, so a caller comparing those reads a body-dropping
	# `--text` as clean – and a rebuild mints new objects, so a signature cannot come along
	# either, with neither showing in a tree or a subject
	_ST_SCENARIO "\e[1;96m[64] a reword names the body and the signature it drops\e[0m"
	git reset -q --hard
	printf 'nb\n' > nb.txt && git add nb.txt
	git commit -q -F - <<-'NBMSG'
		NB subject

		• first body line
		• second body line
	NBMSG
	local NB_TARGET=$(git rev-parse HEAD)
	_ST_RUN -M --text="NB subject reworded" "$NB_TARGET"
	_ST_EQ "the body-dropping reword applies" "$RC" "0"
	_ST_OUT_HAS "names the dropped body, with its length" 'carried a 2-line body'
	_ST_OUT_HAS "and where it stays readable" 'still readable at [0-9a-f]\{12\}'
	# Neighbor: a `--text` that restates the body discards nothing
	_ST_RUN -M --text="$(printf 'NB kept\n\n• first body line')" HEAD
	_ST_EQ "a body-preserving reword applies" "$RC" "0"
	_ST_OUT_LACKS "a restated body draws no notice" 'carried a .*-line body'
	# Negative: a subject-only message has no body to lose
	printf 'nb2\n' > nb2.txt && git add nb2.txt && git commit -qm "NB plain"
	_ST_RUN -M --text="NB plain reworded" HEAD
	_ST_OUT_LACKS "nor does a subject-only message" 'carried a .*-line body'
	# The signature header is read raw, not through `%G?`, so this holds on a
	# machine with no gpg at all – which is why the fixture can forge one
	printf 'ns\n' > ns.txt && git add ns.txt && git commit -qm "NS target"
	local NS_TARGET=$(git rev-parse HEAD)
	printf 'ns2\n' > ns2.txt && git add ns2.txt && git commit -qm "NS signed descendant"
	local NS_RAW=$TMP/ns-raw
	git cat-file commit HEAD | awk '{ print } /^committer /{ print "gpgsig -----BEGIN PGP SIGNATURE-----"; print " selftest-only, never verified"; print " -----END PGP SIGNATURE-----" }' > "$NS_RAW"
	git update-ref refs/heads/main "$(git hash-object -w -t commit "$NS_RAW")"
	_ST_RUN -M --text="NS target reworded" "$NS_TARGET"
	_ST_EQ "a reword under a signed descendant applies" "$RC" "0"
	_ST_OUT_HAS "names the signature the rebuild could not carry" 'carried [0-9]* signature'
	# The notice sits on the shared ref-move path, so it covers every mode –
	# pin a second, non-reword one rather than trusting that by construction
	printf 'nr\n' > nr.txt && git add nr.txt && git commit -qm "NR first"
	printf 'nr2\n' > nr2.txt && git add nr2.txt && git commit -qm "NR second"
	printf 'nr3\n' > nr3.txt && git add nr3.txt && git commit -qm "NR signed tip"
	local NR_RAW=$TMP/nr-raw
	git cat-file commit HEAD | awk '{ print } /^committer /{ print "gpgsig -----BEGIN PGP SIGNATURE-----"; print " selftest-only, never verified"; print " -----END PGP SIGNATURE-----" }' > "$NR_RAW"
	git update-ref refs/heads/main "$(git hash-object -w -t commit "$NR_RAW")"
	_ST_RUN -S HEAD~2 HEAD~1
	_ST_EQ "a resquash under a signed tip applies" "$RC" "0"
	_ST_OUT_HAS "and a non-reword mode names the signature too" 'carried [0-9]* signature'
	# Negative: unsigned history says nothing about signatures
	_ST_RUN -M --text="NS reworded again" HEAD~1
	_ST_OUT_LACKS "unsigned history draws no signature notice" 'carried [0-9]* signature'
	git reset -q --hard

	# --- 65. a rewrite names the notes git's policy left behind ---
	# Copying is git's own call, so the tool reports rather than overrides – the
	# same posture as an orphaned tag, which it names but never re-points
	_ST_SCENARIO "\e[1;96m[65] a rewrite names the notes left behind\e[0m"
	git reset -q --hard
	# Scenario 50 turned the config on and left it there, so the unconfigured
	# half has to clear it rather than assume a fresh repo
	git config --unset notes.rewriteRef 2>/dev/null
	printf 'nn\n' > nn.txt && git add nn.txt && git commit -qm "NN target"
	local NN_TARGET=$(git rev-parse HEAD)
	printf 'nn2\n' > nn2.txt && git add nn2.txt && git commit -qm "NN annotated descendant"
	# A non-default ref on purpose: `notes.rewriteRef` is a glob, so the check
	# has to look past `refs/notes/commits`
	git notes --ref=ge-left add -m "a note worth not losing quietly" HEAD >/dev/null 2>&1
	_ST_RUN -M --text="NN target reworded" "$NN_TARGET"
	_ST_EQ "the reword over an annotated descendant applies" "$RC" "0"
	_ST_OUT_HAS "names the notes left on the replaced commits" 'Notes stayed on [0-9]* replaced commit'
	_ST_OUT_HAS "and points at the config that would carry them" 'notes\.rewriteRef'
	# Configured, git carries them itself and the notice stays quiet
	git config notes.rewriteRef 'refs/notes/*'
	printf 'nc\n' > nc.txt && git add nc.txt && git commit -qm "NC target"
	local NC_TARGET=$(git rev-parse HEAD)
	printf 'nc2\n' > nc2.txt && git add nc2.txt && git commit -qm "NC annotated descendant"
	git notes --ref=ge-left add -m "carried by config" HEAD >/dev/null 2>&1
	_ST_RUN -M --text="NC target reworded" "$NC_TARGET"
	_ST_OUT_LACKS "a carried note draws no notice" 'Notes stayed on [0-9]* replaced commit'
	_ST_CHECK "and the note reached the rebuilt commit" \
		sh -c "git notes --ref=ge-left show HEAD >/dev/null 2>&1"
	# Negative: a rewrite touching no annotated commit says nothing
	git config --unset notes.rewriteRef 2>/dev/null
	printf 'nq\n' > nq.txt && git add nq.txt && git commit -qm "NQ target"
	local NQ_TARGET=$(git rev-parse HEAD)
	printf 'nq2\n' > nq2.txt && git add nq2.txt && git commit -qm "NQ plain descendant"
	_ST_RUN -M --text="NQ target reworded" "$NQ_TARGET"
	_ST_OUT_LACKS "an unannotated span draws no notice" 'Notes stayed on [0-9]* replaced commit'
	git reset -q --hard

	# --- 66. a re-signing rebase draws no signature notice ---
	# The plumbing modes cannot sign, so the notice fires for them – but a rebase re-signs
	# under `commit.gpgsign` and a mode that drops a commit takes its signature along, so a
	# shortfall alone would cry wolf, and only a real key proves the quiet half
	_ST_SCENARIO "\e[1;96m[66] a re-signing rebase draws no signature notice\e[0m"
	git reset -q --hard
	local GPG_HOME=$TMP/gnupg
	local GPG_OK=false
	if command -v gpg >/dev/null 2>&1; then
		mkdir -p "$GPG_HOME" && chmod 700 "$GPG_HOME"
		print -r -- 'pinentry-mode loopback' > "$GPG_HOME/gpg.conf"
		print -r -- 'allow-loopback-pinentry' > "$GPG_HOME/gpg-agent.conf"
		# A long `$TMPDIR` can push the agent socket past the ~104-char sun_path
		# limit, so a failure here is "no usable gpg" rather than a test failure
		GNUPGHOME=$GPG_HOME gpg --batch --yes --passphrase '' --quick-generate-key \
			"git-edit selftest <selftest@example.invalid>" default default never \
			>/dev/null 2>&1 && GPG_OK=true
	fi
	if [ "$GPG_OK" != "true" ]; then
		ECHO_E "\e[0;90m  skipped – no usable gpg on this machine\e[0m"
	else
		local GPG_KEY=$(GNUPGHOME=$GPG_HOME gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
		local SR=$TMP/signed
		git init -q -b main "$SR"
		git -C "$SR" config user.email selftest@example.invalid
		git -C "$SR" config user.name "git-edit selftest"
		git -C "$SR" config user.signingkey "$GPG_KEY"
		git -C "$SR" config commit.gpgsign true
		git -C "$SR" config gpg.program gpg
		export GNUPGHOME=$GPG_HOME
		cd "$SR"
		local SN
		for SN in 1 2 3; do
			print -r -- "s$SN" > "s$SN.txt"
			git add "s$SN.txt" && git commit -qm "SG $SN"
		done
		_ST_CHECK "the fixture really produced signed commits" \
			sh -c "[ \"\$(git -C '$SR' log -1 --format='%G?')\" != 'N' ]"
		# A reorder replays through rebase, which re-signs under the config above
		_ST_RUN --reorder HEAD~1 HEAD
		_ST_EQ "the reorder applies" "$RC" "0"
		_ST_CHECK "its tip is still signed" \
			sh -c "[ \"\$(git -C '$SR' log -1 --format='%G?')\" != 'N' ]"
		_ST_OUT_LACKS "and no signature notice is printed" 'carried [0-9]* signature'
		# The plumbing counterpart, against a real signature rather than a forged
		# header: `commit-tree` takes no key, so this one must speak up
		_ST_RUN -M --text="SG 1 reworded" HEAD~2
		_ST_EQ "the reword applies" "$RC" "0"
		_ST_OUT_HAS "while a plumbing rewrite names the lost signatures" 'carried [0-9]* signature'
		_ST_CHECK "and its tip really did lose the signature" \
			sh -c "[ \"\$(git -C '$SR' log -1 --format='%G?')\" = 'N' ]"
		gpgconf --homedir "$GPG_HOME" --kill all >/dev/null 2>&1
		unset GNUPGHOME
		cd "$TMP/repo"
	fi

	# --- 67. linear spans rebuild in one replay, proven commit for commit ---
	# The plumbing modes hand a linear span to `git replay` and keep its result only once
	# every commit mirrors its original in tree, author and message – the walk stays for a
	# merge in the span, a git without `replay`, the opt-out, and a replay failing the proof
	_ST_SCENARIO "\e[1;96m[67] linear spans rebuild in one replay, proven commit for commit\e[0m"
	cd "$TMP/repo"
	git checkout -q main 2>/dev/null
	git reset -q --hard
	printf 'rp0\n' > rp0.txt && git add rp0.txt && git commit -qm "RP target"
	local RP_TARGET=$(git rev-parse HEAD)
	# Message shapes a rebuild has to carry: an empty message, a Latin-1 one
	# (transcoded to UTF-8, as the walk does), a distinct author, plain ones
	printf 'rp1\n' > rp1.txt && git add rp1.txt && git commit -q --allow-empty-message -m ""
	printf 'rp2\n' > rp2.txt && git add rp2.txt && git -c i18n.commitEncoding=ISO-8859-1 commit -qm "$(printf 'RP caf\xe9')"
	printf 'rp3\n' > rp3.txt && git add rp3.txt
	GIT_AUTHOR_DATE='@1600007777 +0000' git -c user.name='RP Author' -c user.email='rp@x' commit -qm "RP authored"
	local RP_N
	for RP_N in 4 5 6 7 8 9; do
		printf 'rp%s\n' "$RP_N" > "rp$RP_N.txt" && git add "rp$RP_N.txt" && git commit -qm "RP $RP_N"
	done
	local RP_TIP=$(git rev-parse HEAD)
	local RP_FMT='%T|%an|%ae|%aI|%s|%b'
	local RP_BEFORE=$(git log --reverse --format="$RP_FMT" "$RP_TARGET..HEAD")
	# One clock for both engines, so their results can be held to one SHA
	GIT_COMMITTER_DATE='@1700000000 +0000' _ST_RUN -M --text="RP target reworded" "$RP_TARGET"
	_ST_EQ "a reword over a linear span exits 0" "$RC" "0"
	_ST_OUT_HAS "and rebuilds it in one replay" 'git replay --advance'
	_ST_OUT_LACKS "not commit by commit" '# rebuilt'
	_ST_OUT_HAS "stating the proof rather than a construction" 'Trees unchanged ✓ – proven'
	_ST_EQ "the target was reworded" "$(git log -1 --format=%s HEAD~9)" "RP target reworded"
	_ST_EQ "every descendant mirrors its original – tree, author, message" "$(git log --reverse --format="$RP_FMT" HEAD~9..HEAD)" "$RP_BEFORE"
	_ST_EQ "the empty message stayed empty, byte for byte" "$(git cat-file commit HEAD~8 | sed '1,/^$/d' | wc -c | tr -d ' ')" "0"
	_ST_EQ "no transient ref was left behind" "$(git for-each-ref refs/git-edit | wc -l | tr -d ' ')" "0"
	local RP_REPLAYED=$(git rev-parse HEAD)
	# The walk, on the same inputs under the same clock, lands the same tip
	git reset -q --hard "$RP_TIP"
	GIT_COMMITTER_DATE='@1700000000 +0000' GIT_EDIT_NO_REPLAY=1 _ST_RUN -M --text="RP target reworded" "$RP_TARGET"
	_ST_EQ "GIT_EDIT_NO_REPLAY takes the walk" "$RC" "0"
	_ST_OUT_HAS "commit by commit" '# rebuilt'
	_ST_OUT_LACKS "with no replay" 'git replay'
	_ST_EQ "and lands the identical tip" "$(git rev-parse HEAD)" "$RP_REPLAYED"
	# A merge in the span keeps the walk – replay refuses merges
	git reset -q --hard "$RP_TIP"
	git checkout -q -b rp-side HEAD~3
	printf 'rps\n' > rps.txt && git add rps.txt && git commit -qm "RP side"
	git checkout -q main
	git merge -q --no-ff rp-side -m "RP merge" >/dev/null 2>&1
	_ST_RUN -M --text="RP target reworded below a merge" "$RP_TARGET"
	_ST_EQ "a span holding a merge still rewords" "$RC" "0"
	_ST_OUT_HAS "through the walk" '# rebuilt'
	_ST_OUT_LACKS "never a replay" 'git replay'
	_ST_EQ "and keeps the merge's two parents" "$(git log -1 --format=%P HEAD | wc -w | tr -d ' ')" "2"
	git branch -qD rp-side
	# A git without `replay` – older than 2.44, shimmed here – falls back too
	# `whence -p` resolves the real binary past the tick wrapper's `git` function
	mkdir -p "$TMP/shim-noreplay"
	printf '#!/bin/zsh\nif [[ "$1" == "replay" ]]; then echo "git: '"'"'replay'"'"' is not a git command. See '"'"'git --help'"'"'." >&2; exit 1; fi\nexec %s "$@"\n' "$(whence -p git)" > "$TMP/shim-noreplay/git"
	chmod +x "$TMP/shim-noreplay/git"
	git reset -q --hard "$RP_TIP"
	PATH="$TMP/shim-noreplay:$PATH" _ST_RUN -M --text="RP target reworded without replay" "$RP_TARGET"
	_ST_EQ "a git without replay still rewords" "$RC" "0"
	_ST_OUT_HAS "through the walk" '# rebuilt'
	_ST_OUT_LACKS "with no replay attempted" 'git replay'
	# A replay whose answer fails the proof is discarded – this one answers the
	# probe honestly, then claims the pre-op tip as its result: one commit too
	# many for the span comparison
	mkdir -p "$TMP/shim-lyingreplay"
	printf '#!/bin/zsh\nif [[ "$1" == "replay" && "$2" != "-h" ]]; then echo "update refs/git-edit/lie $(%s rev-parse HEAD) 0000000"; exit 0; fi\nexec %s "$@"\n' "$(whence -p git)" "$(whence -p git)" > "$TMP/shim-lyingreplay/git"
	chmod +x "$TMP/shim-lyingreplay/git"
	git reset -q --hard "$RP_TIP"
	PATH="$TMP/shim-lyingreplay:$PATH" _ST_RUN -M --text="RP target reworded past a lie" "$RP_TARGET"
	_ST_EQ "a replay that fails the proof is discarded" "$RC" "0"
	_ST_OUT_HAS "and the walk rebuilds instead" '# rebuilt'
	_ST_OUT_LACKS "nothing replay-built is applied" 'git replay --advance'
	_ST_EQ "the result is still right" "$(git log --reverse --format="$RP_FMT" HEAD~9..HEAD)" "$RP_BEFORE"
	# Blank lines and a `#` line a verbatim message carries survive the replay
	# byte for byte – the walk's `-m` would fold the trailing blank lines away
	git reset -q --hard "$RP_TIP"
	printf 'RP verbatim\n\n\nbody   \n# kept, not a comment\n\n\n' | git commit -q --allow-empty --cleanup=verbatim -F -
	local RP_VERBATIM=$(git cat-file commit HEAD | sed '1,/^$/d' | git hash-object --stdin)
	_ST_RUN -M --text="RP target reworded under a verbatim message" "$RP_TARGET"
	_ST_EQ "a verbatim message survives the replay byte for byte" "$(git cat-file commit HEAD | sed '1,/^$/d' | git hash-object --stdin)" "$RP_VERBATIM"
	_ST_OUT_HAS "which was a replay" 'git replay --advance'
	git reset -q --hard

	# --- 68. `-e` names the edit mode, refusing what the bare form squashes ---
	# Bare, two commits read as a squash – named, the mode refuses a second one and any other mode
	_ST_SCENARIO "\e[1;96m[68] -e names the edit mode, refusing what the bare form squashes\e[0m"
	cd "$TMP/repo"
	git checkout -q main 2>/dev/null
	git reset -q --hard
	local EE_N
	for EE_N in 1 2 3; do
		printf 'ee%s\n' "$EE_N" > "ee$EE_N.txt" && git add "ee$EE_N.txt" && git commit -qm "EE $EE_N"
	done
	local EE_TIP=$(git rev-parse HEAD)
	_ST_RUN -e HEAD~1 HEAD
	_ST_EQ "-e with two commits exits 1" "$RC" "1"
	_ST_OUT_HAS "rather than squashing them" 'takes exactly one <commit>'
	_ST_EQ "and the branch stays put" "$(git rev-parse HEAD)" "$EE_TIP"
	_ST_RUN --edit HEAD~2..HEAD
	_ST_EQ "a range under --edit is refused alike" "$RC" "1"
	_ST_RUN -e -d HEAD~1
	_ST_EQ "-e beside another mode exits 1" "$RC" "1"
	_ST_OUT_HAS "naming the conflict" 'cannot be combined with another mode'
	_ST_RUN -e HEAD~1
	_ST_EQ "-e on one commit pauses as the bare form does" "$RC" "2"
	_ST_OUT_HAS "into an edit" 'git-edit: paused – edit'
	_ST_RUN --abort
	_ST_EQ "and aborts clean" "$RC" "0"
	_ST_CHECK "leaving no operation in flight" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"

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
		echo "git-edit: ok – selftest $PASS/$TOTAL passed"
		_STATUS_EMITTED=true
		return 0
	else
		PRINT_TEXT "%s" 31 "Selftest: $FAIL of $TOTAL checks FAILED."
		# A failing run keeps both, that tree being the evidence – the keep is disarming the cleanup
		# hook registered at the start, or the exit trap would remove it right after this promise
		_CLEANUP_HOOK=""
		PRINT_TEXT "Scratch repo kept for inspection: %s" 33 "$TMP"
		echo "git-edit: error – selftest $FAIL/$TOTAL failed"
		_STATUS_EMITTED=true
		return 1
	fi
}
