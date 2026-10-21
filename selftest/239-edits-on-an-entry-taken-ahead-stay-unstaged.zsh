# A file a sync's merge leaves as it is is staged whole only where nothing is unstaged – edits past
# an entry taken ahead stay changes to that:
# • A landing the checkout missed, its entry taken ahead and its file edited past that, keeps the
#   edits unstaged as the next landing's sync brings the checkout along
# • The same edits staged whole stay staged so
_ST_SCENARIO "\e[1;96m[239] edits on an entry taken ahead stay unstaged\e[0m"
local SU_ADD
for SU_ADD in "" 1; do
	_ST_PZ_NEW "su${SU_ADD:+-staged}"
	print -l l{1..6} > f && print -l g{1..6} > g && git add f g && git commit -qm "SU base"
	_ST_RUN_UNSYNCED --commit --text "SU L1" --edits='{"f": [["l2\n", "L2\n"]]}'
	# Its entry taken ahead to what landed, its file restored from that and edited
	git reset -q -- f && git checkout -- f
	print -l l1 L2 l3 l4 E5 l6 > f
	[ -n "$SU_ADD" ] && git add f
	_ST_RUN --commit --text "SU L2" --edits='{"g": [["g1\n", "D1\n"]]}'
	_ST_EQ "${SU_ADD:+staged: }a sync over edits on an entry taken ahead leaves the file as it is" \
		"$RC:$(sed -n 1p g):$(tr '\n' ' ' < f)" "0:D1:l1 L2 l3 l4 E5 l6 "
	_ST_OUT_HAS "${SU_ADD:+staged: }naming the file it wrote alone" '^Your checkout came along – now as they landed: g$'
	if [ -z "$SU_ADD" ]; then
		_ST_EQ "its entry left on what landed, the edits unstaged" \
			"$(git rev-parse :f):$(git status --porcelain | tr '\n' ' ')" "$(git rev-parse HEAD:f): M f "
	else
		_ST_EQ "staged whole, they stay staged so" \
			"$(git cat-file -p :f | tr '\n' ' '):$(git status --porcelain | tr '\n' ' ')" "l1 L2 l3 l4 E5 l6 :M  f "
	fi
done
cd "$TMP/repo"
