# What a run prints and parses holds whatever the names, values and settings
_ST_SCENARIO "\e[1;96m[122] output and parsing hold whatever the names, values and settings\e[0m"
local OP_A OP_OLD OP_WT
# A check given at a resume is recorded as written, and rerere's notes come before the
# trailer, which stays the last line
_ST_PZ_NEW o1
git config rerere.enabled false
printf 'a\nb\nc\n' > f.txt && git add f.txt && git commit -qm "OP base"
printf 'a\nB1\nc\n' > f.txt && git commit -qam "OP A" && OP_A=$(git rev-parse HEAD)
printf 'a\nB2\nc\n' > f.txt && git commit -qam "OP B"
_ST_PZ_C g.txt g "OP C"
printf 'a\nB3\nc\n' > f.txt && git add f.txt
_ST_RUN --amend-into="$OP_A" -- f.txt
OP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${OP_WT:-$ST_NO_WT}" f.txt $'a\nB3\nc'
_ST_RUN --continue --verify='printf "a\nb\n" | grep -qx b'
_ST_EQ "a resume given a check pauses at the next stop" "$RC" "2"
_ST_EQ "recording the check as written" "$(sed -n 's/^verify_cmd=//p' "$(git rev-parse --git-common-dir)/git-edit-state")" 'printf "a\nb\n" | grep -qx b'
_ST_RESOLVE "${OP_WT:-$ST_NO_WT}" f.txt $'a\nB3\nc'
_ST_RUN --continue
_ST_EQ "which then passes as written" "$RC" "0"
_ST_OUT_HAS "rerere's record is forgotten" 'Forgot [0-9]* resolution'
_ST_EQ "with the trailer still last" "$(print -r -- "$OUT" | tail -1 | cut -c1-12)" "git-edit: ok"
git config --unset rerere.enabled
# A ref name reaches a printed command quoted, as data
git checkout -q -b 'op$(>pwned)x'
_ST_RUN -M --text "OP C reworded" HEAD
_ST_OUT_HAS "the Undo line quotes a branch name holding shell syntax" "update-ref -m 'git edit: undo reword [0-9a-f]*' 'refs/heads/op"
git checkout -q main
# A parse error names the argument it refused, which has left `$1` by then
_ST_RUN -M --txt=hello HEAD
_ST_OUT_HAS "a parse error names the argument it refused" 'Unknown option: --txt=hello'
_ST_RUN HEAD --after
_ST_OUT_HAS "and a missing value names its option" 'Option --after needs a value'
# Parsing needs no temp file, so a missing `TMPDIR` still lets the standalone commands answer
TMPDIR="$TMP/no-such-dir" _ST_RUN --version
_ST_EQ "a missing TMPDIR leaves --version answering" "$RC" "0"
TMPDIR="$TMP/no-such-dir" _ST_RUN --status
_ST_OUT_HAS "and --status" '^git-edit: ok – no operation in flight'
# A `..` in a value is no range
_ST_PZ_C r1.txt r1 "OP R1"
_ST_PZ_C r2.txt r2 "OP R2"
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)" --verify='test -n ..'
_ST_EQ "a reorder whose check holds '..' runs" "$RC" "0"
_ST_EQ "in the order given" "$(git log -1 --format=%s HEAD~1)" "OP R2"
# A value given apart keeps its leading `=`, the `--text=` form only drops its own
_ST_RUN -M --text "==> see notes" HEAD
_ST_EQ "a separate --text keeps its leading '='" "$(git log -1 --format=%s)" "==> see notes"
_ST_RUN -M --text="=> eq form" HEAD
_ST_EQ "while the '=' form drops only its own" "$(git log -1 --format=%s)" "=> eq form"
# The `=` form keeps dropping its own past an `--exec` command's flag of the same name
_ST_RUN --verify='OP_GATE=1 true' --exec -- git commit -q --allow-empty --verify -m "OP verify past --"
_ST_EQ "an --exec command's own --verify leaves the gate's value alone" "$RC:$(git log -1 --format=%s)" "0:OP verify past --"
git reset -q --hard HEAD~1
echo v > op-v.txt
_ST_RUN --verify='OP_GATE=1 true' --commit --text --verify -- op-v.txt
_ST_OUT_HAS "a value given apart that reads like a flag is named as the flag it is" '--text takes a value, and got the flag --verify'
_ST_RUN --verify='OP_GATE=1 true' --commit --text=--verify -- op-v.txt
_ST_EQ "while glued on, it is the value, kept whole" "$RC:$(git log -1 --format=%s)" "0:--verify"
git reset -q --hard HEAD~1
# A repeated `--carry` refuses as every single-value option does, and a
# `--` ahead of the commits only ends the flags
_ST_RUN --carry=HEAD --carry=HEAD~1
_ST_EQ "a repeated --carry refuses" "$RC" "1"
_ST_OUT_HAS "saying why" '--carry given twice'
_ST_RUN -d -- HEAD
_ST_EQ "a drop after -- runs" "$RC" "0"
_ST_EQ "dropping the commit named" "$(git log -1 --format=%s)" "OP R2"
# `-m` reopens the message once an edit is amended, which a run with no terminal never reaches
_ST_RUN -m HEAD
_ST_EQ "-m on an edit without a terminal refuses" "$RC" "1"
_ST_OUT_HAS "pointing at --text on the continue" 'git edit --continue --text'
[ -n "$(_ST_PZ_WT)" ] && _ST_RUN --abort
# A worktree whose `.git` pointer is relative belongs to a live repo, which the sweep leaves
mkdir -p "$TMP/sweep"
git -c worktree.useRelativePaths=true worktree add -q --detach "$TMP/sweep/git-edit-rel.1" HEAD 2>/dev/null
touch -t 202001010000 "$TMP/sweep/git-edit-rel.1"
OUT=$(TMPDIR="$TMP/sweep" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "OP sweep" HEAD </dev/null 2>&1)
_ST_CHECK "a worktree with a relative pointer survives the sweep" test -d "$TMP/sweep/git-edit-rel.1"
git worktree remove --force "$TMP/sweep/git-edit-rel.1" 2>/dev/null
# A caller's own config pins stand beside the script's, which still apply
rm -f "$TMP/op-pin"
OUT=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=op.caller GIT_CONFIG_VALUE_0=kept GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- \
	sh -c "git config --get op.caller > '$TMP/op-pin'; git config --get diff.relative >> '$TMP/op-pin'; git commit -q --allow-empty -m 'OP pin'" </dev/null 2>&1)
_ST_EQ "a caller's GIT_CONFIG_COUNT keeps its pins and the script's" "$(tr '\n' ' ' < "$TMP/op-pin" 2>/dev/null)" "kept false "
# A subject holding a byte no UTF-8 has passes every sed, so a conflict's remaining steps list it
_ST_PZ_NEW o2
for OP_A in 1 2 3; do _ST_PZ_C f.txt "$OP_A" "OP $OP_A"; done
_ST_PZ_C c.txt c "OP raw"
OP_OLD=$(printf 'tree %s\nparent %s\nauthor P <p@x.invalid> 1700000000 +0000\ncommitter P <p@x.invalid> 1700000000 +0000\n\nOP raw \377 byte\n' \
	"$(git rev-parse 'HEAD^{tree}')" "$(git rev-parse HEAD~1)" | git hash-object -t commit -w --stdin)
git reset -q --hard "$OP_OLD"
OUT=$(LC_ALL=en_US.UTF-8 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d HEAD~2 </dev/null 2>&1)
_ST_OUT_HAS "a remaining step with a non-UTF-8 subject is listed in a UTF-8 locale" 'Remaining steps'
_ST_OUT_LACKS "with no sed dying on it" 'illegal byte'
_ST_RUN --abort
_ST_EQ "every ls-tree naming a path reads it from the top" "$(grep -n 'git ls-tree [^|]* -- ' "$SELF" | grep -v -e '--full-tree' -e 'ECHO_E')" ""
# A function defined twice runs as the later one everywhere, the earlier one's callers included
_ST_EQ "no function is defined twice" "$(grep -oE '^[A-Za-z_][A-Za-z0-9_]* \(\) \{' "$SELF" | LC_ALL=C sort | uniq -d)" ""
_ST_CHECK "the scratch dir's cleanup quotes its path" grep -qF '_CLEANUP_HOOK="rm -rf ${(q-)TMP}"' "$SELFTEST_DIR/lib.zsh"
# A run sent to a file keeps every line – Linux reopens that file for `tee /dev/stderr`
_ST_PZ_NEW o9
for OP_A in a b c; do _ST_PZ_C "$OP_A.txt" "$OP_A" "OP $OP_A"; done
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d HEAD~1 </dev/null >"$TMP/op-out" 2>&1
_ST_CHECK "a run written to a file keeps its opening lines" grep -q '^Dropping' "$TMP/op-out"
_ST_EQ "and no tee reopens a stream it would truncate" "$(grep -n 'tee /dev/' "$SELF")" ""
# A path holding a byte no UTF-8 has is read as text, so a mode flip on it still refuses –
# where the filesystem takes such a name at all, as APFS does not
_ST_PZ_NEW o10
_ST_PZ_C base.txt b "OP base"
OP_A=$'m\377.sh'
if print -r -- echo > "$OP_A" 2>/dev/null; then
	git add -- "$OP_A" && git commit -qm "OP M"
	_ST_PZ_C other.txt o "OP other"
	chmod +x "$OP_A" && git add -- "$OP_A"
	OUT=$(LC_ALL=en_US.UTF-8 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$(git rev-parse ':/OP M')" -- "$OP_A" </dev/null 2>&1)
	RC=$?
	_ST_EQ "a mode flip on a non-UTF-8 path still refuses" "$RC" "1"
fi
# A replant's summary shows a subject's escape in caret notation
_ST_PZ_NEW o3
_ST_PZ_C a.txt a "OP base"
git branch -q op-up
_ST_PZ_C b.txt b $'OP raw \e[2J subject'
git checkout -q op-up && _ST_PZ_C u.txt u "OP upstream" && git checkout -q main
_ST_RUN --onto=op-up
_ST_OUT_HAS "a replant's summary shows a subject's escape in caret notation" 'OP raw ^\[\[2J subject'
_ST_CHECK "with no escape byte reaching the terminal" eval '[[ "$OUT" != *$'"'"'\e'"'"'* ]]'
# A comma inside a name stays part of it in the conflict trailer
_ST_PZ_NEW o4
for OP_A in 1 2 3; do _ST_PZ_C 'Smith,John.txt' "$OP_A" "OP $OP_A"; done
_ST_RUN -d HEAD~1
_ST_OUT_HAS "a comma inside a conflicted name stays in it" '(Smith,John.txt);'
_ST_RUN --abort
# A gitlink counts by its commit, whatever a setting hides from a plain diff
_ST_PZ_NEW o5
_ST_PZ_C a.txt a "OP base"
git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),sub" && git commit -qm "OP sub" && mkdir sub
git config diff.ignoreSubmodules all
# `--allow-empty`, as an older git's commit sees nothing a submodule setting hides
OP_A=${$(git rev-parse HEAD)//?/1}
_ST_RUN --exec -- sh -c "git update-index --cacheinfo 160000,$OP_A,sub && git commit -q --allow-empty -m 'OP bump'"
_ST_EQ "an --exec bumping a gitlink lands" "$RC" "0"
_ST_EQ "and the checkout's index follows it" "$(git ls-files -s sub | cut -d' ' -f2)" "$OP_A"
_ST_OUT_LACKS "never prescribing a blanket reset" 'git reset --hard'
git config --unset diff.ignoreSubmodules
# A carry from a subdirectory reads paths from the top, whatever `diff.relative` says
_ST_PZ_NEW o6
mkdir src && printf 'l%s\n' {1..12} > src/f.txt && git add src && git commit -qm "OP src"
OP_OLD=$(git rev-parse HEAD)
git show HEAD:src/f.txt | sed 's/^l3$/X3/' > "$TMP/op-x3"
sed 's/^l10$/C10/' src/f.txt > src/f.new && mv src/f.new src/f.txt
_ST_RUN --exec -- sh -c "cp '$TMP/op-x3' src/f.txt && git commit -qam 'OP X3'"
git config diff.relative true
OUT=$(cd src && GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --carry="$OP_OLD" </dev/null 2>&1)
RC=$?
git config --unset diff.relative
_ST_EQ "a carry from a subdirectory under diff.relative lands" "$RC" "0"
_ST_EQ "with the edit on the new content" "$(sed -n '3p;10p' src/f.txt | tr '\n' ' ')" "X3 C10 "
# A carry never writes over a rename's destination holding an edit a clean filter hashes away
_ST_PZ_NEW o7b
git config filter.o7b.clean "sed 's/^secret=.*/secret=/'" && git config filter.o7b.smudge cat
print -r -- '*.cfg filter=o7b' > .gitattributes
{ printf 'l%s\n' {1..12}; print -r -- 'secret='; } > f.cfg && git add .gitattributes f.cfg && git commit -qm "OP f"
OP_OLD=$(git rev-parse HEAD)
git mv f.cfg moved.cfg && sed 's/^l3$/X3/' moved.cfg > m.new && mv m.new moved.cfg && git commit -qam "OP rename"
git show "$OP_OLD:f.cfg" | sed 's/^l10$/C10/' > f.cfg
sed 's/^secret=$/secret=HIDDEN/' moved.cfg > m.new && mv m.new moved.cfg
_ST_RUN --carry="$OP_OLD"
_ST_EQ "a carry leaves a destination's edit a clean filter hides" "$(grep -c '^secret=HIDDEN$' moved.cfg)" "1"
_ST_OUT_HAS "naming the source it held back" 'f.cfg – renamed to moved.cfg, which the checkout holds already'
# A rename this checkout landed takes the carry of its source's stale edits
_ST_PZ_NEW o7
printf 'l%s\n' {1..12} > f.txt && git add f.txt && git commit -qm "OP f"
OP_OLD=$(git rev-parse HEAD)
git mv f.txt moved.txt && sed 's/^l3$/X3/' moved.txt > m.new && mv m.new moved.txt && git commit -qam "OP rename"
git show "$OP_OLD:f.txt" | sed 's/^l10$/C10/' > f.txt
_ST_RUN --carry="$OP_OLD"
_ST_EQ "a carry into a rename destination holding what landed succeeds" "$RC" "0"
_ST_EQ "merging the stale edits there" "$(sed -n '3p;10p' moved.txt | tr '\n' ' ')" "X3 C10 "
_ST_CHECK "and taking the source along" test ! -e f.txt
# A rebuilt commit keeps its author line byte for byte, as a rebase does – quotes git would
# trim from a name it is handed, and a name it would refuse
_ST_PZ_NEW o8
_ST_PZ_C a.txt a "OP base"
OP_A=$(git rev-parse 'HEAD^{tree}')
OP_OLD=$(printf 'tree %s\nparent %s\nauthor "Q. Doe Jr." <q@x.invalid> 1600000000 +0530\ncommitter P <p@x.invalid> 1600000000 +0530\n\nOP quoted\n' \
	"$OP_A" "$(git rev-parse HEAD)" | git hash-object -t commit -w --stdin)
git reset -q --hard "$OP_OLD"
_ST_RUN -M --text "OP quoted reworded" HEAD
_ST_EQ "a reword keeps a quoted author as written" "$(git cat-file commit HEAD | sed -n '/^author /p')" 'author "Q. Doe Jr." <q@x.invalid> 1600000000 +0530'
OP_OLD=$(printf 'tree %s\nparent %s\nauthor  <e@x.invalid> 1600000000 +0530\ncommitter P <p@x.invalid> 1600000000 +0530\n\nOP unnamed\n' \
	"$OP_A" "$(git rev-parse HEAD)" | git hash-object -t commit -w --stdin)
git reset -q --hard "$OP_OLD"
OUT=$(GIT_EDIT_NO_REPLAY=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "OP quoted again" HEAD~1 </dev/null 2>&1)
RC=$?
_ST_EQ "a reword below an unnamed author lands" "$RC" "0"
_ST_EQ "rebuilding the unnamed one above it as it was" "$(git cat-file commit HEAD | sed -n '/^author /p')" 'author  <e@x.invalid> 1600000000 +0530'
# A trailing `.` was crud to git before 2.42, which a rebuild there must keep as well
OP_OLD=$(printf 'tree %s\nparent %s\nauthor Foo Jr. <f@x.invalid> 1600000000 +0530\ncommitter P <p@x.invalid> 1600000000 +0530\n\nOP dotted\n' \
	"$OP_A" "$(git rev-parse HEAD)" | git hash-object -t commit -w --stdin)
git reset -q --hard "$OP_OLD"
OUT=$(GIT_EDIT_NO_REPLAY=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "OP below dotted" HEAD~1 </dev/null 2>&1)
_ST_EQ "a name ending in a dot is rebuilt as written" "$?:$(git cat-file commit HEAD | sed -n '/^author /p')" '0:author Foo Jr. <f@x.invalid> 1600000000 +0530'
cd "$TMP/repo"
