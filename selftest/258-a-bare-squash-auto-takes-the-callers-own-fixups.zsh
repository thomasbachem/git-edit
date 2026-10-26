# A bare `-s=auto` squashes the caller's own pending fixups, each into the commit its marker names:
# • Its own as the journal names who landed each – its label's, or to a caller with none an
#   unlabeled run's or one made outside git-edit – through a landing since that rewrote them
# • One landed amid history, after a commit, its lander's too – another caller's of the same
#   target in the same second told apart by the paths it changes
# • None of its own ends ok and unchanged, naming the other callers' left
# • One it can't take refuses the run, naming the rest's own run
#   and what a target reworded since became
_ST_SCENARIO "\e[1;96m[258] a bare -s=auto squashes the caller's own pending fixups\e[0m"
local FO_PRE FO_B
# Every commit in one second, so two callers' `fixup! FO b` share author, date and subject
local -x GIT_AUTHOR_DATE="1700000000 +0000"
_ST_PZ_NEW fo
_ST_PZ_C a a1 "FO a"
_ST_PZ_C b b1 "FO b"
_ST_PZ_C c c1 "FO c"
_ST_PZ_C d d1 "FO d"
print a2 > a
GIT_EDIT_ACTOR=fo-1 _ST_RUN --commit --text "fixup! FO a" -- a
print b2 > b
GIT_EDIT_ACTOR=fo-2 _ST_RUN --commit --text "fixup! FO b" -- b
print c2 > c
_ST_RUN --commit --text "fixup! FO c" -- c
_ST_PZ_C d d2 "fixup! FO d"
print e1 > e
GIT_EDIT_ACTOR=fo-1 _ST_RUN --commit --after="$(git log -1 --format=%H --grep='^FO c$')" --text "fixup! FO b" -- e
_ST_EQ "a fixup lands amid history" "$RC:$(git log -1 --format=%s HEAD~5)" "0:fixup! FO b"
# Another caller's fold rewrites every fixup above its target
print x1 > x && git add x
GIT_EDIT_ACTOR=fo-3 _ST_RUN --amend-into="$(git log -1 --format=%H --grep='^FO a$')" -- x
GIT_EDIT_ACTOR=fo-1 _ST_RUN -s=auto
_ST_EQ "a label's bare -s=auto squashes its own alone, the rewrite since notwithstanding" \
	"$RC:$(git log --format=%s | tr '\n' '|')" "0:fixup! FO d|fixup! FO c|fixup! FO b|FO d|FO c|FO b|FO a|"
_ST_EQ "each into the commit its marker names" \
	"$(git show "$(git log -1 --format=%H --grep='^FO a$')":a)$(git show "$(git log -1 --format=%H --grep='^FO b$')":e)$(git show "$(git log -1 --format=%H --grep='^FO b$')":b)" "a2e1b1"
_ST_OUT_HAS "naming the other callers' left" "2 pending fixup(s) of yours on main – other callers' 3 left to them"
FO_PRE=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=fo-1 _ST_RUN -s=auto
_ST_EQ "with none of its own left, it ends ok and unchanged" "$RC:$(git rev-parse HEAD)" "0:$FO_PRE"
_ST_OUT_HAS "saying so" "No pending fixups of yours on main – nothing to squash"
_ST_OUT_HAS "and naming the others'" "3 other pending fixup(s) there are other callers' to squash – git edit --status lists them"
_ST_OUT_HAS "its trailer too" "git-edit: ok – refs/heads/main unchanged, no pending fixups of yours"
_ST_RUN -s=auto
_ST_EQ "a caller with no label takes an unlabeled run's and one made outside git-edit" \
	"$RC:$(git log --format=%s | tr '\n' '|')" "0:fixup! FO b|FO d|FO c|FO b|FO a|"
GIT_EDIT_ACTOR=fo-2 _ST_RUN -s=auto
_ST_EQ "and each label its own" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:b)" "0:FO d|FO c|FO b|FO a|:b2"
# A pushed target and one reworded since refuse the run whole, the rest named for their own
_ST_PZ_NEW fo-refuse
_ST_PZ_C a a1 "FR a"
git update-ref refs/remotes/o/main HEAD
_ST_PZ_C b b1 "FR b"
_ST_PZ_C c c1 "FR c"
for FO_B in a b c; do
	print ${FO_B}2 > $FO_B
	GIT_EDIT_ACTOR=fr _ST_RUN --commit --text "fixup! FR $FO_B" -- $FO_B
done
GIT_EDIT_ACTOR=fr-peer _ST_RUN -M --subject "Renamed FR b" "$(git log -1 --format=%H --grep='^FR b$')"
FO_PRE=$(git rev-parse HEAD)
FO_B=$(git log -1 --format=%H --grep='^Renamed FR b$')
GIT_EDIT_ACTOR=fr _ST_RUN -s=auto
_ST_EQ "a fixup it can't take refuses the run, nothing changed" "$RC:$(git rev-parse HEAD)" "1:$FO_PRE"
_ST_OUT_HAS "naming one whose target is pushed" "fixup! FR a – names $(git log -1 --format=%h --abbrev=7 --grep='^FR a$'), already pushed"
_ST_OUT_HAS "and one whose target was reworded since, as what it became" \
	"fixup! FR b – names no commit below it, its target reworded since as ${FO_B:0:7} (Renamed FR b): git edit -s=${FO_B:0:7} $(git rev-parse --short=7 HEAD~1)"
_ST_OUT_HAS "and the rest's own run" "Your other pending fixups alone: git edit -s=auto $(git rev-parse HEAD | cut -c1-12)"
GIT_EDIT_ACTOR=fr _ST_RUN -s=auto "$FO_PRE"
_ST_EQ "which squashes them" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show "$(git log -1 --format=%H --grep='^FR c$')":c)" \
	"0:fixup! FR b|fixup! FR a|FR c|Renamed FR b|FR a|:c2"
