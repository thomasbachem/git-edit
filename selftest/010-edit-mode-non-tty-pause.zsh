# Edit mode pauses in non-TTY instead of prompting
_ST_SCENARIO "\e[1;96m[10] edit-mode non-TTY pause\e[0m"
_ST_RUN "$(git rev-parse HEAD)"
_ST_EQ "pauses (exit 2)" "$RC" "2"
_ST_OUT_HAS "paused trailer names the worktree" 'git-edit: paused'
_ST_RUN --abort
_ST_EQ "abort clears it" "$RC" "0"
