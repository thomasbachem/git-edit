# A fold's or squash's replacement follows its lines to the stop through each commit's own
# change, never one diff across them, which pairs a line with text a later commit wrote anew
# – a given text its line only through a run of as many lines – so each such stop pauses
_ST_SCENARIO "\e[1;96m[261] a replacement follows its lines through each commit's own change\e[0m"
local LF_A LF_F LF_OLD LF_T LF_C
# Commits a line, one moving the lines after it, then one writing
# its text anew further down and dropping it – sets `LF_A`
_LF_REWRITTEN () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l foo k26 k17 t k5 > f && git add f && git commit -qm "LF target"
	LF_A=$(git rev-parse HEAD)
	print -l foo k26 k11 t k5 k17 > f && git commit -qam "LF moves"
	print -l k26 k11 foo k5 k17 > f && git commit -qam "LF writes anew"
}
_LF_REWRITTEN lf-fold
print -l k26 k11 FOO k5 k17 > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "a fold of the line written anew pauses at the target" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U):$(git show "$LF_A:f" | tr '\n' '|')" "2:f:foo|k26|k17|t|k5|"
_ST_RUN --abort
_LF_REWRITTEN lf-squash
print -l k26 k11 FOO k5 k17 > f && git commit -qam "fixup! LF target"
_ST_RUN -s=auto HEAD
_ST_EQ "as does a squash of it" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# Changed words a later commit's line holds anew, its own rewritten
_ST_PZ_NEW lf-words
print -l head "b X c m n" tail > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l head "b Z c m n b X c" tail > f && git commit -qam "LF rewrites"
print -l head "m2 n b X c" tail > f && git commit -qam "LF drops"
print -l head "m2 n b Y c" tail > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "changed words a later commit wrote anew pause" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# A given text on a line a run of other length rewrote
_ST_PZ_NEW lf-given
print -l head s=1 "x=baz(1)" "y=foo(1)" w=1 z=0 tail > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l head s=1 "x=baz(1)" "y=foo(1)" w=1 tail > f && git commit -qam "LF drops"
print -l head s=2 "x=foo(1)" "y=bar(2)" w=2 tail > f && git commit -qam "LF rewrites"
_ST_RUN --amend-into="$LF_A" --edits '{"f": [["foo(1)", "foo(10)"]]}'
_ST_EQ "a given text on another line than it was read from pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW lf-uneven
print -l head s=1 "x=foo(1) a" tail > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l head s=2 t=2 "x=foo(1) b" tail > f && git commit -qam "LF rewrites a run longer"
_ST_PZ_C g g1 "LF beside"
_ST_RUN --amend-into="$LF_A" --edits '{"f": [["foo(1)", "foo(10)"]]}'
_ST_EQ "as does one through a run of other length" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# Given texts holding pattern characters match as written, each on its own line
# – never a decoy a pattern would match first – two on one line in turn
_ST_PZ_NEW lf-literal
print -l xyz2 "xa2 f1 ab x #h" top "a x*2 b" "c f(1) d" "e x?2 f" "g [x] h" "i (a|b) j" "k #h ^k l" bottom > f
git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l xyz2 "xa2 f1 ab x #h" TOP "a x*2 b" "c f(1) d" "e x?2 f" "g [x] h" "i (a|b) j" "k #h ^k l" BOTTOM > f
git commit -qam "LF rewrites beside them"
_ST_PZ_C g g1 "LF beside"
_ST_RUN --amend-into="$LF_A" --edits '{"f": [["x*2", "X*2"], ["f(1)", "F(1)"], ["x?2", "X?2"], ["[x]", "[X]"], ["(a|b)", "(A|B)"], ["k #h", "k #H"], ["^k", "^K"]]}'
_ST_EQ "texts holding *, ?, [x], (a|b), # and ^ resolve as written" \
	"$RC:$(git show HEAD~2:f | tr '\n' '|'):$(git show HEAD~1:f | tr '\n' '|')" \
	"0:xyz2|xa2 f1 ab x #h|top|a X*2 b|c F(1) d|e X?2 f|g [X] h|i (A|B) j|k #H ^K l|bottom|:xyz2|xa2 f1 ab x #h|TOP|a X*2 b|c F(1) d|e X?2 f|g [X] h|i (A|B) j|k #H ^K l|BOTTOM|"

# Pausing exactly where another line of its text beside a commit's change could pair with it
# – a run added beside it, or words removed beside them – and resolving everywhere else
_ST_PZ_NEW lf-pairs
print -l 1 a z > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l 1 a b a z > f && git commit -qam "LF inserts beside it"
_ST_PZ_C g g1 "LF beside"
print -l X A b a z > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "a fold beside a run ending in its line's text pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW lf-pairs-words
print -l head "p b X c X c q" m tail > f && git add f && git commit -qm "LF before"
print -l head "p b X c X c q" m2 tail > f && git commit -qam "LF target"
LF_A=$(git rev-parse HEAD)
print -l head "p b X c q" m2 tail > f && git commit -qam "LF drops words"
print -l head "p b Y c q" m2 tail > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "as do changed words beside words removed holding them" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW lf-unique
print -l a foo bar b > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l a b bar > f && git commit -qam "LF moves"
print -l a bar b bar bar > f && git commit -qam "LF inserts"
print -l a bar B8 bar bar > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "a line no other of its text could pair with resolves beside added lines" \
	"$RC:$(git show HEAD~2:f | tr '\n' '|'):$(git show HEAD~1:f | tr '\n' '|'):$(git show HEAD:f | tr '\n' '|')" \
	"0:a|foo|bar|B8|:a|B8|bar|:a|bar|B8|bar|bar|"
_ST_PZ_NEW lf-moved-words
print -l w0 "y a" "a y a" a tail > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l w0 y "a a" "y a" a tail > f && git commit -qam "LF moves words"
print -l w0 y "a a" "Y2 a" a tail > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "but one beside a removed line holding all its words, as moving them leaves it, pauses" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# A CRLF line's words read as its LF twin's
_ST_PZ_NEW lf-crlf-words
git config core.autocrlf false
printf 'w0\r\ny a\r\na y a b\r\na\r\ntail\r\n' > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
printf 'w0\r\ny\r\na a b\r\ny a\r\na\r\ntail\r\n' > f && git commit -qam "LF moves words"
printf 'w0\r\ny\r\na a b\r\nY2 a\r\na\r\ntail\r\n' > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "as does a CRLF one" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# Another line of its text anywhere in the file, past the hunks beside it, pairing as well
_ST_PZ_NEW lf-pairs-far
print -l h P a a b a > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l H P a a a b > f && git commit -qam "LF rewrites and moves"
_ST_PZ_C g g1 "LF beside"
print -l H Q A a a b > f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "a line one of its text beyond the next hunk could pair with pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# A commit renaming the file and rewriting beside the line, its parent read under its own name
# – the log `log.follow` would turn to a rename read alike
for LF_F in "" true; do
	_ST_PZ_NEW lf-rename${LF_F:+-follow}
	[ -n "$LF_F" ] && git config log.follow true
	print -l h0 P l1 l2 l3 l4 l5 l6 > f && git add f && git commit -qm "LF target"
	LF_A=$(git rev-parse HEAD)
	git mv f g && print -l h1 P l1 l2 l3 l4 l5 l6 > g && git add g && git commit -qm "LF renames"
	print -l h2 P l1 l2 l3 l4 l5 l6 > g && git commit -qam "LF rewrites"
	print -l h2 Q l1 l2 l3 l4 l5 l6 > g && git add g
	_ST_RUN --amend-into="$LF_A" -- g
	_ST_EQ "a fold across a commit renaming the file resolves${LF_F:+, under log.follow too}" \
		"$RC:$(git show HEAD~2:f | head -2 | tr '\n' '|'):$(git show HEAD~1:g | head -2 | tr '\n' '|'):$(git show HEAD:g | head -2 | tr '\n' '|')" \
		"0:h0|Q|:h1|Q|:h2|Q|"
done

# A squash of two fixups into a target that adds the file follows the second's lines
# into the target the first rebuilt, from where the file came on both ways
_ST_PZ_NEW lf-squash-two
_ST_PZ_C g r "LF root"
print -l a b c d e f > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l a b1 c d e f > f && git commit -qam "LF c1"
print -l a b1 c d e3 f > f && git commit -qam "LF c2"
print -l A b1 c d e3 f > f && git commit -qam "LF f1"
print -l A b1 c D e3 f > f && git commit -qam "LF f2"
_ST_RUN -s="$LF_A" HEAD~1 HEAD
_ST_EQ "two fixups into a target adding the file resolve" \
	"$RC:$(git show HEAD~2:f | tr '\n' '|'):$(git show HEAD:f | tr '\n' '|')" "0:A|b|c|D|e|f|:A|b1|c|D|e3|f|"
_ST_PZ_NEW lf-squash-auto
_ST_PZ_C g r "LF root"
print -l a b c d e f > f && git add f && git commit -qm "LF t1"
print -l a b1 c d e f > f && git commit -qam "LF c1"
print -l a b1 c d2 e f > f && git commit -qam "LF t2"
print -l a b1 c d2 e3 f > f && git commit -qam "LF c2"
print -l A b1 c d2 e3 f > f && git commit -qam "fixup! LF t1"
print -l A b1 c D2 e3 f > f && git commit -qam "fixup! LF t2"
_ST_RUN -s=auto HEAD~1 HEAD
_ST_EQ "as do two markers, the first's target adding it" \
	"$RC:$(git show HEAD~3:f | tr '\n' '|'):$(git show HEAD~1:f | tr '\n' '|')" "0:A|b|c|d|e|f|:A|b1|c|D2|e|f|"
# A pairing only the exact diff of what comes before and after it settles – one another "}"
# survives the count bound for – resolves, bar before git 2.50, whose `--minimal` still drops
# frequent lines beside unmatched ones, and under a git a shim reports as 2.49
[[ "$(git --version)" =~ '^git version 2\.([0-9]+)\.' ]] && (( match[1] < 50 )) && LF_OLD=1
mkdir -p "$TMP/shim-git249"
printf '#!/bin/sh\n[ "$1" = --version ] && [ $# -eq 1 ] && { echo "git version 2.49.0"; exit 0; }\nexec %s "$@"\n' "$(whence -p git)" > "$TMP/shim-git249/git"
chmod +x "$TMP/shim-git249/git"
for LF_F in "" shim; do
	_ST_PZ_NEW lf-exact${LF_F:+-$LF_F}
	print -l u641 '}' y y '}' > f && git add f && git commit -qm "LF target"
	LF_A=$(git rev-parse HEAD)
	print -l '}' x '}' x y x y x y '}' x '}' y '}' y u641 '}' y y '}' > f && git commit -qam "LF rewrites before it"
	_ST_PZ_C g g1 "LF beside"
	print -l '}' x '}' x y x y x y '}' x '}' y '}' y U641 '};' y y '}' > f
	if [ -n "$LF_F" ]; then PATH="$TMP/shim-git249:$PATH" _ST_RUN --amend-into="$LF_A" --whole -- f; else _ST_RUN --amend-into="$LF_A" --whole -- f; fi
	if [[ -n "$LF_F$LF_OLD" ]]; then
		_ST_EQ "a pairing only the exact diff settles pauses before git 2.50${LF_F:+, as a shim reports it}" \
			"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
		_ST_RUN --abort
	else
		_ST_EQ "a pairing only the exact diff settles resolves" "$RC:$(git show HEAD~2:f | tr '\n' '|')" "0:U641|};|y|y|}|"
	fi
done
# As does one with more candidates than the count bound rules out, the check bounded by
# the lines it writes – over 32 of them past a refactor of many lines of the same text
_ST_PZ_NEW lf-many
LF_T='y } u289 x x y } u984 y } x x y y } x } } u283 } u540 } } u634 } y } u232 } y u316 } } y x } y v168 y } } x x } x y y } } } x u191 } u861 } } x } } u450 } } } } } } } } y } u429 x v50 } u32 x } y } x u261 y y } } } u288 } y } u861 } y x u35 } } } x } u937 } y x y } u661 x } } } } y } } u917 y } } } y } }'
LF_C='y } u289 u984 } } u283 } u540 } } u634 } y } } y y } } } } u232 } y u316 } } y x y } } y } y } } x x } x y y } } } x u191 } u861 } } x } } u450 } } } } } } } } y } u429 x } } u32 x } } } } } u403 x y } y } x u261 y y } } } u288 } y y y } } } } y } u861 } y x u35 } } } x } u937 } y x y x u954 x } } u661 x } } y } } u917 y } } } y } }'
print -l ${=LF_T} > f && git add f && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -l ${=LF_C} > f && git commit -qam "LF refactors around it"
_ST_PZ_C g g1 "LF beside"
print -l ${=${LF_C/u232 \}/U232 \};}} > f
_ST_RUN --amend-into="$LF_A" --whole -- f
if [ -n "$LF_OLD" ]; then
	_ST_EQ "as does one past 32 candidates" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
	_ST_RUN --abort
else
	_ST_EQ "as does one past 32 candidates" "$RC:$(git show HEAD~2:f | sed -n '28,29p' | tr '\n' '|')" "0:U232|};|"
fi

# A commit swapping two files – each its own diff a rewrite sharing one line with the other's,
# as git's break detection reads it – keeps no line's identity, so a fold across it pauses
_ST_PZ_NEW lf-swap
LF_T=$'h0\nP\n' LF_C=''
for LF_F in {1..30}; do LF_T+="line of f number $LF_F"$'\n' LF_C+="other g text $LF_F"$'\n'; done
LF_C+=$'P\n'
print -rn -- "$LF_T" > f && print -rn -- "$LF_C" > g && git add f g && git commit -qm "LF target"
LF_A=$(git rev-parse HEAD)
print -rn -- "${LF_T/h0/h1}" > g && print -rn -- "$LF_C" > f && git commit -qam "LF swaps the files"
_ST_PZ_C x x1 "LF beside"
print -rn -- "${${LF_T/h0/h1}/P/Q}" > g
_ST_RUN --amend-into="$LF_A" --whole -- g
_ST_EQ "a fold across a commit swapping two files pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:g"
_ST_RUN --abort
# As does one swapping two files too small for git to break, each keeping one line of ten
_ST_PZ_NEW lf-small-swap
print -l h0 P l1 l2 l3 l4 l5 l6 l7 l8 > f && print -l k1 k2 k3 k4 k5 k6 k7 k8 k9 P > g && git add f g && git commit -qm "LF small target"
LF_A=$(git rev-parse HEAD)
cp g h && print -l h1 P l1 l2 l3 l4 l5 l6 l7 l8 > g && mv h f && git commit -qam "LF small swap"
_ST_PZ_C x x1 "LF small beside"
print -l h1 Q l1 l2 l3 l4 l5 l6 l7 l8 > g
_ST_RUN --amend-into="$LF_A" --whole -- g
_ST_EQ "a fold across a small swap pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:g"
_ST_RUN --abort
# While a fold resolves across a heavily edited rename, which git never weighs for a rewrite,
# and across a commit more than doubling a file by insertions alone, which removes nothing
_ST_PZ_NEW lf-rename-heavy
LF_T=$'h0\nP\n' LF_C=$'h1\nP\n'
for LF_F in {1..60}; do
	LF_T+="body line number $LF_F of the file"$'\n'
	(( LF_F * 100 / 60 < 45 )) && LF_C+="rewritten $LF_F entirely"$'\n' || LF_C+="body line number $LF_F of the file"$'\n'
done
print -rn -- "$LF_T" > f && git add f && git commit -qm "LF rename target"
LF_A=$(git rev-parse HEAD)
git mv f g && print -rn -- "$LF_C" > g && git add g && git commit -qm "LF renames and rewrites"
_ST_PZ_C x x1 "LF rename beside"
print -rn -- "${LF_C/P/Q}" > g
_ST_RUN --amend-into="$LF_A" --whole -- g
_ST_EQ "a fold across a heavily edited rename resolves" "$RC:$(git show "$(git log --format=%H --grep='^LF rename target$' -1)":f | sed -n 2p)" "0:Q"
_ST_PZ_NEW lf-insertions
LF_T="" LF_C=""
for LF_F in {1..10}; do LF_T+="line $LF_F of the original file"$'\n'; done
for LF_F in {1..30}; do LF_C+="inserted line $LF_F of the new block"$'\n'; done
print -rn -- "$LF_T" > f && git add f && git commit -qm "LF insertion target"
LF_A=$(git rev-parse HEAD)
print -rn -- "${LF_T/line 5 of/${LF_C}line 5 of}" > f && git commit -qam "LF inserts before line 5"
_ST_PZ_C x x1 "LF insertion beside"
sed 's/^line 5 of the original file$/LINE 5 OF THE ORIGINAL FILE/' f > f.new && mv f.new f
_ST_RUN --amend-into="$LF_A" --whole -- f
_ST_EQ "as does one across insertions alone" "$RC:$(git show "$(git log --format=%H --grep='^LF insertion target$' -1)":f | sed -n 5p)" "0:LINE 5 OF THE ORIGINAL FILE"
unfunction _LF_REWRITTEN
cd "$TMP/repo"
