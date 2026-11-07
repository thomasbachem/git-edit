# A run losing the race to another caller runs itself again on the new tip, up to twice:
# • Each loss and re-run named as it goes, one trailer at the end
# • The last loss refused as before, its trailer naming the rerun a caller needs
# • Never a run that read stdin or ran an `--exec` command, nor with `GIT_EDIT_NO_RERUN` set
_ST_SCENARIO "\e[1;96m[268] a run losing the race runs itself again\e[0m"
local RR_TGT RR_PEER

# Makes a repo with `f.txt` staged for a target below the tip, and
# a gate moving `main` by a peer commit on each of its first <n> runs
_RR_NEW () {
	# Args: <repo name> <n>
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt f1 "RR target"
	RR_TGT=$(git rev-parse HEAD)
	_ST_PZ_C g.txt g1 "RR above"
	print -r -- f2 > f.txt && git add f.txt
	cat > "$TMP/rr-race.sh" <<RACE
#!/bin/sh
[ "\$(cat "$TMP/rr-$1.count" 2>/dev/null | wc -c)" -lt $2 ] || exit 0
printf x >> "$TMP/rr-$1.count"
git update-ref -m "commit: RR peer" refs/heads/main "\$(git commit-tree -p refs/heads/main -m "RR peer" "refs/heads/main^{tree}")"
RACE
	chmod +x "$TMP/rr-race.sh"
}
# Counts the trailers in the run's output
_RR_TRAILERS () {
	grep -c '^git-edit: ' <<<"$OUT"
}
export GIT_EDIT_NO_RERUN=

# A fold losing once runs again on the peer's tip and lands there
_RR_NEW rr1 1
_ST_RUN --amend-into="$RR_TGT" --verify="$TMP/rr-race.sh" -- f.txt
_ST_EQ "a fold losing the race once lands on its re-run, above the peer's commit" \
	"$RC:$(git log --format=%s | tr '\n' ,):$(git show HEAD~2:f.txt)" "0:RR peer,RR above,RR target,:f2"
# The peer's tip, which the fold rewrote, from where the reflog has it before the landing
RR_PEER=$(git rev-parse 'main@{1}')
_ST_OUT_HAS "naming the loss, who moved the branch, its new tip and the try" \
	"^Lost the race – a commit outside git-edit (commit 'RR peer') moved main to ${RR_PEER:0:7} – running it again on the new tip, re-run 1 of 2"
_ST_EQ "ending in one trailer, the re-run's" "$(_RR_TRAILERS):${OUT##*$'\n'}" "1:git-edit: ok – refs/heads/main moved $RR_PEER → $(git rev-parse HEAD)"

# Losing every try – two re-runs, one trailer, the remedy on it
_RR_NEW rr2 99
_ST_RUN --amend-into="$RR_TGT" --verify="$TMP/rr-race.sh" -- f.txt
_ST_EQ "a fold losing every try refuses, the peers' commits kept and its staging too" \
	"$RC:$(git log -1 --format=%s):$(git show HEAD:f.txt):$(git diff --cached --name-only)" "1:RR peer:f1:f.txt"
_ST_EQ "after two re-runs, no third" \
	"$(grep -c '^Lost the race – .* re-run [12] of 2' <<<"$OUT"):$(grep -c 're-run 3' <<<"$OUT")" "2:0"
_ST_EQ "in one trailer" "$(_RR_TRAILERS)" "1"
_ST_OUT_HAS "naming the tries and the rerun on it" \
	"^git-edit: error – Branch 'main' moved from [0-9a-f]\{7\} to [0-9a-f]\{7\} during the fold – refusing to overwrite – lost on each of 3 tries, nothing was applied, so run it again$"

# A commit losing once lands on its re-run, while one whose message came from stdin refuses
_RR_NEW rr3 1
git reset -q
print -r -- c > c.txt
_ST_RUN --commit --text "RR commit" --verify="$TMP/rr-race.sh" -- c.txt
_ST_EQ "a commit losing the race once lands on its re-run" \
	"$RC:$(git log --format=%s -2 | tr '\n' ,):$(_RR_TRAILERS)" "0:RR commit,RR peer,:1"
_RR_NEW rr4 1
git reset -q
print -r -- c > c.txt
_ST_RUN_IN "RR stdin" --commit --text - --verify="$TMP/rr-race.sh" -- c.txt
_ST_EQ "one whose message came from stdin refuses at its first loss" "$RC:$(git log -1 --format=%s)" "1:RR peer"
_ST_OUT_LACKS "never running again" 'Lost the race'
_ST_OUT_HAS "the trailer saying nothing landed" "^git-edit: error – main moved to [0-9a-f]\{7\} while the commit was composed on [0-9a-f]\{7\} – nothing landed, so run it again$"

# An `--exec` refuses at its first loss, as its command may not do the same twice
_RR_NEW rr5 1
git reset -q
_ST_RUN --exec --verify="$TMP/rr-race.sh" -- git commit --allow-empty -qm "RR exec"
_ST_EQ "an --exec losing the race refuses" "$RC:$(git log -1 --format=%s)" "1:RR peer"
_ST_OUT_HAS "as moved during it" "Ref 'refs/heads/main' moved during exec – refusing to overwrite"
_ST_OUT_LACKS "never running it again" 'Lost the race'
# Nor where its command moved the branch, which the check before its gate finds
_RR_NEW rr5b 1
git reset -q
_ST_RUN --exec --verify=true -- sh -c "\"$TMP/rr-race.sh\" && git commit --allow-empty -qm 'RR exec'"
_ST_EQ "an --exec whose command moved the branch refuses before its gate" "$RC:$(git log -1 --format=%s)" "1:RR peer"
_ST_OUT_HAS "as moved since it read it" "^Branch 'main' moved from [0-9a-f]\{7\} to [0-9a-f]\{7\} since this run read it"
_ST_OUT_LACKS "never running it again" 'Lost the race'

# A move losing once runs again on the peer's tip, as the replayed modes do
_RR_NEW rr7 1
git reset -q
_ST_RUN --move="$(git rev-parse ':/RR above')" --before="$RR_TGT" --verify="$TMP/rr-race.sh"
_ST_EQ "a move losing the race once lands on its re-run, below the peer's commit" \
	"$RC:$(git log --format=%s -3 | tr '\n' ,):$(_RR_TRAILERS)" "0:RR peer,RR target,RR above,:1"
_ST_OUT_HAS "naming the loss" '^Lost the race – .* re-run 1 of 2'

# `GIT_EDIT_NO_RERUN` keeps the loss a refusal, its trailer naming the rerun
_RR_NEW rr6 1
export GIT_EDIT_NO_RERUN=1
_ST_RUN --amend-into="$RR_TGT" --verify="$TMP/rr-race.sh" -- f.txt
_ST_EQ "GIT_EDIT_NO_RERUN refuses the fold at its first loss" "$RC:$(git log -1 --format=%s):$(git diff --cached --name-only)" "1:RR peer:f.txt"
_ST_OUT_LACKS "never running it again" 'Lost the race'
_ST_OUT_HAS "the trailer naming the rerun" "^git-edit: error – Branch 'main' moved from [0-9a-f]\{7\} to [0-9a-f]\{7\} during the fold – refusing to overwrite – nothing was applied, so run it again$"

unfunction _RR_NEW _RR_TRAILERS
cd "$TMP/repo"
