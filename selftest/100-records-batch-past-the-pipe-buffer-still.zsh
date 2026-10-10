# Piped into `grep -q`, a text past the pipe buffer lost its writer at grep's early match,
# and `pipefail` read the match as a miss – the batch was refused as missing its commit
_ST_SCENARIO "\e[1;96m[100] a records batch past the pipe buffer still reads as records\e[0m"
local LB
for LB in one two; do
	echo "$LB" > "lb_$LB.txt" && git add "lb_$LB.txt" && git commit -qm "LB $LB"
done
local LB_ONE=$(git rev-parse --short ':/LB one') LB_TWO=$(git rev-parse --short ':/LB two')
# Twice the 64 KiB a macOS pipe buffer grows to, split across both messages – Linux caps the
# argument `commit-tree -m` takes a message as at 128 KiB
local LB_BODY=$(printf 'Body line %s of a long batch reword\n' {1..1800})
_ST_RUN_IN "$(printf -- '--- %s\nLB one reworded\n\n%s\n--- %s\nLB two reworded\n\n%s\n' "$LB_ONE" "$LB_BODY" "$LB_TWO" "$LB_BODY")" -M --text -
_ST_EQ "a batch past the pipe buffer rewords" "$RC" "0"
_ST_EQ "both its commits" "$(git log -2 --format=%s | LC_ALL=C sort | tr '\n' ' ')" "LB one reworded LB two reworded "
# The two-dash check reads as long a text
_ST_RUN_IN "$(printf -- '-- %s\nTwo dashes\n\n%s\n%s\n' "$LB_ONE" "$LB_BODY" "$LB_BODY")" -M --text -
_ST_OUT_HAS "and one with two-dash headers is named as such" "Records start with '--- <commit>'"
