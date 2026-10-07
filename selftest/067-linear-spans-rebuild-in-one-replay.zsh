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
# One clock for both engines, so their results can be held to one SHA – a git older than
# 2.44 has no `replay` and takes the walk throughout, probed the way the tool probes it
local RP_HAS_REPLAY=false
[[ "$( export LC_ALL=C; git replay -h 2>&1 )" == *"--advance"* ]] && RP_HAS_REPLAY=true
GIT_COMMITTER_DATE='@1700000000 +0000' _ST_RUN -M --text="RP target reworded" "$RP_TARGET"
_ST_EQ "a reword over a linear span exits 0" "$RC" "0"
if [ "$RP_HAS_REPLAY" = "true" ]; then
	_ST_OUT_HAS "and rebuilds it in one replay" 'git replay --advance'
	_ST_OUT_LACKS "not commit by commit" '# rebuilt'
	_ST_OUT_HAS "stating the proof rather than a construction" 'Trees unchanged ✓ – proven'
else
	_ST_OUT_HAS "and, with no replay in this git, rebuilds it commit by commit" '# rebuilt'
fi
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
if [ "$RP_HAS_REPLAY" = "true" ]; then
	git reset -q --hard "$RP_TIP"
	printf 'RP verbatim\n\n\nbody   \n# kept, not a comment\n\n\n' | git commit -q --allow-empty --cleanup=verbatim -F -
	local RP_VERBATIM=$(git cat-file commit HEAD | sed '1,/^$/d' | git hash-object --stdin)
	_ST_RUN -M --text="RP target reworded under a verbatim message" "$RP_TARGET"
	_ST_EQ "a verbatim message survives the replay byte for byte" "$(git cat-file commit HEAD | sed '1,/^$/d' | git hash-object --stdin)" "$RP_VERBATIM"
	_ST_OUT_HAS "which was a replay" 'git replay --advance'
else
	ECHO_E "\e[0;90m  skipped – only a replay carries a verbatim message byte for byte, and this git has none\e[0m"
fi
git reset -q --hard
