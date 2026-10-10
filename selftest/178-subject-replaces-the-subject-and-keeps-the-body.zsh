# `--subject` replaces git's subject – the whole first paragraph – with -M and an edit pause's
# `--continue`, keeping everything from the blank line after it byte for byte, one line only, never
# beside `--text`, refused by a mode writing a new message – and a `--text` dropping a body
# names it as the way to keep one
_ST_SCENARIO "\e[1;96m[178] --subject replaces the subject and keeps the body\e[0m"
local SJ_T SJ_TREE SJ_TOP SJ_HEAD SJ_WT
# Prints commit <1>'s message as its object holds it, byte for byte
_SJ_MSG () {
	local O
	O=$(git cat-file commit "$1"; print -n x)
	O=${O%x}
	print -rn -- "${O#*$'\n\n'}"
}
# Commits what is staged with the message <1> exactly, as `printf` reads it
_SJ_COMMIT () {
	printf "$1" > "$TMP/sj-msg" && git commit -q --allow-empty --cleanup=verbatim -F "$TMP/sj-msg"
}

# A reword keeps the body byte for byte – a trailer, a `#` line, no last newline – and takes a
# first paragraph of two lines as the one subject git reads it as, given apart from its flag
_ST_PZ_NEW sj1
_ST_PZ_C a.txt a "SJ1 base"
print -r -- b > b.txt && git add b.txt
_SJ_COMMIT 'Old line one\nold line two\n\n• body line\n\nSigned-off-by: X <x@y.invalid>\n# a hash line\ntrailing words'
SJ_T=$(git rev-parse HEAD)
_ST_PZ_C c.txt c "SJ1 top"
SJ_TREE=$(git rev-parse 'HEAD^{tree}')
_ST_RUN -M --subject "New subject" "$SJ_T"
_ST_EQ "-M --subject given apart applies" "$RC" "0"
printf 'New subject\n\n• body line\n\nSigned-off-by: X <x@y.invalid>\n# a hash line\ntrailing words' > "$TMP/sj-want"
_ST_CHECK "the subject replaced, the rest kept byte for byte" cmp -s <(_SJ_MSG HEAD~1) "$TMP/sj-want"
_ST_EQ "the commit above keeps its message, the tip its tree" "$(git log -1 --format=%s HEAD):$(git rev-parse 'HEAD^{tree}')" "SJ1 top:$SJ_TREE"
_ST_OUT_HAS "naming the subject it replaced, as git reads it" '  replaced: Old line one old line two$'
_ST_OUT_LACKS "and no body as dropped" 'carried a .*-line body'
# Glued on, the same subject again is a message unchanged
SJ_HEAD=$(git rev-parse HEAD)
_ST_RUN -M --subject="New subject" HEAD~1
_ST_EQ "the same subject again changes nothing" "$RC:$(git rev-parse HEAD)" "0:$SJ_HEAD"
_ST_OUT_HAS "and says so" 'Message unchanged – nothing to do'
# A glued value holds what follows its `=`, a leading `=` of its own and the trimmed spaces aside
_ST_RUN -M "--subject==Glued  " HEAD~1
_ST_EQ "a glued value is taken after its first =, trimmed" "$RC:$(git log -1 --format=%s HEAD~1)" "0:=Glued"

# A CRLF message stays one, its body untouched
_ST_PZ_NEW sj2
_ST_PZ_C a.txt a "SJ2 base"
_SJ_COMMIT 'Old CRLF\r\n\r\nBody line\r\n'
_ST_RUN -M --subject=CRLF-new HEAD
_ST_EQ "a CRLF message rewords" "$RC" "0"
printf 'CRLF-new\r\n\r\nBody line\r\n' > "$TMP/sj-want"
_ST_CHECK "keeping its line endings and body" cmp -s <(_SJ_MSG HEAD) "$TMP/sj-want"
# A message with no body is the subject alone, ended in a newline as `--text` ends one
_SJ_COMMIT 'Bare, no newline'
_ST_RUN -M --subject="Bare reworded" HEAD
printf 'Bare reworded\n' > "$TMP/sj-want"
_ST_CHECK "a body-less message becomes the subject and a newline" cmp -s <(_SJ_MSG HEAD) "$TMP/sj-want"
_ST_PZ_C d.txt d "Plain old"
_ST_RUN -M --subject="Plain new" HEAD
printf 'Plain new\n' > "$TMP/sj-want"
_ST_CHECK "so does one ending in its own newline" cmp -s <(_SJ_MSG HEAD) "$TMP/sj-want"
# Neighbor: `--text` still replaces the whole message,
# naming the command putting a body it drops back
_SJ_COMMIT 'Text target\n\n• kept by subject alone\n• second line\n'
_ST_RUN -M --text="Text whole" HEAD
printf 'Text whole\n' > "$TMP/sj-want"
_ST_CHECK "-M --text still replaces the whole message" cmp -s <(_SJ_MSG HEAD) "$TMP/sj-want"
_ST_OUT_HAS "naming the body it drops" 'carried a 2-line body the new one drops'
_ST_OUT_HAS "and the command putting it back under the new subject" "^To put the body back under the new subject: git edit -M --text=.*git log -1 --format=%b [0-9a-f]\{12\})\" $(git rev-parse --short=12 HEAD)\$"
# Not where the new message restates part of the body – that one was rewritten on purpose
_SJ_COMMIT 'Cut target\n\n• line kept\n• line cut\n'
_ST_RUN -M --text="$(printf 'Cut new\n\n• line kept')" HEAD
_ST_OUT_HAS "a body cut in part is named" 'the new one lacks 1 of its lines'
_ST_OUT_LACKS "without the --subject hint" 'To change the subject alone'

# An edit pause's continue takes it with the content it amends, the body kept
_ST_PZ_NEW sj3
_ST_PZ_C f.txt 1 "SJ3 base"
print -r -- 2 > f.txt && git add f.txt
_SJ_COMMIT 'SJ3 target\n\n• edit body\nCo-authored-by: Y <y@y.invalid>\n'
SJ_T=$(git rev-parse HEAD)
_ST_PZ_C g.txt g "SJ3 top"
_ST_RUN "$SJ_T"
_ST_EQ "the edit pauses" "$RC" "2"
_ST_OUT_HAS "its hint naming --subject" 'or --subject "…" for the subject alone'
SJ_WT=$(_ST_PZ_WT)
print -r -- 2-edited > "${SJ_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue --subject "SJ3 edited"
_ST_EQ "--continue --subject lands" "$RC" "0"
printf 'SJ3 edited\n\n• edit body\nCo-authored-by: Y <y@y.invalid>\n' > "$TMP/sj-want"
_ST_CHECK "with the subject replaced and the body kept" cmp -s <(_SJ_MSG HEAD~1) "$TMP/sj-want"
_ST_EQ "and the content amended" "$(git show HEAD~1:f.txt):$(git log -1 --format=%s HEAD)" "2-edited:SJ3 top"
_ST_OUT_LACKS "naming no body as dropped" 'carried a .*-line body'
# With nothing to amend but the subject
_ST_RUN HEAD~1
_ST_RUN --continue --subject=SJ3-again
_ST_EQ "a subject alone is something to amend" "$RC:$(git log -1 --format=%s HEAD~1):$(git log -1 --format=%b HEAD~1 | head -1)" "0:SJ3-again:• edit body"
# Neighbor: `--continue --text` still drops the body,
# naming the reword of the landed commit that puts it back
_ST_RUN HEAD~1
_ST_RUN --continue --text "SJ3 whole"
_ST_EQ "--continue --text replaces the whole message" "$RC:$(git log -1 --format=%B HEAD~1)" "0:SJ3 whole"
_ST_OUT_HAS "and names the reword putting it back on the landed commit" "^To put the body back under the new subject: git edit -M --text=.*git log -1 --format=%b [0-9a-f]\{12\})\" $(git rev-parse --short=12 HEAD~1)\$"
# Past the amend, at a replay's stop, it refuses naming itself
_ST_PZ_NEW sj4
git config rerere.enabled false
_ST_PZ_C f.txt 1 "SJ4 base" && _ST_PZ_C f.txt 2 "SJ4 target" && SJ_T=$(git rev-parse HEAD) && _ST_PZ_C f.txt 3 "SJ4 later"
_ST_RUN "$SJ_T"
SJ_WT=$(_ST_PZ_WT)
print -r -- X > "${SJ_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "an edit's replay stops at a conflict" "$RC" "2"
_ST_RUN --continue --subject=late
_ST_EQ "where --subject refuses" "$RC" "1"
_ST_OUT_HAS "as past the amend, naming the reword that takes it" '--subject takes effect at the amend, which is past – finish the edit, then reword: git edit -M --subject="…" <sha>'
_ST_RUN --abort

# Refusals, each with nothing moved
_ST_PZ_NEW sj5
_ST_PZ_C a.txt a "SJ5 base" && _ST_PZ_C b.txt b "SJ5 second" && _ST_PZ_C c.txt c "SJ5 top"
SJ_HEAD=$(git rev-parse HEAD)
_ST_RUN -M --subject="$(printf 'one\ntwo')" HEAD
_ST_EQ "a subject of two lines refuses" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming --text for a body" '--subject takes one line, and got several'
_ST_RUN -M --subject= HEAD
_ST_EQ "an empty one glued on refuses" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "as needing a subject" '--subject needs a subject'
_ST_RUN -M --subject "   " HEAD
_ST_EQ "as does one of spaces given apart" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_RUN -M --subject=x --text=y HEAD
_ST_EQ "beside --text it refuses" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming both" '--subject and --text cannot be combined'
print -r -- a2 > a.txt
_ST_RUN --commit --subject=x -- a.txt
_ST_EQ "--commit refuses it" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming --text" 'not --commit – nothing was done'
_ST_OUT_HAS "as the flag a new message takes" 'takes it whole as --text "…"'
git checkout -q -- a.txt
_ST_RUN --split=HEAD --subject=x -- c.txt
_ST_EQ "so does --split" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming it" 'not --split – nothing was done'
_ST_RUN -S --subject=x HEAD~1 HEAD
_ST_EQ "and -S" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming it too" 'not -S – nothing was done'
_ST_RUN --subject=x HEAD~1 HEAD
_ST_EQ "and an implicit squash" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming --text" 'a squash writes a new message, which takes it whole as --text'
_ST_RUN --subject=x HEAD~1
_ST_EQ "an edit's start refuses it" "$RC:$(git rev-parse HEAD):$([ -f .git/git-edit-state ] && echo paused)" "1:$SJ_HEAD:"
_ST_OUT_HAS "naming the continue that takes it" "Pass --subject with 'git edit --continue'"
_ST_RUN -M --subject=x HEAD~1 HEAD
_ST_EQ "-M with two commits refuses, as with --text" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_RUN -M --subject=x
_ST_EQ "with no commit it refuses" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "naming the reword with --subject" "Missing <commit> – name the commit to act on (e.g. 'git edit -M --subject=\"…\" "
_ST_RUN -M --subject=a --subject=b HEAD
_ST_EQ "given twice it refuses" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "as taking one" '--subject given twice – it takes one subject'
_ST_RUN -M --subjectx HEAD
_ST_EQ "a word running on past its name is unknown" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "as an option" 'Unknown option: --subjectx'
_ST_RUN -M --subject -d HEAD
_ST_EQ "a flag given as its value refuses" "$RC:$(git rev-parse HEAD)" "1:$SJ_HEAD"
_ST_OUT_HAS "as the value gone missing" '--subject takes a value, and got the flag -d'
# A split's pause writes a new message on its continue, which --subject refuses, naming --text
_ST_RUN --split=HEAD
_ST_EQ "a content split pauses" "$RC" "2"
_ST_RUN --continue --subject=x
_ST_EQ "its continue refuses --subject, the pause kept" "$RC:$([ -f .git/git-edit-state ] && echo paused)" "1:paused"
_ST_OUT_HAS "naming --text" "a split's continue writes the extracted commit's message whole, as --text"
_ST_RUN --abort
_ST_EQ "and nothing moved" "$(git rev-parse HEAD)" "$SJ_HEAD"
cd "$TMP/repo"
