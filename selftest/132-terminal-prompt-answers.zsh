_ST_SCENARIO "\e[1;96m[132] a terminal prompt answers only its own pause, and the checkout keeps every edit\e[0m"
local TP_WT TP_T TP_PID TP_GD
# A conflict no markers tell – a binary's – takes Enter only once confirmed, as git left it
_ST_PZ_NEW tp1
_ST_PZ_C a.txt a "TP base"
printf 'b\0one' > b.bin && git add b.bin && git commit -qm "TP b1"
printf 'b\0two' > b.bin && git commit -qam "TP b2"
printf 'b\0three' > b.bin && git commit -qam "TP b3"
_ST_TTY_START -- -d -y HEAD~1
if _ST_TTY_AT 'Resolve the conflicts in'; then
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'Nothing tells a resolution of b.bin' && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "Enter on a binary conflict asks again rather than take git's side" "$RC:$(git -C "$(_ST_PZ_WT)" ls-files -u -- b.bin | wc -l | tr -d ' ')" "2:3"
_ST_RUN --abort
# Keys typed ahead answer no prompt not yet shown
_ST_TTY_START -- -d HEAD~1
if _ST_TTY_AT 'Press Enter to confirm'; then
	zpty -wn ST_TTY $'\r\r'
	_ST_TTY_AT 'Resolve the conflicts in' && { sleep 0.5; zpty -wn ST_TTY q; }
fi
_ST_TTY_END
_ST_EQ "an Enter typed ahead of a conflict's prompt answers nothing" "$RC" "2"
_ST_OUT_LACKS "staging nothing" 'Staged as resolved'
_ST_RUN --abort
# A prompt left waiting acts on no pause another run took the slot with meanwhile
_ST_PZ_NEW tp2
_ST_PZ_C a.txt a "TP2 a" && _ST_PZ_C b.txt b "TP2 b"
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	_ST_RUN --abort
	_ST_RUN HEAD~1
	TP_WT=$(_ST_PZ_WT)
	print -r -- mine > "${TP_WT:-$ST_NO_WT}/a.txt"
	zpty -wn ST_TTY $'\e'
	_ST_TTY_AT 'Press Escape again' && zpty -wn ST_TTY $'\e'
fi
_ST_TTY_END
_ST_EQ "a stale prompt cancels nothing" "$RC" "1"
_ST_OUT_HAS "saying the pause is gone" 'no longer pending'
_ST_CHECK "the other run's pause stands, what was authored there too" grep -qx mine "${TP_WT:-$ST_NO_WT}/a.txt"
_ST_RUN --abort
# Escape, then any other key, goes back to the prompt
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\e'
	_ST_TTY_AT 'Press Escape again' && zpty -wn ST_TTY x
	_ST_TTY_AT 'Not cancelled' && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "Escape then another key cancels nothing" "$RC" "2"
_ST_CHECK "the pause stays" test -d "$(_ST_PZ_WT)"
# Ctrl-C at the prompt leaves the pause and says so, ending as q does
_ST_TTY_START -- --continue
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\003'
fi
_ST_TTY_END
_ST_EQ "Ctrl-C at the prompt leaves the pause" "$RC" "2"
_ST_OUT_HAS "saying so, as q does" 'Left paused – resume with'
_ST_RUN --abort
# Markers at a configured size keep a file unstaged at Enter
_ST_PZ_NEW tp3
print -r -- '*.adoc conflict-marker-size=9' > .gitattributes && git add .gitattributes
_ST_PZ_C f.adoc $'l1\nl2\nl3' "TP3 c1"
_ST_PZ_C f.adoc $'l1\nX2\nl3' "TP3 c2"
_ST_PZ_C f.adoc $'l1\nXY2\nl3' "TP3 c3"
_ST_TTY_START -- -d -y HEAD~1
if _ST_TTY_AT 'Resolve the conflicts in'; then
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'Resolve the conflicts in' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_OUT_LACKS "Enter stages no file still holding markers of its configured size" 'Staged as resolved: f.adoc'
_ST_OUT_HAS "asking again" 'Conflict continues'
_ST_RUN --abort
# A squash's -m editor quit with an error abandons the squash
_ST_PZ_NEW tp4
_ST_PZ_C a.txt a "TP4 a" && _ST_PZ_C b.txt b "TP4 b" && _ST_PZ_C c.txt c "TP4 c" && _ST_PZ_C d.txt d "TP4 d"
TP_T=$(git rev-parse HEAD)
printf '#!/bin/sh\nexit 1\n' > "$TMP/tp-editor-fail" && chmod +x "$TMP/tp-editor-fail"
# Apart, so the squash runs as a rebase, its fold opening the editor
_ST_TTY "GIT_EDITOR=$TMP/tp-editor-fail" -- -s="$(git rev-parse HEAD~2)" -m -y HEAD
_ST_EQ "a squash whose -m editor fails lands nothing" "$RC:$(git rev-parse HEAD)" "1:$TP_T"
# An editor runs in the caller's own environment, git-edit's config pins out of it
printf '#!/bin/sh\nprintf "%%s\\n" "$GIT_CONFIG_PARAMETERS" > "%s/tp-editor-env"\nprintf "TP4 squashed\\n" > "$1"\n' "$TMP" > "$TMP/tp-editor-env.sh"
chmod +x "$TMP/tp-editor-env.sh"
rm -f "$TMP/tp-editor-env"
_ST_TTY "GIT_EDITOR=$TMP/tp-editor-env.sh" -- -s="$(git rev-parse HEAD~2)" -m -y HEAD
_ST_EQ "a squash's -m editor runs" "$RC:$(git log -1 --format=%s HEAD~1)" "0:TP4 squashed"
_ST_CHECK "without git-edit's config pins" sh -c "test -e '$TMP/tp-editor-env' && ! grep -q maintenance.auto '$TMP/tp-editor-env'"
rm -f "$TMP/tp-editor-env"
_ST_TTY "GIT_EDITOR=$TMP/tp-editor-env.sh" -- -s="$(git rev-parse HEAD~1)" -m -y HEAD
_ST_CHECK "as on the squash rebuilt apart from a rebase" sh -c "test -e '$TMP/tp-editor-env' && ! grep -q maintenance.auto '$TMP/tp-editor-env'"
mkdir -p "$TMP/tp-bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$GIT_CONFIG_PARAMETERS" > "%s/tp-gui-env"\n' "$TMP" > "$TMP/tp-bin/code"
chmod +x "$TMP/tp-bin/code"
rm -f "$TMP/tp-gui-env"
_ST_TTY_START "GIT_EDITOR=code" "PATH=$TMP/tp-bin:$PATH" -- HEAD~1
if _ST_TTY_AT 'opens it in VS Code'; then
	zpty -wn ST_TTY ' '
	local -i TP_W=0
	until [ -e "$TMP/tp-gui-env" ] || (( ++TP_W > 100 )); do sleep 0.1; done
	zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_CHECK "nor does a GUI editor opened at the prompt" sh -c "test -e '$TMP/tp-gui-env' && ! grep -q maintenance.auto '$TMP/tp-gui-env'"
_ST_RUN --abort
# The sync leaves no staged revert where it can't merge – a binary's edits stay as changes to it
_ST_PZ_NEW tp5
_ST_PZ_C a.txt a "TP5 base"
printf 'b\0one' > b.bin && git add b.bin && git commit -qm "TP5 b1"
printf 'b\0two' > b.bin && git commit -qam "TP5 b2"
_ST_PZ_C c.txt c "TP5 c"
printf 'b\0mine' > b.bin
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a binary's edits stay unstaged, its entry what landed" "$RC:$(git diff --cached --name-only):$(git status --porcelain -- b.bin)" "0:: M b.bin"
_ST_OUT_HAS "named as kept" 'Your edits stay as they were, now changes to what landed'
git checkout -q -- b.bin
# An entry flagged assume-unchanged hides edits the sync merges, never overwrites
_ST_PZ_NEW tp6
_ST_PZ_C f.txt $'1\n2\n3\n4\n5\n6\n7\n8' "TP6 c1"
_ST_PZ_C f.txt $'1\n2x\n3\n4\n5\n6\n7\n8' "TP6 c2"
_ST_PZ_C g.txt g "TP6 g"
git update-index --assume-unchanged f.txt
print -r -- $'1\n2x\n3\n4\n5\n6\n7\n8 mine' > f.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a hidden edit is merged onto what landed" "$RC:$(tr '\n' ' ' < f.txt)" "0:1 2 3 4 5 6 7 8 mine "
git update-index --no-assume-unchanged f.txt; git checkout -q -- f.txt
# A locked index is named with the command for once it is free, never as a change while it ran
_ST_PZ_C h.txt h1 "TP6 h1"
_ST_PZ_C h.txt h2 "TP6 h2"
TP_GD=$(git rev-parse --absolute-git-dir)
printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n: > "%s/index.lock"\n' "$TP_GD" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
_ST_TTY -- -d -y HEAD
rm -f .git/hooks/reference-transaction "$TP_GD/index.lock"
_ST_OUT_HAS "a locked index is named with the restore for later" 'once it is free'
_ST_OUT_LACKS "never as a change while it ran" 'changed while it ran'
git restore -q --source=HEAD --staged --worktree -- h.txt
# A rename the carry can't take lands its destination all the same, a file standing there kept
_ST_PZ_NEW tp7
_ST_PZ_C a.txt a "TP7 base"
print -l {1..10} > b && git add b && git commit -qm "TP7 adds b"
git mv b a2 && git commit -qm "TP7 renames b"
_ST_PZ_C c.txt c "TP7 c"
print -l {1..10} mine > a2
print -r -- scratch > b
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a rename's destination reaches the index where the carry can't" "$RC:$(git status --porcelain | LC_ALL=C sort | tr '\n' '|')" "0: M b|?? a2|"
rm -f a2; git checkout -q -- b
# A removal staged by hand stays staged, the file untracked
_ST_PZ_NEW tp8
_ST_PZ_C f.txt $'1\n2\n3' "TP8 c1"
_ST_PZ_C f.txt $'1\n2x\n3' "TP8 c2"
_ST_PZ_C g.txt g "TP8 g"
git rm -q --cached f.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a staged removal stays staged, the file untracked" "$RC:$(git status --porcelain -- f.txt | LC_ALL=C sort | tr '\n' '|')" "0:?? f.txt|D  f.txt|"
cd "$TMP/repo"
