# Status: idle report
_ST_SCENARIO "\e[1;96m[14] status (idle)\e[0m"
_ST_RUN --status
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "reports idle" '^git-edit: ok – no operation in flight'
