# The inputs take each path as `git add` would take the file – a link as a link, attributes read
# for the path wherever the caller stands – and a value as given, its every way to mislead refused
_ST_SCENARIO "\e[1;96m[138] inputs take each path as git add would, and each value as given\e[0m"
local IG_T IG_B
_ST_PZ_NEW ig1
print -r -- data > real.txt && ln -s real.txt link && mkdir sub && print -r -- '/x.txt text' > sub/.gitattributes
printf 'one\ntwo\n' > sub/x.txt && print -r -- g > g && print -r -- eq > '=g' && print -r -- '}' > brace.txt
printf 'f() {\n}\n}\n}\n' > nest.js
git add -A && git commit -qm "IG base"
IG_B=$(git rev-parse HEAD)
# An old text overlapping itself matches twice, not once
_ST_RUN --commit --text "IG overlap" --edits '{"nest.js": [["}\n}\n", "} // end\n"]]}'
_ST_EQ "an old text occurring twice, overlapping, refuses" "${RC}:$(git rev-parse HEAD)" "1:$IG_B"
_ST_OUT_HAS "counting both" '2 matches for edit 1'
# A put onto a link lands a file, never the file's content as the link's target
print -r -- 'key = value' > "$TMP/ig-conf"
_ST_RUN --commit --text "IG onto link" --put link="$TMP/ig-conf"
_ST_EQ "a file put onto a link refuses as a type change" "${RC}:$(git rev-parse HEAD)" "1:$IG_B"
_ST_OUT_HAS "naming it as one" 'A link becomes a file, or a file a link: link'
_ST_RUN --commit --text "IG onto link" --allow-mode-change --put link="$TMP/ig-conf"
_ST_EQ "and lands a file where that is meant" "${RC}:$(git ls-tree HEAD link | cut -c1-6):$(git show HEAD:link)" "0:100644:key = value"
git reset -q --hard "$IG_B"
# A link put onto a link stays one, as `git add` stages it – elsewhere its content is read through
ln -s g "$TMP/ig-link"
_ST_RUN --commit --text "IG link" --put link="$TMP/ig-link"
_ST_EQ "a link put onto a link lands as a link to its own target" "${RC}:$(git ls-tree HEAD link | cut -c1-6):$(git cat-file -p HEAD:link)" "0:120000:g"
ln -s "$TMP/ig-conf" "$TMP/ig-link2"
_ST_RUN --commit --text "IG link content" --put real.txt="$TMP/ig-link2"
_ST_EQ "and onto a file its content, the tip's mode kept" "${RC}:$(git ls-tree HEAD real.txt | cut -c1-6):$(git show HEAD:real.txt)" "0:100644:key = value"
ln -s "$TMP/ig-none" "$TMP/ig-link3"
_ST_RUN --commit --text "IG dangling" --put real.txt="$TMP/ig-link3"
_ST_OUT_HAS "a link to no file put onto a file refuses" 'is a link to no file'
git reset -q --hard "$IG_B"
# The path's own attributes apply from a subdirectory as from the top
printf 'one\r\ntwo\r\n' > "$TMP/ig-crlf.txt"
cd sub
_ST_RUN --commit --text "IG from sub" --put x.txt="$TMP/ig-crlf.txt" --edits '{"x.txt": [["one\n", "ONE\n"]]}'
cd ..
_ST_EQ "a put from a subdirectory lands normalized by that path's attributes, an edit after it on that" \
	"${RC}:$(git show HEAD:sub/x.txt | od -An -c | tr -d ' \n')" '0:ONE\ntwo\n'
_ST_RUN --commit --text "IG crlf old" --edits $'{"sub/x.txt": [["ONE\\r\\n", "one\\r\\n"]]}'
_ST_OUT_HAS "an old text with CRLF on an LF-stored file says why it misses" 'stores the file with LF line ends'
_ST_RUN --commit --text "IG crlf new" --edits $'{"sub/x.txt": [["ONE\\n", "one\\r\\n"]]}'
_ST_EQ "a CRLF new text is normalized as git add would" "${RC}:$(git show HEAD:sub/x.txt | od -An -c | tr -d ' \n')" '0:one\ntwo\n'
IG_T=$(git rev-parse HEAD)
# A path named twice refuses, as either would silently win
print -r -- one > "$TMP/ig-1" && print -r -- two > "$TMP/ig-2"
_ST_RUN --commit --text "IG twice" --put g="$TMP/ig-1" --put g="$TMP/ig-2"
_ST_OUT_HAS "a path put twice refuses" '--put g: named twice'
_ST_RUN --commit --text "IG put rm" --put g="$TMP/ig-1" --rm g
_ST_OUT_HAS "as does one both put and removed" '--rm g: also named by another input'
_ST_RUN --commit --text "IG edit rm" --edits '{"brace.txt": [["}", "{"]]}' --rm brace.txt
_ST_OUT_HAS "or both edited and removed" '--rm brace.txt: also named by another input'
_ST_EQ "nothing landing either time" "$(git rev-parse HEAD)" "$IG_T"
# A path holding `=` splits where the rest names a file
print -r -- 'a=b' > 'a=b.txt' && git add 'a=b.txt' && git commit -qm "IG eq path"
_ST_RUN --commit --text "IG eq put" --put "a=b.txt=$TMP/ig-1"
_ST_EQ "a path holding = is put" "${RC}:$(git show 'HEAD:a=b.txt')" "0:one"
# A value given apart keeps a leading `=` – only the glued form's is zparseopts' own
_ST_RUN --commit --text "IG rm eq" --rm '=g'
_ST_EQ "--rm '=g' given apart removes =g, not g" "${RC}:$(git ls-tree --name-only HEAD -- g '=g' | tr '\n' ' ')" "0:g "
_ST_RUN --commit --text "IG rm glued" --rm=g
_ST_EQ "and --rm=g removes g" "${RC}:$(git ls-tree --name-only HEAD -- g | wc -l | tr -d ' ')" "0:0"
# A mode flip on a name git quotes is named by --chmod as on any other
print -r -- s > 'q"b.sh' && git add 'q"b.sh' && git commit -qm "IG quoted"
_ST_RUN --commit --text "IG chmod quoted" --chmod 'q"b.sh=+x'
_ST_EQ "--chmod takes a name holding a quote" "${RC}:$(git ls-tree HEAD 'q"b.sh' | cut -c1-6)" "0:100755"
# The edits file: a raw NUL refuses, a pipe reads, a missing file named like JSON is no JSON
printf '{"brace.txt": [["}\0", "x"]]}' > "$TMP/ig-nul.json"
_ST_RUN --commit --text "IG nul" --edits "$TMP/ig-nul.json"
_ST_OUT_HAS "a raw NUL in an edits file refuses" 'a raw control character'
IG_T=$(git rev-parse HEAD)
OUT=$(print -r -- '{"brace.txt": [["}", "{"]]}' | GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "IG pipe" --edits /dev/stdin 2>&1)
_ST_EQ "an edits file read from a pipe lands" "$(git show HEAD:brace.txt):$(git log -1 --format=%s)" "{:IG pipe"
_ST_RUN --commit --text "IG missing" --edits '{x}.json'
_ST_OUT_HAS "a missing file named like JSON is named as missing" 'no such file, nor inline JSON'
_ST_RUN --commit --text "IG shape" --edits '{"brace.txt" "x"}'
_ST_OUT_HAS "a shape error names a string as one" "':' expected where a string stands"
# A --base beside edits alone guards their paths as it does a put's
_ST_RUN --commit --text "IG base" --base="$IG_B" --edits '{"brace.txt": [["{", "}"]]}'
_ST_OUT_HAS "--base beside edits alone refuses a path changed since" 'so changed by --edits they would take that back: brace.txt'
# An intent-to-add entry on a path the landing adds stages nothing, so is re-synced rather than
# left to read as a staged removal of what landed
_ST_PZ_NEW ig2
_ST_PZ_C a.txt a "IG2 base" && _ST_PZ_C b.txt b "IG2 b"
IG_B=$(git rev-parse HEAD)
print -r -- new > new.txt && git add -N new.txt && print -r -- new > "$TMP/ig2-src"
_ST_RUN --commit --text "IG2 new" --put new.txt="$TMP/ig2-src"
_ST_EQ "an intent-to-add entry where the landing adds the file is re-synced" "${RC}:$(git status --porcelain -- new.txt)" "0:"
git rm -q --cached a.txt
_ST_RUN --commit --text "IG2 edit a" --edits '{"a.txt": [["a", "A"]]}'
_ST_EQ "while a staged removal of a path the inputs edit stays staged" "${RC}:$(git diff --cached --name-status -- a.txt | cut -c1)" "0:D"
git reset -q -- a.txt
# A bare tree's fold takes --base, a peer's change since refusing
IG_T=$(GIT_INDEX_FILE="$TMP/ig2-idx" sh -c 'git read-tree "$1" && git update-index --cacheinfo "100644,$(echo b-mine | git hash-object -w --stdin),b.txt" && git write-tree' _ "$IG_B")
rm -f "$TMP/ig2-idx"
print -r -- b-peer > b.txt && git commit -qam "IG2 peer b"
_ST_RUN --amend-into="$(git rev-parse HEAD)" --tree="$IG_T" --base="$IG_B"
_ST_OUT_HAS "--base beside a bare tree's fold still guards it" 'folded from --tree they would take that back'
IG_T=$(_ST_COMPOSE b.txt b-composed)
_ST_RUN --commit --text "IG2 tree base" --tree="$IG_T" --base="$IG_B"
_ST_OUT_HAS "while beside a commit composed on the tip it refuses" 'a --tree commit composed on the tip applies to the tip itself'
# A type change refuses whatever --chmod names, every unnamed flip beside it named too
ln -s a.txt lnk && git add lnk && git commit -qm "IG2 link"
_ST_RUN --commit --text "IG2 typed" --put lnk="$TMP/ig2-src" --chmod lnk=+x
_ST_EQ "a --chmod on a link turned file still refuses the type change" "${RC}:$(git ls-tree HEAD lnk | cut -c1-6)" "1:120000"
# Line ends named either way an old text misses by them
printf 'one\r\ntwo\r\n' > w.txt && git add w.txt && git commit -qm "IG2 crlf"
_ST_RUN --commit --text "IG2 lf old" --edits '{"w.txt": [["one\n", "ONE\n"]]}'
_ST_OUT_HAS "an LF old text on a file stored with CRLF says why it misses" 'stores the file with CRLF line ends'
# A file stored with CRLF before its attributes asked for LF keeps its line ends through an edit
print -r -- 'w.txt text' > .gitattributes && git add .gitattributes && git commit -qm "IG2 attrs"
_ST_RUN --commit --text "IG2 crlf kept" --edits $'{"w.txt": [["one\\r\\n", "ONE\\r\\n"]]}'
_ST_EQ "a file stored before its attributes keeps its line ends" "${RC}:$(git show HEAD:w.txt | od -An -c | tr -d ' \n')" '0:ONE\r\ntwo\r\n'
# A value stuck to its flag is an unknown option, one after `=` or given apart the value – a removal
# and an edit of one path refuse
print -r -- f > foo && print -r -- e > '=bar' && git add -A && git commit -qm "IG2 stuck"
_ST_RUN --commit --text "IG2 stuck rm" --rmfoo --rm '=bar'
_ST_OUT_HAS "--rmfoo is an unknown option" 'Unknown option: --rmfoo'
_ST_RUN --commit --text "IG2 stuck rm" --rm=foo --rm '=bar'
_ST_EQ "--rm=foo and --rm '=bar' remove foo and =bar" "${RC}:$(git ls-tree --name-only HEAD -- foo '=bar' | wc -l | tr -d ' ')" "0:0"
# Removing a file another caller's recent run edited takes that edit back – refused, --base the way
print -r -- 'peer line' > "$TMP/ig2-peer"
GIT_EDIT_ACTOR=ig-peer _ST_RUN --commit --text "IG2 peer edits b" --put b.txt="$TMP/ig2-peer"
IG_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=ig-me _ST_RUN --commit --text "IG2 rm b" --rm b.txt
_ST_EQ "removing a file another caller just edited refuses" "${RC}:$(git rev-parse HEAD)" "1:$IG_T"
_ST_OUT_HAS "naming the edit it would take back" 'which edited it – removing the file takes that edit back'
rm b.txt
GIT_EDIT_ACTOR=ig-me _ST_RUN --commit --text "IG2 rm b whole" -- b.txt
_ST_EQ "as does removing it whole from the checkout" "${RC}:$(git rev-parse HEAD)" "1:$IG_T"
git checkout -q -- b.txt
GIT_EDIT_ACTOR=ig-me _ST_RUN --commit --text "IG2 rm b meant" --rm b.txt --base="$IG_T"
_ST_EQ "while --base the removal rests on lands it" "${RC}:$(git ls-tree --name-only HEAD -- b.txt)" "0:"
_ST_RUN --commit --edits --text "IG2 lost value"
_ST_OUT_HAS "an input whose value given apart is a flag names the flag it swallowed" '--edits takes a value, and got the flag --text'
mkdir -p "$TMP/ig2-dir"
_ST_RUN --commit --text "IG2 dir" --put d.txt="$TMP/ig2-dir"
_ST_OUT_HAS "a directory as a put's source is named as one" 'is a directory'
# Every flag taking a value names one it swallowed, short ones included
_ST_RUN --commit --text --whole -- a.txt
_ST_OUT_HAS "--text given the next flag as its value names it" '--text takes a value, and got the flag --whole'
_ST_RUN --amend-into -y -- a.txt
_ST_OUT_HAS "as does --amend-into given a short one" '--amend-into takes a value, and got the flag -y'
# A path new to the tip in another case than one it holds refuses where the filesystem ignores case
_ST_PZ_C cs.txt cs "IG2 cs"
IG_T=$(git rev-parse HEAD)
git config core.ignorecase true
print -r -- 'cased' > "$TMP/ig2-cased"
_ST_RUN --commit --text "IG2 cased" --put CS.txt="$TMP/ig2-cased"
_ST_EQ "a put spelling a tip path in another case refuses" "${RC}:$(git rev-parse HEAD)" "1:$IG_T"
_ST_OUT_HAS "naming the tip's spelling" "CS.txt differs from the tip's cs.txt only in case"
_ST_RUN --commit --text "IG2 two" --put Zq.txt="$TMP/ig2-cased" --put ZQ.txt="$TMP/ig2-cased"
_ST_OUT_HAS "as do two new ones differing only in case" 'ZQ.txt and Zq.txt differ only in case'
git config core.ignorecase false
_ST_RUN --commit --text "IG2 cased" --put CS.txt="$TMP/ig2-cased"
_ST_EQ "while a case-sensitive one takes it as the new path it is" "${RC}:$(git ls-tree --name-only HEAD | grep -ci '^cs.txt$')" "0:2"
# A decomposed name, as macOS hands one over, is the composed path the tip holds
if [ "$(print -rn -- $'ü' | iconv -f UTF-8-MAC -t UTF-8 2>/dev/null)" = $'ü' ]; then
	_ST_PZ_C $'ü.txt' u "IG2 umlaut"
	git config core.precomposeUnicode true
	_ST_RUN --commit --text "IG2 umlaut put" --put $'ü.txt'="$TMP/ig2-cased"
	git config core.precomposeUnicode false
	_ST_EQ "a decomposed put name replaces the composed file" "${RC}:$(git ls-tree --name-only -z HEAD | tr '\0' '\n' | grep -c '\.txt$'):$(git show HEAD:$'ü.txt')" "0:$(git ls-tree --name-only -z HEAD~1 | tr '\0' '\n' | grep -c '\.txt$'):cased"
fi
cd "$TMP/repo"
