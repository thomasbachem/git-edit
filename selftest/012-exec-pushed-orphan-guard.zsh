_ST_SCENARIO "\e[1;96m[12] exec pushed-orphan guard\e[0m"
PRE_HEAD=$(git rev-parse HEAD)
_ST_RUN --exec -- git reset --hard "$SHA_A"
_ST_CHECK "refuses" test "$RC" != "0"
_ST_OUT_HAS "names the reason" 'pushed history'
_ST_EQ "branch unchanged" "$(git rev-parse HEAD)" "$PRE_HEAD"
