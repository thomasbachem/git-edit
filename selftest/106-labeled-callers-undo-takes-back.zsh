# The journal is the repo's, so its last line can be a parallel session's on any branch
_ST_SCENARIO "\e[1;96m[106] a labeled caller's --undo takes back only its own run\e[0m"
echo u > ua.txt && git add ua.txt && git commit -qm "UA base"
local UA_BASE=$(git rev-parse HEAD)
export GIT_EDIT_ACTOR=ua-peer
_ST_RUN -M --text="UA by the peer" "$UA_BASE"
local UA_PEER=$(git rev-parse HEAD)
_ST_EQ "the journal closes its line on a tab and the label" "$(tail -1 "$(git rev-parse --git-common-dir)/git-edit-journal" | cut -d' ' -f5-)" "reword ${UA_BASE:0:7}"$'\t'"ua-peer"
_ST_RUN --status
_ST_OUT_HAS "which --status reads apart from the operation" "Last completed: reword ${UA_BASE:0:7} ("
export GIT_EDIT_ACTOR=ua-self
_ST_RUN --undo
_ST_EQ "another caller's run is refused" "$RC" "1"
_ST_OUT_HAS "naming whose it is" 'ran as ua-peer, this undo as ua-self'
_ST_EQ "and the branch stays" "$(git rev-parse HEAD)" "$UA_PEER"
_ST_RUN -M --text="UA by itself" "$UA_PEER"
_ST_RUN --undo
_ST_EQ "its own run it takes back" "$RC:$(git rev-parse HEAD)" "0:$UA_PEER"
_ST_RUN --undo
_ST_EQ "while the peer's under it still refuses" "$RC" "1"
_ST_RUN --undo --allow-other-actor
_ST_EQ "unless --allow-other-actor says it is meant" "$RC:$(git rev-parse HEAD)" "0:$UA_BASE"
# A run journaled unlabeled – a person's, or one from before labels – is no labeled caller's
export GIT_EDIT_ACTOR=
_ST_RUN -M --text="UA by hand" "$UA_BASE"
export GIT_EDIT_ACTOR=ua-self
_ST_RUN --undo
_ST_EQ "an unlabeled run is refused too" "$RC" "1"
_ST_OUT_HAS "as an unlabeled caller's" 'ran as an unlabeled caller'
export GIT_EDIT_ACTOR=
_ST_RUN --undo
_ST_EQ "which an unlabeled caller takes back" "$(git rev-parse HEAD)" "$UA_BASE"
export GIT_EDIT_ACTOR=ua-peer
_ST_RUN -M --text="UA by the peer again" "$UA_BASE"
export GIT_EDIT_ACTOR=
_ST_RUN --undo
_ST_EQ "as it does a labeled one" "$RC:$(git rev-parse HEAD)" "0:$UA_BASE"
# A label's other characters map to `_` in the reflog, and the run says so, while the journal keeps
# it as given, `$'…'`-quoted, so none breaks its fields and two mapping alike stay apart
export GIT_EDIT_ACTOR=$'ua\tunsafe'
_ST_RUN -M --text="UA unsafe" "$UA_BASE"
_ST_EQ "an unsafe label journals as given, quoted" "$(tail -1 "$(git rev-parse --git-common-dir)/git-edit-journal" | cut -d' ' -f5-)" "reword ${UA_BASE:0:7}"$'\t'"\$'ua\\tunsafe'"
_ST_OUT_HAS "saying it was mapped" 'Labeled ua_unsafe – GIT_EDIT_ACTOR keeps letters, digits'
export GIT_EDIT_ACTOR=
