# Rerere records are operation-scoped under an explicit opt-out
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
