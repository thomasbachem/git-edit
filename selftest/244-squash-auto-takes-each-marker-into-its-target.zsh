# `-s=auto` squashes each commit into the one its `fixup!`, `amend!` or `squash!` marker names,
# every pair in one replay:
# • Each target takes the message its markers ask for, the gate checking the commit it became
# • A commit named outright with no marker refuses with the others, nothing changed, bar a target
# • One a range brought without a marker stays where it is, and may be a target
# • A fixup of a file a commit after its target adds refuses, as a fold of it does – bar an add
#   replayed ahead of it, a rename followed
# • The unpushed commits answer first, as in git's own pass, opening words only where no subject
#   or name answers anywhere, a pushed target refusing without --allow-pushed
# • Across a pause, each message still set once the replay is through, and kept past a gate's
# • A fixup replacing lines resolves its stops as a fold of replaced lines does
_ST_SCENARIO "\e[1;96m[244] -s=auto takes each marker into its target\e[0m"
local AU_PRE AU_WT AU_I AU_STOPS=0
local -a AU_M AU_STEPS
_ST_PZ_NEW au
_ST_PZ_C a a1 "AU a"
_ST_PZ_C b b1 "AU b"
_ST_PZ_C x x1 "AU between"
_ST_PZ_C c c1 "AU c"
_ST_PZ_C a a2 "fixup! AU a"
print b2 > b && git commit -qam "amend! AU b" -m "AU b reworded" -m "With a body"
print c2 > c && git commit -qam "squash! AU c" -m "AU c note"
_ST_PZ_C a a3 "fixup! fixup! AU a"
AU_M=($(git log --reverse --format=%H -4))
git config edit.verifyCmd "sh -c 'git log -1 --format=%s \"\$GIT_EDIT_VERIFY_COMMIT\" >> \"$TMP/au-verified\"'"
: > "$TMP/au-verified"
_ST_RUN -s=auto "${AU_M[@]}"
_ST_EQ "one replay squashes each marker into its own target" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse main@{1})" "0:AU c|AU between|AU b reworded|AU a|:${AU_M[4]}"
_ST_EQ "an amend! takes its target's message, a squash! adds its body" \
	"$(git log -1 --format=%B HEAD~2)|$(git log -1 --format=%B HEAD)" \
	"AU b reworded"$'\n\n'"With a body|AU c"$'\n\n'"AU c note"
_ST_EQ "the content stays the tip's" "$(git show HEAD:a)$(git show HEAD:b)$(git show HEAD:c)" "a3b2c2"
_ST_OUT_HAS "naming the marker a message follows" "follows amend! ${AU_M[2]:0:7}, as git's autosquash would"
_ST_OUT_HAS "and each commit squashed into" "squashed into: $(git rev-parse --short HEAD~2) AU b reworded"
_ST_EQ "the gate checks each commit a target became" \
	"$(sort -u "$TMP/au-verified" | grep -c -x -e 'AU a' -e 'AU b reworded' -e 'AU c')" "3"
git config --unset edit.verifyCmd
_ST_RUN --undo
_ST_EQ "one undo takes the whole run back" "$RC:$(git rev-parse HEAD)" "0:${AU_M[4]}"
# An empty message-only `amend!` and a marker naming its target by SHA
_ST_PZ_NEW au-named
_ST_PZ_C a a1 "AU named"
_ST_PZ_C x x1 "AU named between"
git commit -q --allow-empty -m "amend! AU named" -m "AU named reworded"
_ST_PZ_C a a2 "fixup! $(git rev-parse --short HEAD~2)"
_ST_RUN -s=auto HEAD~1 HEAD
_ST_EQ "an empty amend! rewords, a SHA names its target" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:a)" "0:AU named between|AU named reworded|:a2"
# A subject answers before a name, as in git's order – here a tag of the older commit
_ST_PZ_NEW au-order
_ST_PZ_C a a1 "AU tagged"
git tag release
_ST_PZ_C r r1 "release"
_ST_PZ_C a a2 "fixup! release"
_ST_RUN -s=auto HEAD
_ST_EQ "a whole subject wins over a name" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:a)" "0:release|AU tagged|:a1"
# An exact subject among the pushed outranks an unpushed one's opening words – refused as pushed
_ST_PZ_NEW au-loose
_ST_PZ_C a a1 "AU typo"
git update-ref refs/remotes/o/main HEAD
_ST_PZ_C b b1 "AU typo in README"
_ST_PZ_C a a2 "fixup! AU typo"
AU_PRE=$(git rev-parse HEAD)
_ST_RUN -s=auto HEAD
_ST_EQ "a pushed exact subject wins over unpushed opening words" "$RC:$(git rev-parse HEAD)" "1:$AU_PRE"
_ST_OUT_HAS "naming the marker behind the pushed target" "fixup! AU typo – names $(git rev-parse --short HEAD~2), already pushed"
_ST_RUN -s=auto --allow-pushed HEAD
_ST_EQ "and --allow-pushed takes it there" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:a)" "0:AU typo in README|AU typo|:a2"
# Opening words alone and a name pair where nothing else answers, said so
# – spaces after a marker stripped as git strips them
_ST_PZ_NEW au-loose-ok
_ST_PZ_C a a1 "AU opening words of it"
_ST_PZ_C b b1 "AU spaced"
_ST_PZ_C x x1 "AU named one"
_ST_PZ_C a a2 "fixup! AU opening"
_ST_PZ_C b b2 "fixup!  AU spaced"
_ST_PZ_C x x2 "fixup! $(git rev-parse --short HEAD~2)"
_ST_RUN -s=auto HEAD~2..HEAD
_ST_EQ "each pairs" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:a)$(git show HEAD~1:b)$(git show HEAD:x)" \
	"0:AU named one|AU spaced|AU opening words of it|:a2b2x2"
_ST_OUT_HAS "an opening-words pairing said so" "by its opening words"
_ST_OUT_HAS "and a name's" "by a name resolving to it"
# A range's commits with no marker stay where they are, and one may be a target
_ST_PZ_NEW au-range
_ST_PZ_C a a1 "AU ranged target"
_ST_PZ_C b b1 "AU own"
_ST_PZ_C a a2 "fixup! AU ranged target"
_ST_PZ_C c c1 "AU own later"
_ST_RUN -s=auto HEAD~3..HEAD
_ST_EQ "a range squashes its markers, the rest staying" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~2:a)" "0:AU own later|AU own|AU ranged target|:a2"
_ST_OUT_HAS "naming what stayed" "2 commit(s) in the range carry no marker and stay where they are"
_ST_RUN -s=auto HEAD~1..HEAD
_ST_EQ "a range with no marker refuses" "$RC" "1"
_ST_OUT_HAS "as given none" "-s=auto was given no fixup!, amend! or squash! commit"
# A target named outright beside its fixup is no marker missed
_ST_PZ_NEW au-named-target
_ST_PZ_C a a1 "AU named target"
AU_PRE=$(git rev-parse HEAD)
_ST_PZ_C b b1 "AU between it"
_ST_PZ_C a a2 "fixup! AU named target"
git branch auto HEAD~1
_ST_RUN -s=auto "$AU_PRE" HEAD
_ST_EQ "a target named outright pairs, -s=auto a keyword beside a branch of that name" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:a)" "0:AU between it|AU named target|:a2"
# A fixup changing or removing a file a commit after its target adds refuses, as a fold of it does
_ST_PZ_NEW au-later-file
_ST_PZ_C a a1 "AU early"
_ST_PZ_C x x1 "AU adds x"
AU_X=$(git rev-parse --short HEAD)
_ST_PZ_C l l1 "AU adds l"
AU_L=$(git rev-parse --short HEAD)
git mv l m && git commit -qm "AU renames l"
_ST_PZ_C w w1 "fixup! AU adds x"
AU_W=$(git rev-parse --short HEAD)
_ST_PZ_C x x2 "fixup! AU early"
git rm -q x && git commit -qm "fixup! AU early"
print m2 > m && print w2 > w && git commit -qam "fixup! AU early"
AU_PRE=$(git rev-parse HEAD)
_ST_RUN -s=auto HEAD~3 HEAD~2 HEAD~1 HEAD
_ST_EQ "a fixup of a file its target predates refuses" "$RC:$(git rev-parse HEAD)" "1:$AU_PRE"
_ST_OUT_HAS "each commit counted once" "can't take 3 of its commits"
_ST_OUT_HAS "naming the change and the commit adding the file" "– changes x, which $AU_X AU adds x adds after its target"
_ST_OUT_HAS "and the removal" "– removes x, which $AU_X AU adds x adds after its target"
_ST_OUT_HAS "a rename followed to the commit adding the file" "– changes m, which $AU_L AU adds l adds after its target"
_ST_OUT_HAS "and an add by a fixup of a later target" "– changes w, which $AU_W fixup! AU adds x adds after its target"
_ST_RUN -s=auto --allow-new-path HEAD~2
_ST_EQ "--allow-new-path replays it anyway" "$RC" "2"
_ST_RUN --abort
# Bar an add by a fixup of its target or an older one, and a file its target held under another name
_ST_PZ_NEW au-added-ahead
_ST_PZ_C a a1 "AU base"
_ST_PZ_C o o1 "AU older"
_ST_PZ_C b b1 "AU mid"
git mv o n && git commit -qm "AU renames o"
_ST_PZ_C y y1 "fixup! AU base"
_ST_PZ_C y y2 "fixup! AU base"
_ST_PZ_C z z1 "fixup! AU base"
_ST_PZ_C z z2 "fixup! AU mid"
_ST_PZ_C n o2 "fixup! AU older"
_ST_RUN -s=auto HEAD~4 HEAD~3 HEAD~2 HEAD~1 HEAD
_ST_EQ "a file a fixup replayed ahead adds, or its target held renamed, takes its fixups" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~3:y)$(git show HEAD~3:z):$(git show HEAD~1:z):$(git show HEAD~2:o):$(git show HEAD:n)" \
	"0:AU renames o|AU mid|AU older|AU base|:y2z1:z2:o2:o2"
# Refusals – each commit named, nothing changed
_ST_PZ_NEW au-refused
_ST_PZ_C a a1 "AU a"
AU_PRE=$(git rev-parse HEAD)
_ST_PZ_C y y1 "AU plain"
_ST_PZ_C z z1 "fixup! AU nothing like it"
_ST_RUN -s=auto HEAD~1 HEAD
_ST_EQ "a commit without a marker, or naming nothing below, refuses all" \
	"$RC:$(git rev-parse HEAD~2)" "1:$AU_PRE"
_ST_OUT_HAS "naming the unmarked one" "AU plain – carries no fixup!, amend! or squash! marker"
_ST_OUT_HAS "and the one naming nothing" "fixup! AU nothing like it – names no commit below it"
_ST_PZ_NEW au-dup
_ST_PZ_C a a1 "AU dup"
_ST_PZ_C b b1 "AU dup"
_ST_PZ_C a a2 "fixup! AU dup"
_ST_RUN -s=auto HEAD
_ST_EQ "two commits matching alike refuse" "$RC" "1"
_ST_OUT_HAS "naming both" "names $(git rev-parse --short HEAD~1), $(git rev-parse --short HEAD~2) alike"
_ST_RUN -s=auto HEAD --text "AU given"
_ST_OUT_HAS "--text has no message to set" "--text and -m have none to set"
_ST_RUN -s=auto -m HEAD
_ST_EQ "nor -m" "$RC:$(git log -1 --format=%s)" "1:fixup! AU dup"
# The unpushed commits answer first – a pushed twin below leaves it unique
_ST_PZ_NEW au-pushed
_ST_PZ_C a a1 "AU pushed"
git update-ref refs/remotes/o/main HEAD
_ST_PZ_C b b1 "AU pushed"
_ST_PZ_C b b2 "fixup! AU pushed"
_ST_RUN -s=auto HEAD
_ST_EQ "an unpushed match wins over a pushed twin" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:b)" "0:AU pushed|AU pushed|:b2"
_ST_PZ_NEW au-pushed-only
_ST_PZ_C a a1 "AU pushed only"
git update-ref refs/remotes/o/main HEAD
_ST_PZ_C a a2 "fixup! AU pushed only"
_ST_RUN -s=auto HEAD
_ST_EQ "a target only pushed refuses" "$RC" "1"
_ST_OUT_HAS "as pushed" "already pushed"
_ST_RUN -s=auto --allow-pushed HEAD
_ST_EQ "--allow-pushed takes it" "$RC:$(git rev-list --count HEAD):$(git show HEAD:a)" "0:1:a2"
# Across a pause – a target stopping twice, its fixup adding a line, another clean beside it
_ST_PZ_NEW au-pause
print -l 1 2 > f && git add f && git commit -qm "AU base"
print -l t 2 > f && git commit -qam "AU target"
_ST_PZ_C g g1 "AU other"
print -l t l > f && git commit -qam "AU later"
print -l t a l > f && git commit -qam "amend! AU target" -m "AU target reworded across a pause"
_ST_PZ_C g g2 "squash! AU other"
git commit -q --amend -m "squash! AU other" -m "AU other note"
_ST_RUN -s=auto HEAD~1 HEAD
AU_WT=$(_ST_PZ_WT)
AU_STEPS=("t a 2" "t a l")
for AU_I in 1 2; do
	[[ "${OUT##*$'\n'}" == "git-edit: conflict"* ]] || break
	AU_STOPS=$AU_I
	print -l ${=AU_STEPS[AU_I]} > "${AU_WT:-$ST_NO_WT}/f" && git -C "${AU_WT:-$ST_NO_WT}" add f
	_ST_RUN --continue
done
_ST_EQ "each target takes its message once its pauses are through" \
	"$AU_STOPS:$RC:$(git log --format=%s | tr '\n' '|'):$(git log -1 --format=%B HEAD~1)" \
	"2:0:AU later|AU other|AU target reworded across a pause|AU base|:AU other"$'\n\n'"AU other note"
_ST_EQ "and the content stays the tip's" "$(git show HEAD:f | tr '\n' ' ')$(git show HEAD:g)" "t a l g2"
# A fixup replacing a line whose neighbors later commits changed resolves those stops itself
# – the target and each such commit taking its replacement, as a fold's stops do
_ST_PZ_NEW au-replace
print -l x1 "the comment" x3 > f && git add f && git commit -qm "AU replaced"
print -l y1 "the comment" y3 > f && git commit -qam "AU around it"
_ST_PZ_C g g1 "AU beside"
print -l y1 "the fixed comment" y3 > f && git commit -qam "fixup! AU replaced"
_ST_RUN -s=auto HEAD
_ST_EQ "a replacement resolves the stops it meets" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~2:f | tr '\n' ' '):$(git show HEAD:f | tr '\n' ' ')" \
	"0:AU beside|AU around it|AU replaced|:x1 the fixed comment x3 :y1 the fixed comment y3 "
_ST_OUT_HAS "saying so" "Made the fixups' line replacements at"
# A fixup whose replacements can't remake its own change, a line it replaced held twice, leaves
# only its files to the resolver – one adding a line to a conflicted file pauses its stop
_ST_PZ_NEW au-unproven
print -l x x > a && print -l y1 "the note" y3 > b && git add a b && git commit -qm "AU dup target"
print -l z1 "the note" z3 > b && git commit -qam "AU dup around"
print -l x X > a && git commit -qam "fixup! AU dup target"
print -l z1 "the fixed note" z3 > b && git commit -qam "fixup! AU dup target"
_ST_RUN -s=auto HEAD~1 HEAD
_ST_EQ "an unproven fixup's files aside, the stops resolve" \
	"$RC:$(git show HEAD~1:a | tr '\n' ' '):$(git show HEAD~1:b | tr '\n' ' '):$(git show HEAD:b | tr '\n' ' ')" \
	"0:x X :y1 the fixed note y3 :z1 the fixed note z3 "
# A stop between two fixups of one file takes the later one's alone, holding the earlier one's
_ST_PZ_NEW au-held
print -l y1 "the line" y3 f1 f2 f3 f4 f5 f6 f7 f8 q1 other q3 > f && git add f && git commit -qm "AU held target"
print -l y1 "the line" y3 f1 f2 f3 f4 f5 f6 f7 f8 q1 "other fixed" q3 > f && git commit -qam "fixup! AU held target"
print -l z1 "the line" z3 f1 f2 f3 f4 f5 f6 f7 f8 q1 "other fixed" q3 > f && git commit -qam "AU held around"
print -l z1 "the fixed line" z3 f1 f2 f3 f4 f5 f6 f7 f8 q1 "other fixed" q3 > f && git commit -qam "fixup! AU held target"
_ST_PZ_C g g1 "AU held later"
_ST_RUN -s=auto HEAD~3 HEAD~1
_ST_EQ "a stop past a fixup its commit holds resolves" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:f | sed -n '1,3p;13p' | tr '\n' ' ')" \
	"0:AU held later|AU held around|AU held target|:z1 the fixed line z3 other fixed "
_ST_PZ_NEW au-mixed
print -l y1 "the line" y3 > f && git add f && git commit -qm "AU mixed target"
print -l z1 "the line" z3 > f && git commit -qam "AU mixed around"
print -l z1 "the fixed line" z3 > f && git commit -qam "fixup! AU mixed target"
print -l z1 "the fixed line" added z3 > f && git commit -qam "fixup! AU mixed target"
_ST_RUN -s=auto HEAD~1 HEAD
_ST_EQ "a stop whose file a fixup adds a line to pauses" "$RC" "2"
_ST_OUT_HAS "at that fixup" "Currently failing on:"
_ST_RUN --abort
# A gate's pause – the resume lands the messages it set as they were, and a note on the target
# follows it on to the commit it became, the reword's map kept across the pause
_ST_PZ_NEW au-gate
git config notes.rewriteRef 'refs/notes/*'
_ST_PZ_C a a1 "AU gated"
git notes --ref=au add -m "AU meta" HEAD
_ST_PZ_C b b1 "AU after"
print a2 > a && git commit -qam "amend! AU gated" -m "AU gated reworded"
_ST_RUN -s=auto HEAD --verify="test -f '$TMP/au-gate-ok'"
_ST_EQ "a failing gate pauses" "$RC:$(git log -1 --format=%s HEAD)" "2:amend! AU gated"
: > "$TMP/au-gate-ok"
_ST_RUN --continue
_ST_EQ "and its resume lands the message set before it" "$RC:$(git log --format=%s | tr '\n' '|')" "0:AU after|AU gated reworded|"
_ST_EQ "its target's note on the commit it became" "$(git notes --ref=au show HEAD~1 2>&1)" "AU meta"
cd "$TMP/repo"
