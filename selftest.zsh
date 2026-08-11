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
	_ST_CHECK () {
		local DESC=$1; shift
		if "$@" >/dev/null 2>&1; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | tail -5 | sed 's/^/       | /'
		fi
	}
	_ST_OUT_HAS () {
		local DESC=$1
		local PATTERN=$2
		if print -r -- "$OUT" | grep -q "$PATTERN"; then
			PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m $DESC"
		else
			FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m $DESC"
			echo "$OUT" | tail -5 | sed 's/^/       | /'
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
		fi
	}

	PRINT_TEXT "Selftest scratch repo: %s" 36 "$TMP"
	unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

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
	ECHO_E "\e[1;96m[1] reword (-M --text)\e[0m"
	local PRE_HEAD=$(git rev-parse HEAD)
	local PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN -M --text="C reworded" "$SHA_C"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok — refs/heads/main moved'
	_ST_OUT_HAS "states tree identity" 'Trees unchanged by construction'
	_ST_OUT_HAS "echoes the resulting subject" '[0-9a-f]\{7\} C reworded'
	# A symbolic target resolves once, so the summary has to name what it
	# replaced – otherwise rewording the wrong commit reads as success
	_ST_OUT_HAS "names the subject it replaced" 'replaced:.*C commit'
	_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
	_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
	_ST_EQ "message applied" "$(git log --format=%s -3 | tail -1)" "C reworded"

	# --- 2. Undo: reverts the reword, CAS-guarded ---
	ECHO_E "\e[1;96m[2] undo\e[0m"
	_ST_RUN --undo
	_ST_EQ "exits 0" "$RC" "0"
	_ST_EQ "HEAD restored" "$(git rev-parse HEAD)" "$PRE_HEAD"

	# --- 3. Pushed guard: refuse B, allow with --allow-pushed ---
	ECHO_E "\e[1;96m[3] pushed guard\e[0m"
	_ST_RUN -M --text="B reworded" "$SHA_B"
	_ST_CHECK "refuses pushed commit" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'already pushed'
	_ST_RUN --allow-pushed -M --text="B reworded" "$SHA_B"
	_ST_EQ "--allow-pushed overrides" "$RC" "0"
	_ST_RUN --undo
	_ST_EQ "undo restores" "$(git rev-parse HEAD)" "$PRE_HEAD"

	# --- 4. Fold (--amend-into) clean: a.txt change into C ---
	ECHO_E "\e[1;96m[4] amend-into (clean)\e[0m"
	echo "alpha folded" > a.txt
	git add a.txt
	_ST_RUN --amend-into="$SHA_C"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok — refs/heads/main moved'
	_ST_OUT_HAS "prints folded summary" 'Folded'
	_ST_OUT_HAS "reports the leftover checkout state" 'Index now empty'
	_ST_EQ "change landed in C" "$(git show 'HEAD~2:a.txt')" "alpha folded"
	_ST_CHECK "index clean afterwards" git diff --cached --quiet
	_ST_CHECK "no fixup commit on branch" test -z "$(git log --format=%s | grep '^fixup!')"

	# --- 5. Fold conflict -> status -> abort: branch + staged intact ---
	ECHO_E "\e[1;96m[5] amend-into conflict + abort\e[0m"
	PRE_HEAD=$(git rev-parse HEAD)
	local SHA_C2=$(git rev-parse HEAD~2)
	echo "line1-conflict" > c.txt
	git add c.txt
	_ST_RUN --amend-into="$SHA_C2"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	_ST_OUT_HAS "emits conflict trailer" '^git-edit: conflict — resolve in'
	_ST_EQ "branch untouched during pause" "$(git rev-parse HEAD)" "$PRE_HEAD"
	_ST_RUN --status
	_ST_OUT_HAS "status reports the conflict" '^git-edit: conflict — resolve in'
	_ST_RUN --abort
	_ST_EQ "abort exits 0" "$RC" "0"
	_ST_EQ "branch still untouched" "$(git rev-parse HEAD)" "$PRE_HEAD"
	_ST_CHECK "staged change preserved" sh -c "git diff --cached --name-only | grep -q c.txt"

	# --- 6. Fold conflict -> resolve -> continue (with cascade) ---
	ECHO_E "\e[1;96m[6] amend-into conflict + continue\e[0m"
	_ST_RUN --amend-into="$SHA_C2"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	local ROUNDS=0
	while [ "$RC" = "2" ] && [ $ROUNDS -lt 4 ]; do
		ROUNDS=$((ROUNDS+1))
		local CONFLICT_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
		if [ -z "$CONFLICT_WT" ] || [ ! -d "$CONFLICT_WT" ]; then
			break
		fi
		if [ $ROUNDS -eq 1 ]; then
			echo "line1-resolved" > "$CONFLICT_WT/c.txt"
		else
			echo "line2" > "$CONFLICT_WT/c.txt"
		fi
		git -C "$CONFLICT_WT" add c.txt
		_ST_RUN --continue
	done
	_ST_EQ "continue completes" "$RC" "0"
	_ST_OUT_HAS "emits ok trailer" '^git-edit: ok — refs/heads/main moved'
	_ST_EQ "resolution in C" "$(git show 'HEAD~2:c.txt')" "line1-resolved"
	_ST_EQ "tip keeps D's content" "$(git show 'HEAD:c.txt')" "line2"
	_ST_CHECK "index clean afterwards" git diff --cached --quiet
	_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"

	# --- 6b. Conflict resolved manually in the worktree, staged WIP survives ---
	ECHO_E "\e[1;96m[6b] manual worktree completion + parallel staged WIP\e[0m"
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
	local MANUAL_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	echo "line1-again" > "$MANUAL_WT/c.txt"
	git -C "$MANUAL_WT" add c.txt
	local MROUNDS=0
	while [ $MROUNDS -lt 4 ]; do
		MROUNDS=$((MROUNDS+1))
		GIT_EDIT_NO_AUTO_OPEN=1 git -C "$MANUAL_WT" -c core.editor=true rebase --continue >/dev/null 2>&1 && break
		echo "line2" > "$MANUAL_WT/c.txt"
		git -C "$MANUAL_WT" add c.txt
	done
	_ST_RUN --continue
	_ST_EQ "continue applies the manual result" "$RC" "0"
	_ST_OUT_HAS "notes manual completion" 'already completed'
	_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
	_ST_CHECK "parallel staged WIP survived" sh -c "git diff --cached --name-only | grep -q w.txt"
	_ST_CHECK "folded path reports clean" sh -c "! git diff --cached --name-only | grep -q c.txt"
	git reset -q -- w.txt && rm -f w.txt

	# --- 6c. Standalone commands refuse stray arguments ---
	ECHO_E "\e[1;96m[6c] stray-argument refusal\e[0m"
	_ST_RUN --undo "$(git rev-parse HEAD)"
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'take no arguments'

	# --- 7. Drop (auto-isolated, non-TTY) ---
	ECHO_E "\e[1;96m[7] drop\e[0m"
	_ST_RUN -d "$(git rev-parse HEAD)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_CHECK "dropped commit's file gone" sh -c "! git cat-file -e 'HEAD:e.txt'"

	# --- 8. Squash (implicit, plumbing route) ---
	ECHO_E "\e[1;96m[8] squash (plumbing)\e[0m"
	PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	local PRE_COUNT=$(git rev-list --count HEAD)
	_ST_RUN --text="C and D combined" "$(git rev-parse HEAD~1)" "$(git rev-parse HEAD)"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree unchanged by construction'
	_ST_EQ "one commit fewer" "$(git rev-list --count HEAD)" "$((PRE_COUNT-1))"
	_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
	_ST_EQ "combined message" "$(git log --format=%s -1)" "C and D combined"

	# --- 9. Reorder: swap two independent tip commits ---
	ECHO_E "\e[1;96m[9] reorder\e[0m"
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
	ECHO_E "\e[1;96m[10] edit-mode non-TTY pause\e[0m"
	_ST_RUN "$(git rev-parse HEAD)"
	_ST_EQ "pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "paused trailer names the worktree" 'git-edit: paused'
	_ST_RUN --abort
	_ST_EQ "abort clears it" "$RC" "0"

	# --- 11. Exec: amend via isolated worktree ---
	ECHO_E "\e[1;96m[11] exec\e[0m"
	_ST_RUN --exec -- git commit --amend -m "amended via exec"
	_ST_EQ "exits 0" "$RC" "0"
	_ST_EQ "amend applied" "$(git log --format=%s -1)" "amended via exec"

	# --- 12. Exec pushed-orphan guard ---
	ECHO_E "\e[1;96m[12] exec pushed-orphan guard\e[0m"
	PRE_HEAD=$(git rev-parse HEAD)
	_ST_RUN --exec -- git reset --hard "$SHA_A"
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'pushed history'
	_ST_EQ "branch unchanged" "$(git rev-parse HEAD)" "$PRE_HEAD"

	# --- 13. Undo refuses after the branch moved on ---
	ECHO_E "\e[1;96m[13] undo CAS guard\e[0m"
	echo "zeta" > z.txt && git add z.txt && git commit -qm "Z commit"
	_ST_RUN --undo
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'has moved since'

	# --- 14. Status: idle report ---
	ECHO_E "\e[1;96m[14] status (idle)\e[0m"
	_ST_RUN --status
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "reports idle" '^git-edit: ok — no operation in flight'

	# --- 15. amend-into=auto: consensus target, new file follows ---
	ECHO_E "\e[1;96m[15] amend-into=auto\e[0m"
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
	ECHO_E "\e[1;96m[16] auto ambiguity refusal\e[0m"
	echo "em3" > m.txt && echo "en3" > n.txt
	git add m.txt n.txt
	_ST_RUN --amend-into=auto
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "lists candidates" 'different commits'
	git reset -q && git checkout -q -- m.txt n.txt

	# --- 17. auto refuses pushed-only history ---
	ECHO_E "\e[1;96m[17] auto pushed-history refusal\e[0m"
	echo "beta2" > b.txt && git add b.txt
	_ST_RUN --amend-into=auto
	_ST_CHECK "refuses" test "$RC" != "0"
	_ST_OUT_HAS "names the reason" 'pushed commit'
	git reset -q && git checkout -q -- b.txt

	# --- 18. split by pathspec ---
	ECHO_E "\e[1;96m[18] split\e[0m"
	echo "s1" > s1.txt && echo "s2" > s2.txt
	git add s1.txt s2.txt && git commit -qm "S mixed commit"
	PRE_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN --split="$(git rev-parse HEAD)" --text="S extracted" -- s1.txt
	_ST_EQ "exits 0" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree unchanged by construction'
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
	ECHO_E "\e[1;96m[19] empty-step guidance\e[0m"
	echo "f1" > f1.txt && echo "v1" > f2.txt && git add f1.txt f2.txt && git commit -qm "R0 base"
	echo "f1x" > f1.txt && echo "v2" > f2.txt && git add f1.txt f2.txt && git commit -qm "R1 commit"
	echo "v1" > f2.txt && git add f2.txt && git commit -qm "R2 revert"
	PRE_HEAD=$(git rev-parse HEAD)
	# Moving the revert before the commit it reverts makes it empty
	_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
	_ST_EQ "pauses with exit 2" "$RC" "2"
	_ST_OUT_HAS "explains the empty step" 'became empty'
	_ST_OUT_HAS "names the skip escape" 'rebase --skip'
	local EMPTY_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
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
	EMPTY_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	git -C "$EMPTY_WT" rebase --abort >/dev/null 2>&1
	_ST_RUN --continue
	_ST_EQ "no-op continue exits 0" "$RC" "0"
	_ST_OUT_HAS "reports unchanged" '^git-edit: ok — .* unchanged'
	_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$PRE_HEAD"
	_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"

	# --- 20. tag-orphan warning on rewrites beneath a tag ---
	ECHO_E "\e[1;96m[20] tag-orphan warning\e[0m"
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

	# --- 21. auto-target resolves from a subdirectory ---
	ECHO_E "\e[1;96m[21] auto-target from subdirectory\e[0m"
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
	ECHO_E "\e[1;96m[22] man page coverage\e[0m"
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
	ECHO_E "\e[1;96m[23] stale SHA handling\e[0m"
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
	ECHO_E "\e[1;96m[24] merge topology\e[0m"
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
	ECHO_E "\e[1;96m[25] move mode\e[0m"
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
	printf 'mv-base\nmv-B\n' > "$MV_WT/mv.txt" && git -C "$MV_WT" add mv.txt
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
	# second, so timestamp sorts tie – the span must sort from HEAD's history,
	# and short SHAs must normalize for that sort's exact match to hit
	ECHO_E "\e[1;96m[26] explicit-target squash ordering\e[0m"
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
	ECHO_E "\e[1;96m[27] rebase-path conflict pause\e[0m"
	printf 'x\nb\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ base"
	printf 'x\nMID\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ mid"
	printf 'x\nTIP\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ tip"
	local PZ_TIP=$(git rev-parse HEAD)
	_ST_RUN -d -y HEAD~1
	_ST_EQ "conflicting drop pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "names the action" 'Conflict during drop'
	_ST_EQ "branch untouched while paused" "$(git rev-parse HEAD)" "$PZ_TIP"
	local PZ_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	printf 'x\nTIP\nz\n' > "$PZ_WT/pz.txt" && git -C "$PZ_WT" add pz.txt
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
	ECHO_E "\e[1;96m[28] blame-aware auto-target\e[0m"
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
	ECHO_E "\e[1;96m[29] edit mode (agent flow)\e[0m"
	git reset -q --hard   # reconcile the scratch checkout so later commits carry no phantom reverts
	printf 'e1\nEDIT-ME\ne2\n' > ed.txt && git add ed.txt && git commit -qm "ED target"
	local ED_TARGET=$(git rev-parse HEAD)
	echo "ed-later" > ed2.txt && git add ed2.txt && git commit -qm "ED later"
	local ED_TIP=$(git rev-parse HEAD)
	_ST_RUN "$ED_TARGET"
	_ST_EQ "edit pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "emits a paused trailer" 'git-edit: paused'
	_ST_EQ "branch untouched while authoring" "$(git rev-parse HEAD)" "$ED_TIP"
	local ED_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused — edit [0-9a-f]* in \(.*\); then.*/\1/p')
	_ST_CHECK "worktree sits at the target" test "$(git -C "$ED_WT" rev-parse HEAD)" = "$ED_TARGET"
	_ST_RUN --status
	_ST_OUT_HAS "status names the authoring phase" 'Authoring phase'
	_ST_RUN --continue
	_ST_EQ "empty continue refused" "$RC" "1"
	_ST_OUT_HAS "explains nothing to amend" 'Nothing to amend'
	printf 'e1\nEDITED\ne2\n' > "$ED_WT/ed.txt"
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
	ECHO_E "\e[1;96m[30] content split (same-file halves)\e[0m"
	git reset -q --hard
	printf 'first\nsecond\n' > cs.txt && git add cs.txt && git commit -qm "CS base"
	printf 'FIRST\nsecond\nthird\n' > cs.txt && git add cs.txt && git commit -qm "CS mixed commit"
	local CS_TARGET=$(git rev-parse HEAD)
	echo "cs-later" > cs2.txt && git add cs2.txt && git commit -qm "CS later"
	local CS_TIP=$(git rev-parse HEAD)
	local CS_TIP_TREE=$(git rev-parse 'HEAD^{tree}')
	_ST_RUN --split="$CS_TARGET"
	_ST_EQ "pathspec-less split pauses (exit 2)" "$RC" "2"
	_ST_OUT_HAS "emits a paused trailer" 'git-edit: paused — split'
	_ST_EQ "branch untouched while authoring" "$(git rev-parse HEAD)" "$CS_TIP"
	local CS_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused — split [0-9a-f]* in \(.*\); then.*/\1/p')
	_ST_CHECK "worktree sits at the target" test "$(git -C "$CS_WT" rev-parse HEAD)" = "$CS_TARGET"
	_ST_RUN --status
	_ST_OUT_HAS "status names the authoring phase" 'Authoring phase'
	_ST_OUT_HAS "status reports it as paused, not conflicted" 'git-edit: paused — split'
	_ST_RUN --continue
	_ST_EQ "continue without a message refused" "$RC" "1"
	_ST_OUT_HAS "asks for --text" 'needs a message'
	_ST_RUN --continue --text "CS extracted"
	_ST_EQ "unedited worktree refused" "$RC" "1"
	_ST_OUT_HAS "names the empty remainder" 'remainder commit would be empty'
	echo "debris" > "$CS_WT/cs-stray.txt"
	_ST_RUN --continue --text "CS extracted"
	_ST_EQ "stray path refused" "$RC" "1"
	_ST_OUT_HAS "names the stray path" 'cs-stray.txt'
	rm -f "$CS_WT/cs-stray.txt"
	printf 'first\nsecond\n' > "$CS_WT/cs.txt"
	_ST_RUN --continue --text "CS extracted"
	_ST_EQ "worktree back at the parent refused" "$RC" "1"
	_ST_OUT_HAS "names the empty extraction" 'extracted commit would be empty'
	# The real split point: the uppercase half only, third line left for the remainder
	printf 'FIRST\nsecond\n' > "$CS_WT/cs.txt"
	# A commit landing on the branch during authoring must be absorbed
	echo "cs-mid" > cs-mid.txt && git add cs-mid.txt && git commit -qm "CS mid-pause"
	# Run the final continue from inside the worktree – its detached HEAD must
	# not stand in for the branch as the trailer's "before"
	local CS_PRE=$(git rev-parse HEAD)
	OUT=$(cd "$CS_WT" && GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue --text "CS extracted" </dev/null 2>&1)
	RC=$?
	_ST_EQ "continue completes the split" "$RC" "0"
	_ST_OUT_HAS "states tree identity" 'Tip tree unchanged by construction'
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
	ECHO_E "\e[1;96m[31] argument-error guidance\e[0m"
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
	ECHO_E "\e[1;96m[32] scoped --amend-into\e[0m"
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
	ECHO_E "\e[1;96m[33] dropped-commit reporting\e[0m"
	git reset -q --hard
	printf 'd1\nd2\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR base"
	printf 'd1\nDX\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR one"
	printf 'd1\nDY\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR two"
	local DR_TIP=$(git rev-parse HEAD)
	_ST_RUN --reorder "$DR_TIP" "$(git rev-parse HEAD~1)"
	_ST_EQ "reordering abutting edits conflicts" "$RC" "2"
	local DR_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	printf 'd1\nDY\nd3\n' > "$DR_WT/dr.txt" && git -C "$DR_WT" add dr.txt
	# The final step restores the pre-op blobs by itself, which leaves the
	# replayed commit empty and the rebase drops it
	_ST_RUN --continue
	_ST_EQ "resolution completes in one continue" "$RC" "0"
	_ST_OUT_HAS "continue path prints the new order too" 'new order (oldest-first)'
	_ST_OUT_HAS "reports the dropped commit" 'resolved to empty and were dropped'
	_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	git reset -q --hard

	# --- 34. a staged resolution with conflict markers must not continue ---
	ECHO_E "\e[1;96m[34] conflict-marker guard\e[0m"
	git reset -q --hard
	printf 'm1\nm2\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK base"
	printf 'm1\nMT\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK target"
	local MK_TARGET=$(git rev-parse HEAD)
	printf 'm1\nML\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK later"
	printf 'm1\nMS\nm3\n' > mk.txt && git add mk.txt
	_ST_RUN --amend-into="$MK_TARGET"
	_ST_EQ "fold conflicts as set up" "$RC" "2"
	local MK_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	_ST_CHECK "worktree file carries markers" sh -c "grep -q '^<<<<<<<' '$MK_WT/mk.txt'"
	# The mistake this guards: a failed resolver, then a blanket `git add`
	git -C "$MK_WT" add mk.txt
	_ST_RUN --continue
	_ST_EQ "continue refused (exit 2)" "$RC" "2"
	_ST_OUT_HAS "names the marker problem" 'still contains conflict markers'
	_ST_CHECK "markers never reached history" sh -c "! git log -p --all | grep -q '^+<<<<<<< '"
	# A marker-free resolution is not blocked
	printf 'm1\nMS\nm3\n' > "$MK_WT/mk.txt" && git -C "$MK_WT" add mk.txt
	_ST_RUN --continue
	_ST_OUT_LACKS "clean resolution passes the guard" 'still contains conflict markers'
	_ST_RUN --abort
	_ST_CHECK "state cleared afterwards" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	git reset -q --hard

	# --- 35. the final-step auto-resolve must refuse when it can't prove itself ---
	ECHO_E "\e[1;96m[35] auto-resolve proof\e[0m"
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
	printf 'p1\npB\n' > "$PR_WT/pa.txt"
	printf 'STRAY\n' > "$PR_WT/pb.txt"
	git -C "$PR_WT" add pa.txt pb.txt
	_ST_RUN --continue
	_ST_EQ "unprovable final step still pauses" "$RC" "2"
	_ST_OUT_LACKS "never claims an unproven auto-resolve" 'auto-resolved'
	_ST_RUN --abort
	_ST_CHECK "abort leaves no state" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
	git reset -q --hard

	# --- 36. reporting must survive the shapes that break naive derivation ---
	ECHO_E "\e[1;96m[36] reporting under merges + scoped conflicts\e[0m"
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
	local SF_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	printf 'sc1\nSFS\nsc3\n' > "$SF_WT/sf.txt" && git -C "$SF_WT" add sf.txt
	_ST_RUN --continue
	printf 'sc1\nSFL\nsc3\n' > "$SF_WT/sf.txt" 2>/dev/null && git -C "$SF_WT" add sf.txt 2>/dev/null
	_ST_RUN --continue
	_ST_OUT_HAS "scope survives the conflict pause" 'outside the pathspec'
	_ST_OUT_LACKS "no bogus not-folded warning" 'not folded'
	_ST_CHECK "out-of-scope file never folded" sh -c "test \"\$(git show \$(git log --format='%H %s' | grep 'SF target' | cut -d' ' -f1):sf-other.txt)\" = keep"
	git reset -q --hard

	# --- 37. edit mode must report the stale checkout it leaves behind ---
	ECHO_E "\e[1;96m[37] edit-mode checkout staleness\e[0m"
	git reset -q --hard
	printf 'ed1\nSTALE-ME\ned3\n' > stale.js && git add stale.js && git commit -qm "STALE target"
	local STALE_T=$(git rev-parse HEAD)
	echo "stale-later" > stale-later.txt && git add stale-later.txt && git commit -qm "STALE later" >/dev/null 2>&1
	_ST_EQ "target has a descendant to replay" "$(git rev-list --count ${STALE_T}..HEAD)" "1"
	_ST_RUN "$STALE_T"
	local STALE_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused — edit [0-9a-f]* in \(.*\); then.*/\1/p')
	printf 'ed1\nEDITED\ned3\n' > "$STALE_WT/stale.js"
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
	ECHO_E "\e[1;96m[38] targeted checkout reconcile\e[0m"
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
	ECHO_E "\e[1;96m[39] exec reports the branch it rewrote\e[0m"
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
	ECHO_E "\e[1;96m[40] untracked absorption is named\e[0m"
	git reset -q --hard
	echo "ua" > ua.txt && git add ua.txt && git commit -qm "UA base"
	echo "ub" > ub.txt && git add ub.txt && git commit -qm "UB target"
	local UA_TGT=$(git rev-parse HEAD)
	echo "uc" > uc.txt && git add uc.txt && git commit -qm "UC later"
	_ST_RUN "$UA_TGT"
	local UA_WT=$(echo "$OUT" | sed $'s/\e\\[[0-9;]*m//g' | grep -oE '/[^ ]*git-edit-edit\.[A-Za-z0-9]+' | head -1)
	echo "edited" >> "$UA_WT/ub.txt"
	echo "scratch" > "$UA_WT/ua-stray.txt"
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
	echo "edited" >> "$UA_WT2/ud.txt"
	_ST_RUN --continue
	_ST_EQ "clean continue exits 0" "$RC" "0"
	_ST_OUT_LACKS "silent when nothing untracked is absorbed" 'Absorbing'
	git reset -q --hard

	# --- 41. a conflict resolution is recorded for rerere to replay ---
	ECHO_E "\e[1;96m[41] conflict resolutions reach rr-cache\e[0m"
	git reset -q --hard
	local RR_DIR="$(git rev-parse --git-common-dir)/rr-cache"
	local RR_BEFORE=$(ls "$RR_DIR" 2>/dev/null | wc -l | tr -d ' ')
	printf 'rr line A\n' > rr.txt && git add rr.txt && git commit -qm "RR base"
	printf 'rr line B\n' > rr.txt && git add rr.txt && git commit -qm "RR middle"
	local RR_MID=$(git rev-parse HEAD)
	printf 'rr line C\n' > rr.txt && git add rr.txt && git commit -qm "RR top"
	_ST_RUN -d -y "$RR_MID"
	_ST_EQ "the drop conflicts as set up" "$RC" "2"
	local RR_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	if [ -n "$RR_WT" ] && [ -d "$RR_WT" ]; then
		printf 'rr line C\n' > "$RR_WT/rr.txt"
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
	local ED_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused — edit [^ ]* in \([^;]*\);.*/\1/p' | head -1)
	if [ -n "$ED_WT" ] && [ -d "$ED_WT" ]; then
		printf 'ed line EDITED\n' > "$ED_WT/ed.txt"
		_ST_RUN --continue
		local ED_CWT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
		if [ -n "$ED_CWT" ] && [ -d "$ED_CWT" ]; then
			printf 'ed line B\n' > "$ED_CWT/ed.txt"
			git -C "$ED_CWT" add ed.txt
			_ST_RUN --continue
		fi
	fi
	_ST_CHECK "edit mode records its resolution too" \
		sh -c "[ $(ls "$RR_DIR" 2>/dev/null | wc -l | tr -d ' ') -gt $RR_BEFORE_E ]"
	git reset -q --hard
	# Structural, so a start that loses the flag is caught even when no scenario
	# happens to drive that mode into a conflict
	# Anchored to the start of a line, or these patterns would count the very
	# assertion lines that carry them
	_ST_CHECK "every conflict-capable rebase start carries rerere" \
		sh -c "[ \$(grep -cE '^[[:space:]]*local CMD=\\(-c rerere.enabled=true rebase' '$SELF') -eq 6 ]"
	_ST_CHECK "and none was left without it" \
		sh -c "! grep -qE '^[[:space:]]*local CMD=\\(rebase' '$SELF'"

	# --- 42. a CAS refusal keeps the resolution instead of deleting it ---
	ECHO_E "\e[1;96m[42] CAS refusal preserves the worktree\e[0m"
	git reset -q --hard
	printf 'cas one\ncas two\n' > cas.txt && git add cas.txt && git commit -qm "CAS base"
	local CAS_TARGET=$(git rev-parse HEAD)
	printf 'cas one\ncas CHANGED\n' > cas.txt && git add cas.txt && git commit -qm "CAS later"
	printf 'cas one\ncas FOLDED\n' > cas.txt && git add cas.txt
	_ST_RUN --amend-into="$CAS_TARGET" -- cas.txt
	_ST_EQ "the fold conflicts" "$RC" "2"
	local CAS_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	# A parallel session lands a commit while the resolution is being worked out
	printf 'other work\n' > other.txt && git add other.txt && git commit -qm "CAS parallel commit"
	# The fold cascades onto the later commit, so resolve until it stops asking
	local CAS_ROUNDS=0
	while [ "$RC" = "2" ] && [ $CAS_ROUNDS -lt 4 ]; do
		CAS_ROUNDS=$((CAS_ROUNDS+1))
		local CAS_WT_NOW=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
		if [ -z "$CAS_WT_NOW" ] || [ ! -d "$CAS_WT_NOW" ]; then
			break
		fi
		CAS_WT=$CAS_WT_NOW
		printf 'cas one\ncas RESOLVED\n' > "$CAS_WT/cas.txt"
		git -C "$CAS_WT" add cas.txt
		_ST_RUN --continue
	done
	_ST_EQ "the CAS refuses the write" "$RC" "1"
	_ST_OUT_HAS "says the branch moved" 'moved during resolution'
	# The refusal used to fire the exit trap, deleting the one copy of the work
	# and leaving a state whose worktree was gone
	_ST_CHECK "the worktree survives the refusal" sh -c "[ -d '$CAS_WT' ]"
	_ST_CHECK "and still holds the resolution" sh -c "grep -q 'cas RESOLVED' '$CAS_WT/cas.txt'"
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
	ECHO_E "\e[1;96m[43] orphan worktree sweep\e[0m"
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
	ECHO_E "\e[1;96m[44] marker-free conflicts still pause\e[0m"
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
	_ST_RUN --abort
	_ST_CHECK "no commit was dropped" sh -c "git log --format=%s | grep -qx 'BIN top'"
	git reset -q --hard

	ECHO_E "\e[1;96m[45] fold and reword in one run\e[0m"
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
	local AE_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	local AE_ROUNDS=0
	while [ -n "$AE_WT" ] && [ -d "$AE_WT" ] && [ $AE_ROUNDS -lt 5 ]; do
		AE_ROUNDS=$((AE_ROUNDS+1))
		printf 'ae folded\n' > "$AE_WT/ae.txt"
		git -C "$AE_WT" add ae.txt
		_ST_RUN --continue
		AE_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict — resolve in \([^ ]*\).*/\1/p' | head -1)
	done
	_ST_EQ "the fold settles" "$RC" "0"
	_ST_CHECK "a commit really was dropped as empty" \
		sh -c "! git log --format=%s | grep -qx 'AE top'"
	_ST_OUT_HAS "the summary names the commit folded into" 'amended: .*AE target'
	_ST_OUT_LACKS "not the one below it" 'amended: .*AE base'
	git reset -q --hard

	ECHO_E "\e[1;96m[46] replanting a branch onto a moved upstream\e[0m"
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

	ECHO_E "\e[1;96m[47] linking gitignored paths into a pause worktree\e[0m"
	git reset -q --hard
	printf 'wl one\n' > wl.txt && git add wl.txt && git commit -qm "WL one"
	printf 'wl two\n' > wl.txt && git add wl.txt && git commit -qm "WL two"
	mkdir -p node_modules/dep && printf 'installed\n' > node_modules/dep/index.js
	_ST_RUN HEAD~1
	local WL_WT=$(echo "$OUT" | sed -n 's/.*paused — edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "nothing is linked without the config" sh -c "test ! -e '$WL_WT/node_modules'"
	_ST_RUN --abort

	printf 'node_modules\n' > .gitignore && git add .gitignore && git commit -qm "WL ignore"
	git config --add edit.worktreeLink node_modules
	# Target HEAD, not HEAD~1: the worktree checks out the commit being edited,
	# so its `.gitignore` is the one that decides whether the link is covered
	_ST_RUN HEAD
	WL_WT=$(echo "$OUT" | sed -n 's/.*paused — edit [^ ]* in \([^;]*\);.*/\1/p')
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
	local WL_WT2=$(echo "$OUT" | sed -n 's/.*paused — edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "and no link was created at all" \
		sh -c "test ! -e '$WL_WT2/node_modules'"
	printf 'wl edited\n' > "$WL_WT2/wl.txt"
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
	local WL_WT3=$(echo "$OUT" | sed -n 's/.*paused — edit [^ ]* in \([^;]*\);.*/\1/p')
	_ST_CHECK "a nested path is linked, not silently skipped" \
		sh -c "test -f '$WL_WT3/vendor/deps/lib.js'"
	_ST_OUT_LACKS "and reports no failure" 'Could not link'
	_ST_RUN --abort
	rm -rf vendor

	git config --unset-all edit.worktreeLink
	rm -rf node_modules
	git reset -q --hard

	ECHO_E "\e[1;96m[48] documented guarantees that had no assertion\e[0m"
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

	ECHO_E "\e[1;96m[49] which commit an operation landed in survives a short tail\e[0m"
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
	local ID_WT=$(print -r -- "$OUT" | sed -n 's/^git-edit: paused — edit [^ ]* in \([^;]*\);.*/\1/p' | head -1)
	_ST_CHECK "it opened a worktree" test -d "$ID_WT"
	printf 'id e1 edited\n' > "$ID_WT/id-e1.txt"
	git -C "$ID_WT" add id-e1.txt
	_ST_RUN --continue
	_ST_EQ "the edit settles" "$RC" "0"
	_ST_EQ "and names what it edited within a 'tail -3'" \
		"$(print -r -- "$OUT" | tail -3 | grep -c 'edited: ')" "1"
	git reset -q --hard

	ECHO_E "\e[1;96m[50] SHA-keyed metadata across a plumbing rewrite\e[0m"
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

	_ST_CHECK "the color gate covers NO_COLOR and TERM=dumb" \
		sh -c "command grep -q '^if \\[ ! -t 1 \\] || \\[ -n \"\\\$NO_COLOR\" \\] || \\[ \"\\\$TERM\" = \"dumb\" \\]; then' '$SELF'"

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
		echo "git-edit: ok — selftest $PASS/$TOTAL passed"
		_STATUS_EMITTED=true
		return 0
	else
		PRINT_TEXT "%s" 31 "Selftest: $FAIL of $TOTAL checks FAILED."
		# A failing run keeps both – that tree is the evidence
		PRINT_TEXT "Scratch repo kept for inspection: %s" 33 "$TMP"
		echo "git-edit: error — selftest $FAIL/$TOTAL failed"
		_STATUS_EMITTED=true
		return 1
	fi
}
