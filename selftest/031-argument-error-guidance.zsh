# Argument mistakes name the right form instead of dead-ending
_ST_SCENARIO "\e[1;96m[31] argument-error guidance\e[0m"
_ST_RUN -M "Some prose that is a message, not a commit"
_ST_EQ "prose in the <commit> slot refused" "$RC" "1"
_ST_OUT_HAS "points at --text" 'pass it as --text'
_ST_RUN -M --text="Some subject"
_ST_EQ "missing commit refused" "$RC" "1"
_ST_OUT_HAS "names the missing argument" 'Missing <commit>'
# The retry is always the tip, so the error has to show what that is – and its example
# names it by SHA, the one form a parallel session's landing cannot retarget
_ST_OUT_HAS "with an example naming the tip by SHA" "e\.g\. 'git edit -M --text=\"…\" $(git rev-parse --short HEAD)'"
_ST_OUT_HAS "and says what HEAD currently is" 'HEAD is currently'
_ST_OUT_HAS "with its subject, not just a sha" \
	"HEAD is currently [0-9a-f]\{7,\} ."
_ST_RUN --amend-into=HEAD -M
_ST_EQ "--amend-into + -M refused" "$RC" "1"
_ST_OUT_HAS "points at the reword form" 'To reword only'
# A range start naming nothing, or off its end's line, refuses – read as a root commit's missing
# parent, it took all history up to the end
local AE_TIP=$(git rev-parse HEAD)
_ST_RUN -d "no-such-commit..HEAD"
_ST_EQ "a range from an unknown commit refused" "$RC" "1"
_ST_OUT_HAS "as an invalid range" 'Invalid commit range: no-such-commit\.\.HEAD'
_ST_RUN -d "$(git commit-tree "HEAD^{tree}" -m "AE orphan")..HEAD"
_ST_OUT_HAS "as is one from a commit off the branch, naming that end" "Invalid commit range: .* – its start [0-9a-f]\{7\} (AE orphan) is not in HEAD's history"
_ST_EQ "neither dropping a thing" "$(git rev-parse HEAD)" "$AE_TIP"
_ST_RUN
_ST_EQ "bare invocation still exits 1" "$RC" "1"
_ST_OUT_HAS "bare invocation still shows usage" 'usage: git edit'
