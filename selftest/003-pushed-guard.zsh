# Pushed guard: refuse B, allow with --allow-pushed
_ST_SCENARIO "\e[1;96m[3] pushed guard\e[0m" # needs 2
_ST_RUN -M --text="B reworded" "$SHA_B"
_ST_CHECK "refuses pushed commit" test "$RC" != "0"
_ST_OUT_HAS "names the reason" 'already pushed'
_ST_RUN --allow-pushed -M --text="B reworded" "$SHA_B"
_ST_EQ "--allow-pushed overrides" "$RC" "0"
_ST_RUN --undo
_ST_EQ "undo restores" "$(git rev-parse HEAD)" "$PRE_HEAD"
