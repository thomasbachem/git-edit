_ST_SCENARIO "\e[1;96m[130] a caller's settings reach what runs on its behalf, and nothing else\e[0m"
local EV_T EV_WT
# A rebuilt message is written in the encoding its header names
_ST_PZ_NEW ev1
git config i18n.commitEncoding ISO-8859-1
_ST_PZ_C a.txt a "EV base"
print -rn -- $'Na\xefve top\n' > "$TMP/ev-msg"
print -r -- b > b.txt && git add b.txt && git commit -q -F "$TMP/ev-msg"
_ST_RUN -M --text "EV base reworded" HEAD~1
_ST_EQ "a rebuilt Latin-1 message stays Latin-1 under its header" \
	"$RC:$(git cat-file commit HEAD | sed -n '/^$/,$p' | sed 1d | od -An -tx1 | tr -d ' \n')" "0:4e61ef766520746f700a"
_ST_EQ "and reads back as it was written" "$(git -c i18n.logOutputEncoding=UTF-8 log -1 --format=%s)" "Naïve top"
# A -M template comments as this git strips – git before 2.45 knows no core.commentString
_ST_PZ_NEW ev2
_ST_PZ_C a.txt a "EV2 a" && _ST_PZ_C b.txt b "EV2 b"
git config core.commentString '//'
printf '#!/bin/sh\n{ printf "EV2 reworded\\n"; grep -E "^(#|//)" "$1"; } > "$1.n" && mv "$1.n" "$1"\n' > "$TMP/ev-editor"
chmod +x "$TMP/ev-editor"
_ST_TTY "GIT_EDITOR=$TMP/ev-editor" -- -M HEAD~1
git config --unset core.commentString
_ST_EQ "a -M template keeps no line in the message, whichever prefix this git strips" \
	"$RC:$(git log -1 --format=%B HEAD~1 | grep -c .)" "0:1"
# Commits from a detached worktree carry the identity the branch's checkout reads
_ST_PZ_NEW ev3
_ST_PZ_C a.txt a "EV3 a"
printf '[user]\n\temail = branch@x.invalid\n' > "$TMP/ev-onbranch.inc"
git config 'includeIf.onbranch:main.path' "$TMP/ev-onbranch.inc"
print -r -- c > c.txt
_ST_RUN --commit --text "EV3 c" -- c.txt
_ST_EQ "a --commit takes an onbranch include's identity" "$RC:$(git log -1 --format='%ae %ce')" "0:branch@x.invalid branch@x.invalid"
_ST_PZ_C d.txt d "EV3 d"
_ST_RUN -d -y HEAD~1
_ST_EQ "as does a drop's rebuild" "$RC:$(git log -1 --format=%ce)" "0:branch@x.invalid"
git config --unset 'includeIf.onbranch:main.path'
# A caller's own variables reach its command, whatever name the tool keeps inside
_ST_PZ_NEW ev4
_ST_PZ_C a.txt a "EV4 a"
TARGET=prod COMMIT=c0 S=s1 STEP=st _ST_RUN --exec -- sh -c 'printf "%s:%s:%s:%s\n" "$TARGET" "$COMMIT" "$S" "$STEP" > "$0"' "$TMP/ev-vars"
_ST_EQ "an --exec command gets the caller's TARGET, COMMIT, S and STEP" "$RC:$(<"$TMP/ev-vars")" "0:prod:c0:s1:st"
git config edit.verifyCmd 'test "$TARGET" = prod'
_ST_PZ_C b.txt b "EV4 b"
TARGET=prod _ST_RUN -d -y HEAD
git config --unset edit.verifyCmd
_ST_EQ "as does a verify check" "$RC" "0"
# A terminal on stdin but output piped away is no person at a prompt
_ST_PZ_NEW ev5
_ST_PZ_C a.txt a "EV5 a" && _ST_PZ_C b.txt b "EV5 b"
zmodload zsh/zpty
rm -f "$TMP/ev5-rc"
zpty EV5 "unset CLAUDECODE CI GIT_EDIT_ACTOR; env HOME=${(q)TMP} GIT_EDIT_NO_AUTO_OPEN=1 ${(q)SELF} HEAD~1 2>&1 | cat >${(q)TMP}/ev5-out; print -r -- \${pipestatus[1]} >${(q)TMP}/ev5-rc"
local -i EV_W=0
until [ -s "$TMP/ev5-rc" ] || (( ++EV_W > 300 )); do sleep 0.1; done
zpty -d EV5
_ST_EQ "an edit with its output piped pauses as an agent's" "$(<"$TMP/ev5-rc")" "2"
_ST_CHECK "ending on its trailer" test "$(tail -1 "$TMP/ev5-out" | cut -c1-17)" = "git-edit: paused "
_ST_RUN --abort
# A relative hooksPath runs from the checkout at a pause's resume too – an untracked one, husky's
_ST_PZ_NEW ev6
_ST_PZ_C a.txt a "EV6 a" && _ST_PZ_C b.txt b "EV6 b"
mkdir -p .hk && printf '#!/bin/sh\necho ran >> "%s/ev6-hook"\n' "$TMP" > .hk/pre-commit && chmod +x .hk/pre-commit
printf '.hk/\n' >> .git/info/exclude
git config core.hooksPath .hk
rm -f "$TMP/ev6-hook"
_ST_RUN HEAD~1
print -r -- a2 > "$(_ST_PZ_WT)/a.txt"
_ST_RUN --continue
git config --unset core.hooksPath
_ST_EQ "an edit's amend runs the checkout's untracked hooks" "$RC:$(grep -c ran "$TMP/ev6-hook" 2>/dev/null)" "0:1"
# The output git itself prints shows a subject's control bytes inert
_ST_PZ_NEW ev7
_ST_PZ_C a.txt a "EV7 a"
_ST_PZ_C c.txt c "EV7 c"
print -r -- b > b.txt && git add b.txt && git commit -qm $'EV7 \e]0;pwned\a title'
_ST_RUN -d -y HEAD~1
_ST_EQ "no raw escape from a subject reaches the output" "$(print -r -- "$OUT" | LC_ALL=C grep -c $'\e]0;')" "0"
# A re-point hint for an annotated tag keeps its message
_ST_PZ_NEW ev8
_ST_PZ_C a.txt a "EV8 a" && _ST_PZ_C b.txt b "EV8 b"
git tag -a -m "EV8 release notes" v8 HEAD
_ST_PZ_C c.txt c "EV8 c"
_ST_RUN -d -y HEAD~2
_ST_OUT_HAS "an annotated tag's hint keeps its message" 'git tag -f -a -F - v8'
eval "$(print -r -- "$OUT" | sed -n 's/^  \(git for-each-ref .*git tag -f -a -F - v8 [0-9a-f]*\)$/\1/p')"
_ST_EQ "which re-points it as an annotated tag" "$(git cat-file -t v8):$(git for-each-ref --format='%(contents:subject)' refs/tags/v8)" "tag:EV8 release notes"
# A path a hint pastes back holds its `!` single-quoted, the cd before it too
mkdir -p "$TMP/ev9!dir" && cd "$TMP/ev9!dir" && git init -q -b main . && git config user.email p@x.invalid && git config user.name P
_ST_PZ_C a.txt a "EV9 a" && _ST_PZ_C b.txt b "EV9 b"
mkdir -p sub && cd sub
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "a cd a hint pastes holds its ! single-quoted" "cd '[^']*/ev9!dir' && "
cd "$TMP"
rm -rf "${TMP:?}/ev9!dir"
cd "$TMP/repo"
