# A landing renaming a directory whole has `--carry` take along each file still at its old path,
# edited or not, and the untracked files left there – never one over a file in its place, an
# ignored one, or any in a directory renamed only in part – as a terminal run's sync does
_ST_SCENARIO "\e[1;96m[156] --carry and a terminal sync take a directory renamed whole along\e[0m"
local DR_A DR_OLD DR_WT
# An agent's landing names the untracked files left behind, and `--carry` brings the lot along
_ST_PZ_NEW dr1
mkdir -p 'old [a]/cases' outside other && print -r -- $'1\n2\n3' > 'old [a]/test.js' && print -r -- a > 'old [a]/cases/a 1.json'
ln -s test.js 'old [a]/t.lnk' && print -r -- f > outside/f.txt && print -r -- o > other/o.txt
git add . && git commit -qm "DR1 A" && DR_A=$(git rev-parse HEAD)
_ST_PZ_C b.txt b "DR1 B"
DR_OLD=$(git rev-parse HEAD)
print -r -- '*.log' >> .git/info/exclude
print -r -- $'1\n2\n3\n4' > 'old [a]/test.js'
mkdir 'old [a]/scratch' 'new *x' 'new *x/cases'
print -r -- b > 'old [a]/cases/b [1].json' && print -r -- n > 'old [a]/scratch/n?.txt' && print -r -- log > 'old [a]/cases/x.log'
print -r -- mine > 'old [a]/cases/c.json' && print -r -- theirs > 'new *x/cases/c.json'
ln -s ../outside 'old [a]/ext' && print -r -- u > other/u.txt
_ST_RUN "$DR_A"
DR_WT=$(_ST_PZ_WT)
git -C "${DR_WT:-$ST_NO_WT}" mv 'old [a]' 'new *x'
_ST_RUN --continue
_ST_OUT_HAS "the landing names an untracked file left in the directory it renamed whole" 'renamed whole: .*old \[a\]/cases/b \[1\]\.json → new \*x/cases/b \[1\]\.json'
_ST_OUT_HAS "with the carry that takes it along" "and take the untracked files along, with: git edit --carry=${DR_OLD:0:12}"
_ST_OUT_HAS "and one whose place is taken as left" 'to move by hand: old \[a\]/cases/c\.json – untracked, new \*x/cases/c\.json exists already'
_ST_OUT_LACKS "never an ignored one" 'x\.log'
_ST_RUN --carry="$DR_OLD"
_ST_EQ "a taken place fails the carry" "$RC" "1"
_ST_EQ "the edited file is carried" "$(cat 'new *x/test.js')" $'1\n2\n3\n4'
_ST_EQ "an unedited one moves, as it landed" "$(cat 'new *x/cases/a 1.json' 2>/dev/null):$(git status --porcelain -- 'new *x/cases/a 1.json')" "a:"
_ST_EQ "as does an unedited symlink" "$(readlink 'new *x/t.lnk')" "test.js"
_ST_EQ "an untracked file goes to the same tail" "$(cat 'new *x/cases/b [1].json' 2>/dev/null)" "b"
_ST_EQ "under an untracked directory too" "$(cat 'new *x/scratch/n?.txt' 2>/dev/null)" "n"
_ST_EQ "an untracked symlink moves as itself, what it points at untouched" "$(readlink 'new *x/ext'):$(cat outside/f.txt)" "../outside:f"
_ST_OUT_HAS "named as moved" 'moved along with their renamed directory: .*old \[a\]/cases/b \[1\]\.json → new \*x/cases/b \[1\]\.json'
_ST_EQ "a file in its place is never overwritten" "$(cat 'new *x/cases/c.json'):$(cat 'old [a]/cases/c.json')" "theirs:mine"
_ST_OUT_HAS "the one left named" 'to merge by hand: .*old \[a\]/cases/c\.json – untracked, new \*x/cases/c\.json exists already'
_ST_EQ "an ignored file stays" "$(cat 'old [a]/cases/x.log')" "log"
_ST_CHECK "nothing else is left in the old directory" test "$(cd 'old [a]' && find . -type f -o -type l | sort | tr '\n' ' ')" = "./cases/c.json ./cases/x.log "
_ST_CHECK "the emptied directories are gone" test ! -e 'old [a]/scratch' -a ! -e 'old [a]/test.js'
_ST_EQ "and nothing outside is touched" "$(cat other/u.txt):$(cat other/o.txt)" "u:o"
_ST_RUN --carry="$DR_OLD"
_ST_OUT_LACKS "a second carry moves nothing twice" 'moved along'
# A directory renamed only in part takes no untracked file along – named as left there
_ST_PZ_NEW dr2
mkdir 'part [d]' && print -r -- k > 'part [d]/keep.js' && print -r -- m > 'part [d]/mv.js'
git add . && git commit -qm "DR2 A" && DR_A=$(git rev-parse HEAD)
_ST_PZ_C b.txt b "DR2 B"
DR_OLD=$(git rev-parse HEAD)
print -r -- u > 'part [d]/u?.txt'
_ST_RUN "$DR_A"
DR_WT=$(_ST_PZ_WT)
mkdir -p "${DR_WT:-$ST_NO_WT}/moved" && git -C "${DR_WT:-$ST_NO_WT}" mv 'part [d]/mv.js' moved/mv.js
_ST_RUN --continue
_ST_OUT_HAS "a landing names an untracked file in a directory renamed only in part as staying" 'renamed only in part: part \[d\]/u?\.txt'
_ST_OUT_LACKS "never as one to take along" 'renamed whole'
_ST_RUN --carry="$DR_OLD"
_ST_EQ "the carry moves the renamed file" "$RC:$(cat moved/mv.js 2>/dev/null)" "0:m"
_ST_EQ "while the untracked file stays" "$(cat 'part [d]/u?.txt'):$(ls moved)" "u:mv.js"
_ST_OUT_HAS "named as left" 'left where they are, in a directory the rewrite renamed only in part: part \[d\]/u?\.txt'
# A terminal run's sync brings the untracked files along too, a file in its place kept
_ST_PZ_NEW dr3
mkdir 'old [a]' && print -r -- t > 'old [a]/t.js'
git add . && git commit -qm "DR3 A" && DR_A=$(git rev-parse HEAD)
_ST_PZ_C b.txt b "DR3 B"
print -r -- '*.log' >> .git/info/exclude
mkdir 'new *x' && print -r -- b > 'old [a]/b [1].json' && print -r -- log > 'old [a]/x.log'
print -r -- mine > 'old [a]/c.json' && print -r -- theirs > 'new *x/c.json'
_ST_TTY_START -- "$DR_A"
if _ST_TTY_AT 'Make your changes in'; then
	DR_WT=$(_ST_PZ_WT)
	git -C "${DR_WT:-$ST_NO_WT}" mv 'old [a]' 'new *x'
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "a terminal landing takes an untracked file along" "$RC:$(cat 'new *x/b [1].json' 2>/dev/null):$(cat 'new *x/t.js' 2>/dev/null)" "0:b:t"
_ST_OUT_HAS "named as moved" 'moved along with their renamed directory: old \[a\]/b \[1\]\.json → new \*x/b \[1\]\.json'
_ST_EQ "never over a file in its place" "$(cat 'new *x/c.json'):$(cat 'old [a]/c.json')" "theirs:mine"
_ST_OUT_HAS "which it names" 'reconcile: old \[a\]/c\.json – untracked, new \*x/c\.json exists already'
_ST_EQ "an ignored file stays" "$(cat 'old [a]/x.log')" "log"
# A rename the checkout made itself, committed through the run, leaves its untracked files alone
_ST_PZ_NEW dr4
mkdir 'old [a]' && print -r -- t > 'old [a]/t.js' && git add . && git commit -qm "DR4 A"
git mv 'old [a]' 'new *x' && mkdir 'old [a]' && print -r -- u > 'old [a]/u.txt'
_ST_TTY -- --commit --text "DR4 mv" -- 'old [a]/t.js' 'new *x/t.js'
_ST_EQ "a terminal commit of the checkout's own directory rename moves no untracked file" "$RC:$(cat 'old [a]/u.txt' 2>/dev/null):$(git ls-files -o --exclude-standard)" "0:u:old [a]/u.txt"
_ST_OUT_LACKS "nor names one" 'renamed whole\|moved along\|only in part'
print -r -- t2 > 'new *x/t2.js' && git add 'new *x/t2.js' && git commit -qm "DR4 t2"
git mv 'new *x' 'old [a]/back' && mkdir 'new *x' && print -r -- v > 'new *x/v.txt'
_ST_RUN --commit --text "DR4 back" -- 'new *x/t.js' 'new *x/t2.js' 'old [a]/back/t.js' 'old [a]/back/t2.js'
_ST_EQ "as does an agent's" "$RC:$(git log -1 --format=%s):$(cat 'new *x/v.txt' 2>/dev/null)" "0:DR4 back:v"
_ST_OUT_LACKS "naming none either" 'renamed whole\|only in part'
# A branch landed into a dirty checkout by a fast-forward, then one carry: edits merged onto what
# landed, every file still as before brought to it, untracked files kept – nothing left stale
_ST_PZ_NEW dr5
mkdir 'sub [s]' && print -r -- $'1\n2\n3' > a.txt && print -r -- c > 'sub [s]/c *.txt' && print -r -- g > g.txt && print -r -- x > x.sh
git add . && git commit -qm "DR5 base" && DR_OLD=$(git rev-parse HEAD)
git checkout -q -b topic
print -r -- $'1\n2\nthree' > a.txt && print -r -- c2 > 'sub [s]/c *.txt' && git rm -q g.txt && print -r -- n > 'sub [s]/n.txt' && chmod +x x.sh
git add . && git commit -qm "DR5 topic" && git checkout -q main
print -r -- $'one\n2\n3' > a.txt && print -r -- u > u.txt
_ST_RUN --exec -- git merge -q --ff-only topic
_ST_EQ "the fast-forward lands" "$RC:$(git log -1 --format=%s)" "0:DR5 topic"
_ST_RUN --carry="$DR_OLD"
_ST_EQ "one carry merges the edits onto what landed" "$RC:$(tr '\n' ' ' < a.txt)" "0:one 2 three "
_ST_EQ "brings a file still as before to it" "$(cat 'sub [s]/c *.txt')" "c2"
_ST_CHECK "its mode too" test -x x.sh
_ST_CHECK "takes out one the landing removed" test ! -e g.txt
_ST_EQ "writes one it added" "$(cat 'sub [s]/n.txt' 2>/dev/null)" "n"
_ST_OUT_HAS "named as brought along" 'Brought to what landed, holding no edits: .*sub \[s\]/c \*\.txt'
_ST_EQ "and keeps the untracked file, nothing else left stale" "$(cat u.txt):$(git status --porcelain | tr '\n' '|')" "u: M a.txt|?? u.txt|"
_ST_RUN --carry="$DR_OLD"
_ST_OUT_HAS "a second carry finds nothing" 'Nothing to carry'
cd "$TMP/repo"
