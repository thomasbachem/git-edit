# A value gone missing, a flag name running on, a resume given more to do, a stale range end and a
# `-C` path holding an `=` or landing in the checkout each read as given – refused or resolved
_ST_SCENARIO "\e[1;96m[147] arguments read as given: a missing value, a run-on flag, a busy resume, a stale range end, a -C path\e[0m"
local AG_T AG_OLD AG_ORPH AG_WT AG_P
_AG_NEW () {
	# Args: <name> – a repo of `AG c1` … `AG c5`, adding a.txt … e.txt
	local F N=0
	_ST_PZ_NEW "$1"
	for F in a b c d e; do N=$((N+1)); _ST_PZ_C "$F.txt" "line $F" "AG c$N"; done
}
# The `--` an empty variable leaves where a value goes refuses, as a flag there does
_AG_NEW ag1
AG_T=$(git rev-parse HEAD)
print more >> a.txt
_ST_RUN --commit --text -- a.txt
_ST_EQ "--text taking the -- as its value refuses" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "naming the -- it got" '--text takes a value, and got the -- that ends the options'
print more >> b.txt && git add b.txt
_ST_RUN --amend-into=HEAD~1 --verify -- b.txt
_ST_EQ "as does --verify, checking nothing" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "naming it there" '--verify takes a value, and got the --'
_ST_RUN --commit --text=-- -- a.txt
_ST_EQ "while glued on, -- is the message" "${RC}:$(git log -1 --format=%s)" "0:--"
# A word running on past a value flag's name is an unknown option, not that flag's value
AG_T=$(git rev-parse HEAD)
print 'AG subject' > "$TMP/ag-msg"
print more >> c.txt
_ST_RUN --commit --text-file="$TMP/ag-msg" -- c.txt
_ST_EQ "--text-file refuses rather than land its path as the message" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "as an unknown option" 'Unknown option: --text-file='
_ST_RUN --amend-into=HEAD~1 --verify-span=true -- b.txt
_ST_EQ "--verify-span=true refuses rather than gate on -span=true" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "as one too" 'Unknown option: --verify-span=true'
_ST_RUN --commit --text "AG rm" --rmc.txt
_ST_OUT_HAS "a value stuck to an input flag too" 'Unknown option: --rmc.txt'
_ST_RUN --carryfoo
_ST_OUT_HAS "and to a flag whose value is optional" 'Unknown option: --carryfoo'
_ST_RUN --amend-into=HEAD~1 --verify=true --verify-span -- b.txt
_ST_EQ "while --verify-span itself still gates the fold" "${RC}:$(git show HEAD~1:b.txt | tail -1)" "0:more"
# A resume or cancel given a commit or a mode beside it refuses, the pause left as it was
_AG_NEW ag2
AG_T=$(git rev-parse HEAD)
_ST_RUN "$(git rev-parse HEAD~2)"
AG_WT=$(_ST_PZ_WT)
print edited >> "${AG_WT:-$ST_NO_WT}/c.txt"
_ST_RUN --continue -d HEAD~4 --move=HEAD~3 --after=HEAD
_ST_EQ "--continue beside a drop and a move refuses" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "naming what it got" '--continue acts on the pause alone – it takes no <commit> or mode, and got: -d --move --after HEAD~4'
_ST_CHECK "the pause still pending" test -f "$(git rev-parse --git-common-dir)/git-edit-state"
_ST_RUN --abort -M --text "AG new msg" HEAD
_ST_OUT_HAS "--abort beside a reword refuses" '--abort acts on the pause alone – it takes no <commit> or mode, and got: -M HEAD'
_ST_RUN --skip HEAD~1
_ST_OUT_HAS "--skip beside a commit refuses" '--skip acts on the pause alone .* got: HEAD~1'
_ST_RUN --continue --amend-into=HEAD --tree=HEAD
_ST_OUT_HAS "as does --continue beside a fold" 'got: --amend-into --tree'
_ST_RUN --continue --text "AG c3 edited"
_ST_EQ "while --continue --text still lands the edit" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG c5|AG c4|AG c3 edited|AG c2|AG c1|"
_ST_RUN "$(git rev-parse HEAD~1)"
_ST_RUN --abort --allow-other-actor -y --text "AG unused" --no-verify
_ST_CHECK "and --abort beside what a resume takes still cancels, the way out never blocked" sh -c '[ "$1" = 0 ] && [ ! -f "$2" ]' _ "$RC" "$(git rev-parse --git-common-dir)/git-edit-state"
# A range end a rewrite staled resolves as a single commit does, a failing end named
_AG_NEW ag3
AG_OLD=$(git rev-parse --short HEAD~1)
_ST_RUN -M --text "AG c3 reworded" HEAD~2
_ST_RUN -d -y "$AG_OLD..HEAD"
_ST_EQ "a range from a stale start drops its current commits" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG c3 reworded|AG c2|AG c1|"
_ST_OUT_HAS "naming the identity it took" "Commit $AG_OLD was rewritten – using its current identity"
AG_T=$(git rev-parse HEAD)
AG_ORPH=$(git commit-tree "HEAD^{tree}" -m "AG orphan")
_ST_RUN -d "$AG_ORPH..HEAD"
_ST_EQ "a range from a commit off the branch refuses" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "naming its start and why" "Invalid commit range: $AG_ORPH..HEAD – its start ${AG_ORPH:0:7} (AG orphan) is not in HEAD's history"
_ST_RUN -d "HEAD~1..$AG_ORPH"
_ST_OUT_HAS "or its end" "– its end ${AG_ORPH:0:7} (AG orphan) is not in HEAD's history"
_ST_RUN -d "no-such-commit..HEAD"
_ST_OUT_HAS "an end naming nothing named as such" 'its start no-such-commit names nothing in this repository'
_ST_RUN -d "HEAD^{tree}..HEAD"
_ST_OUT_HAS "an end naming a tree as a tree" 'its start HEAD^{tree} names a tree, not a commit'
_ST_RUN -d "HEAD^{tree}"
_ST_EQ "a tree given as the commit refuses" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "as a tree, not as missing" '<commit> HEAD^{tree} names a tree, not a commit'
# With both ends stale, each commit the range named resolves alone – the span between their current
# identities holds a commit moved in since, which a drop would take too
_AG_NEW ag5
local AG_O3=$(git rev-parse HEAD~2) AG_O4=$(git rev-parse HEAD~1)
_ST_RUN -M --text "AG c2 reworded" HEAD~3
_ST_RUN --move=HEAD --after=HEAD~2
_ST_EQ "a commit moved in between the stale ends" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG c4|AG c5|AG c3|AG c2 reworded|AG c1|"
_ST_RUN -d -y "$AG_O3..$AG_O4"
_ST_EQ "a range of two stale ends drops what it named alone" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG c5|AG c2 reworded|AG c1|"
# A `-C` path given apart keeps its own `=`, a new one inside the checkout refuses unless ignored
_AG_NEW ag4
AG_P=$TMP/ag-dir
mkdir -p "$AG_P"
_ST_RUN --dir "$AG_P/wt=scratch" -d -y HEAD
_ST_EQ "a path given apart keeps its =" "${RC}:$(git log -1 --format=%s)" "0:AG c4"
_ST_CHECK "the worktree made there, none in the checkout" sh -c '[ -e "$1/.git" ] && [ ! -e scratch ]' _ "$AG_P/wt=scratch"
AG_T=$(git rev-parse HEAD)
_ST_RUN -Cy -d -y HEAD
_ST_EQ "-Cy, a new path y in the checkout, refuses" "${RC}:$(git rev-parse HEAD)" "1:$AG_T"
_ST_OUT_HAS "naming the working tree it lies in" "path '.*/y' is new and inside the working tree"
_ST_CHECK "making no worktree there" test ! -e y
print -r -- 'wtig/' > .gitignore && git add .gitignore && git commit -qm "AG ignore"
_ST_RUN -C=wtig -d -y HEAD~1
_ST_EQ "a new path git ignores there is taken" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG ignore|AG c3|AG c2|AG c1|"
_ST_CHECK "unseen by the checkout's status" sh -c '! git status --porcelain --untracked-files=all | grep -q wtig'
git worktree add -q --detach inwt HEAD 2>/dev/null
_ST_RUN -C=inwt -d -y HEAD~1
_ST_EQ "an existing worktree in the checkout is still reused" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG ignore|AG c2|AG c1|"
# `-s` reads its value the same way – an `=` inside one given apart is part of it
_ST_PZ_C f.txt f "AG a=b"
_ST_RUN -y -s ':/AG a=b'
_ST_EQ "-s given a value holding = squashes that commit" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:AG ignore|AG c2|AG c1|"
_ST_CHECK "carrying its file" git show HEAD:f.txt
# A `:/<text>` value names the commit its search finds wherever a commit is taken – a `^{commit}`
# appended to it joined the search text
_AG_NEW ag6
_ST_RUN -y -s=':/AG c2' HEAD~2
_ST_EQ "-s=:/<text> squashes into the commit it finds" "${RC}:$(git log --format=%s | wc -l | tr -d ' '):$(git ls-tree --name-only HEAD~2 c.txt)" "0:4:c.txt"
_ST_RUN --move=':/AG c5' --after=':/AG c1'
_ST_EQ "--move and --after take one too" "${RC}:$(git log -1 --format=%s HEAD~2)" "0:AG c5"
print folded >> a.txt && git add a.txt
_ST_RUN --amend-into=':/AG c5' -- a.txt
_ST_EQ "as does --amend-into" "${RC}:$(git show HEAD~2:a.txt | tail -1)" "0:folded"
print placed > g.txt
_ST_RUN --commit --text "AG placed" --after=':/AG c1' -- g.txt
_ST_EQ "and a placement's --after" "${RC}:$(git log --reverse --format=%s | sed -n 2p)" "0:AG placed"
cd "$TMP/repo"
