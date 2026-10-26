# `--status` lists the pending fixups on the checked-out branch – unpushed `fixup!`, `amend!`
# and `squash!` commits – and who landed each, the caller's own named as such, ten at most
_ST_SCENARIO "\e[1;96m[259] --status lists pending fixups and who landed each\e[0m"
local FS_I
_ST_PZ_NEW fs
_ST_PZ_C a a1 "FS a"
_ST_PZ_C b b1 "FS b"
_ST_PZ_C a a0 "fixup! FS pushed"
git update-ref refs/remotes/o/main HEAD
GIT_EDIT_ACTOR=fs-1 _ST_RUN --status
_ST_OUT_HAS "with none pending it reports as before" "git-edit: ok – no operation in flight"
_ST_OUT_LACKS "naming no pushed one" "Pending fixups"
print a2 > a
GIT_EDIT_ACTOR=fs-1 _ST_RUN --commit --text "fixup! FS a" -- a
print b2 > b
GIT_EDIT_ACTOR=fs-2 _ST_RUN --commit --text "amend! FS b" -- b
print a3 > a
_ST_RUN --commit --text "squash! FS a" -- a
_ST_PZ_C b b3 "fixup! FS b"
GIT_EDIT_ACTOR=fs-1 _ST_RUN --status
_ST_OUT_HAS "it counts them, the caller's own apart" \
	"Pending fixups on main, unpushed: 4 – 1 of them yours, squashed into their targets by git edit -s=auto"
_ST_OUT_HAS "naming the caller's own" "  $(git rev-parse --short=7 HEAD~3) fixup! FS a – yours"
_ST_OUT_HAS "another label's" "  $(git rev-parse --short=7 HEAD~2) amend! FS b – fs-2's"
_ST_OUT_HAS "an unlabeled run's" "  $(git rev-parse --short=7 HEAD~1) squash! FS a – an unlabeled run's"
_ST_OUT_HAS "and one made outside git-edit" "  $(git rev-parse --short=7 HEAD) fixup! FS b – made outside git-edit"
_ST_OUT_LACKS "never a pushed one" "fixup! FS pushed"
_ST_OUT_HAS "its trailer as before" "git-edit: ok – no operation in flight"
GIT_EDIT_ACTOR=fs-3 _ST_RUN --status
_ST_OUT_HAS "to a label with none of them, none are its own" "Pending fixups on main, unpushed: 4 – none yours, each its own caller's to squash"
_ST_RUN --status
_ST_OUT_HAS "to a caller with no label, an unlabeled run's and one made outside git-edit are" \
	"Pending fixups on main, unpushed: 4 – 2 of them yours"
_ST_OUT_HAS "named so" "squash! FS a – yours"
for FS_I in {1..8}; do git commit -q --allow-empty -m "fixup! FS extra $FS_I"; done
GIT_EDIT_ACTOR=fs-1 _ST_RUN --status
_ST_OUT_HAS "past ten it lists the oldest" "fixup! FS extra 6 – made outside git-edit"
_ST_OUT_LACKS "and none beyond" "fixup! FS extra 7"
_ST_OUT_HAS "counting the rest" "… and 2 more"
