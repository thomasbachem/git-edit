# A name git hands back reaches it as itself
# Read as a pattern, `[id].tsx` matches `i.tsx` beside it, and a leading `:` reads as magic
_ST_SCENARIO "\e[1;96m[114] a name git hands back reaches it as itself, never as a pattern\e[0m"
# Each call naming a path after `--` takes it literally – per call, through its function's
# `GIT_LITERAL_PATHSPECS`, or by taking no pathspec at all – bar the caller's own pathspecs
local PN_AWK='
	/^[A-Za-z_][A-Za-z0-9_]* \(\) \{/ || /^}/ { lit = 0 }
	/local -x GIT_LITERAL_PATHSPECS=1/ { lit = 1 }
	/^[[:space:]]*#/ { next }
	/git[^;|&]* -- "?\$/ {
		seen++
		if (lit || /--literal-pathspecs|:\(literal\)|_QUOTE_PATHS|"\$\{(AMEND_)?PATHSPECS\[@\]\}"/ || / (update-index|hash-object|blame|merge-file|check-attr|apply) |--no-index/) next
		print NR ": " $0
	}
	END { print "seen " seen + 0 }'
local -a PN_OUT
PN_OUT=("${(@f)$(awk "$PN_AWK" "$SELF")}")
_ST_EQ "every name it hands git after -- reads as itself" "${(F)PN_OUT[1,-2]}" ""
_ST_CHECK "across every call taking one" test "${PN_OUT[-1]#seen }" -ge 30
printf '%s\n' 'A () {' '	local -x GIT_LITERAL_PATHSPECS=1' '	git log -- "$P"' '}' 'git reset -q -- "${NAMES[@]}"' \
	'B () {' '	git log -- "$P"' '	git log -- ":(literal)$P"' '	git diff -- "${AMEND_PATHSPECS[@]}"' '}' > "$TMP/pn-fixture"
PN_OUT=("${(@f)$(awk "$PN_AWK" "$TMP/pn-fixture")}")
_ST_EQ "the check flags a bare one, a literal function's scope ending with it" "${(F)PN_OUT}" $'5: git reset -q -- "${NAMES[@]}"\n7: \tgit log -- "$P"\nseen 4'
# A fold's auto-target and its re-sync take the staged name, not what it would match
printf 'a\nb\n' > 'pn-[i].txt' && git add -- ':(literal)pn-[i].txt' && git commit -qm "PN pattern-like name"
printf 'x\n' > pn-i.txt && git add pn-i.txt && git commit -qm "PN the name it matches"
printf 'x\ny\n' > pn-i.txt && git add pn-i.txt
printf 'a\nb\nc\n' > 'pn-[i].txt' && git add -- ':(literal)pn-[i].txt'
_ST_RUN --amend-into=auto -- ':(literal)pn-[i].txt'
_ST_EQ "auto-target takes the commit that touched the name itself" "$RC:$(git log -1 --format=%s HEAD~1):$(git show 'HEAD~1:pn-[i].txt' | tail -1)" "0:PN pattern-like name:c"
_ST_EQ "and the staging it would match stays staged" "$(git diff --cached --name-only)" "pn-i.txt"
git restore --staged --worktree -- pn-i.txt
# A name git C-quotes in its line form – a backslash, a double quote – re-syncs and carries as
# itself, as a run does under the caller's own pathspec settings
printf 'v1\n' > 'pn\b.txt' && printf 'v1\n' > 'pn"q.txt' && git add -- ':(literal)pn\b.txt' ':(literal)pn"q.txt' && git commit -qm "PN quoted names"
printf 'v2\n' > 'pn\b.txt' && printf 'v2\n' > 'pn"q.txt'
_ST_RUN --commit --text "PN quoted names whole" -- 'pn\b.txt' 'pn"q.txt'
_ST_EQ "a name git quotes re-syncs as itself, the checkout clean" "$RC:$(git status --porcelain -- ':(literal)pn\b.txt' ':(literal)pn"q.txt')" "0:"
local PN_OLD=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c "printf 'v2\nlanded\n' > 'pn\"q.txt' && git commit -qam 'PN land on a quoted name'"
printf 'mine\nv2\n' > 'pn"q.txt'
_ST_RUN --carry="$PN_OLD"
_ST_EQ "and --carry merges onto it" "$RC:$(tr '\n' ' ' < 'pn"q.txt')" "0:mine v2 landed "
git checkout -q -- ':(literal)pn"q.txt'
printf 'v3\n' > pn-i.txt
export GIT_GLOB_PATHSPECS=1
_ST_RUN --commit --text "PN under glob pathspecs" -- pn-i.txt
unset GIT_GLOB_PATHSPECS
_ST_EQ "a caller's GIT_GLOB_PATHSPECS leaves the re-sync intact" "$RC:$(git status --porcelain -- pn-i.txt)" "0:"
# While a command --exec runs for the caller still reads the caller's own pathspec setting
export GIT_LITERAL_PATHSPECS=1
_ST_RUN --exec -- sh -c 'git rm -q "pn-[i].txt" && git commit -qm "PN rm the bracketed name"'
unset GIT_LITERAL_PATHSPECS
_ST_EQ "a caller's GIT_LITERAL_PATHSPECS reaches an --exec command" "$RC:$(git ls-tree --name-only HEAD -- pn-i.txt)" "0:pn-i.txt"
# A conflicted name holding a quote reads as itself in the pause it causes
printf '1\n2\n3\n' > 'pn"c.txt' && git add -- ':(literal)pn"c.txt' && git commit -qm "PN quote base"
local PN_QB=$(git rev-parse HEAD)
printf '1\nL\n3\n' > 'pn"c.txt' && git commit -qm "PN quote later" -- ':(literal)pn"c.txt'
printf '1\nS\n3\n' > 'pn"c.txt' && git add -- ':(literal)pn"c.txt'
_ST_RUN --amend-into="$PN_QB" -- ':(literal)pn"c.txt'
_ST_OUT_HAS "a conflicted name with a quote is named as itself" 'resolve in .* (pn"c.txt);'
_ST_OUT_LACKS "never as a file without markers" 'No conflict markers'
_ST_OUT_HAS "the later step touching it is named" 'Remaining steps also touch a conflicted file'
local PN_QW=$(print -r -- "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
git -C "$PN_QW" add -- ':(literal)pn"c.txt'
_ST_RUN --continue
_ST_OUT_HAS "and its resolution still holding markers refuses" 'still contains conflict markers'
_ST_RUN --abort
git reset -q -- ':(literal)pn"c.txt' && git checkout -q -- ':(literal)pn"c.txt'
# As does one named like a stage, `:1:pn.txt` being stage 1 of `pn.txt` to an index lookup
printf '1\n2\n3\n' > 1:pn.txt && git add -- ':(literal)1:pn.txt' && git commit -qm "PN stage-like base"
local PN_SB=$(git rev-parse HEAD)
printf '1\nL\n3\n' > 1:pn.txt && git commit -qm "PN stage-like later" -- ':(literal)1:pn.txt'
printf '1\nS\n3\n' > 1:pn.txt && git add -- ':(literal)1:pn.txt'
_ST_RUN --amend-into="$PN_SB" -- ':(literal)1:pn.txt'
PN_QW=$(print -r -- "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
git -C "$PN_QW" add -- ':(literal)1:pn.txt'
_ST_RUN --continue
_ST_OUT_HAS "as does one named like a stage" 'still contains conflict markers'
_ST_RUN --abort
git reset -q -- ':(literal)1:pn.txt' && git checkout -q -- ':(literal)1:pn.txt'
