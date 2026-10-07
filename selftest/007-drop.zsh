# Drop (auto-isolated, non-TTY)
_ST_SCENARIO "\e[1;96m[7] drop\e[0m"
_ST_RUN -d "$(git rev-parse HEAD)"
_ST_EQ "exits 0" "$RC" "0"
_ST_CHECK "dropped commit's file gone" sh -c "! git cat-file -e 'HEAD:e.txt'"
