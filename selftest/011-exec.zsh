# Exec: amend via isolated worktree
_ST_SCENARIO "\e[1;96m[11] exec\e[0m"
_ST_RUN --exec -- git commit --amend -m "amended via exec"
_ST_EQ "exits 0" "$RC" "0"
_ST_EQ "amend applied" "$(git log --format=%s -1)" "amended via exec"
# Two shapes that ran the wrong thing in the wild – a quoted shell line as one argument, and
# a commit ahead of the command – refuse by name instead of exiting 127
_ST_RUN --exec -- 'ls -d nowhere-at-all'
_ST_EQ "one quoted shell line refuses" "$RC" "1"
_ST_OUT_HAS "and names the shape" 'one argument, run as a program of that name'
_ST_OUT_LACKS "before any bare 127" 'status 127'
_ST_RUN --exec "$(git rev-parse HEAD)" -- true
_ST_EQ "a commit ahead of the command refuses" "$RC" "1"
_ST_OUT_HAS "and says exec runs at the tip" 'takes no commit'
_ST_EQ "neither moved the branch" "$(git log --format=%s -1)" "amended via exec"
