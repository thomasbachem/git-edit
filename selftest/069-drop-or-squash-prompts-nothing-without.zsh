# Nobody can confirm one with no TTY, on either squash route, so each proceeds without
# printing a prompt its read could never take
_ST_SCENARIO "\e[1;96m[69] a drop or squash prompts nothing without a TTY\e[0m"
cd "$TMP/repo"
git checkout -q main 2>/dev/null
git reset -q --hard
local NP_N
for NP_N in 1 2 3; do
	printf 'np%s\n' "$NP_N" > "np$NP_N.txt" && git add "np$NP_N.txt" && git commit -qm "NP $NP_N"
done
local NP_TIP=$(git rev-parse HEAD)
# A contiguous pair auto-routes to plumbing, a split pair and `-d` take a rebase
_ST_RUN HEAD~1 HEAD
_ST_EQ "a plumbing-route squash with no TTY proceeds" "$RC" "0"
_ST_OUT_LACKS "printing no prompt" 'to confirm, or cancel with'
git reset -q --hard "$NP_TIP"
_ST_RUN HEAD~2 HEAD
_ST_EQ "a rebase-route squash with no TTY proceeds" "$RC" "0"
_ST_OUT_LACKS "printing no prompt" 'to confirm, or cancel with'
_ST_OUT_LACKS "nor zsh's complaint at reading one" "can't open terminal"
git reset -q --hard "$NP_TIP"
_ST_RUN -d HEAD
_ST_EQ "a drop with no TTY proceeds" "$RC" "0"
_ST_OUT_LACKS "printing no prompt" 'to confirm, or cancel with'
git reset -q --hard "$NP_TIP"
