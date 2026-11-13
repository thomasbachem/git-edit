# A fixup a run gives a key of its own is that run's caller's – a split's inserted half, a reword
# into a marker, a fold changing its paths – another caller's replay since leaving it so
_ST_SCENARIO "\e[1;96m[275] a fixup a split, reword or fold reshapes is its caller's\e[0m"
local FK_A FK_B
_ST_PZ_NEW fk
print a1 > a && print c0 > c && print e0 > e && git add a c e && git commit -q -m "FK a"
print b1 > b && print c1 > c && git add b c && git commit -q -m "FK b"
_ST_PZ_C d d1 "FK d"
GIT_EDIT_ACTOR=fk-1 _ST_RUN --split="$(git log -1 --format=%H --grep='^FK b$')" --text "fixup! FK a" -- c
_ST_EQ "a split inserts its half as a marker" "$RC:$(git log -1 --format=%s HEAD~2)" "0:fixup! FK a"
GIT_EDIT_ACTOR=fk-1 _ST_RUN -M "$(git log -1 --format=%H --grep='^FK d$')" --text "fixup! FK b"
_ST_EQ "a reword makes a commit one" "$RC:$(git log -1 --format=%s)" "0:fixup! FK b"
print a2 > a
GIT_EDIT_ACTOR=fk-1 _ST_RUN --commit --text "fixup! FK a" -- a
print e1 > e && git add e
GIT_EDIT_ACTOR=fk-1 _ST_RUN --amend-into="$(git rev-parse HEAD)" -- e
_ST_EQ "a fold gives a pending one a path" "$RC:$(git diff-tree --no-commit-id --name-only -r HEAD | tr '\n' ' ')" "0:a e "
# Another caller's fold replays all three, keeping their keys
print b2 > b && git add b
GIT_EDIT_ACTOR=fk-2 _ST_RUN --amend-into="$(git log -1 --format=%H --grep='^FK b$')" -- b
GIT_EDIT_ACTOR=fk-1 _ST_RUN --status
_ST_OUT_HAS "all three are the caller's" "Pending fixups on main, unpushed: 3 – 3 of them yours"
_ST_OUT_HAS "the split's half" "  $(git rev-parse --short=7 HEAD~3) fixup! FK a – yours"
_ST_OUT_HAS "the reworded one" "  $(git rev-parse --short=7 HEAD~1) fixup! FK b – yours"
_ST_OUT_HAS "and the one a fold gave a path" "  $(git rev-parse --short=7 HEAD) fixup! FK a – yours"
GIT_EDIT_ACTOR=fk-2 _ST_RUN --status
_ST_OUT_HAS "never the replaying caller's" "Pending fixups on main, unpushed: 3 – none yours, each its own caller's to squash"
_ST_RUN --status
_ST_OUT_HAS "to a caller with no label, named by their own" "  $(git rev-parse --short=7 HEAD~1) fixup! FK b – fk-1's"
GIT_EDIT_ACTOR=fk-1 _ST_RUN -s=auto
FK_A=$(git log -1 --format=%H --grep='^FK a$') FK_B=$(git log -1 --format=%H --grep='^FK b$')
_ST_EQ "a bare -s=auto squashes all three" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FK b|FK a|"
_ST_EQ "each into its target" \
	"$(git show "${FK_A}:a")$(git show "${FK_A}:c")$(git show "${FK_A}:e")$(git show "${FK_B}:b")$(git show "${FK_B}:d")" "a2c1e1b2d1"
# Another caller's reword of one gives it a subject of its own, so takes it on
_ST_PZ_NEW fr
_ST_PZ_C a a1 "FR a"
_ST_PZ_C b b1 "FR b"
print a2 > a
GIT_EDIT_ACTOR=fr-1 _ST_RUN --commit --text "fixup! FR a" -- a
GIT_EDIT_ACTOR=fr-2 _ST_RUN -M "$(git rev-parse HEAD)" --text "fixup! FR b"
GIT_EDIT_ACTOR=fr-1 _ST_RUN --status
_ST_OUT_HAS "another caller's reword takes it on" "  $(git rev-parse --short=7 HEAD) fixup! FR b – fr-2's"
