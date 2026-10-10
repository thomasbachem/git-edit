# A file taken whole supersedes its own staging, an intent-to-add entry too, as git commit has it
_ST_SCENARIO "\e[1;96m[113c] files taken whole against landings the checkout lacks, by kind\e[0m"
export GIT_EDIT_ACTOR=wc-self
local WC_HOOK=$(git rev-parse --git-path hooks/pre-commit)
echo ita > wc-ita.txt && git add -N wc-ita.txt
_ST_RUN --commit --text "WC intent to add" -- wc-ita.txt
_ST_EQ "an intent-to-add entry follows the commit" "$RC:$(git status --porcelain -- wc-ita.txt)" "0:"
echo staged >> wc-ita.txt && git add wc-ita.txt && echo edited >> wc-ita.txt
_ST_RUN --commit --text "WC past its own staging" -- wc-ita.txt
_ST_EQ "as does a version of it staged before" "$RC:$(git status --porcelain -- wc-ita.txt)" "0:"
# The guard reads what no merge can – an addition the checkout never got, a binary, a link
printf '\0bin1' > wc.bin && ln -s wc.txt wc-ln
_ST_RUN --commit --text "WC bin and link" -- wc.bin wc-ln
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN_UNSYNCED --exec -- sh -c "echo peer > wc-peer-new.txt && printf '\0bin2' > wc.bin && ln -sf wc-g.txt wc-ln && git add -A wc-peer-new.txt wc.bin wc-ln && git commit -qm 'WC peer adds and changes'"
export GIT_EDIT_ACTOR=wc-self
_ST_RUN --commit --text "x" -- wc-peer-new.txt wc.bin wc-ln
_ST_OUT_HAS "removing a file another caller added refuses" 'wc-peer-new.txt – wc-peer.*which added it'
_ST_OUT_HAS "as does an old binary" 'wc.bin – wc-peer'
_ST_OUT_HAS "and an old link" 'wc-ln – wc-peer'
_ST_OUT_HAS "offering to restore the addition and the old copies" "Take what landed with: git restore --source=HEAD --worktree -- wc-ln wc-peer-new.txt wc.bin – or leave it out"
_ST_OUT_LACKS "rather than a carry, which takes nothing from a file still as before it" '--carry='
_ST_OUT_HAS "and the status line names them" '^git-edit: error – .*landed: wc-ln, wc-peer-new.txt, wc.bin$'
git restore --source=HEAD --worktree -- wc-peer-new.txt wc.bin wc-ln
# A file lacking two landings is pointed at a carry from the older, which takes in both
printf 'o1\no2\no3\no4\no5\no6\no7\no8\n' > wc-two.txt
_ST_RUN --commit --text "WC two base" -- wc-two.txt
local WC_P1=$(git rev-parse HEAD)
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN_UNSYNCED --exec -- sh -c "printf 'o1\nP1\no3\no4\no5\no6\no7\no8\n' > wc-two.txt && git commit -qam 'WC p1'"
export GIT_EDIT_ACTOR=wc-other
_ST_RUN_UNSYNCED --exec -- sh -c "printf 'o1\nP1\no3\no4\no5\nP2\no7\no8\n' > wc-two.txt && git commit -qam 'WC p2'"
export GIT_EDIT_ACTOR=wc-self
printf 'o1\no2\no3\no4\no5\no6\no7\nMINE\n' > wc-two.txt
_ST_RUN --commit --text "x" -- wc-two.txt
_ST_OUT_HAS "a file lacking two landings is pointed at the older" "--carry=${WC_P1:0:12}"
_ST_RUN --carry="$WC_P1"
_ST_EQ "whose carry takes in both" "$RC:$(tr '\n' ' ' < wc-two.txt)" "0:o1 P1 o3 o4 o5 P2 o7 MINE "
printf 'o1\no2\no3\no4\no5\no6\no7\no8\n' > wc-two.txt
_ST_RUN --commit --text "x" -- wc-two.txt
_ST_OUT_HAS "a file still as before both is pointed at the restore" "Take what landed with: git restore --source=HEAD --worktree -- wc-two.txt – or leave it out"
_ST_OUT_LACKS "never at a carry, which takes nothing in" '--carry='
git checkout -q -- wc-two.txt
# As is one whose later landing sits next to the earlier, where the merge conflicts, or a binary
printf 'a1\na2\na3\na4\n' > wc-adj.txt && printf 'v0\0bin' > wc-adj.bin
_ST_RUN --commit --text "WC adjacent base" -- wc-adj.txt wc-adj.bin
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN_UNSYNCED --exec -- sh -c "printf 'a1\nP1\na3\na4\n' > wc-adj.txt && printf 'v1\0bin' > wc-adj.bin && git commit -qam 'WC adj one'"
export GIT_EDIT_ACTOR=wc-other
_ST_RUN_UNSYNCED --exec -- sh -c "printf 'a1\nP1\nP2\na4\n' > wc-adj.txt && printf 'v2\0bin' > wc-adj.bin && git commit -qam 'WC adj two'"
export GIT_EDIT_ACTOR=wc-self
printf 'a1\na2\na3\na4\n' > wc-adj.txt && printf 'v0\0bin' > wc-adj.bin
local WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-adj.txt wc-adj.bin
_ST_EQ "a copy still as before a landing another sits next to refuses, a binary too" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
_ST_OUT_HAS "both pointed at the restore" "Take what landed with: git restore --source=HEAD --worktree -- wc-adj.bin wc-adj.txt – or leave it out"
git checkout -q -- wc-adj.txt wc-adj.bin
# A file holding a later landing but lacking an earlier one is named for the earlier, as the
# landings are checked oldest first
printf 'k1\nk2\nk3\nk4\nk5\nk6\nk7\nk8\n' > wc-ord.txt
_ST_RUN --commit --text "WC order base" -- wc-ord.txt
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN_UNSYNCED --exec -- sh -c "printf 'k1\nK2\nk3\nk4\nk5\nk6\nk7\nk8\n' > wc-ord.txt && git commit -qam 'WC order one'"
export GIT_EDIT_ACTOR=wc-other
_ST_RUN_UNSYNCED --exec -- sh -c "printf 'k1\nK2\nk3\nk4\nk5\nk6\nK7\nk8\n' > wc-ord.txt && git commit -qam 'WC order two'"
export GIT_EDIT_ACTOR=wc-self
printf 'k1\nk2\nk3\nk4\nMINE\nk6\nK7\nk8\n' > wc-ord.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-ord.txt
_ST_EQ "a file lacking an earlier landing but holding a later one refuses" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
_ST_OUT_HAS "naming the earlier" "wc-ord.txt – wc-peer's exec run"
git checkout -q -- wc-ord.txt
# Outside a sparse checkout, a file's absence is no deletion
mkdir -p wc-out && echo out > wc-out/x.txt
_ST_RUN --commit --text "WC outside the cone" -- wc-out/x.txt
git sparse-checkout set wc-sub 2>/dev/null
_ST_RUN --commit --text "x" -- wc-out/x.txt
git sparse-checkout disable 2>/dev/null
_ST_OUT_HAS "a file outside a sparse checkout refuses rather than land as removed" 'outside the sparse checkout'
_ST_CHECK "and stays at the tip" git cat-file -e HEAD:wc-out/x.txt
chmod +x wc-two.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" --whole -- wc-two.txt
_ST_OUT_HAS "a whole-file fold's mode change names the chmod" 'Restore the mode with chmod'
chmod -x wc-two.txt
# A file the commit's hooks rewrote is named as such, never as taking a landing back
printf '#!/bin/sh\nfor f in $(git diff --cached --name-only -- wc-hk.txt); do tr a-z A-Z < "$f" > "$f.t" && mv "$f.t" "$f" && git add "$f"; done\n' > "$WC_HOOK" && chmod +x "$WC_HOOK"
echo lower > wc-hk.txt
_ST_RUN --commit --text "WC hooked" -- wc-hk.txt
rm -f "$WC_HOOK"
_ST_OUT_HAS "a file the commit's hooks changed is named as such" 'still as the commit read them, which its hooks then changed, now as they landed: wc-hk.txt'
_ST_OUT_LACKS "never as taking a landing back" 'take the landing back'
_ST_EQ "and it takes what they made of it" "$(<wc-hk.txt):$(git status --porcelain -- wc-hk.txt)" "LOWER:"
# A landing's rename is carried rather than left out, the carry following it
echo r1 > wc-rn.txt
_ST_RUN --commit --text "WC rename base" -- wc-rn.txt
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN_UNSYNCED --exec -- sh -c "git mv wc-rn.txt wc-rn2.txt && git commit -qm 'WC peer renames'"
export GIT_EDIT_ACTOR=wc-self
echo mine >> wc-rn.txt
_ST_RUN --commit --text "x" -- wc-rn.txt
_ST_OUT_HAS "a file a landing renamed is named so" 'wc-rn.txt – wc-peer.*which renamed it to wc-rn2.txt'
_ST_OUT_HAS "and pointed at the carry, which follows it" '--carry='
_ST_RUN --commit --text "x" -- wc-rn.txt wc-rn2.txt
_ST_OUT_HAS "as is its new name, the old one edited" 'wc-rn2.txt – wc-peer.*which renamed wc-rn.txt to it'
echo r1 > wc-rn.txt
_ST_RUN --commit --text "x" -- wc-rn.txt wc-rn2.txt
_ST_OUT_HAS "while untouched, the new name is pointed at the restore" "Take what landed with: git restore --source=HEAD --worktree -- wc-rn2.txt – or leave it out"
_ST_OUT_HAS "and the old one left out" 'Leave out what was removed: wc-rn.txt'
_ST_OUT_LACKS "with no carry, which takes nothing in" '--carry='
rm -f wc-rn.txt && git checkout -q -- wc-rn2.txt
# A fold resumed after a pause still re-syncs the staging of a file it took
# whole, one whose name holds a tab too
local WC_PS WC_PSW WC_K WC_PN
for WC_PN in wc-ps.txt $'wc-p\ts.txt'; do
	printf '1\n2\n3\n' > "$WC_PN"
	_ST_RUN --commit --text "WC pause base" -- "$WC_PN"
	WC_PS=$(git rev-parse HEAD)
	printf '1\nL\n3\n' > "$WC_PN"
	_ST_RUN --commit --text "WC pause later" -- "$WC_PN"
	printf '1\nSTAGED\n3\n' > "$WC_PN" && git add -- "$WC_PN" && printf '1\nW\n3\n' > "$WC_PN"
	_ST_RUN --amend-into="$WC_PS" --whole -- "$WC_PN"
	for WC_K in 1 2; do
		WC_PSW=$(print -r -- "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
		[ -n "$WC_PSW" ] || break
		printf '1\nW\n3\n' > "$WC_PSW/$WC_PN" && git -C "$WC_PSW" add -- "$WC_PN"
		_ST_RUN --continue
	done
	_ST_EQ "a fold resumed after a pause re-syncs the file's own staging${${WC_PN:#wc-ps.txt}:+, a tab in its name}" "$RC:$(git status --porcelain -- "$WC_PN")" "0:"
done
# A fold's tip differs from what it read by what later commits replay – no hook at work
printf 'x\na\nb\nc\n' > wc-dv.txt
_ST_RUN --commit --text "WC dissolve base" -- wc-dv.txt
local WC_DV=$(git rev-parse HEAD)
printf 'x\na\nb\nc\nLATER\n' > wc-dv.txt
_ST_RUN --commit --text "WC dissolve later" -- wc-dv.txt
printf 'X2\na\nb\nc\n' > wc-dv.txt
_ST_RUN --amend-into="$WC_DV" --whole -- wc-dv.txt
_ST_OUT_HAS "a fold dissolving against a later commit says so" 'dissolved against a later commit'
_ST_OUT_LACKS "naming no hook, as none ran" 'hooks then changed'
git checkout -q -- wc-dv.txt
# A deletion folds from a subdirectory as from the top
mkdir -p wc-sd && echo g > wc-sd/gone.txt && echo k > wc-sd/keep.txt
_ST_RUN --commit --text "WC subdir base" -- wc-sd/gone.txt wc-sd/keep.txt
local WC_SD=$(git rev-parse HEAD)
echo z > wc-sd-next.txt
_ST_RUN --commit --text "WC subdir next" -- wc-sd-next.txt
rm wc-sd/gone.txt
cd wc-sd
_ST_RUN --amend-into="$WC_SD" --whole -- gone.txt
cd "$TMP/repo"
_ST_EQ "--whole folds a deletion named from a subdirectory" "$RC:$(git cat-file -e "$(git log -1 --format=%H --grep='^WC subdir base')":wc-sd/gone.txt 2>/dev/null && echo kept || echo gone)" "0:gone"
