# A long `-h` topic opens with its usage lines, and a replant names its fork where the reflog can't:
# • A long mode's entry has its forms under its tag and its paragraphs after, as the man page does
# • `--onto` falling back to a merge base names `--onto=<upstream> --base=<sha>`, with the newest
#   commit the upstream holds a copy of where there is one, else a placeholder
# • `--onto --base` replays only what follows the fork named, listing what stays out below it, and
#   refuses a name, the tip itself or a commit off the branch
_ST_SCENARIO "\e[1;96m[234] long -h topics open with their usage, --onto takes a named fork\e[0m"
local OB_T OB_U OB_A OB_B OB_F OB_AD OB_BD OB_MB OB_TIP

for OB_T in --commit --amend-into --land --carry --exec --onto -e -M --split; do
	OB_U=$("$SELF" -h "$OB_T" 2>/dev/null | grep -m1 -A1 -E -- "^${OB_T}[ =,[]|^${OB_T}\$" | tail -1)
	_ST_CHECK "-h $OB_T opens with a usage line under its tag" test "${OB_U:0:8}" = "    git "
done
_ST_CHECK "-h --commit's first form is the plain commit of whole files" \
	grep -qE -- '^    git edit --commit --text <msg> -- <path>\.\.\. +# files wholly yours' <<<"$("$SELF" -h --commit 2>/dev/null)"
_ST_CHECK "its paragraphs follow, the first as before" \
	grep -qE -- '^  Commit each <path> as it stands in the checkout on top of the tip' <<<"$("$SELF" -h --commit 2>/dev/null)"
_ST_CHECK "-h --onto gives the form naming the fork" \
	grep -qE -- '^    git edit --onto=<upstream> --base=<sha> +# the fork named' <<<"$("$SELF" -h --onto 2>/dev/null)"
_ST_CHECK "-h base says what it means with --onto" \
	grep -qE -- 'With --onto, the commit the branch.s own work starts above' <<<"$("$SELF" -h base 2>/dev/null)"
_ST_CHECK "-h gives --onto its --base" grep -qE -- '--onto=<upstream> \[--base=<sha>\]' <<<"$("$SELF" -h 2>&1)"

# A rewrite of main kept its commits' author, date and subject but not their content, and main
# kept no reflog – the merge base sits below the real fork
_ST_PZ_NEW ob
_ST_PZ_C init.txt i "OB init"
_ST_PZ_C a.txt a "OB shared a"
OB_A=$(git rev-parse HEAD)
_ST_PZ_C b.txt b "OB shared b"
OB_B=$(git rev-parse HEAD)
git checkout -q -b strip
_ST_PZ_C f.txt f "OB feature"
OB_F=$(git rev-parse HEAD)
git checkout -q main
OB_AD=$(git log -1 --format=%ad --date=raw "$OB_A")
OB_BD=$(git log -1 --format=%ad --date=raw "$OB_B")
git reset -q --hard HEAD~2
print -r -- a2 > a.txt && git add a.txt && GIT_AUTHOR_DATE=$OB_AD git commit -qm "OB shared a"
print -r -- b2 > b.txt && git add b.txt && GIT_AUTHOR_DATE=$OB_BD git commit -qm "OB shared b"
_ST_PZ_C n.txt n "OB main moves on"
git checkout -q strip
git reflog expire --expire=now --all 2>/dev/null
_ST_RUN --onto=main
_ST_EQ "the too-wide replay stops at the rewritten commit" "$RC" "2"
_ST_OUT_HAS "flagging the guessed fork" 'could not answer'
_ST_OUT_HAS "naming the run that states the fork, the newest copy as it" \
	"name the fork: git edit --onto=main --base=${OB_B:0:12} – ${OB_B:0:7} OB shared b, the newest commit here main holds a copy of"
_ST_OUT_HAS "and again at the pause, where a tail reads it" \
	"^Or, the fork guessed as above, abort and name it: git edit --abort && git edit --onto=main --base=${OB_B:0:12}\$"
_ST_RUN --abort
_ST_EQ "an abort leaves the branch" "$RC:$(git rev-parse HEAD)" "0:$OB_F"

_ST_RUN --onto=main --base=HEAD~1
_ST_EQ "--base with --onto takes a SHA, not a name" "$RC" "1"
_ST_OUT_HAS "saying which" "--base takes the SHA of the commit this branch's own work starts above"
_ST_RUN --onto=main --base="$OB_F"
_ST_EQ "nor the tip itself" "$RC:$(git rev-parse HEAD)" "1:$OB_F"
_ST_OUT_HAS "as nothing would be below it" "--base ${OB_F:0:7} is not below strip's tip – nothing replanted"
_ST_RUN --onto=main --base="$(git rev-parse main)"
_ST_EQ "nor a commit off the branch" "$RC:$(git rev-parse HEAD)" "1:$OB_F"

_ST_RUN --onto=main --base="$OB_B"
_ST_EQ "a named fork replays only what follows it" \
	"$RC:$(git log --format=%s main..strip | tr '\n' '|'):$(git rev-parse HEAD~1)" "0:OB feature|:$(git rev-parse main)"
_ST_OUT_HAS "saying where the fork came from" "Fork point ${OB_B:0:7} OB shared b, as --base names it – not on main, so the commits up to it stay out"
_ST_OUT_HAS "and which of those main holds in no form" '^2 of them main holds in no form by patch id:'
_ST_OUT_LACKS "never guessing" 'could not answer'
_ST_CHECK "the checkout comes along" sh -c "test \"\$(cat a.txt):\$(cat f.txt)\" = 'a2:f'"

# Where the upstream merely moved, no copy names the fork – a placeholder does, and a fork named
# on the upstream itself is still on it
git checkout -q -b plain main~1
_ST_PZ_C p.txt p "OB plain own"
OB_TIP=$(git rev-parse HEAD)
git reflog expire --expire=now --all 2>/dev/null
_ST_RUN --onto=main
_ST_EQ "an upstream that only moved replants all the same" "$RC" "0"
_ST_OUT_HAS "the fork named by placeholder" 'the commit the branch.s own work starts above: git edit --onto=main --base=<sha>'
_ST_RUN --undo
git checkout -q -B plain2 "$OB_TIP"
OB_MB=$(git merge-base main plain2)
_ST_RUN --onto=main --base="$OB_MB"
_ST_EQ "a fork named on the upstream replants as the merge base would" "$RC:$(git log --format=%s main..plain2 | tr '\n' '|')" "0:OB plain own|"
_ST_OUT_HAS "still on it" "Fork point ${OB_MB:0:7} .*, as --base names it – still on main"
