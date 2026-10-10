# A commit placed below a later rewrite of a line it rewrites lands where that later commit keeps the
# rest of its change to the file, the line named as superseded – one left with none of it refuses
_ST_SCENARIO "\e[1;96m[185] a superseded line lands, a commit losing all its change to a file refuses\e[0m"
local SU_A SU_L

# Writes c.md's lines and commits them
_SU_C () {
	# Args: <subject> <line>...
	print -l -- "${@:2}" > c.md && git add c.md && git commit -qm "$1"
}

# The later commit trims a line beside the one it rewords, which the placed note rewrites again
_ST_PZ_NEW su1
git config rerere.enabled false
_SU_C "SU1 base" "# Doc" "intro" "Restart: poll until it answers 200." "tail"
print -r -- x > o.txt && git add o.txt && git commit -qm "SU1 A other" && SU_A=$(git rev-parse HEAD)
_SU_C "SU1 L trims and rewords" "# Doc" "intro trimmed" "Restart: poll for a 200." "tail" && SU_L=$(git rev-parse HEAD)
print -r -- y > p.txt && git add p.txt && git commit -qm "SU1 T top"
print -l "# Doc" "intro trimmed" "Restart: NOTE one curl waits it out." "tail" > c.md
_ST_RUN --commit --after="$SU_A" --text "SU1 note the restart" -- c.md
_ST_EQ "a commit placed below a later rewrite of its line stops" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" c.md $'# Doc\nintro\nRestart: NOTE one curl waits it out.\ntail'
_ST_RUN --continue
_ST_EQ "its own content at its place, the later commit stops" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" c.md $'# Doc\nintro trimmed\nRestart: NOTE one curl waits it out.\ntail'
_ST_RUN --continue
_ST_EQ "the later commit's own content with the note lands" "$RC:$(git log --format=%s | tr '\n' '|')" \
	"0:SU1 T top|SU1 L trims and rewords|SU1 note the restart|SU1 A other|SU1 base|"
_ST_OUT_HAS "naming the line it rewrote as superseded" 'SU1 L trims and rewords – c\.md: Restart: poll until it answers 200\.'
_ST_EQ "that commit keeping the rest of its change" "$(git show --format= HEAD~1 -- c.md | grep -c '^+intro trimmed')" "1"
_ST_EQ "the tip holding the note" "$(git show HEAD:c.md | sed -n 3p)" "Restart: NOTE one curl waits it out."

# Its neighbour: a later commit that only rewords that line, left with nothing of its own, refuses
_ST_PZ_NEW su2
git config rerere.enabled false
_SU_C "SU2 base" "# Doc" "Restart: poll until it answers 200." "tail"
print -r -- x > o.txt && git add o.txt && git commit -qm "SU2 A other" && SU_A=$(git rev-parse HEAD)
_SU_C "SU2 L rewords" "# Doc" "Restart: poll for a 200." "tail"
print -r -- y > p.txt && git add p.txt && git commit -qm "SU2 T top" && SU_L=$(git rev-parse HEAD)
print -l "# Doc" "Restart: NOTE one curl waits it out." "tail" > c.md
_ST_RUN --commit --after="$SU_A" --text "SU2 note the restart" -- c.md
_ST_RESOLVE "$(_ST_PZ_WT)" c.md $'# Doc\nRestart: NOTE one curl waits it out.\ntail'
_ST_RUN --continue
_ST_RESOLVE "$(_ST_PZ_WT)" c.md $'# Doc\nRestart: NOTE one curl waits it out.\ntail'
_ST_RUN --continue
_ST_EQ "a later commit losing all its change to the file refuses" "$RC:$(git rev-parse HEAD)" "1:$SU_L"
_ST_OUT_HAS "naming it" 'SU2 L rewords'
_ST_RUN --abort
cd "$TMP/repo"
