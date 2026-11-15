# Lines a fold or squash adds alone resolve its stops beside the line above them, else the one
# below, held once there and followed to it – words added in a line beside those before them,
# else after – an `-s=auto` fixup's and a fold's alike:
# • A neighbor held twice, missing on both sides, or its text on another line pauses as before
# • The gate checks a commit a placement resolved as a resolver's own
# • An `--amend-into` whose tip then differs from the fold applied to the tip refuses where it
#   placed lines so, on a first run and on a resume – nothing applied, a rerun by hand named
_ST_SCENARIO "\e[1;96m[278] a fold places its insertions beside a line held once\e[0m"
local AI_T AI_O AI_WT
# Commits `test.js` as the field had it – a list, runners, one-line judges – then one adding
# `End lock` to each, a judge after it too, and one rewriting its entry and trading that judge
# for one at the end, the fold's text left for the last: an entry after `End lock`, a runner
# before `runFind`, a judge after `jE,` – sets `AI_T`
_AI_FIELD () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l "cases = [" "  'Rooms'," "  'Find'," "];" "" "function runRooms() {" "}" "" "function runFind() {" "}" "" \
		"judges = { rooms: jR, find: jF };" > test.js && git add test.js && git commit -qm "AI target"
	AI_T=$(git rev-parse HEAD)
	print -l "cases = [" "  'Rooms'," "  'End lock'," "  'Find'," "];" "" "function runRooms() {" "}" "" "function runEndLock() {" "}" "" \
		"function runFind() {" "}" "" "judges = { rooms: jR, end_lock: jE, x: jX, find: jF };" > test.js && git commit -qam "AI adds end lock"
	print -l "cases = [" "  'Rooms'," "  'End lock', slow," "  'Find'," "];" "" "function runRooms() {" "}" "" "function runEndLock() {" "}" "" \
		"function runFind() {" "}" "" "judges = { rooms: jR, end_lock: jE, find: jF, zed: jZ };" > test.js && git commit -qam "AI rewrites"
	print -l "cases = [" "  'Rooms'," "  'End lock', slow," "  'Local'," "  'Find'," "];" "" "function runRooms() {" "}" "" \
		"function runEndLock() {" "}" "" "function runLocal() {" "}" "" "function runFind() {" "}" "" \
		"judges = { rooms: jR, end_lock: jE, local: jL, find: jF, zed: jZ };" > test.js
}
# Prints <rev>'s `test.js` on one line
_AI_AT () {
	# Args: <rev>
	git show "${1}:test.js" | tr '\n' '|'
}
local AI_AT_T="cases = [|  'Rooms',|  'Local',|  'Find',|];||function runRooms() {|}||function runLocal() {|}||function runFind() {|}||judges = { rooms: jR, local: jL, find: jF };|"
local AI_AT_C="cases = [|  'Rooms',|  'End lock',|  'Local',|  'Find',|];||function runRooms() {|}||function runEndLock() {|}||function runLocal() {|}||function runFind() {|}||judges = { rooms: jR, end_lock: jE, local: jL, x: jX, find: jF };|"
_AI_FIELD ai-auto
git commit -qam "fixup! AI target"
AI_O=$(git rev-parse 'HEAD^{tree}')
_ST_RUN -s=auto HEAD
_ST_EQ "-s=auto places the entry, the runner and the judge at each stop, the tip as it was" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse 'HEAD^{tree}')" "0:AI rewrites|AI adds end lock|AI target|:$AI_O"
_ST_EQ "the target takes each beside the line or word after it, as it lacks End lock" "$(_AI_AT HEAD~2)" "$AI_AT_T"
_ST_EQ "End lock's commit takes them in the tip's order, the judge after its word" "$(_AI_AT HEAD~1)" "$AI_AT_C"
_ST_OUT_HAS "saying so" "Made the fixups' line replacements at"
_AI_FIELD ai-fold
_ST_RUN --amend-into="$AI_T" --whole -- test.js
_ST_EQ "a fold of the same lands with no pause" \
	"$RC:$(_AI_AT HEAD~2):$(_AI_AT HEAD~1):$(git status --porcelain)" "0:$AI_AT_T:$AI_AT_C:"
_ST_OUT_HAS "its stops resolved" "Made the fold's line replacements in the 3 commit(s) the replay stopped at"

# The line above held twice there, the one below takes it – the gate checking that commit
_ST_PZ_NEW ai-twice
print -l sep x sep old tail > f && git add f && git commit -qm "AI2 target"
print -l x sep tail > f && git commit -qam "AI2 rewrites"
_ST_PZ_C other o "AI2 later"
print -l x sep new tail > f && git commit -qam "fixup! AI2 target"
git config edit.verifyCmd "sh -c 'git log -1 --format=%s \"\$GIT_EDIT_VERIFY_COMMIT\" >> \"$TMP/ai-verified\"'"
: > "$TMP/ai-verified"
_ST_RUN -s=auto HEAD
_ST_EQ "a line above held twice places it before the line below" \
	"$RC:$(git show HEAD~2:f | tr '\n' '|'):$(git show HEAD~1:f | tr '\n' '|')" "0:sep|x|sep|old|new|tail|:x|sep|new|tail|"
_ST_EQ "the gate checking the commit a placement resolved" "$(grep -c -x 'AI2 rewrites' "$TMP/ai-verified")" "1"
git config --unset edit.verifyCmd

# Lines added between two held twice on the tip derive nothing, the fold's other files resolving
_ST_PZ_NEW ai-unplaced
print -l x "}" "}" y > u && print -l one two0 > f && git add u f && git commit -qm "AI9 target"
AI_T=$(git rev-parse HEAD)
print -l one two > f && git commit -qam "AI9 rewrites"
print -l x "}" new "}" y > u && print -l ONE two > f
_ST_RUN --amend-into="$AI_T" --whole -- u f
_ST_EQ "a file whose insertion nothing places leaves the others' stops resolving" \
	"$RC:$(git show HEAD~1:u | tr '\n' ' '):$(git show HEAD~1:f | tr '\n' ' ')" "0:x } new } y :ONE two0 "

# Pauses: a line above held twice and none below, both lines rewritten later, the text above written
# anew on another line, and words whose neighbors a later commit both rewrote
_ST_PZ_NEW ai-held
print -l sep head sep tail0 > f && git add f && git commit -qm "AI3 target"
print -l head sep tail > f && git commit -qam "AI3 rewrites"
print -l head sep new tail > f && git commit -qam "fixup! AI3 target"
_ST_RUN -s=auto HEAD
AI_WT=$(_ST_PZ_WT)
_ST_EQ "a line above held twice and none below pauses at the target" \
	"$RC:$(git -C "${AI_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null):$(git -C "${AI_WT:-$ST_NO_WT}" log -1 --format=%s HEAD 2>/dev/null)" "2:f:AI3 target"
_ST_OUT_LACKS "placing nothing" "Made the"
_ST_RUN --abort
_ST_PZ_NEW ai-both
print -l a0 b0 > f && git add f && git commit -qm "AI4 target"
AI_T=$(git rev-parse HEAD)
print -l a1 b1 > f && git commit -qam "AI4 rewrites"
print -l a1 new b1 > f
_ST_RUN --amend-into="$AI_T" --whole -- f
_ST_EQ "lines either side rewritten later pause the fold's stop" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U 2>/dev/null)" "2:f"
_ST_OUT_LACKS "placing nothing there" "Made the"
_ST_RUN --abort
git checkout -q -- f
_ST_PZ_NEW ai-anew
print -l A other B0 > f && git add f && git commit -qm "AI5 target"
print -l other A B > f && git commit -qam "AI5 writes A anew"
print -l other A new B > f && git commit -qam "fixup! AI5 target"
_ST_RUN -s=auto HEAD
_ST_EQ "a line above whose text the target holds on another line pauses" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U 2>/dev/null)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW ai-words
print -l "k = { a: 1, b: 2 };" > f && git add f && git commit -qm "AI6 target"
AI_T=$(git rev-parse HEAD)
print -l "k = { aa: 11, bb: 22 };" > f && git commit -qam "AI6 rewrites"
print -l "k = { aa: 11, c: 3, bb: 22 };" > f
_ST_RUN --amend-into="$AI_T" --whole -- f
_ST_EQ "words added between two a later commit rewrote pause" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U 2>/dev/null)" "2:f"
_ST_RUN --abort
git checkout -q -- f

# A tip the fold applied to the tip doesn't make – a staged revert of a later commit dissolving
# against it – refuses where lines were placed, landing with its note where only replaced

# Commits `f` and `g`, each changed later, staging <f> and `g`'s revert – sets `AI_T`, `AI_O`
_AI_DISSOLVE () {
	# Args: <repo name> <f as folded>
	_ST_PZ_NEW "$1"
	print -l one two0 > f && print "v = 1" > g && git add f g && git commit -qm "AI7 target"
	AI_T=$(git rev-parse HEAD)
	print -l one two > f && git commit -qam "AI7 rewrites"
	print "v = 2" > g && git commit -qam "AI7 sets v"
	AI_O=$(git rev-parse HEAD)
	print -r -- "$2" > f && print "v = 1" > g && git add f g
}
_AI_DISSOLVE ai-tip "$(print -l one mid two)"
_ST_RUN --amend-into="$AI_T" -- f g
_ST_EQ "a fold placing a line, its tip off the fold's, refuses, nothing applied" \
	"$RC:$(git rev-parse HEAD):$(git diff --cached --name-only | tr '\n' ' '):$(_ST_PZ_WT):$(git worktree list | wc -l | tr -d ' ')" "1:$AI_O:f g ::1"
_ST_OUT_HAS "naming the path" "The rebuilt tip differs from the fold applied to the tip, at g, where its own resolutions placed lines it adds beside others – nothing was applied"
_ST_OUT_HAS "and the rerun by hand in its trailer" "^git-edit: error – .* – run it again under GIT_EDIT_NO_SELF_RESOLVE=1 to resolve its stops by hand"
_ST_OUT_HAS "forgetting what rerere recorded of it" "Forgot 2 resolution(s) rerere recorded of this run's own"
git restore --staged f g && git checkout -q -- f g
_AI_DISSOLVE ai-tip-replaced "$(print -l ONE two)"
_ST_RUN --amend-into="$AI_T" -- f g
_ST_EQ "one only replacing lands as before" "$RC:$(git show HEAD~2:f | tr '\n' ' ')" "0:ONE two0 "
_ST_OUT_HAS "with its note" "Note: tip tree differs from the staged result"
# A resume refuses too, its first run's placement kept in the pause, which stays
# for the cancel – its stops past them a copy of a replaced line, resolved by hand
_ST_PZ_NEW ai-tip-resume
print -l one two0 > f && print "v = 1" > g && print -l a b > k && git add f g k && git commit -qm "AI8 target"
AI_T=$(git rev-parse HEAD)
print -l one two > f && git commit -qam "AI8 rewrites f"
print -l a a b > k && git commit -qam "AI8 copies a"
print -l a b > k && git commit -qam "AI8 drops the copy"
print "v = 2" > g && git commit -qam "AI8 sets v"
AI_O=$(git rev-parse HEAD)
print -l one mid two > f && print "v = 1" > g && print -l A b > k && git add f g k
_ST_RUN --amend-into="$AI_T" -- f g k
AI_WT=$(_ST_PZ_WT)
_ST_EQ "a stop it can't resolve pauses past its placements" \
	"$RC:$(git -C "${AI_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null):$(git -C "${AI_WT:-$ST_NO_WT}" show HEAD:f 2>/dev/null | tr '\n' ' ')" "2:k:one mid two "
_ST_RESOLVE "${AI_WT:-$ST_NO_WT}" k "$(print -l A a b)"
_ST_RUN --continue
_ST_RESOLVE "${AI_WT:-$ST_NO_WT}" k "$(print -l A b)"
_ST_RUN --continue
_ST_EQ "its resume refuses, its pause kept" "$RC:$(git rev-parse HEAD):$(_ST_PZ_WT)" "1:$AI_O:${AI_WT:-$ST_NO_WT}"
_ST_OUT_HAS "naming the cancel" "Cancel with git edit --abort, then fold again under GIT_EDIT_NO_SELF_RESOLVE=1"
_ST_RUN --abort
_ST_EQ "--abort leaves the branch and the staging" "$RC:$(git rev-parse HEAD):$(git diff --cached --name-only | tr '\n' ' ')" "0:$AI_O:f g k "
git restore --staged f g k && git checkout -q -- f g k
unfunction _AI_FIELD _AI_AT _AI_DISSOLVE
cd "$TMP/repo"
