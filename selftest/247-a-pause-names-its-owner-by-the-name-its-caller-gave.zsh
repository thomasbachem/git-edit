# A pause names its owner by the name its caller gave beside the label – in `--status`, a refused
# resume and a run it is in the way of – on one line, and kept when another label takes it on
_ST_SCENARIO "\e[1;96m[247] a pause names its owner by the name its caller gave\e[0m"
local AN_SF
_ST_PZ_NEW an1
_ST_PZ_C f.txt $'1\n2\n3' "AN c1" && _ST_PZ_C f.txt $'1\n2x\n3' "AN c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "AN c3"
AN_SF="$(git rev-parse --git-common-dir)/git-edit-state"
GIT_EDIT_ACTOR=an-a GIT_EDIT_ACTOR_NAME="Peer Session" _ST_RUN -d -y HEAD~1
_ST_EQ "the pause records the name its caller gave" "$(sed -n 's/^actor_name=//p' "$AN_SF")" "Peer Session"
GIT_EDIT_ACTOR=an-b _ST_RUN --status
_ST_OUT_HAS "--status names the owner by it" "Paused by an-a's (\"Peer Session\") run – not yours to resume"
GIT_EDIT_ACTOR=an-b _ST_RUN --continue
_ST_OUT_HAS "as does another label's refused resume" "is an-a's (\"Peer Session\") – refusing to continue it as an-b"
GIT_EDIT_ACTOR=an-b _ST_RUN -M --text "AN c3 reworded" HEAD
_ST_OUT_HAS "and a run the pause is in the way of" "paused for its resolution – an-a's (\"Peer Session\")"
GIT_EDIT_ACTOR=an-a _ST_RUN --abort
# Another label taking an edit on keeps its owner's name in the pause its replay writes anew
GIT_EDIT_ACTOR=an-a GIT_EDIT_ACTOR_NAME="Peer Session" _ST_RUN HEAD~1
print -r -- $'1\n2q\n3' > "$(_ST_PZ_WT)/f.txt"
GIT_EDIT_ACTOR=an-b GIT_EDIT_ACTOR_NAME="Taker" _ST_RUN --continue --allow-other-actor
_ST_EQ "another label taking the pause on keeps its owner's name" "$(sed -n 's/^actor=//p;s/^actor_name=//p' "$AN_SF")" $'an-a\nPeer Session'
GIT_EDIT_ACTOR=an-a _ST_RUN --abort
# A newline or escape in the name never reaches the state file as one,
# a long one is cut, a blank one and one without a label recorded as none
GIT_EDIT_ACTOR=an-a GIT_EDIT_ACTOR_NAME=$'Peer\nkey=x\e[31m' _ST_RUN -d -y HEAD~1
_ST_EQ "a name keeps to one line, control characters as spaces" "$(grep -c '^key=' "$AN_SF"):$(sed -n 's/^actor_name=//p' "$AN_SF")" "0:Peer key=x [31m"
GIT_EDIT_ACTOR=an-b _ST_RUN --continue
_ST_OUT_HAS "and a refusal reads it back whole" "is an-a's (\"Peer key=x \[31m\") – refusing to continue it as an-b"
GIT_EDIT_ACTOR=an-a _ST_RUN --abort
GIT_EDIT_ACTOR=an-a GIT_EDIT_ACTOR_NAME="$(printf 'n%.0s' {1..150})" _ST_RUN -d -y HEAD~1
_ST_EQ "a long name is cut to 100 characters" "$(sed -n 's/^actor_name=//p' "$AN_SF" | tr -d '\n' | wc -c | tr -d ' ')" "100"
GIT_EDIT_ACTOR=an-a _ST_RUN --abort
GIT_EDIT_ACTOR=an-a GIT_EDIT_ACTOR_NAME=$' \n\t' _ST_RUN -d -y HEAD~1
_ST_EQ "a blank one records none" "$(grep -c '^actor_name=' "$AN_SF")" "0"
GIT_EDIT_ACTOR=an-a _ST_RUN --abort
GIT_EDIT_ACTOR_NAME="Nobody" _ST_RUN -d -y HEAD~1
_ST_EQ "and a caller with no label records none" "$(grep -c '^actor_name=' "$AN_SF")" "0"
_ST_RUN --abort
