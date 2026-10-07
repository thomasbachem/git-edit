# Standalone commands refuse stray arguments
_ST_SCENARIO "\e[1;96m[6c] stray-argument refusal\e[0m"
_ST_RUN --undo "$(git rev-parse HEAD)"
_ST_CHECK "refuses" test "$RC" != "0"
_ST_OUT_HAS "names the reason" 'take no arguments'
