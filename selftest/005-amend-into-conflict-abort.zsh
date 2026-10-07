# Fold conflict -> status -> abort: branch + staged intact
_ST_SCENARIO "\e[1;96m[5] amend-into conflict + abort\e[0m"
PRE_HEAD=$(git rev-parse HEAD)
local SHA_C2=$(git rev-parse HEAD~2)
echo "line1-conflict" > c.txt
git add c.txt
_ST_RUN --amend-into="$SHA_C2"
_ST_EQ "pauses with exit 2" "$RC" "2"
_ST_OUT_HAS "emits conflict trailer" '^git-edit: conflict – resolve in'
# The resolver's next question is which later steps touch the file, since
# the resolution is the state before they replay – so the pause answers it,
# naming D (which touches c.txt) and not E (which doesn't) – matched on the hint's own
# indented lines, as the raw todo above it lists every step (subjects bare before git 2.50)
_ST_OUT_HAS "flags the later steps touching a conflicted file" 'Remaining steps also touch a conflicted file'
_ST_OUT_HAS "names the step that touches it" '^    [0-9a-f]\{7,\} D commit$'
_ST_OUT_LACKS "leaves out a step touching other files" '^    [0-9a-f]\{7,\} E commit$'
_ST_EQ "branch untouched during pause" "$(git rev-parse HEAD)" "$PRE_HEAD"
_ST_RUN --status
_ST_OUT_HAS "status reports the conflict" '^git-edit: conflict – resolve in'
_ST_RUN --abort
_ST_EQ "abort exits 0" "$RC" "0"
_ST_EQ "branch still untouched" "$(git rev-parse HEAD)" "$PRE_HEAD"
_ST_CHECK "staged change preserved" sh -c "git diff --cached --name-only | grep -q c.txt"
