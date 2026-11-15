# A stop's resolution taking in what a later commit of the replay changes refuses at that stop, its
# pause kept – resolved again there, no stop to come is resolved for a landing that would refuse:
# • Resolved without those lines, the replay goes on and lands
# • Another resolution still taking them in refuses again, the same one again goes on, the landing
#   judging what that commit lost
# • A rewrite the stop's commit makes again, most of the later change surviving, refuses nowhere
_ST_SCENARIO "\e[1;96m[277] a stop taking in a later commit's lines refuses there\e[0m"
local TI_X TI_Y TI_WT TI_TIP
# Writes `app.js` and `test.js` as <name>'s commits make them,
# `<name> y` adding a line to `test.js` – the fold into `<name> x` staged
_TI_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	print -l one two three > app.js && print -l setup run > test.js && git add . && git commit -qm "$1 a"
	print -l one call three > app.js && git commit -qam "$1 x" && TI_X=$(git rev-parse HEAD)
	print -l setup load run > test.js && git commit -qam "$1 y" && TI_Y=$(git rev-parse HEAD)
	print -l one call three-w > app.js && git commit -qam "$1 w"
	TI_TIP=$(git rev-parse HEAD)
	print -l one call-new three-w > app.js && git add app.js
}
export GIT_EDIT_NO_SELF_RESOLVE=1 GIT_EDIT_ACTOR=ti-1
_TI_REPO ti
_ST_RUN --amend-into="$TI_X" -- app.js
TI_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" app.js "$(print -l one call-new three)"
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" test.js "$(print -l setup load run)"
_ST_RUN --continue
_ST_EQ "the stop taking in a later commit's line refuses, the branch unmoved" "$RC:$(git rev-parse HEAD)" "2:$TI_TIP"
_ST_OUT_HAS "naming that commit and its file" "${TI_Y:0:7} ti y – test.js"
_ST_OUT_HAS "and the line held" 'its line "load" held here'
_ST_OUT_HAS "its pause kept, a conflict naming the file" "^git-edit: conflict – resolve in .* (test.js); then 'git edit --continue'"
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" test.js "$(print -l setup run)"
_ST_RUN --continue
_ST_EQ "resolved again without it, the replay goes on and lands, the line where its own commit adds it" \
	"$RC:$(git show "$(git log -1 --format=%H --grep='^ti x$'):test.js" | tr '\n' ' ')|$(git show "$(git log -1 --format=%H --grep='^ti y$'):test.js" | tr '\n' ' ')" \
	"0:setup run |setup load run "
_ST_EQ "the tip the fold applied to it" "$(git show HEAD:app.js | tr '\n' ' ')" "one call-new three-w "
# Another resolution still taking it in refuses again, the same one again goes on
_TI_REPO tr
_ST_RUN --amend-into="$TI_X" -- app.js
TI_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" app.js "$(print -l one call-new three)"
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" test.js "$(print -l setup load run)"
_ST_RUN --continue
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" test.js "$(print -l setup load run more)"
_ST_RUN --continue
_ST_EQ "another resolution taking it in refuses again" "$RC" "2"
_ST_OUT_HAS "naming it again" 'its line "load" held here'
_ST_RUN --continue
_ST_EQ "the same one again goes on, to the commit it emptied" "$RC" "2"
_ST_OUT_LACKS "refusing it no more" "The staged resolution takes in"
_ST_OUT_HAS "that commit's stop" "Could not apply ${TI_Y:0:7}"
_ST_RUN --continue
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" app.js "$(print -l one call-new three-w)"
_ST_RUN --continue
_ST_EQ "where the landing refuses what that commit lost" "$RC" "1"
_ST_OUT_HAS "as a resolution taking it in" "A resolution took in what a later commit changes"
_ST_RUN --abort
git restore --staged app.js && git checkout -q -- app.js
# A later commit's line of punctuation alone, taken in, refuses nowhere – the landing counts none
_ST_PZ_NEW tp
git config rerere.enabled false
print -l one two three > app.js && print -l setup run > test.js && git add . && git commit -qm "tp a"
print -l one call three > app.js && git commit -qam "tp x" && TI_X=$(git rev-parse HEAD)
print -l setup run "};" > test.js && git commit -qam "tp y"
print -l one call three-w > app.js && git commit -qam "tp w"
print -l one call-new three-w > app.js && git add app.js
_ST_RUN --amend-into="$TI_X" -- app.js
TI_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" app.js "$(print -l one call-new three)"
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" test.js "$(print -l setup run "};")"
_ST_RUN --continue
_ST_OUT_LACKS "a punctuation line taken in refuses nowhere at the stop" "The staged resolution takes in"
_ST_RUN --abort
git restore --staged app.js && git checkout -q -- app.js
# A rewrite the stop's commit makes again, the later commit keeping most of its change, goes on
_ST_PZ_NEW ts
git config rerere.enabled false
print -l alpha bravo charlie delta echo > s.js && git add . && git commit -qm "ts a"
print -l alpha bravo-x charlie delta echo > s.js && git commit -qam "ts x" && TI_X=$(git rev-parse HEAD)
print -l alpha-c bravo-x charlie-c delta-c echo > s.js && git commit -qam "ts c"
print -l alpha-new bravo-x charlie-c delta-c echo > s.js && git add s.js
_ST_RUN --amend-into="$TI_X" -- s.js
TI_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" s.js "$(print -l alpha-new bravo-x charlie delta echo)"
_ST_RUN --continue
_ST_EQ "a superseded rewrite goes on and lands" "$RC:$(git show HEAD:s.js | tr '\n' ' ')" "0:alpha-new bravo-x charlie-c delta-c echo "
_ST_OUT_LACKS "refusing nothing at the stop" "The staged resolution takes in"
# A resolution re-indenting lines a later commit rewrites, a fixup written on the tip wrapping
# them, takes nothing in – that commit rewrites them where they now stand, as the landing reads it
_ST_PZ_NEW tw
git config rerere.enabled false
print -l "function a() {" $'\t// keep the skip here,' $'\t// as the lock avoids it' $'\trun();' "}" > w.js && git add w.js && git commit -qm "tw a"
print -l "function a() {" $'\t// keep the skip here,' $'\t// as the lock avoids it' $'\trun(1);' "}" > w.js && git commit -qam "tw x"
print -l "function a() {" $'\t// skip kept, the lock avoiding it' $'\trun(1);' "}" > w.js && git commit -qam "tw c"
TI_TIP=$(git rev-parse HEAD)
print -l "function a() {" $'\tif (ok) {' $'\t\t// skip kept, the lock avoiding it' $'\t\trun(1);' $'\t}' "}" > w.js && git commit -qam "fixup! tw x"
local TW_T=$(git rev-parse 'HEAD^{tree}')
_ST_RUN -s=auto HEAD
TI_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" w.js "$(print -l "function a() {" $'\tif (ok) {' $'\t\t// keep the skip here,' $'\t\t// as the lock avoids it' $'\t\trun(1);' $'\t}' "}")"
_ST_RUN --continue
_ST_EQ "a re-indented line a later commit rewrites goes on to that commit's stop" "$RC" "2"
_ST_OUT_LACKS "refusing nothing at the stop" "The staged resolution takes in"
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" w.js "$(print -l "function a() {" $'\tif (ok) {' $'\t\t// skip kept, the lock avoiding it' $'\t\trun(1);' $'\t}' "}")"
_ST_RUN --continue
_ST_EQ "and lands, the tip as the fixup made it" "$RC:$(git rev-parse 'HEAD^{tree}')" "0:$TW_T"
# A copy of the removed line that its own commits put in elsewhere moves nothing – still taken in
_ST_PZ_NEW tk
git config rerere.enabled false
print -l a "keep me here" m b c > k.js && git add k.js && git commit -qm "tk a"
print -l a1 "keep me here" m b c > k.js && git commit -qam "tk x"
print -l a1 m b2 c > k.js && git commit -qam "tk c"
print -l a1 m b2 c1 "keep me here" > k.js && git commit -qam "fixup! tk x"
GIT_EDIT_NO_SELF_RESOLVE=1 _ST_RUN -s=auto HEAD
TI_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${TI_WT:-$ST_NO_WT}" k.js "$(print -l a1 m b c1 "keep me here")"
_ST_RUN --continue
_ST_EQ "its removal taken in beside its own copy refuses at the stop" "$RC" "2"
_ST_OUT_HAS "naming that commit" "tk c – k\.js"
_ST_RUN --abort
unset GIT_EDIT_NO_SELF_RESOLVE GIT_EDIT_ACTOR
