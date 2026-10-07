# Undo: reverts the reword, CAS-guarded
_ST_SCENARIO "\e[1;96m[2] undo\e[0m" # needs 1
_ST_RUN --undo
_ST_EQ "exits 0" "$RC" "0"
_ST_EQ "HEAD restored" "$(git rev-parse HEAD)" "$PRE_HEAD"
