# Undo refuses after the branch moved on
_ST_SCENARIO "\e[1;96m[13] undo CAS guard\e[0m" # needs 11
echo "zeta" > z.txt && git add z.txt && git commit -qm "Z commit"
_ST_RUN --undo
_ST_CHECK "refuses" test "$RC" != "0"
_ST_OUT_HAS "names the reason" 'has moved since'
