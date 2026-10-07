# --snapshot merges a fold into each commit from its target, a conflict once
# A later commit rewrote the line beside the fold, which a replay would stop at, and a move since
# takes the fold under the file's old name – one resolution serves every commit with that content
_ST_SCENARIO "\e[1;96m[111] --snapshot merges a fold into each commit, stopping once per content\e[0m"
printf 'a\nb\nc\nd\ne\nf\ng\nh\ni\n' > sn.txt && git add sn.txt && git commit -qm "SN target"
local SN_T=$(git rev-parse HEAD)
echo x > sn-other.txt && git add sn-other.txt && git commit -qm "SN unrelated"
printf 'a\nb\nc\nd\ne\nf\ng\nh\nI\n' > sn.txt && git commit -qam "SN tail"
printf 'a\nb\nc\nD\ne\nf\ng\nh\nI\n' > sn.txt && git commit -qam "SN beside"
mkdir -p sn-dir && git mv sn.txt sn-dir/sn.txt && git commit -qm "SN move"
printf 'a\nb\nc\nD\ne\nf\ng\nH\nI\n' > sn-dir/sn.txt && git commit -qam "SN far"
local SN_TIP=$(git rev-parse HEAD) SN_AUTHORS=$(git log -6 --format='%an %ae %aI %s')
_ST_RUN --snapshot
_ST_OUT_HAS "--snapshot alone is refused" 'only applies to --amend-into'
printf 'a\nb\nC\nD\ne\nf\ng\nH\nI\n' > sn-dir/sn.txt && git add sn-dir/sn.txt
_ST_RUN --amend-into="$SN_T" --snapshot --text="SN reworded" -- sn-dir/sn.txt
_ST_OUT_HAS "as is --text with it" 'takes no --text'
# A git before 2.40 has no `merge-tree --merge-base`, so --snapshot refuses there, naming it – and
# the tool's own probe has to say the same, or a broken one turns these checks into the refusal's
_ST_EQ "the tool's merge-tree probe answers as git does" "$(_MERGE_TREE_TAKES_BASE && echo yes)" "$(_ST_MERGE_BASE_OK && echo yes)"
if _ST_MERGE_BASE_OK; then
	_ST_RUN --amend-into="$SN_T" --snapshot -- sn-dir/sn.txt
	_ST_EQ "a conflict beside the fold pauses" "$RC" "2"
	_ST_OUT_HAS "at the oldest commit it reaches" 'at: [0-9a-f]* SN target'
	local SN_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	_ST_CHECK "laid out as a merge's conflict" test -n "$(git -C "${SN_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null)"
	_ST_RUN --status
	_ST_OUT_HAS "which --status reports as one" "git-edit: conflict – resolve in ${SN_WT:-$ST_NO_WT} (sn.txt)"
	_ST_RUN --continue
	_ST_OUT_HAS "a continue with it unresolved is refused" 'Unresolved paths remain'
	git -C "${SN_WT:-$ST_NO_WT}" add sn.txt
	_ST_RUN --continue
	_ST_OUT_HAS "as is one staging its markers" 'still contains conflict markers'
	printf 'a\nb\nC\nd\ne\nf\ng\nh\ni\n' > "${SN_WT:-$ST_NO_WT}/sn.txt" && git -C "${SN_WT:-$ST_NO_WT}" add sn.txt
	_ST_RUN --continue
	_ST_EQ "the commit sharing its content takes the resolution, the next content stops" "$RC" "2"
	_ST_OUT_HAS "at the next one" 'at: [0-9a-f]* SN tail'
	_ST_EQ "pre-filled by rerere" "$(cat "${SN_WT:-$ST_NO_WT}/sn.txt" 2>/dev/null)" "$(printf 'a\nb\nC\nd\ne\nf\ng\nh\nI')"
	git -C "${SN_WT:-$ST_NO_WT}" add sn.txt
	_ST_RUN --continue
	_ST_EQ "and the fold lands" "$RC" "0"
	_ST_EQ "into the target" "$(git show HEAD~5:sn.txt)" "$(printf 'a\nb\nC\nd\ne\nf\ng\nh\ni')"
	_ST_EQ "the commit sharing its content" "$(git show HEAD~4:sn.txt)" "$(printf 'a\nb\nC\nd\ne\nf\ng\nh\ni')"
	_ST_EQ "every later one, the move's old path included" "$(git show HEAD~2:sn.txt)" "$(printf 'a\nb\nC\nD\ne\nf\ng\nh\nI')"
	_ST_EQ "and the tip" "$(git show HEAD:sn-dir/sn.txt)" "$(printf 'a\nb\nC\nD\ne\nf\ng\nH\nI')"
	_ST_EQ "each commit keeps its author, date and subject" "$(git log -6 --format='%an %ae %aI %s')" "$SN_AUTHORS"
	_ST_CHECK "and the staged fold is consumed" git diff --cached --quiet -- sn-dir/sn.txt
	# Away from every later change, a fold merges clean throughout
	local SN_T2=$(git rev-parse HEAD~5)
	printf 'A\nb\nC\nD\ne\nf\ng\nH\nI\n' > sn-dir/sn.txt && git add sn-dir/sn.txt
	_ST_RUN --amend-into="$SN_T2" --snapshot -- sn-dir/sn.txt
	_ST_EQ "a fold clear of them lands at once" "$RC:$(git show HEAD~5:sn.txt | head -1):$(git show HEAD:sn-dir/sn.txt | head -1)" "0:A:A"
	local SN_BEFORE=$(git rev-parse HEAD)
	printf 'A\nb\nCC\nD\ne\nf\ng\nH\nI\n' > sn-dir/sn.txt && git add sn-dir/sn.txt
	_ST_RUN --amend-into="$(git rev-parse HEAD~5)" --snapshot -- sn-dir/sn.txt
	_ST_RUN --abort
	_ST_EQ "an abort leaves the branch" "$RC:$(git rev-parse HEAD)" "0:$SN_BEFORE"
	_ST_CHECK "and the fold staged" test -n "$(git diff --cached --name-only -- sn-dir/sn.txt)"
	git reset -q -- sn-dir/sn.txt && git checkout -q -- sn-dir/sn.txt
	# A deletion meeting the fold has no one text to resolve
	echo y > sn-other.txt && git add sn-other.txt
	_ST_RUN --amend-into="$(git rev-parse HEAD~5)" --snapshot --allow-new-path -- sn-other.txt
	_ST_EQ "a conflict not over content refuses" "$RC:$(git rev-parse HEAD)" "1:$SN_BEFORE"
	_ST_OUT_HAS "naming it" 'not over its content'
	git reset -q -- sn-other.txt && git checkout -q -- sn-other.txt
	# A commit whose change the fold overwrites is left empty and named, one empty before is not
	local SN_E=$(git rev-parse HEAD)
	git commit -q --allow-empty -m "SN empty"
	printf 'A\nB\nC\nD\ne\nf\ng\nH\nI\n' > sn-dir/sn.txt && git commit -qam "SN redundant"
	printf 'A\nX\nC\nD\ne\nf\ng\nH\nI\n' > sn-dir/sn.txt && git add sn-dir/sn.txt
	_ST_RUN --amend-into="$SN_E" --snapshot -- sn-dir/sn.txt
	SN_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	printf 'A\nX\nC\nD\ne\nf\ng\nH\nI\n' > "${SN_WT:-$ST_NO_WT}/sn-dir/sn.txt" && git -C "${SN_WT:-$ST_NO_WT}" add sn-dir/sn.txt
	_ST_RUN --continue
	_ST_OUT_HAS "a commit the fold overwrote is named as left empty" 'left empty by the fold: [0-9a-f]* SN redundant'
	_ST_OUT_LACKS "while one empty before is not" 'left empty by the fold: [0-9a-f]* SN empty'
	# A failed check pauses with the result built – a continue checks again, `--no-verify` applies it
	printf 'A\nX\nC\nD\ne\nf\ng\nH\nZ\n' > sn-dir/sn.txt && git add sn-dir/sn.txt
	local SN_PRE=$(git rev-parse HEAD)
	_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --snapshot --verify="! grep -q '^Z\$' sn-dir/sn.txt" -- sn-dir/sn.txt
	_ST_EQ "a failed check pauses with nothing applied" "$RC:$(git rev-parse HEAD)" "2:$SN_PRE"
	_ST_OUT_HAS "as a verify pause" 'git-edit: paused – verify failed'
	_ST_RUN --continue
	_ST_EQ "a continue checks again" "$RC" "2"
	_ST_RUN --no-verify --continue
	_ST_EQ "and --no-verify applies it" "$RC:$(git show HEAD~1:sn-dir/sn.txt | tail -1)" "0:Z"
else
	_ST_RUN --amend-into="$SN_T" --snapshot -- sn-dir/sn.txt
	_ST_OUT_HAS "below git 2.40 it refuses, naming the version it needs" 'needs git 2.40 or later'
	git reset -q -- sn-dir/sn.txt && git checkout -q -- sn-dir/sn.txt
fi
