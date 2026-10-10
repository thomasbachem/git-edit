_ST_SCENARIO "\e[1;96m[128] a landing takes back nothing another caller landed, and says what it did\e[0m"
local LA_GIT=$(whence -p git) LA_TIP LA_T LA_WT LA_N
# Staging made before another caller's landing would take it back where the fold rebuilds the
# file as staged – above the landing that went through silently
_ST_PZ_NEW la1
print -l {1..10} > f.txt && git add f.txt && git commit -qm "LA base"
print -l 1x {2..10} > f.txt && git add f.txt
OUT=$(GIT_EDIT_ACTOR=la-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c "sed 's/^7\$/7x/' f.txt > f.tmp && mv f.tmp f.txt && git commit -qam 'LA peer'" </dev/null 2>&1)
OUT=$(GIT_EDIT_ACTOR=la-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c "echo g > g.txt && git add g.txt && git commit -qm 'LA target'" </dev/null 2>&1)
LA_TIP=$(git rev-parse HEAD)
OUT=$(GIT_EDIT_ACTOR=la-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$LA_TIP" -- f.txt </dev/null 2>&1)
RC=$?
_ST_EQ "a fold of staging that predates a landing refuses" "$RC:$(git rev-parse HEAD)" "1:$LA_TIP"
_ST_OUT_HAS "naming it as staged" 'Folded as staged, 1 file(s) would take back what another caller landed: f.txt'
OUT=$(GIT_EDIT_ACTOR=la-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$LA_TIP" --base="$LA_TIP" -- f.txt </dev/null 2>&1)
RC=$?
_ST_EQ "--base naming the tip takes it back deliberately" "$RC:$(git show HEAD:f.txt | sed -n 7p)" "0:7"
# Under --snapshot as much
print -l 1y {2..10} > f.txt && git add f.txt
OUT=$(GIT_EDIT_ACTOR=la-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c "sed 's/^8\$/8x/' f.txt > f.tmp && mv f.tmp f.txt && git commit -qam 'LA peer 2'" </dev/null 2>&1)
LA_TIP=$(git rev-parse HEAD)
if _ST_MERGE_BASE_OK; then
	# Into the landing itself – one above the target the fold's replay applies again
	OUT=$(GIT_EDIT_ACTOR=la-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$LA_TIP" --snapshot -- f.txt </dev/null 2>&1)
	RC=$?
	_ST_EQ "as does a snapshot fold" "$RC:$(git rev-parse HEAD)" "1:$LA_TIP"
fi
git reset -q
git checkout -q -- f.txt
# A tree composed on a tip a peer moves past before the fold reads it takes that peer back –
# refused, named as the caller gave it
mkdir -p "$TMP/la-shim"
cat > "$TMP/la-shim/git" <<LA_SHIM
#!/bin/sh
if [ "\$1 \$2" = "rev-list --merges" ] && [ -e "$TMP/la-shim/arm" ]; then
rm -f "$TMP/la-shim/arm"
G="$LA_GIT -C $TMP/pz-la1"
C=\$(\$G commit-tree "\$(\$G rev-parse HEAD^{tree})" -p "\$(\$G rev-parse HEAD)" -m "LA peer meanwhile" </dev/null)
\$G update-ref refs/heads/main "\$C"
fi
exec "$LA_GIT" "\$@"
LA_SHIM
chmod +x "$TMP/la-shim/git"
git show HEAD:f.txt | sed 's/^1.*$/1z/' > f.txt
: > "$TMP/la-shim/arm"
PATH="$TMP/la-shim:$PATH" _ST_RUN --amend-into="$(git rev-parse HEAD~1)" --whole -- f.txt
_ST_EQ "files read before a landing that came during the run refuse" "$RC:$(git log -1 --format=%s)" "1:LA peer meanwhile"
_ST_OUT_HAS "naming the files, never a --tree" 'The files were read on [0-9a-f]*, but the branch moved'
git checkout -q -- f.txt
# A file another caller added is taken back by one written in its place – never by edits on top
_ST_PZ_NEW la2
_ST_PZ_C a.txt a "LA2 base"
OUT=$(GIT_EDIT_ACTOR=la-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c "printf '%s\\n' 1 2 3 4 5 6 7 8 > n.txt && git add n.txt && git commit -qm 'LA2 peer adds'" </dev/null 2>&1)
LA_TIP=$(git rev-parse HEAD)
print -r -- mine > n.txt
OUT=$(GIT_EDIT_ACTOR=la-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "LA2 self" -- n.txt </dev/null 2>&1)
RC=$?
_ST_EQ "a file written over one another caller added refuses" "$RC:$(git rev-parse HEAD)" "1:$LA_TIP"
_ST_OUT_HAS "naming the landing" "n.txt – la-peer's exec run .*which added it"
print -l {1..8} 9 > n.txt
OUT=$(GIT_EDIT_ACTOR=la-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "LA2 self" -- n.txt </dev/null 2>&1)
RC=$?
_ST_EQ "edits on top of it land" "$RC:$(git log -1 --format=%s)" "0:LA2 self"
# An undo puts the index back with the branch, nothing left staged against it
_ST_PZ_C b.txt b "LA2 b"
_ST_RUN HEAD
print -r -- b2 > "$(_ST_PZ_WT)/b.txt"
_ST_RUN --continue
_ST_RUN --undo
_ST_EQ "an undo leaves nothing staged against the tip it restores" "$RC:$(git diff --cached --name-only | wc -l | tr -d ' ')" "0:0"
# An undo removes the line it read – a landing appended meanwhile stays on record
_ST_RUN -d -y HEAD
cat > "$TMP/la-shim/git" <<LA_SHIM
#!/bin/sh
if [ "\$1" = "update-ref" ] && [ -e "$TMP/la-shim/arm" ]; then
rm -f "$TMP/la-shim/arm"
printf '%s refs/heads/elsewhere 1111111 2222222 peer\n' "\$(date +%s)" >> "$TMP/pz-la2/.git/git-edit-journal"
fi
exec "$LA_GIT" "\$@"
LA_SHIM
: > "$TMP/la-shim/arm"
PATH="$TMP/la-shim:$PATH" _ST_RUN --undo
_ST_EQ "an undo keeps a landing journaled meanwhile" "$RC:$(command grep -c 'refs/heads/elsewhere' .git/git-edit-journal)" "0:1"
_ST_EQ "and removes the run it took back" "$(awk '$5 == "drop"' .git/git-edit-journal | wc -l | tr -d ' ')" "0"
# The trailer names the tip a resume swapped – a peer landing during its replay moved it on
_ST_PZ_NEW la3
for LA_N in a b c; do _ST_PZ_C "$LA_N.txt" "$LA_N" "LA3 $LA_N"; done
_ST_RUN HEAD~1
LA_WT=$(_ST_PZ_WT)
print -r -- b2 > "${LA_WT:-$ST_NO_WT}/b.txt"
cat > "$TMP/la-shim/git" <<LA_SHIM
#!/bin/sh
if [ "\$1" = "-c" ] && [ -e "$TMP/la-shim/arm" ] && case " \$* " in *" --onto "*) true ;; *) false ;; esac; then
rm -f "$TMP/la-shim/arm"
G="$LA_GIT -C $TMP/pz-la3"
B=\$(echo p | \$G hash-object -w --stdin)
T=\$( { \$G ls-tree main; printf '100644 blob %s\tpeer.txt\n' "\$B"; } | \$G mktree)
C=\$(\$G commit-tree "\$T" -p "\$(\$G rev-parse main)" -m "LA3 peer" </dev/null)
\$G update-ref refs/heads/main "\$C"
echo "\$C" > "$TMP/la-shim/peer"
fi
exec "$LA_GIT" "\$@"
LA_SHIM
: > "$TMP/la-shim/arm"
PATH="$TMP/la-shim:$PATH" _ST_RUN --continue
_ST_OUT_HAS "a resume's trailer names the tip it swapped" "moved $(cat "$TMP/la-shim/peer" 2>/dev/null) → $(git rev-parse HEAD)"
# --exec reports a branch its command moved itself
LA_TIP=$(git rev-parse HEAD)
_ST_RUN --exec -- git update-ref refs/heads/main HEAD~1
_ST_EQ "an --exec whose command moved the branch reports the move" "$RC:$(git rev-parse HEAD)" "0:$(git rev-parse "$LA_TIP~1")"
_ST_OUT_HAS "never as unchanged" 'main moved meanwhile, .* not by this run'
git update-ref refs/heads/main "$LA_TIP"
# A failing post-checkout hook fails no worktree a run sets up, nor leaves one registered
printf '#!/bin/sh\nexit 1\n' > .git/hooks/post-checkout && chmod +x .git/hooks/post-checkout
print -r -- c2 > c.txt
_ST_RUN --commit --text "LA3 c2" -- c.txt
_ST_EQ "a failing post-checkout hook leaves --commit landing" "$RC:$(git log -1 --format=%s)" "0:LA3 c2"
_ST_EQ "and no worktree registered" "$(git worktree list | wc -l | tr -d ' ')" "1"
rm -f .git/hooks/post-checkout
# A hook vetoing the ref move is no branch that moved
printf '#!/bin/sh\n[ "$1" = prepared ] && grep -q refs/heads/main && exit 1\nexit 0\n' > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
LA_TIP=$(git rev-parse HEAD)
_ST_RUN -M --text "LA3 vetoed" HEAD
_ST_EQ "a vetoed ref move lands nothing" "$RC:$(git rev-parse HEAD)" "1:$LA_TIP"
_ST_OUT_HAS "named as refused, the branch where it was" 'git refused to move main, still at the tip this run read'
rm -f .git/hooks/reference-transaction
# --commit refused by its hook names the hook, as there was no command of the caller's
printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
print -r -- c3 > c.txt
_ST_RUN --commit --no-verify --text "LA3 c3" -- c.txt
_ST_EQ "--commit runs the repository's hooks even with --no-verify" "$RC:$(git log -1 --format=%s)" "1:LA3 c2"
_ST_OUT_HAS "naming the refused commit, not a command" 'The commit was refused (exit 1)'
rm -f .git/hooks/pre-commit
git checkout -q -- c.txt
# --whole and --tree together refuse
_ST_RUN --amend-into=HEAD --whole --tree=HEAD -- c.txt
_ST_OUT_HAS "--whole with --tree refuses" '--whole and --tree cannot be combined'
# A symlink turned file is no chmod away
ln -s a.txt ln.txt && git add ln.txt && git commit -qm "LA3 link"
rm ln.txt && print -r -- plain > ln.txt
_ST_RUN --commit --text "LA3 unlink" -- ln.txt
_ST_OUT_HAS "a symlink turned file is named as one, not a chmod" 'Put a symlink back where one was'
git checkout -q -- ln.txt
# A drop's content leaves the checkout, nothing of it staged, and edits on top of it merge onto what
# is left, so a carry after it finds nothing to do
_ST_PZ_NEW la4
_ST_PZ_C f.txt $'1\n2\n3' "LA4 base"
print -r -- $'1\n2x\n3' > f.txt && print -r -- g > g.txt && git add f.txt g.txt && git commit -qm "LA4 drop"
LA_T=$(git rev-parse HEAD)
_ST_PZ_C h.txt h "LA4 tip"
print -r -- $'1\n2x\n3\n4' > f.txt
_ST_RUN -d -y "$LA_T"
_ST_EQ "a drop leaves nothing staged" "$RC:$(git diff --cached --name-only | tr '\n' ' ')" "0:"
_ST_OUT_HAS "naming the dropped file taken out" 'Taken out of your checkout with the rewrite: .*g\.txt'
_ST_OUT_HAS "and the edits merged" 'Uncommitted edits merged onto what landed: f\.txt'
_ST_OUT_LACKS "offering no discard" 'git clean\|git restore \(--source\|--worktree\|-- \)'
_ST_RUN --carry
_ST_EQ "the carry keeps the edits, the dropped line gone, nothing staged" \
	"$RC:$(tr '\n' ' ' < f.txt):$(git diff --cached --name-only | wc -l | tr -d ' ')" "0:1 2 3 4 :0"
# A branch checked out twice re-syncs the caller's own index
_ST_PZ_C k.txt k "LA4 k"
git restore -q --source=HEAD --worktree -- . 2>/dev/null; git clean -fq
git worktree add -q -f "$TMP/la4-twin" main 2>/dev/null
cd "$TMP/la4-twin"
_ST_RUN -d -y HEAD
_ST_EQ "a branch checked out twice re-syncs the index of the copy the run started in" "$RC:$(git diff --cached --name-only | wc -l | tr -d ' ')" "0:0"
cd "$TMP/pz-la4"
git worktree remove --force "$TMP/la4-twin"
cd "$TMP/repo"
