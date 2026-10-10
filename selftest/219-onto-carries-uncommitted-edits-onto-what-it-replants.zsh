# `--onto` brings the checkout's uncommitted edits along onto what it replants, as any landing does:
# • An edit on a path the upstream changed merges onto what landed, staged or not, a clean merge
#   written in – a conflict writes nothing, its `git merge-file` named and the file on record
# • A file standing where the upstream adds one stays, as a change to what landed
# • A paused replant brings them along at its `--continue` the same way
# • A checkout halfway through a merge, rebase, cherry-pick or revert, or holding unmerged entries,
#   still refuses before anything moves, as no sync can bring its work along
_ST_SCENARIO "\e[1;96m[219] --onto carries uncommitted edits onto what it replants\e[0m"
local OC_UP

# Makes and enters repo <name>: `main` changing line 1 of `f.txt`, `feat` adding `g.txt` – on `feat`
_OC219_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	print -l 1 2 3 4 5 6 > f.txt && git add f.txt && git commit -qm "OC base"
	git checkout -q -b feat && _ST_PZ_C g.txt g "OC feat"
	git checkout -q main && print -l 1up 2 3 4 5 6 > f.txt && git commit -qam "OC up" && OC_UP=$(git rev-parse HEAD)
	git checkout -q feat
}

# An unstaged edit merges onto what landed
_OC219_REPO oc1
print -l 1 2 3 4 5 6mine > f.txt
_ST_RUN --onto=main
_ST_EQ "a replant over an edit on a path the upstream changed lands" "$RC:$(git rev-parse HEAD~1)" "0:$OC_UP"
_ST_EQ "the edit merged onto what landed, unstaged" "$(tr '\n' ' ' < f.txt):$(git status --porcelain | tr '\n' '|')" "1up 2 3 4 5 6mine : M f.txt|"
_ST_OUT_LACKS "never the old refusal" 'Uncommitted work sits on'
# A staged one too
_OC219_REPO oc2
print -l 1 2 3 4 5 6mine > f.txt && git add f.txt
_ST_RUN --onto=main
_ST_EQ "a staged edit lands merged as well" "$RC:$(tr '\n' ' ' < f.txt):$(git diff --name-only HEAD | tr '\n' '|')" "0:1up 2 3 4 5 6mine :f.txt|"
# A conflicting one is left as it is, its merge named, on record
_OC219_REPO oc3
print -l 1mine 2 3 4 5 6 > f.txt
_ST_RUN --onto=main
_ST_EQ "a conflicting edit lands the replant, the file as it was" "$RC:$(git rev-parse HEAD~1):$(head -1 f.txt)" "0:$OC_UP:1mine"
_ST_OUT_HAS "naming its merge" 'git merge-file -- f.txt '
_ST_RUN --status
_ST_OUT_HAS "and the file on record" "^Left unbrought by a run.s sync, still lacking what landed past [0-9a-f]*: f.txt – "
# A file standing where the upstream adds one stays
_OC219_REPO oc4
git checkout -q main && _ST_PZ_C n.txt up "OC n" && OC_UP=$(git rev-parse HEAD) && git checkout -q feat
print -r -- mine > n.txt
_ST_RUN --onto=main
_ST_EQ "an untracked file where the upstream adds one stays" "$RC:$(<n.txt):$(git show HEAD:n.txt)" "0:mine:up"
# A paused replant carries the edit at its resume
_ST_PZ_NEW oc5
git config rerere.enabled false
print -r -- 1 > f.txt && print -l k1 k2 k3 > k.txt && git add -A && git commit -qm "OC base"
git checkout -q -b feat && _ST_PZ_C f.txt "1 feat" "OC feat f"
git checkout -q main && print -r -- "1 main" > f.txt && print -l k1up k2 k3 > k.txt && git commit -qam "OC main" && git checkout -q feat
print -l k1 k2 k3mine > k.txt
_ST_RUN --onto=main
_ST_EQ "a replant over an edit pauses at its own conflict, nothing refused" "$RC:$([ -f .git/git-edit-state ] && echo paused)" "2:paused"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "1 both"
_ST_RUN --continue
_ST_EQ "its resume lands, the edit merged onto what landed" "$RC:$(git show HEAD:f.txt):$(tr '\n' ' ' < k.txt)" "0:1 both:k1up k2 k3mine "
# Halfway through a sequence, it refuses before anything moves
_OC219_REPO oc6
print -l 1 2 3 4 5 6mine > f.txt
OC_UP=$(git rev-parse HEAD)
_ST_RUN_UNSYNCED --onto=main
_ST_EQ "a checkout halfway through a sequence refuses" "$RC:$(git rev-parse HEAD)" "1:$OC_UP"
_ST_OUT_HAS "naming why" 'halfway through a cherry-pick or revert sequence, so no sync can bring it along – nothing was changed'
_ST_OUT_HAS "with the steps per path" 'f.txt (modified) – yours: '
