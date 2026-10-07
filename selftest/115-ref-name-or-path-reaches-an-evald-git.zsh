# A ref name or path reaches an eval'd command as data, never as code
# A branch from `gh pr checkout` carries the contributor's name, a repo sits at the user's own
# path – `$(…)`, backticks and quotes in either must not run when a command string is eval'd
_ST_SCENARIO "\e[1;96m[115] a ref name or path reaches an eval'd git command as data, not code\e[0m"
# Every eval'd update-ref, worktree, reset or rm command quotes its interpolations with
# `${(q-)…}` – strip those spans and any `$` left is an unquoted ref or path
local IQ_AWK='
	$0 ~ /="git / && $0 ~ /(update-ref|worktree add|worktree remove|rm -rf|reset --hard)/ {
		seen++; out = ""; n = length($0); i = 1
		while (i <= n) {
			rest = substr($0, i)
			if (rest ~ /^\$\{\(q-\)/ || rest ~ /^\$\{\(qq\)/) {
				j = i + 2; depth = 0
				while (j <= n) {
					c = substr($0, j, 1)
					if (c == "{") depth++
					else if (c == "}") { depth--; if (depth == 0) break }
					j++
				}
				i = j + 1; continue
			}
			out = out substr($0, i, 1); i++
		}
		if (out ~ /\$/) print NR ": " $0
	}
	END { print "seen " seen + 0 }'
local -a IQ_OUT
IQ_OUT=("${(@f)$(awk "$IQ_AWK" "$SELF")}")
_ST_EQ "every eval'd ref or path command quotes its interpolations" "${(F)IQ_OUT[1,-2]}" ""
_ST_CHECK "across every such command" test "${IQ_OUT[-1]#seen }" -ge 40
printf '%s\n' 'local CMD="git worktree add --detach $WT ${(q-)SHA}"' \
	'local U="git update-ref -m ${(q-)${:-git edit: x}} ${(q-)REF} ${(q-)A} ${(q-)B}"' > "$TMP/iq-fixture"
IQ_OUT=("${(@f)$(awk "$IQ_AWK" "$TMP/iq-fixture")}")
_ST_EQ "the check flags a bare path and clears a fully quoted line" "${(F)IQ_OUT}" $'1: local CMD="git worktree add --detach $WT ${(q-)SHA}"\nseen 2'
# A ref name is shell code only an eval would run: a branch created by plumbing (as a fetch or
# push of a crafted ref would), its name a `$(>file)` redirection – valid, space-free, and under
# the old bare `$REF` it fired when the reword's update-ref was eval'd
local IQ_WAS=$(git symbolic-ref --short HEAD)
local IQ_HEAD=$(git rev-parse HEAD)
local IQ_REF='refs/heads/iq$(>iq-pwned)x'
rm -f iq-pwned
git update-ref "$IQ_REF" "$IQ_HEAD"
git symbolic-ref HEAD "$IQ_REF"
_ST_RUN -M --text "IQ reword on an odd branch" "$IQ_HEAD"
_ST_EQ "a reword on a branch whose name is shell code lands" "$RC:$(git rev-parse "$IQ_REF^{tree}")" "0:$(git rev-parse "$IQ_HEAD^{tree}")"
_ST_CHECK "running no payload the name carried" test ! -e iq-pwned
git symbolic-ref HEAD "refs/heads/$IQ_WAS"
git update-ref -d "$IQ_REF"
