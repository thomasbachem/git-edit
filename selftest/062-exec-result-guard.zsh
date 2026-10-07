# --exec's result guard refuses to orphan a remote ref
# --exec can't know its targets up front, so the pushed guard runs on
# the result – a remote ref reachable from the old tip but not the new
# one refuses the apply
_ST_SCENARIO "\e[1;96m[62] exec result guard\e[0m"
echo "xg" > xg.txt && git add xg.txt && git commit -qm "XG commit"
git update-ref refs/remotes/guard/main HEAD
local XG_TIP=$(git rev-parse HEAD)
_ST_RUN --exec -- git commit --amend -m "XG amended"
_ST_EQ "exec orphaning a remote ref refuses" "$RC" "1"
_ST_OUT_HAS "naming the ref" 'rewrote pushed history.*guard/main'
_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$XG_TIP"
_ST_RUN --allow-pushed --exec -- git commit --amend -m "XG amended"
_ST_EQ "--allow-pushed overrides" "$RC" "0"
git update-ref -d refs/remotes/guard/main
