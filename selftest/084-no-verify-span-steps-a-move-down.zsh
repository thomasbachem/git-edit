# A move steps down from a standing span as a fold does
# The tier flag was pinned on folds alone, though a move rebuilds everything above its anchor
# too – a landing passed it to its folds, not its moves, 18 minutes of suite runs
_ST_SCENARIO "\e[1;96m[84] --no-verify-span steps a move down from edit.verifySpan\e[0m"
local VM
for VM in base m1 m2 m3 tip; do
	echo "$VM" > "vm_$VM.txt" && git add "vm_$VM.txt" && git commit -qm "VM $VM"
done
git config edit.verifyCmd "echo run >> '$TMP/vm-count'"
git config edit.verifySpan true
: > "$TMP/vm-count"
_ST_RUN --move="$(git rev-parse ':/VM tip')" --after="$(git rev-parse ':/VM base')"
_ST_EQ "a move under the standing span applies" "$RC" "0"
_ST_EQ "verifying all it rebuilt" "$(wc -l < "$TMP/vm-count" | tr -d ' ')" "4"
# A move down's default tier is the commit it moved, the first one rebuilt and the tip
_ST_OUT_HAS "with the lever that steps back down" 'no-verify-span` runs only its 2 (set by edit.verifySpan)'
: > "$TMP/vm-count"
# Moved up to the tip, the commit is the tip, beside the first one rebuilt and the one it lands on
_ST_RUN --no-verify-span --move="$(git rev-parse ':/VM tip')" --after="$(git rev-parse ':/VM m3')"
_ST_EQ "the flag steps the move down" "$RC" "0"
_ST_EQ "to the first commit rebuilt, the one it lands on and the tip" "$(wc -l < "$TMP/vm-count" | tr -d ' ')" "3"
_ST_OUT_HAS "naming the shortfall" 'Verified 3 of 4 commit(s)'
: > "$TMP/vm-count"
_ST_RUN --no-verify-span --move="$(git rev-parse ':/VM m2')..$(git rev-parse ':/VM m3')" --after="$(git rev-parse ':/VM base')"
_ST_EQ "and a run's move" "$RC" "0"
_ST_EQ "to both commits it moved and the tip" "$(wc -l < "$TMP/vm-count" | tr -d ' ')" "3"
git config --unset edit.verifySpan
git config --unset edit.verifyCmd
