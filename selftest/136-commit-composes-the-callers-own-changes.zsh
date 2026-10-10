# A commit composed from the caller's own changes alone – replacements replayed onto the tip's
# text, files put, patches applied, paths removed – in a private index, so a peer's line in the
# same checkout file and a peer's staging beside it never come along
_ST_SCENARIO "\e[1;96m[136] a commit composes the caller's own changes, a peer's beside them left out\e[0m"
local IN_T IN_B IN_O IN_P
_ST_PZ_NEW in1
printf 'a\nb\nc\nd\ne\n' > app.js && chmod +x app.js
print -r -- x > other.txt && print -r -- gone > del.txt && git add -A && git commit -qm "IN base"
IN_B=$(git rev-parse HEAD)
printf 'a\nMINE\nc\nd\nPEER-WIP\n' > app.js
print -r -- "peer staged" > other.txt && git add other.txt
print -r -- "new file" > "$TMP/in-new.txt"
_ST_RUN --commit --text $'IN hoist `x` into \'y\'\n\nBody with `ticks`' --edits '{"app.js": [["a\nb\n", "a\nMINE\n"]]}' \
	--put new.txt="$TMP/in-new.txt" --rm del.txt --base="$IN_B"
_ST_EQ "only my line reaches the commit" "${RC}:$(git show HEAD:app.js | tr '\n' ' ')" "0:a MINE c d e "
_ST_EQ "its executable bit kept" "$(git ls-tree HEAD app.js | cut -c1-6)" "100755"
_ST_EQ "a put file lands, a removed one goes" "$(git show HEAD:new.txt):$(git cat-file -e HEAD:del.txt 2>/dev/null && echo kept)" "new file:"
_ST_EQ "the message as given" "$(git log -1 --format=%B)" $'IN hoist `x` into \'y\'\n\nBody with `ticks`'
_ST_EQ "the peer's line stays in the checkout, its staging staged" "$(git diff HEAD -- app.js | grep -c '^+PEER-WIP'):$(git show :other.txt)" "1:peer staged"
_ST_EQ "my stranded index entry re-synced" "$(git diff --cached --name-only -- app.js)" ""
_ST_EQ "journaled as a commit, which --carry sets aside" "$(git reflog -1 --format=%gs main)" "git edit: commit"
# Refusals, each before anything lands
IN_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "IN dup" --edits '{"app.js": [["\n", "X"]]}'
_ST_EQ "an old text matching several times refuses" "${RC}:$(git rev-parse HEAD)" "1:$IN_T"
_ST_OUT_HAS "counting them" 'app.js: 5 matches for edit 1'
_ST_RUN --commit --text "IN gone" --edits '{"app.js": [["PEER-WIP", "x"]]}'
_ST_OUT_HAS "one matching nowhere refuses, a peer's line the likely cause" 'no match for edit 1 .* a peer.s line sits inside it'
_ST_RUN --commit --text "IN empty" --edits '{"app.js": [["", "x"]]}'
_ST_OUT_HAS "an empty old text refuses" 'empty old text, which matches everywhere'
_ST_RUN --commit --text "IN absent" --edits '{"nope.txt": [["a", "b"]]}'
_ST_OUT_HAS "an edit to a file the tip lacks points at --put" 'nope.txt: not a file at the tip – --put it if it is new'
_ST_RUN --commit --text "IN noop" --edits '{"app.js": [["MINE", "MINE"]]}'
_ST_OUT_HAS "a no-op refuses" 'Nothing to commit – every input left the tree as it was'
_ST_RUN --commit --text "IN missing" --edits "$TMP/no-such.json"
_ST_OUT_HAS "a missing input refuses" 'no such file, nor inline JSON'
_ST_RUN --commit --text "IN bad" --edits '{"app.js": [["a"]]}'
_ST_OUT_HAS "JSON of another shape refuses, saying where" "',' expected where ']' stands"
_ST_RUN --commit --text "IN both" --edits '{"app.js": [["a", "b"]]}' -- app.js
_ST_OUT_HAS "a file taken whole and edited at once refuses" 'named after -- to take whole, and by --edits too'
_ST_RUN -M --text "IN x" --edits '{"app.js": [["a", "b"]]}' HEAD
_ST_OUT_HAS "inputs on another mode refuse" 'only apply to --commit and --amend-into'
_ST_EQ "no refusal moved the branch" "$(git rev-parse HEAD)" "$IN_T"
# A patch applies with its context, from the top, a mode line refused unless --chmod names it
print -r -- $'a\nMINE\nc\nDELTA\nPEER-WIP' > app.js
git diff -- app.js | sed '/^-e$/d;/^+PEER-WIP$/s/^+PEER-WIP$/ e/' > "$TMP/in.patch"
_ST_RUN --commit --text "IN patch" --patch "$TMP/in.patch"
_ST_EQ "a patch lands, the peer's line left out" "${RC}:$(git show HEAD:app.js | tr '\n' ' ')" "0:a MINE c DELTA e "
_ST_RUN --commit --text "IN patch again" --patch "$TMP/in.patch"
_ST_OUT_HAS "one that no longer applies refuses" 'does not apply to the tip'
chmod -x app.js && git diff -- app.js > "$TMP/in-mode.patch" && chmod +x app.js
_ST_RUN --commit --text "IN flip" --patch "$TMP/in-mode.patch"
_ST_OUT_HAS "a patch's mode line refuses where --chmod names no flip" 'mode change outside --chmod rides along: app.js'
_ST_RUN --commit --text "IN flip named" --patch "$TMP/in-mode.patch" --chmod app.js=-x
_ST_EQ "and lands where it does" "${RC}:$(git ls-tree HEAD app.js | cut -c1-6)" "0:100644"
_ST_RUN --commit --text "IN back" --chmod app.js=+x --chmod app.js=+x
_ST_EQ "--chmod sets a bit as chmod does, said twice or not" "${RC}:$(git ls-tree HEAD app.js | cut -c1-6)" "0:100755"
_ST_RUN --commit --text "IN redundant" --chmod app.js=+x
_ST_OUT_HAS "alone, a chmod to the mode it has refuses as a no-op" 'Nothing to commit'
_ST_RUN --commit --text "IN nothing" --chmod nope.sh=+x
_ST_OUT_HAS "a chmod on a path the tip lacks refuses" 'nope.sh: not a file in the commit'
# Paths read from where the caller stands, a same-named root file catching a root-relative reading
mkdir -p sub && print -r -- inner > sub/same.txt && print -r -- root > same.txt && print -r -- g > sub/gone.txt
git add sub same.txt && git commit -qm "IN sub"
IN_B=$(git rev-parse HEAD)
print -r -- "new inside sub" > "$TMP/in-sub-new.txt"
cd sub
_ST_RUN --commit --text "IN from sub" --edits '{"same.txt": [["inner", "INNER"]]}' --put added.txt="$TMP/in-sub-new.txt" --rm gone.txt --base="$IN_B"
cd ..
_ST_EQ "paths from a subdirectory resolve there" "${RC}:$(git show HEAD:sub/same.txt):$(git show HEAD:same.txt)" "0:INNER:root"
_ST_EQ "a put and a removal too" "$(git show HEAD:sub/added.txt):$(git cat-file -e HEAD:sub/gone.txt 2>/dev/null && echo kept)" "new inside sub:"
# An editor names files by absolute path, which reads as any other
_ST_RUN --commit --text "IN absolute" --edits "{\"$TMP/pz-in1/sub/same.txt\": [[\"INNER\", \"INNER, absolute\"]]}"
_ST_EQ "an absolute path in --edits takes its file" "$RC:$(git show HEAD:sub/same.txt)" "0:INNER, absolute"
# A new path takes the mode `git add` gives the checkout's file – the source's where it has none
print -r -- '#!/bin/sh' > tool.sh && chmod +x tool.sh && cp tool.sh "$TMP/in-tool.sh" && chmod -x "$TMP/in-tool.sh"
_ST_RUN --commit --text "IN tool" --put tool.sh="$TMP/in-tool.sh"
_ST_EQ "a new path takes the checkout's executable bit over the source's" "${RC}:$(git ls-tree HEAD tool.sh | cut -c1-6)" "0:100755"
git config core.fileMode false
print -r -- plain > plain.sh && chmod +x plain.sh
_ST_RUN --commit --text "IN plain" --put plain.sh=plain.sh --put other2.txt="$TMP/in-new.txt"
_ST_EQ "under core.fileMode false a new path is 100644, as git add makes it" "${RC}:$(git ls-tree HEAD plain.sh | cut -c1-6)" "0:100644"
_ST_RUN --commit --text "IN plain x" --chmod plain.sh=+x
_ST_EQ "and --chmod still sets the bit" "${RC}:$(git ls-tree HEAD plain.sh | cut -c1-6)" "0:100755"
git config --unset core.fileMode
# A put of the checkout's own file onto its path alone is a whole-file commit, named as one
print -r -- whole > whole.txt && git add whole.txt && git commit -qm "IN whole" && print -r -- "whole, edited" > whole.txt
_ST_RUN --commit --text "IN whole put" --put whole.txt=whole.txt --base="$(git rev-parse HEAD)"
_ST_OUT_HAS "puts of checkout files onto themselves alone refuse, naming the whole-file form" 'take them whole.*git edit --commit --text "…" -- whole.txt'
_ST_RUN --commit --text "IN whole beside" --put whole.txt=whole.txt --base="$(git rev-parse HEAD)" --edits '{"same.txt": [["root", "root, beside"]]}'
_ST_EQ "beside another input it lands" "${RC}:$(git show HEAD:whole.txt)" "0:whole, edited"
# Escapes reach the file as the JSON spells them – quotes, backslashes, tabs, non-ASCII, surrogates
print -r -- $'say "hi"\\there\ttab é 😀\nend' > esc.txt && git add esc.txt && git commit -qm "IN esc"
_ST_RUN --commit --text "IN esc edit" --edits '{"esc.txt": [["say \"hi\"\\there\ttab \u00e9 \ud83d\ude00\n", "SAID\\\n\u4e2d\n"]]}'
_ST_EQ "escapes decode to the bytes the file holds" "${RC}:$(git show HEAD:esc.txt | od -An -tx1 | tr -d ' \n')" "0:$(print -rn -- $'SAID\\\n中\nend\n' | od -An -tx1 | tr -d ' \n')"
# A file in another encoding takes an ASCII edit byte for byte
print -rn -- $'caf\xe9 old\n' > latin.txt && git add latin.txt && git commit -qm "IN latin"
_ST_RUN --commit --text "IN latin edit" --edits '{"latin.txt": [["old", "new"]]}'
_ST_EQ "a non-UTF-8 file's other bytes stay as they were" "${RC}:$(git show HEAD:latin.txt | od -An -tx1 | tr -d ' \n')" "0:636166e9206e65770a"
# Where python3 is at hand, its JSON reading of random texts and the parser's agree
if command -v python3 >/dev/null 2>&1; then
	python3 -c '
import json, random, sys
random.seed(136)
pool = "ab \"\\/\n\t\r\b\f é漢😀\u2028\x01\x1f}{[],:"
texts = ["<%d>" % i + "".join(random.choice(pool) for _ in range(random.randint(1, 12))) + "</%d>" % i for i in range(40)]
open(sys.argv[1], "w", encoding="utf-8").write("".join(t + "\n<<>>\n" for t in texts))
edits = [[t, t.upper() + "!"] for t in texts]
open(sys.argv[2], "w", encoding="utf-8").write(json.dumps({"fuzz.txt": edits}, ensure_ascii=bool(random.getrandbits(1))))
open(sys.argv[3], "w", encoding="utf-8").write("".join(t.upper() + "!" + "\n<<>>\n" for t in texts))
' "$TMP/fuzz.txt" "$TMP/fuzz.json" "$TMP/fuzz.want"
	cp "$TMP/fuzz.txt" fuzz.txt && git add fuzz.txt && git commit -qm "IN fuzz"
	_ST_RUN --commit --text "IN fuzz edit" --edits "$TMP/fuzz.json"
	_ST_EQ "random texts replay as python3's JSON reads them" "${RC}:$(git show HEAD:fuzz.txt | cksum)" "0:$(cksum < "$TMP/fuzz.want")"
fi
# A directory is no file to put, edit, chmod or remove – its files a pathspec would name instead
mkdir -p dir && print -r -- a > dir/x && git add dir && git commit -qm "IN dir"
IN_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "IN dir rm" --rm dir --base="$IN_T"
_ST_OUT_HAS "a removal of a directory refuses" 'rm dir: a directory at the tip – name its files'
_ST_RUN --commit --text "IN dir chmod" --chmod dir=+x
_ST_OUT_HAS "as does a chmod of it" 'chmod dir: not a file in the commit'
_ST_RUN --commit --text "IN dir edit" --edits '{"dir": [["a", "b"]]}'
_ST_OUT_HAS "an edit of it" 'edits dir: not a file at the tip'
_ST_RUN --commit --text "IN dir put" --put dir="$TMP/in-new.txt" --base="$IN_T"
_ST_OUT_HAS "and a put onto it, or under a file" 'put dir: a directory, or a file where one should be, stands in its way'
_ST_EQ "none of them moving the branch" "$(git rev-parse HEAD)" "$IN_T"
# Escaped control characters stay themselves, and a large replacement takes as long as a small one
python3 -c 'import json, sys; t = "".join("line %d \"q\" \u0001\u0002\n" % i for i in range(3000)); open(sys.argv[1], "w").write(t); json.dump({"big.txt": [[t, t.replace("q", "Q")]]}, open(sys.argv[2], "w")); open(sys.argv[3], "w").write(t.replace("q", "Q"))' \
	big.txt "$TMP/in-big.json" "$TMP/in-big.want" 2>/dev/null && git add big.txt && git commit -qm "IN big" && \
	_ST_RUN --commit --text "IN big edit" --edits "$TMP/in-big.json" && \
	_ST_EQ "a replacement of 3000 lines with escaped quotes and controls lands byte for byte" "$RC:$(git show HEAD:big.txt | cksum)" "0:$(cksum < "$TMP/in-big.want")"
# A bare word where a string belongs is no JSON, and would shift which text is old and which new
IN_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "IN bare" --edits '{"same.txt": [[S, "root"]]}'
_ST_EQ "a value outside quotes refuses" "$RC:$(git rev-parse HEAD)" "1:$IN_T"
_ST_OUT_HAS "saying so" 'a value outside quotes'
# A submodule takes no put, and mid-merge the inputs refuse as whole files do
git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),gitlink" && git commit -qm "IN gitlink"
_ST_RUN --commit --text "IN gitlink put" --put gitlink="$TMP/in-new.txt" --base="$(git rev-parse HEAD)"
_ST_OUT_HAS "a put onto a submodule refuses" 'put gitlink: a submodule at the tip'
git rm -q --cached gitlink && git commit -qm "IN gitlink gone"
print -r -- "$(git rev-parse HEAD)" > "$(git rev-parse --git-path MERGE_HEAD)"
_ST_RUN --commit --text "IN mid-merge" --edits '{"same.txt": [["root", "root, mid-merge"]]}'
_ST_OUT_HAS "mid-merge the inputs refuse" 'A merge is in progress – finish it with git commit'
rm -f "$(git rev-parse --git-path MERGE_HEAD)"
# A tree composed elsewhere lands as a commit, pinned to the tip it rests on
IN_T=$(git rev-parse HEAD)
IN_O=$(_ST_COMPOSE same.txt "composed")
_ST_RUN --commit --text "IN tree" --tree="$IN_O"
_ST_EQ "--commit --tree lands a commit composed on the tip" "${RC}:$(git show HEAD:same.txt):$(git rev-parse HEAD~1)" "0:composed:$IN_T"
_ST_RUN --commit --text "IN tree stale" --tree="$IN_O"
_ST_OUT_HAS "one composed on another tip refuses" 'takes a commit composed on the tip'
# Inputs land beside an anchor as whole files do
IN_P=$(git rev-parse HEAD~2)
print -r -- placed > "$TMP/in-placed.txt"
_ST_RUN --commit --text "IN placed" --put placed.txt="$TMP/in-placed.txt" --after="$IN_P"
_ST_EQ "and place beside an anchor" "${RC}:$(git log -3 --format=%s | tail -1)" "0:IN placed"
git checkout -q -- . 2>/dev/null
# A peer's staging on a path the inputs change stays staged, as they never read the checkout
_ST_PZ_NEW in2
_ST_PZ_C f.txt $'1\n2\n3' "IN2 base"
print -r -- $'1\n2\nPEER' > f.txt && git add f.txt
print -r -- $'1\n2\nPEER 2' > f.txt
_ST_RUN --commit --text "IN2 mine" --edits '{"f.txt": [["1\n", "MINE\n"]]}'
_ST_EQ "a peer's staging on a path an edit changes stays staged" "${RC}:$(git show HEAD:f.txt | tr '\n' ' '):$(git show :f.txt | tr '\n' ' ')" "0:MINE 2 3 :1 2 PEER "
_ST_OUT_HAS "named as left alone" 'Left as they were.*: f.txt'
IN_O=$(_ST_COMPOSE f.txt $'MINE\n2\n3\n4')
_ST_RUN --commit --text "IN2 tree" --tree="$IN_O"
_ST_EQ "as on a path a composed tree changes" "${RC}:$(git show :f.txt | tr '\n' ' ')" "0:1 2 PEER "
cd "$TMP/repo"
