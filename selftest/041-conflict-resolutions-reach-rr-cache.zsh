# A conflict resolution is recorded for rerere to replay
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
	sh -c "[ \$(grep -cE '^[[:space:]]*reply=\\(-c rerere.enabled=true (-c [^ ]+ |[^ ]*_CAPTURE_PIN[^ ]* )*rebase' \"\$1\") -eq 1 ]" _ "$SELF"
_ST_CHECK "and none was left without it" \
	sh -c "! grep -qE '^[[:space:]]*(local CMD|reply)=\\(rebase' \"\$1\"" _ "$SELF"
# Every rebase the script runs carries rerere, so a line with that flag but not the
# `rebase.updateRefs` pin is a rebase that would move other branches ahead of the CAS – a
# snapshot fold's direct `git rerere` aside, which moves nothing
_ST_CHECK "and every one pins rebase.updateRefs off" \
	sh -c "! grep -E -- '-c rerere\\.enabled=true' \"\$1\" | grep -vE -- '-c rerere\\.enabled=true (-c [^ ]+ )*rerere ' | grep -vq -- '-c rebase\\.updateRefs=false'" _ "$SELF"
_ST_CHECK "and carries the pins that hold a rewrite's delivery back" \
	sh -c "! grep -E -- '-c rebase\\.updateRefs=false' \"\$1\" | grep -vq -- '_CAPTURE_PIN'" _ "$SELF"
# A start holding git's delivery back without the `--exec` step saving the list has nothing to
# deliver in its place – the one way the hold-back could lose a rewrite that landed
_ST_CHECK "and every start saves the list it holds back" \
	sh -c "! grep -E -- '_CAPTURE_PIN[^ ]* rebase' \"\$1\" | grep -vE 'rebase (--continue|--skip|[^ ]*SUBCMD)' | grep -vq -- '_CAPTURE_EXEC'" _ "$SELF"
# A command array run as is hands git one argument per element, so the quoted capture strings
# in one arrive whole and git refuses them – only an array joined and `eval`d takes those
print -r -- '/^[A-Z_]+ \(\) \{/ { n = 0; direct = 0 }
/local CMD=\(/ { cmd[++n] = $0 }
/git "\$\{CMD\[@\]\}"/ { direct = 1 }
/^\}/ { if (direct) for (i = 1; i <= n; i++) if (cmd[i] ~ /\$_CAPTURE_(PINS|EXEC)[^_]/) bad = 1; n = 0; direct = 0 }
END { exit bad }' > "$TMP/direct-cmd.awk"
_ST_CHECK "and an array run as is carries them as arrays" awk -f "$TMP/direct-cmd.awk" "$SELF"
