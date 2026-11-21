# A tag `edit.followTag` names stays at the cut it marks, `--at` landing commits inside it:
# • A reorder below it leaves it on top of what it held, its own commit moved or squashed down
# • A commit moved across it held back or taken in as the move put it, said – on a tie its own
# • `--commit`, `--exec` and `--move` with `--at` taking the tag onto the newest placed with the
#   branch, an annotated one re-made – resumed from a pause too, and put back by `--undo`
# • `--after` its commit leaving a new commit above it, said, as landing at the tip does
# • Refused for a tag no value names or one off the branch, beside `--after` or in another mode,
#   and where the tag moved while the run built, nothing landed
_ST_SCENARIO "\e[1;96m[286] a cut tag stays at the cut\e[0m"
# Makes repo <name> of commits <subject>..., each writing a file of its name, `cut-1` on <cut>
_CT_REPO () {
	# Args: <name> <cut> <subject>...
	local CUT=$2 S
	_ST_PZ_NEW "$1"
	git config edit.followTag 'cut-*'
	shift 2
	for S in "$@"; do
		_ST_PZ_C "$S.txt" "$S" "$S"
		[ "$S" = "$CUT" ] && git tag cut-1
	done
}
# Prints the branch's subjects oldest first, the cut's commit marked with a `*`
_CT_LINE () {
	local C CUT=$(git rev-parse -q --verify 'cut-1^{commit}')
	local -a L
	for C in ${(f)"$(git rev-list --reverse HEAD)"}; do
		L+=("$(git log -1 --format=%s "$C")")
		[ "$C" = "$CUT" ] && L[-1]+="*"
	done
	print -rn -- "${(j: :)L}"
}
# Prints the commit of subject <subject> on the branch
_CT_ID () {
	# Args: <subject>
	git log --format=%H --grep="^$1\$" HEAD
}

# A reorder below the cut leaves it on top of what it held, whichever commit moved
_CT_REPO ct-swap FEATURES CHANGELOG bump FEATURES release
_ST_RUN --move="$(_CT_ID FEATURES)" --before="$(_CT_ID bump)"
_ST_EQ "the cut's own commit moved down, the cut stays on top of what it held" "$RC:$(_CT_LINE)" "0:CHANGELOG FEATURES bump* release"
_ST_OUT_HAS "saying where it went" "^Tag cut-1 followed the rewrite, .* to where the cut now falls, as the run reordered what it held\$"
_CT_REPO ct-swap2 FEATURES CHANGELOG bump FEATURES release
_ST_RUN --move="$(_CT_ID bump)" --after="$(_CT_ID FEATURES)"
_ST_EQ "a commit below it moved up past its commit keeping its side" "$RC:$(_CT_LINE)" "0:CHANGELOG FEATURES bump* release"

# A commit moved across the cut goes as the move put it, named – on a tie the cut keeps its commit
_CT_REPO ct-out C A B C H I
_ST_RUN --move="$(_CT_ID B)" --after="$(_CT_ID H)"
_ST_EQ "one moved above a held commit is held back" "$RC:$(_CT_LINE)" "0:A C* H B I"
_ST_OUT_HAS "named as no longer held" "^Tag cut-1's commit no longer holds the change of what this run moved above it: B\$"
_CT_REPO ct-in C A B C H I
_ST_RUN --move="$(_CT_ID H)" --before="$(_CT_ID B)"
_ST_EQ "one moved below a commit of the cut is taken in" "$RC:$(_CT_LINE)" "0:A H B C* I"
_ST_OUT_HAS "named as now held" "^Tag cut-1's commit now holds the change of what this run moved or squashed below it: H\$"
_CT_REPO ct-tie C A B C H I
_ST_RUN --move="$(_CT_ID I)" --before="$(_CT_ID C)"
_ST_EQ "one moved right below the cut's commit is taken in, the cut kept" "$RC:$(_CT_LINE)" "0:A B I C* H"
_CT_REPO ct-own C A B C H I
_ST_RUN --move="$(_CT_ID C)" --after="$(_CT_ID H)"
_ST_EQ "the cut's commit moved above a held one takes the cut with it, on the tie" "$RC:$(_CT_LINE)" "0:A B H C* I"
# A tie its own commit is no part of goes to the lower one, holding back rather than taking in
_CT_REPO ct-low C Z A B C H
_ST_RUN --reorder "$(_CT_ID C)" "$(_CT_ID A)" "$(_CT_ID H)" "$(_CT_ID B)"
_ST_EQ "a reorder tying two cuts takes the lower" "$RC:$(_CT_LINE)" "0:Z C A* H B"

# A split of the cut's own commit keeps both halves inside it
_ST_PZ_NEW ct-split
git config edit.followTag 'cut-*'
_ST_PZ_C A.txt A A && print x > x.txt && print y > y.txt && git add x.txt y.txt && git commit -qm XY && git tag cut-1 && _ST_PZ_C H.txt H H
_ST_RUN --split="$(git rev-parse cut-1)" --text="X half" -- x.txt
_ST_EQ "a split of the cut's commit keeps both halves inside it" "$RC:$(_CT_LINE)" "0:A X half XY* H"

# A fixup at the cut squashed down leaves the cut on top of what stays, not on its target
_ST_PZ_NEW ct-squash
git config edit.followTag 'cut-*'
_ST_PZ_C Z.txt Z Z && _ST_PZ_C A.txt A A && _ST_PZ_C B.txt B B && _ST_PZ_C A.txt A2 "fixup! A" && git tag cut-1 && _ST_PZ_C H.txt H H
_ST_RUN -s=auto "$(_CT_ID 'fixup! A')"
_ST_EQ "a squashed fixup at the cut leaves it on the commit below" "$RC:$(_CT_LINE)" "0:Z A B* H"

# `--at` lands a commit as the cut's last, the tag moving with the branch – `--undo` putting it back
_CT_REPO ct-at C A B C H
print L > L.txt
_ST_RUN --commit --text L --at=cut-1 -- L.txt
_ST_EQ "a commit --at the cut lands as its last" "$RC:$(_CT_LINE)" "0:A B C L* H"
_ST_OUT_HAS "saying the tag took in it" "^Tag cut-1 took in what this run placed after its commit, [0-9a-f]\{12\} → $(git rev-parse --short=12 HEAD~1)\$"
_ST_OUT_LACKS "never naming its own branch as still holding the old commit" "^Tag cut-1 no longer marks its old commit"
_ST_RUN --move="$(_CT_ID L)" --after="$(_CT_ID A)"
_ST_EQ "moved down, the cut stays on top of what it held" "$RC:$(_CT_LINE)" "0:A L B C* H"
_ST_RUN --undo
_ST_EQ "undone, the tag goes back with the branch" "$RC:$(_CT_LINE)" "0:A B C L* H"
_ST_RUN --undo
_ST_EQ "and with the landing undone, back on the commit it marked" "$RC:$(_CT_LINE)" "0:A B C* H"
_ST_OUT_HAS "saying so" "^Tag cut-1 back on "

# `--after` the cut's commit lands above it, as the tip does, said with what takes it in
_CT_REPO ct-after B A B H
print N > N.txt
_ST_RUN --commit --text N --after=cut-1 -- N.txt
_ST_EQ "a commit --after the cut lands above it" "$RC:$(_CT_LINE)" "0:A B* N H"
_ST_OUT_HAS "saying it is held back" "^Lands above the cut cut-1 marks, held back – --at=cut-1 lands it as the cut's last commit\$"
_CT_REPO ct-tip B A B
print N > N.txt
_ST_RUN --commit --text N -- N.txt
_ST_EQ "one landing at the tip above a cut there stays above it" "$RC:$(_CT_LINE)" "0:A B* N"
_ST_OUT_LACKS "no tag moving" "^Tag cut-1"

# An annotated cut is re-made on the commit, a tag no value names left as it was
_ST_PZ_NEW ct-ann
git config edit.followTag 'cut-*'
_ST_PZ_C A.txt A A && _ST_PZ_C B.txt B B && git tag -a -m "the cut" cut-1 && git tag v1 && _ST_PZ_C H.txt H H
print N > N.txt
_ST_RUN --commit --text N --at=cut-1 -- N.txt
_ST_EQ "an annotated cut is re-made on it, its message kept" "$RC:$(git cat-file -t cut-1):$(git for-each-ref --format='%(contents:subject)' refs/tags/cut-1):$(_CT_LINE)" "0:tag:the cut:A B N* H"
_ST_EQ "a tag no value names stays" "$(git rev-parse v1)" "$(_CT_ID B)"

# `--exec` and `--move` take `--at` as `--commit` does
_CT_REPO ct-exec B A B H
_ST_RUN --exec --dry-run --at=cut-1 -- sh -c 'echo E > E.txt && git add E.txt && git commit -qm E'
_ST_OUT_HAS "a dry run's landing named as leaving the cut below" "^That leaves cut-1 below what this run placed – run it again without --dry-run for --at to take it in\$"
_ST_RUN --exec --at=cut-1 -- sh -c 'echo E > E.txt && git add E.txt && git commit -qm E'
_ST_EQ "an --exec's commit --at the cut lands as its last" "$RC:$(_CT_LINE)" "0:A B E* H"
_CT_REPO ct-move B A B H X
_ST_RUN --move="$(_CT_ID X)" --at=cut-1
_ST_EQ "a commit moved --at the cut lands as its last" "$RC:$(_CT_LINE)" "0:A B X* H"
_ST_OUT_HAS "named as now held" "^Tag cut-1's commit now holds the change of what this run moved or squashed below it: X\$"

# Refused, nothing done – no cut, one off the branch, beside `--after`, in another mode
_CT_REPO ct-refuse B A B H
git tag v1 "$(_CT_ID A)"
git checkout -q -b side "$(_CT_ID A)" && _ST_PZ_C S.txt S S && git tag cut-s && git checkout -q main
CT_TIP=$(git rev-parse HEAD)
print N > N.txt
_ST_RUN --commit --text N --at=v1 -- N.txt
_ST_EQ "a tag no value names is no cut" "$RC:$(git rev-parse HEAD)" "1:$CT_TIP"
_ST_OUT_HAS "saying so" "^git-edit: error – --at=v1 names no cut – it takes a tag edit.followTag names"
_ST_RUN --commit --text N --at=cut-s -- N.txt
_ST_EQ "nor one off the branch" "$RC:$(git rev-parse HEAD)" "1:$CT_TIP"
_ST_OUT_HAS "saying so" "^git-edit: error – --at=cut-s marks [0-9a-f]\{12\}, which this branch doesn't hold – nothing was done\$"
_ST_RUN --commit --text N --at=cut-1 --after="$(_CT_ID A)" -- N.txt
_ST_EQ "nor beside --after" "$RC:$(git rev-parse HEAD)" "1:$CT_TIP"
_ST_OUT_HAS "saying so" "^git-edit: error – Take one of --at=<cut>, --after=<sha> or --before=<sha>, not several\$"
_ST_RUN -M --text=x --at=cut-1 "$(_CT_ID A)"
_ST_EQ "nor in a mode placing nothing" "$RC:$(git rev-parse HEAD)" "1:$CT_TIP"
_ST_OUT_HAS "saying so" "^git-edit: error – --after/--before/--at only apply to --move, --commit and --exec\$"

# A signed one refuses, as a run can't move it – up front, or at the landing re-made so meanwhile
printf 'CT signed\n-----BEGIN PGP SIGNATURE-----\n\nCT\n-----END PGP SIGNATURE-----\n' > "$TMP/ct-sig"
git tag -a -F "$TMP/ct-sig" cut-signed "$(_CT_ID B)"
_ST_RUN --commit --text N --at=refs/tags/cut-signed -- N.txt
_ST_EQ "a signed cut refuses, named by its full ref too" "$RC:$(git rev-parse HEAD)" "1:$CT_TIP"
_ST_OUT_HAS "saying so" "^git-edit: error – --at=refs/tags/cut-signed is signed or tags a tag, which a run can't move without losing what it holds – nothing was done\$"
git config edit.verifyCmd "git tag -f -a -F $TMP/ct-sig cut-1 $(_CT_ID B) >/dev/null 2>&1"
_ST_RUN --commit --text N --at=cut-1 -- N.txt
_ST_EQ "a cut re-made signed while it built lands nothing" "$RC:$(git rev-parse HEAD)" "1:$CT_TIP"
_ST_OUT_HAS "saying so" "^git-edit: error – Tag cut-1 can't take in what this run placed after [0-9a-f]\{12\} – a moved copy would lose its signature – nothing was applied\$"
git tag -f cut-1 "$(_CT_ID B)" >/dev/null

# The tag moved while the run built fails the branch's transaction with it
git config edit.verifyCmd "git tag -f cut-1 $(_CT_ID A) >/dev/null 2>&1"
_ST_RUN --commit --text N --at=cut-1 -- N.txt
_ST_EQ "a tag moved meanwhile lands nothing" "$RC:$(git rev-parse HEAD):$(git rev-parse 'cut-1^{commit}')" "1:$CT_TIP:$(_CT_ID A)"
_ST_OUT_HAS "saying so" "^git-edit: error – Tag cut-1 moved while this run built, by another run or by hand – nothing was applied, so run it again\$"
git config --unset edit.verifyCmd

# A pause keeps the cut, its resume reading the tag as it stands then
_CT_REPO ct-gate B A B H X
git config edit.verifyCmd "test -e $TMP/ct-ok"
_ST_RUN --move="$(_CT_ID X)" --at=cut-1
_ST_EQ "a move --at the cut its gate fails pauses" "$RC" "2"
: >"$TMP/ct-ok"
_ST_RUN --continue
_ST_EQ "resumed, it lands as the cut's last" "$RC:$(_CT_LINE)" "0:A B X* H"
rm -f "$TMP/ct-ok"
_CT_REPO ct-gate2 B A B H X
git config edit.verifyCmd "test -e $TMP/ct-ok"
_ST_RUN --move="$(_CT_ID X)" --at=cut-1
_ST_EQ "paused again" "$RC" "2"
git tag -f cut-1 "$(_CT_ID A)" >/dev/null
: >"$TMP/ct-ok"
_ST_RUN --continue
_ST_EQ "a cut moved while it paused stays where it was put" "$RC:$(_CT_LINE)" "0:A* B X H"
_ST_OUT_HAS "saying so" "^Tag cut-1 no longer marks [0-9a-f]\{12\}, which this run places its commits after – it stays where it is now\$"
rm -f "$TMP/ct-ok"
git config --unset edit.verifyCmd

# A placement paused on a conflict lands as the cut's last once resumed
_ST_PZ_NEW ct-stop
git config edit.followTag 'cut-*'
printf 'a\nb\nc\n' > F.txt && git add F.txt && git commit -qm A && _ST_PZ_C B.txt B B && git tag cut-1
printf 'a\nb\nh\n' > F.txt && git add F.txt && git commit -qm H
printf 'a\nb\nh\nn\n' > F.txt
_ST_RUN --commit --text N --at=cut-1 -- F.txt
_ST_EQ "a placement --at the cut its replay can't place pauses" "$RC:$(git log -1 --format=%s REBASE_HEAD 2>/dev/null; git -C "$(_ST_PZ_WT)" log -1 --format=%s REBASE_HEAD)" "2:N"
printf 'a\nb\nc\nn\n' > "$(_ST_PZ_WT)/F.txt" && git -C "$(_ST_PZ_WT)" add F.txt
_ST_RUN --continue
_ST_EQ "resolved and resumed, it lands as the cut's last" "$RC:$(_CT_LINE)" "0:A B N* H"

unfunction _CT_REPO _CT_LINE _CT_ID
cd "$TMP/repo"
