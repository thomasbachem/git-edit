_ST_SCENARIO "\e[1;96m[119] the rewrite engine holds to the commits it was named\e[0m"
local EN_DIR="$TMP/en" EN_X
git init -q -b main "$EN_DIR" && cd "$EN_DIR" && git config user.email e@x.invalid && git config user.name E
for EN_X in a b c d; do echo "$EN_X" > "$EN_X.txt" && git add "$EN_X.txt" && git commit -qm "EN ${(U)EN_X}"; done
# A stale squash target resolves as any commit does – its fixups once followed a `pick` the
# todo never had, which dropped the squashed commits
local EN_B=$(git rev-parse HEAD~2) EN_D=$(git rev-parse HEAD)
_ST_RUN -M --text "EN B2" "$EN_B"
_ST_RUN -s="$EN_B" "$EN_D"
_ST_EQ "a stale squash target lands every commit" "$RC:$(git log --format=%s | tr '\n' ' '):$(git cat-file -e HEAD:d.txt 2>/dev/null && echo kept)" "0:EN C EN B2 EN A :kept"
git checkout -q -b en-side HEAD~1 && echo s > s.txt && git add s.txt && git commit -qm "EN side" && git checkout -q main
_ST_RUN -s="$(git rev-parse en-side)" HEAD
_ST_OUT_HAS "a target outside the branch refuses" 'not in HEAD.s history'
git branch -q -D en-side
# A peer's rewrite between the run's reading of its commits and of the tip refuses the run – it
# would have replayed the old commits back over the peer's
echo e > e.txt && git add e.txt && git commit -qm "EN E" && echo f > f.txt && git add f.txt && git commit -qm "EN F"
# The binary, past the suite's own `git` function – named, the shim would exec itself
local EN_GIT=$(whence -p git) EN_BEFORE
mkdir -p "$TMP/en-shim"
cat > "$TMP/en-shim/git" <<EN_SHIM
#!/bin/sh
if [ "\$1 \$2" = "rev-list --merges" ] && [ ! -e "$TMP/en-shim/fired" ]; then
touch "$TMP/en-shim/fired"
G="$EN_GIT -C $EN_DIR"
C2=\$(\$G commit-tree "\$(\$G rev-parse HEAD~2^{tree})" -p "\$(\$G rev-parse HEAD~3)" -m "EN C peer" </dev/null)
E2=\$(\$G commit-tree "\$(\$G rev-parse HEAD~1^{tree})" -p "\$C2" -m "EN E" </dev/null)
F2=\$(\$G commit-tree "\$(\$G rev-parse HEAD^{tree})" -p "\$E2" -m "EN F" </dev/null)
\$G update-ref refs/heads/main "\$F2"
fi
exec "$EN_GIT" "\$@"
EN_SHIM
chmod +x "$TMP/en-shim/git"
EN_BEFORE=$(git rev-parse HEAD~1)
PATH="$TMP/en-shim:$PATH" _ST_RUN -d "$EN_BEFORE"
_ST_EQ "a peer's rewrite under the run refuses it" "$RC:$(git log --format=%s | tr '\n' ' ')" "1:EN F EN E EN C peer EN B2 EN A "
_ST_OUT_HAS "saying the branch moved" 'moved while this run read it'
# A stale SHA among --reorder's arguments takes its place in the order as given
local EN_E=$(git rev-parse HEAD~1)
_ST_RUN -M --text "EN E2" "$EN_E"
_ST_RUN --reorder "$(git rev-parse HEAD)" "$EN_E"
_ST_EQ "a stale SHA reorders where it was named" "$RC:$(git log -2 --format=%s | tr '\n' ' ')" "0:EN E2 EN F "
# A drop prints no stray variable among its lines
_ST_RUN --abort
echo z > z.txt && git add z.txt && git commit -qm "EN Z" && echo y > y.txt && git add y.txt && git commit -qm "EN Y"
_ST_RUN -d HEAD~1
_ST_OUT_LACKS "a drop prints no stray DROPPED= line" '^DROPPED='
# A plumbing squash refuses where a merge above it keeps a squashed commit reachable
local EN_S1 EN_S2
echo s1 > s1.txt && git add s1.txt && git commit -qm "EN S1" && EN_S1=$(git rev-parse HEAD)
git checkout -q -b en-fork && echo k > k.txt && git add k.txt && git commit -qm "EN fork" && git checkout -q main
echo s2 > s2.txt && git add s2.txt && git commit -qm "EN S2" && EN_S2=$(git rev-parse HEAD)
git merge -q --no-ff -m "EN merge" en-fork && echo t > t.txt && git add t.txt && git commit -qm "EN T"
local EN_TIP=$(git rev-parse HEAD)
_ST_RUN -S "$EN_S1" "$EN_S2"
_ST_EQ "a squash a merge keeps reachable refuses" "$(git rev-parse HEAD)" "$EN_TIP"
git branch -q -D en-fork
# Every commit-tree given a message reads no terminal – an empty one reads stdin otherwise
_ST_EQ "every commit-tree with -m reads /dev/null" "$(grep -n 'git commit-tree' "$SELF" | grep -v 'PRINT_CMD' | grep -v '^[0-9]*:[[:space:]]*#' | grep -v '</dev/null')" ""
cd "$TMP/repo"
