# A caller's .zshenv sets no option the script runs under

# A caller's `$ZDOTDIR/.zshenv` runs for every zsh invocation, scripts included, so a `setopt
# sh_word_split` or `ksh_arrays` there would run a different tool than this suite proves
# `emulate zsh` as the script's first statement puts every option that changes parsing back,
# first since it resets `pipefail` too – and this suite, sourced into the script's process,
# runs under its options as they stand, so a reset in here would reach every check after it
_ST_SCENARIO "\e[1;96m[82] a hostile .zshenv changes nothing\e[0m"
_ST_EQ "git-edit opens with emulate zsh" "$(command grep -v -E -m1 '^(#|$)' "$SELF")" "emulate zsh"
_ST_EQ "the suite runs under the script's pipefail" "$([[ -o pipefail ]] && echo on || echo off)" "on"
mkdir -p "$TMP/zdotdir"
# Six options `emulate` resets – `csh_junkie_quotes` makes a multi-line quote a parse error,
# which is what an editor git-edit writes for git would hit as a zsh script of its own – and
# an alias, which zsh expands in scripts too and `emulate` leaves alone: this one puts a color
# escape into every SHA parsed out of grep, and `unalias -a` is what clears it
printf "setopt sh_word_split glob_subst ksh_arrays csh_junkie_quotes\nunsetopt nomatch equals\nalias grep='grep --color=always'\n" > "$TMP/zdotdir/.zshenv"
printf '#!/bin/zsh\n[[ -o ksh_arrays ]] && echo on || echo off\n' > "$TMP/zdotdir/probe.zsh"
_ST_EQ "the fixture reaches a child zsh" "$(ZDOTDIR="$TMP/zdotdir" zsh "$TMP/zdotdir/probe.zsh")" "on"
echo "hz" > hz.txt && git add hz.txt && git commit -qm "HZ wrong subject"
local HZ_SHA=$(git rev-parse HEAD)
OUT=$(ZDOTDIR="$TMP/zdotdir" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text="HZ right subject" "$HZ_SHA" </dev/null 2>&1); RC=$?
_ST_EQ "a reword under it exits 0" "$RC" "0"
_ST_OUT_HAS "and lands" '^git-edit: ok'
_ST_EQ "with its subject" "$(git log -1 --format=%s)" "HZ right subject"
# A reorder hands git a sequence editor written at runtime – as a zsh script it would start
# a zsh of its own, which reads the same .zshenv, since `emulate` in the parent reaches no child
echo "hz2" > hz2.txt && git add hz2.txt && git commit -qm "HZ second"
local HZ_TIP_TREE=$(git rev-parse 'HEAD^{tree}')
OUT=$(ZDOTDIR="$TMP/zdotdir" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)" </dev/null 2>&1); RC=$?
_ST_EQ "a reorder under it exits 0" "$RC" "0"
_ST_EQ "swapping the two" "$(git log -2 --format=%s | tr '\n' '|')" "HZ right subject|HZ second|"
_ST_EQ "with the tip tree kept" "$(git rev-parse 'HEAD^{tree}')" "$HZ_TIP_TREE"
