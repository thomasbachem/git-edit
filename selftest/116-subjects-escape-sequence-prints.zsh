# A commit subject's escape sequence prints literally, never as a terminal control
# A pulled commit's subject is data – listed in a refusal it must not move the cursor, clear the
# screen or set the title, which `echo -e` would have run
_ST_SCENARIO "\e[1;96m[116] a subject's escape sequence prints as literal text, not a control\e[0m"
local TE_BASE=$(git rev-parse HEAD)
printf 'te1\n' > te-a.txt && printf 'tu1\n' > te-b.txt && git add te-a.txt te-b.txt
git commit -qm $'TE-A clear \\e[2J and title \\e]0;x\\a end, conceal \\e[8m kept, reset \\e[0m too' -- te-a.txt
git commit -qm "TE-B plain" -- te-b.txt
printf 'te2\n' >> te-a.txt && printf 'tu2\n' >> te-b.txt && git add te-a.txt te-b.txt
_ST_RUN --amend-into=auto -- te-a.txt te-b.txt
_ST_OUT_HAS "the refusal lists the candidates" 'different commit'
_ST_OUT_HAS "a subject's screen-clear prints as its literal characters" 'clear \\e\[2J and'
_ST_OUT_HAS "and its OSC title stays literal too" 'title \\e]0;x\\a end'
_ST_OUT_HAS "as does a color code no template uses, a conceal" 'conceal \\e\[8m kept'
_ST_OUT_HAS "and one a template uses, a reset" 'reset \\e\[0m too'
_ST_CHECK "with no real escape byte reaching the terminal" eval '[[ "$OUT" != *$'"'"'\e'"'"'* ]]'
git reset -q --hard "$TE_BASE"
rm -f te-a.txt te-b.txt
# A subject carrying the raw bytes rather than their spelling shows them in caret notation
printf 'tr1\n' > te-r.txt && printf 'tu1\n' > te-b.txt && git add te-r.txt te-b.txt
git commit -qm $'TE-R raw \e[2J and \e]0;x\a end' -- te-r.txt
git commit -qm "TE-B plain" -- te-b.txt
printf 'tr2\n' >> te-r.txt && printf 'tu2\n' >> te-b.txt && git add te-r.txt te-b.txt
_ST_RUN --amend-into=auto -- te-r.txt te-b.txt
_ST_OUT_HAS "a subject's raw escape bytes show in caret notation" 'raw ^\[\[2J and ^\[\]0;x^G end'
_ST_CHECK "with no escape byte reaching the terminal" eval '[[ "$OUT" != *$'"'"'\e'"'"'* ]]'
git reset -q --hard "$TE_BASE"
rm -f te-r.txt te-b.txt
# The refusal naming the commit a path arrives in shows its subject inert too
printf 'n0\n' > te-n0.txt && git add te-n0.txt && git commit -qm "TE-N base"
local TE_N=$(git rev-parse HEAD)
printf 'n1\n' > te-new.txt && git add te-new.txt && git commit -qm $'TE-N adds \e[2J it'
printf 'n2\n' >> te-new.txt && git add te-new.txt
_ST_RUN --amend-into="$TE_N" -- te-new.txt
_ST_OUT_HAS "the commit a path arrives in shows its subject in caret notation" 'arrives in .*TE-N adds ^\[\[2J it'
_ST_CHECK "there too with no escape byte reaching the terminal" eval '[[ "$OUT" != *$'"'"'\e'"'"'* ]]'
git reset -q --hard "$TE_BASE"
rm -f te-n0.txt te-new.txt
# The order a move prints shows a subject's raw bytes in caret notation too
git commit -q --allow-empty -m $'TE-M raw \e]0;x\a end'
git commit -q --allow-empty -m "TE-M top"
_ST_RUN --move=HEAD~1 --after=HEAD
_ST_OUT_HAS "a move's summary shows a raw escape in caret notation" 'TE-M raw ^\[\]0;x^G end'
_ST_CHECK "there too with no escape byte reaching the terminal" eval '[[ "$OUT" != *$'"'"'\e'"'"'* ]]'
git reset -q --hard "$TE_BASE"
# A name holding a color code's text prints as itself in a hint – rendered, it hid part of the
# name, and the command pasted would restore another file
printf 'v1\n' > 'te\e[0mx.txt' && printf 'v1\n' > tex.txt && git add -- ':(literal)te\e[0mx.txt' tex.txt && git commit -qm "TE-L names"
_ST_RUN --exec -- sh -c 'printf "v2\n" > "$1" && git commit -qam "TE-L lands"' sh 'te\e[0mx.txt'
_ST_OUT_HAS "a hint names such a file as itself" 'Reconcile those paths.*te\\e\[0mx\.txt'
git reset -q --hard "$TE_BASE"
rm -f 'te\e[0mx.txt' tex.txt
# A conflict lists such a name, and a later step's subject holding one, as themselves
printf '1\n2\n3\n' > 'te\e[0mc.txt' && git add -- ':(literal)te\e[0mc.txt' && git commit -qm "TE-C base"
local TE_CB=$(git rev-parse HEAD)
printf '1\nL\n3\n' > 'te\e[0mc.txt' && git commit -qam 'TE-C later \e[0m kept'
printf '1\nS\n3\n' > 'te\e[0mc.txt' && git add -- ':(literal)te\e[0mc.txt'
_ST_RUN --amend-into="$TE_CB" -- ':(literal)te\e[0mc.txt'
_ST_OUT_HAS "a conflicted name lists as itself" '^  - te\\e\[0mc\.txt$'
_ST_OUT_HAS "as does a remaining step's subject" '^  pick [0-9a-f]* .*TE-C later \\e\[0m kept$'
_ST_OUT_HAS "and the step touching the name, listed under it" '^    [0-9a-f]* TE-C later \\e\[0m kept$'
_ST_RUN --abort
git reset -q --hard "$TE_BASE"
rm -f 'te\e[0mc.txt'
# A subject holding a backslash or `|` finds its counterpart, and shows as itself
printf 'tt\n' > te-t.txt && git add te-t.txt && git commit -qm "TE-T below"
printf 'tt2\n' >> te-t.txt && git commit -qam 'TE-T reset \e[0m | kept'
git tag te-tag && git branch te-br
_ST_RUN -M --text "TE-T below reworded" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "a tag's re-point hint shows the subject as itself" 'Tag te-tag .*same [a-z]*: TE-T reset \\e\[0m | kept$'
_ST_OUT_HAS "as does a branch's" 'Branch te-br .*same [a-z]*: TE-T reset \\e\[0m | kept$'
git tag -d te-tag >/dev/null && git branch -q -D te-br
git reset -q --hard "$TE_BASE"
rm -f te-t.txt
printf 'ts\n' > te-s.txt && git add te-s.txt && git commit -qm 'TE-S stale \e[0m kept'
local TE_S=$(git rev-parse HEAD)
printf 'ts2\n' > te-s.txt && git add te-s.txt
_ST_RUN --amend-into="$TE_S" -- te-s.txt
_ST_RUN -d -y "$TE_S"
_ST_OUT_HAS "as does a stale SHA's, its content changed" 'counterpart on HEAD'
git reset -q --hard "$TE_BASE"
rm -f te-s.txt
# A gate's CRLF line prints without its `\r`, a long colored one without a pass per character,
# and a byte no UTF-8 holds in a UTF-8 locale where one is installed, as BSD sed died on it there
local TE_U8=$(locale -a 2>/dev/null | grep -m1 -E '^(en_US\.UTF-8|en_US\.utf8|C\.UTF-8|C\.utf8)$')
git config edit.verifyCmd "printf 'TE gate CRLF\r\n'; printf 'TE gate \377\nTE gate past the byte\n'; awk 'BEGIN { for (i = 0; i < 8000; i++) printf \"\033[31mred\033[0m te \"; print \"\" }'; exit 1"
printf 'tg\n' > te-g.txt
# CPU seconds, as a loaded machine stretches the clock's tenfold – a pass per character takes
# 30 here, where this run takes under one
times > "$TMP/te-cpu"
LC_ALL=${TE_U8:-C} _ST_RUN --commit --text "x" -- te-g.txt
times >> "$TMP/te-cpu"
git config --unset edit.verifyCmd
_ST_OUT_HAS "a gate's CRLF line prints" '| TE gate CRLF'
_ST_OUT_LACKS "with no caret for the line's own ending" 'TE gate CRLF\^M'
_ST_OUT_HAS "as does the line past a byte no UTF-8 holds" '| TE gate past the byte'
_ST_CHECK "and a 128 KB colored line in under 10 CPU seconds" test "$(awk 'function s(t, a) { split(t, a, /[ms]/); return a[1] * 60 + a[2] }
	NR == 2 { b = s($1) + s($2) } NR == 4 { print int(s($1) + s($2) - b) }' "$TMP/te-cpu")" -lt 10
rm -f te-g.txt
# A byte above 0x7f prints as itself – as the stand-in for a data backslash, it came back as one
local TE_LC
for TE_LC in C $TE_U8; do
	LC_ALL=$TE_LC _ST_RUN --exec -- true $'te\xffff'
	_ST_CHECK "a raw byte above 0x7f in a printed command prints as itself under $TE_LC" eval '[[ "$(print -r -- "$OUT" | od -An -tx1 | tr -d " \n")" == *7465ff6666* ]]'
done
# A name ending in a carriage return lists with it – only a command's output drops a CRLF ending
printf 'cr1\n' > $'te-cr.txt\r' && git add -- $'te-cr.txt\r' && git commit -qm "TE-CR base"
_ST_RUN --exec -- sh -c 'printf "cr2\n" > "$1" && git commit -qam "TE-CR lands"' sh $'te-cr.txt\r'
_ST_OUT_HAS "a name ending in a carriage return lists with it" '^  te-cr\.txt\^M$'
git reset -q --hard "$TE_BASE"
rm -f $'te-cr.txt\r'
# The `HEAD` a missing commit names shows its subject as itself
git commit -q --allow-empty -m 'TE-H reset \e[0m kept'
_ST_RUN -M --text "x"
_ST_OUT_HAS "the HEAD a missing commit names shows its subject as itself" 'HEAD is currently [0-9a-f]* TE-H reset \\e\[0m kept$'
git reset -q --hard "$TE_BASE"
# A C1 control in a subject – U+009B, a CSI to some terminals – shows as `cat -v` has it, and a
# caret's own backslash starts no escape
git commit -q --allow-empty -m $'TE-C1 \xc2\x9b2J and \x1ce[0;30mhidden'
_ST_RUN -M --text "x"
_ST_OUT_HAS "a C1 control in a subject shows as cat -v has it" 'HEAD is currently [0-9a-f]* TE-C1 M-BM-^\[2J and'
_ST_OUT_HAS "and a caret's backslash renders no escape" 'and \^\\e\[0;30mhidden$'
_ST_CHECK "with no C1 pair reaching the terminal" eval '[[ "$(print -r -- "$OUT" | od -An -tx1 | tr -d " \n")" != *c29b* ]]'
git reset -q --hard "$TE_BASE"
# A terminal run pads with a real blank line – `ECHO_E` renders no `\n` spelled out, so padding
# held as text would print literally on every line
local TE_TTY=""
if script -q /dev/null true </dev/null >/dev/null 2>&1; then
	TE_TTY=$(script -q /dev/null "$SELF" --status </dev/null 2>&1)
elif script -qec true /dev/null </dev/null >/dev/null 2>&1; then
	TE_TTY=$(script -qec "${(q)SELF} --status" /dev/null </dev/null 2>&1)
fi
if [ -n "$TE_TTY" ]; then
	_ST_CHECK "a terminal run pads with blank lines, never a literal \\n" eval '[[ "$TE_TTY" == *"git-edit: ok"* && "$TE_TTY" != *"\\n"* ]]'
fi
# The status line stays the last line, a name in it whole – `echo` cut one at its `\c`, and a
# raw newline split the line, leaving no `git-edit:` anchor last
_ST_RUN --commit --text "x" -- 'te\c\nno.txt'
_ST_EQ "the status line keeps a name's backslashes" "$(print -r -- "$OUT" | tail -1)" 'git-edit: error – te\c\nno.txt: no such file, in the checkout or at the tip'
_ST_RUN --commit --text "x" -- $'te\nnl.txt'
_ST_CHECK "and a raw newline in one leaves it on one line" eval '[[ "$(print -r -- "$OUT" | tail -1)" == "git-edit: error – "*"has a newline in its name"* ]]'
# A `%` in a squash target's subject must not miscount the preamble's `%s` and collapse its
# list onto one line – the target is rendered apart, its subject never in the format string
git commit -q --allow-empty -m 'TE pct 50% and %s and -> arrow'
printf 'tc1\n' > te-c.txt && git add te-c.txt && git commit -qm "TE top one"
printf 'tc2\n' > te-d.txt && git add te-d.txt && git commit -qm "TE top two"
_ST_RUN -s HEAD~2 HEAD~1 HEAD
_ST_EQ "a squash into a %-subject target keeps each commit on its own line" "$RC:$(print -r -- "$OUT" | grep -c '^ - ')" "0:2"
_ST_OUT_HAS "with the hostile subject rendered literally and whole" 'into .* (TE pct 50% and %s and -> arrow)'
git reset -q --hard "$TE_BASE"
rm -f te-c.txt te-d.txt
# A message through `--text` keeps its backslash escapes – `echo` would turn a `\t` or `\e`
# in it into a real control byte in the stored commit
export GIT_EDIT_ACTOR=wc-self
printf 'tm\n' > te-msg.txt && git add te-msg.txt
_ST_RUN --commit --text $'TE msg \\t tab \\e esc keep' -- te-msg.txt
_ST_EQ "a --text message keeps its escapes as literal text" "$RC:$(git log -1 --format=%B)" "0:TE msg \t tab \e esc keep"
_ST_EQ "no control byte reached the stored message" "$(git log -1 --format=%B | od -An -c | grep -cE '033|\\t')" "0"
export GIT_EDIT_ACTOR=
git reset -q --hard "$TE_BASE"
rm -f te-msg.txt
