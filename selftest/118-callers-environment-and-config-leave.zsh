# An exported name the script uses, a git dir named through the environment, or config that
# changes the output it parses each changed what ran
_ST_SCENARIO "\e[1;96m[118] a caller's environment and config leave the script as it reads itself\e[0m"
local GV_AWK='
	/^[A-Za-z_][A-Za-z0-9_]* \(\) \{/ { infn = 1; delete loc; next }
	/^}/ { infn = 0; delete loc; next }
	/^[[:space:]]*#/ { next }
	{
		line = $0
		if (match(line, /^[[:space:]]*(local|typeset|declare|integer)[[:space:]]/)) {
			rest = substr(line, RLENGTH + 1)
			n = split(rest, w, /[[:space:]]+/)
			for (i = 1; i <= n; i++) { v = w[i]; sub(/=.*/, "", v); if (v ~ /^[A-Z_][A-Z0-9_]*$/) loc[v] = 1 }
		}
		while (match(line, /(^|[^A-Za-z0-9_$.{])[A-Z_][A-Z0-9_]*\+?=/)) {
			tok = substr(line, RSTART, RLENGTH); sub(/^[^A-Z_]/, "", tok); sub(/\+?=$/, "", tok)
			if (!(tok in loc)) print tok
			line = substr(line, RSTART + RLENGTH)
		}
	}'
local GV_MISS=$(LC_ALL=C comm -23 \
	<({ awk "$GV_AWK" "$SELF"; grep -oE '=OPT_[A-Z_]+' "$SELF" | sed 's/^=//'; } | grep -vE '^(GIT_.*|HOME|IFS|LC_ALL|REPLY|TMPDIR|XDG_CONFIG_HOME)$' | LC_ALL=C sort -u) \
	<(awk '/^_UNSET_OWN ACTION /{ f = 1 } f { l = $0; sub(/\\$/, "", l); print l; if ($0 !~ /\\$/) exit }' "$SELF" | tr -s ' \t' '\n' | grep -vx _UNSET_OWN | LC_ALL=C sort -u))
_ST_EQ "every global the script assigns starts unset" "$GV_MISS" ""
printf '%s\n' 'f () {' '	local A' '	A=1' '	B=2' '}' 'C=3' > "$TMP/gv-fixture"
_ST_EQ "the check finds a global, never a local" "$(awk "$GV_AWK" "$TMP/gv-fixture" | LC_ALL=C sort -u | tr '\n' ' ')" "B C "
local GV_DIR="$TMP/gv" GV_I
git init -q -b main "$GV_DIR" && cd "$GV_DIR" && git config user.email g@x.invalid && git config user.name G
for GV_I in 1 2 3 4; do echo "$GV_I" > "gv$GV_I.txt" && git add "gv$GV_I.txt" && git commit -qm "GV c$GV_I"; done
OUT=$(env TARGET="$(git rev-parse --short HEAD~3)" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" HEAD~1 HEAD -s </dev/null 2>&1)
RC=$?
_ST_EQ "an exported TARGET joins no squash" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:GV c3 GV c2 GV c1 "
_ST_RUN -M --text "GV reworded" HEAD
git config edit.verifyCmd false
export VERIFY_VALUE=true
_ST_RUN -d HEAD~1
unset VERIFY_VALUE
_ST_RUN --abort
git config --unset edit.verifyCmd
_ST_EQ "nor an exported VERIFY_VALUE stand in for the gate" "$(git log --format=%s | tr '\n' ' ')" "GV reworded GV c2 GV c1 "
git init -q "$TMP/gv-other"
GIT_DIR="$TMP/gv-other/.git" _ST_RUN -M --text "x" HEAD
_ST_OUT_HAS "a GIT_DIR naming another repository refuses" 'names another repository'
GIT_INDEX_FILE="$TMP/gv-index" _ST_RUN -M --text "x" HEAD
_ST_OUT_HAS "as does a GIT_INDEX_FILE naming another index" 'names another repository'
GIT_DIR=.git _ST_RUN -M --text "GV via GIT_DIR" HEAD
_ST_EQ "while a GIT_DIR naming this one runs" "$RC:$(git log -1 --format=%s)" "0:GV via GIT_DIR"
# Where this git can sign with an SSH key at all – `gpg.format=ssh` arrived in 2.34
if command -v ssh-keygen >/dev/null 2>&1 && ssh-keygen -q -t ed25519 -N '' -f "$TMP/gv-key" </dev/null >/dev/null 2>&1 \
	&& git -c gpg.format=ssh -c user.signingkey="$TMP/gv-key.pub" commit-tree -S 'HEAD^{tree}' -m probe </dev/null >/dev/null 2>&1; then
	git config gpg.format ssh && git config user.signingkey "$TMP/gv-key.pub"
	echo s > gvs.txt && git add gvs.txt && git commit -q -S -m "GV signed"
	echo t > gvt.txt && git add gvt.txt && git commit -qm "GV top"
	git config log.showSignature true
	_ST_RUN -M --text "GV below signed" HEAD~2
	git config --unset log.showSignature && git config --unset gpg.format && git config --unset user.signingkey
	_ST_EQ "log.showSignature leaves a reword below a signed commit alone" "$RC:$(git log -1 --format=%s HEAD~2)" "0:GV below signed"
fi
git config rebase.abbreviateCommands true && git config core.abbrev 5
local GV_N=$(git rev-list --count HEAD)
_ST_RUN -d HEAD~1
git config --unset rebase.abbreviateCommands && git config --unset core.abbrev
_ST_EQ "abbreviated todo commands and short SHAs still drop" "$RC:$(git rev-list --count HEAD)" "0:$(( GV_N - 1 ))"
# The same from `git -c`, which outranks the config files – a fold, a drop and a reorder alike
local GV_GCP="'rebase.abbreviateCommands=true' 'core.abbrev=5'"
for GV_N in 1 2 3; do echo "gc$GV_N" > "gvc$GV_N.txt" && git add "gvc$GV_N.txt" && git commit -qm "GV c$GV_N"; done
echo "gc1 folded" > gvc1.txt && git add gvc1.txt
GIT_CONFIG_PARAMETERS=$GV_GCP _ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- gvc1.txt
_ST_EQ "a fold under git -c folds" "$RC:$(git log -1 --format=%s HEAD~2):$(git show HEAD~2:gvc1.txt)" "0:GV c1:gc1 folded"
GV_N=$(git rev-list --count HEAD)
GIT_CONFIG_PARAMETERS=$GV_GCP _ST_RUN -d HEAD~1
_ST_EQ "a drop under git -c drops" "$RC:$(git rev-list --count HEAD):$(git log -1 --format=%s HEAD~1)" "0:$(( GV_N - 1 )):GV c1"
GIT_CONFIG_PARAMETERS=$GV_GCP _ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "a reorder under git -c reorders" "$RC:$(git log -2 --format=%s | tr '\n' ' ')" "0:GV c1 GV c3 "
git tag main
_ST_RUN -M --text "GV past a tag named main" HEAD~1
git tag -d main >/dev/null
_ST_EQ "a tag named like the branch blocks no rewrite" "$RC:$(git log -1 --format=%s HEAD~1)" "0:GV past a tag named main"
echo p > gvp.txt && git add gvp.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" --verify='seq 1 200000 | head -1 >/dev/null' -- gvp.txt
_ST_EQ "a check piping into head passes as a shell runs it" "$RC" "0"
local GV_STALE=$(git rev-parse HEAD~1)
_ST_RUN -M --text "GV stale once" HEAD~1
GIT_EDIT_NO_RESOLVE=0 _ST_RUN -M --text "GV stale twice" "$GV_STALE"
_ST_OUT_HAS "a GIT_EDIT_NO_ switch set to 0 is off" 'was rewritten'
# A caller's `rerere.autoUpdate` stages no resolution an abandoned run
# recorded – the file comes back unmerged
_ST_RUN --abort
git config rerere.autoUpdate true
printf 'l1\nl2\nl3\n' > gvr.txt && git add gvr.txt && git commit -qm "GV rr A"
local GV_RA=$(git rev-parse HEAD) GV_WT
echo g > gvg.txt && printf 'l1\nX2\nl3\n' > gvr.txt && git add gvr.txt gvg.txt && git commit -qm "GV rr B"
echo h > gvh.txt && git add gvh.txt && git commit -qm "GV rr C"
printf 'l1\nY2\nl3\n' > gvr.txt && git add gvr.txt
_ST_RUN --amend-into="$GV_RA" -- gvr.txt
GV_WT=$(sed -n 's/^worktree=//p' "$(git rev-parse --git-common-dir)/git-edit-state")
printf 'l1\nBAD\nl3\n' > "$GV_WT/gvr.txt" && git -C "$GV_WT" add gvr.txt
_ST_RUN --continue
_ST_RUN --abort
_ST_RUN --amend-into="$GV_RA" -- gvr.txt
_ST_OUT_HAS "a recorded resolution comes back unmerged, never staged" '^git-edit: conflict – resolve in .* (gvr.txt);'
_ST_RUN --abort
git config --unset rerere.autoUpdate
cd "$TMP/repo"
