# A squash into a target newer than some of its commits replays those first, in their order, right
# before it – after it, the target would replay without the lines it rewrote – the fold at its
# place with its authorship, and its message where the run brings none of its own:
# • `--text`, or `-m`'s editor, giving one – a newer commit still folding in after it
# • A gate's pause resumed keeping what the first pass gave the fold, conflict stops `--text` too
# • A commit sharing the target's authorship told apart by its message
_ST_SCENARIO "\e[1;96m[274] a squash into a newer target replays its older commits first\e[0m"
local SN_T SN_P SN_TIP

# Makes and enters repo <name>: a commit pinning line b, an unrelated one, then the target
# reworking the pinned line – each a day apart
_SN_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	print -l a b c > f.txt && git add f.txt && GIT_AUTHOR_DATE="2026-10-01T10:00:00+0000" git commit -qm "SN base"
	print -l a "b pinned" c > f.txt && GIT_AUTHOR_DATE="2026-10-02T10:00:00+0000" git commit -qam "SN pin b"
	SN_P=$(git rev-parse HEAD)
	print -r -- x > g.txt && git add g.txt && GIT_AUTHOR_DATE="2026-10-03T10:00:00+0000" git commit -qm "SN unrelated"
	print -l a "b pinned and reworked" c > f.txt
	GIT_AUTHOR_NAME="SN Target" GIT_AUTHOR_DATE="2026-10-04T10:00:00+0000" git commit -qam "SN rework b" -m "SN rework body"
	SN_T=$(git rev-parse HEAD) SN_TIP=$(git rev-parse HEAD)
}

_SN_REPO sn1
_ST_RUN -s="$SN_T" "$SN_P"
_ST_EQ "an older commit squashed into a target rewriting its line lands" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt | tr '\n' ' ')" "0:SN rework b|SN unrelated|SN base|:a b pinned and reworked c "
_ST_EQ "the fold taking the target's authorship and message" \
	"$(git log -1 --format='%an %ad|%B' --date=short HEAD | tr '\n' ' ')" "SN Target 2026-10-04|SN rework b  SN rework body  "
_ST_OUT_HAS "naming the commit it became" "squashed into: $(git rev-parse --short HEAD) SN rework b\$"
_ST_OUT_LACKS "never stopping on the target" 'Conflict during squash'

_SN_REPO sn2
_ST_RUN -s="$SN_T" "$SN_P" --text "SN pinned and reworked"
_ST_EQ "a message given is the fold's, under the target's authorship" \
	"$RC:$(git log -1 --format='%an %ad|%B' --date=short HEAD | tr '\n' ' ')" "0:SN Target 2026-10-04|SN pinned and reworked  "

_SN_REPO sn3
print -l a "b pinned and reworked" "c fixed" > f.txt && git commit -qam "SN fix c"
_ST_RUN -s="$SN_T" "$SN_P" HEAD
_ST_EQ "a newer commit folds in after it" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt | tr '\n' ' '):$(git log -1 --format=%an)" \
	"0:SN rework b|SN unrelated|SN base|:a b pinned and reworked c fixed :SN Target"

_SN_REPO sn4
git config edit.verifyCmd "test -f '$TMP/sn4.ok'"
_ST_RUN -s="$SN_T" "$SN_P"
_ST_EQ "a gate failing pauses" "$RC" 2
: > "$TMP/sn4.ok"
_ST_RUN --continue
_ST_EQ "its resume lands the fold as the first pass gave it" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git log -1 --format='%an %ad' --date=short HEAD)" "0:SN rework b|SN unrelated|SN base|:SN Target 2026-10-04"
git config --unset edit.verifyCmd

_SN_REPO sn5
_ST_TTY "GIT_EDITOR=printf 'SN via editor\n' >" -- -s="$SN_T" "$SN_P" -m -y
_ST_EQ "and -m's editor gives one too" "$RC:$(git log -1 --format='%an|%s' HEAD)" "0:SN Target|SN via editor"

# Commits of one author and second, as a scripted session makes them, told apart by message alone
_ST_PZ_NEW sn6
export GIT_AUTHOR_DATE="2026-10-01T10:00:00+0000"
print -l a b > f.txt && git add f.txt && git commit -qm "SN6 base"
print -l a B > f.txt && git commit -qam "SN6 pin" && SN_P=$(git rev-parse HEAD)
print -r -- x > g.txt && git add g.txt && git commit -qm "SN6 unrelated"
print -l a B2 > f.txt && git commit -qam "SN6 rework" -m "SN6 rework body" && SN_T=$(git rev-parse HEAD)
unset GIT_AUTHOR_DATE
_ST_RUN -s="$SN_T" "$SN_P"
_ST_EQ "one sharing the target's authorship still takes its message" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git log -1 --format=%b)" "0:SN6 rework|SN6 unrelated|SN6 base|:SN6 rework body"

# Stops resolved as each commit holds it, the older one replayed past the commit beside its line
# – `--text` carried through both resumes
_SN_REPO sn7
git reset -q --hard "$SN_P"
print -l a "b pinned" "c changed" > f.txt && GIT_AUTHOR_DATE="2026-10-03T10:00:00+0000" git commit -qam "SN7 beside it"
print -l a "b pinned and reworked" "c changed" > f.txt
GIT_AUTHOR_NAME="SN Target" GIT_AUTHOR_DATE="2026-10-04T10:00:00+0000" git commit -qam "SN7 rework b" && SN_T=$(git rev-parse HEAD)
_ST_RUN -s="$SN_T" "$SN_P" --text "SN7 pinned and reworked"
_ST_EQ "the commit beside it stops" "$RC" 2
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'a\nb\nc changed'
_ST_RUN --continue
_ST_EQ "as does the older one after it" "$RC" 2
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'a\nb pinned\nc changed'
_ST_RUN --continue
_ST_EQ "resumed, the fold takes --text under the target's authorship" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git log -1 --format=%an)" "0:SN7 pinned and reworked|SN7 beside it|SN base|:SN Target"
unfunction _SN_REPO
cd "$TMP/repo"
