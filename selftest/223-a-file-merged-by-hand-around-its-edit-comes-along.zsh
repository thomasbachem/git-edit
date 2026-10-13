# A file a landing left unbrought, merged by hand since, comes along – its edit kept on a line that
# landing changed:
# • `--status` names it no more, and the next landing brings it along, a rename's source too
# • So does a file a commit was composed from, edited again on a committed line, that commit's
#   own run naming no conflict – and a landing the checkout missed, merged by hand since
# • A file a commit took part of, its committed line edited again or undone, comes along as it is
# • One left as it was keeps its record, as does one whose edit rewrote all the landing changed,
#   which reads the same on either base
_ST_SCENARIO "\e[1;96m[223] a file merged by hand around its edit comes along\e[0m"
local HM_X

# Makes and enters repo <name>: `f` of ten lines and `u` of four committed, `f`'s line 3 edited,
# then a peer's landing of lines 3 and 7, which records `f`
_HM223_REPO () {
	# Args: <name> [<line 7 as the landing leaves it>] [<command running the landing>]
	_ST_PZ_NEW "$1"
	print -l {1..10} > f && print -l u{1..4} > u && git add f u && git commit -qm "HM base"
	HM_X=$(git rev-parse HEAD)
	print -l 1 2 3-mine {4..10} > f
	GIT_EDIT_ACTOR=hm-a ${3:-_ST_RUN} --exec -- sh -c "printf '%s\n' 1 2 3-L1 4 5 6 ${2:-7-L1} 8 9 10 > f && git commit -qam 'HM L1'"
}
# Lands a peer's change of `f`'s line 10
_HM223_L2 () {
	GIT_EDIT_ACTOR=hm-b _ST_RUN --exec -- sh -c "git show HEAD:f | sed 's/^10\$/10-L2/' > f.new && mv f.new f && git commit -qam 'HM L2'"
}

# Merged by hand, the edit kept on the line the landing changed – once, the record stood for its 7
# days, every landing on the file merging from its base and conflicting there
_HM223_REPO hm1
_ST_EQ "a landing conflicting with the edit records the file" "$(sed -n 3p f):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "3-mine:f"
print -l 1 2 3-L1-mine 4 5 6 7-L1 8 9 10 > f
_ST_RUN --status
_ST_OUT_LACKS "merged by hand, its edit kept on the landed line, --status names it no more" "Left unbrought"
_ST_OUT_HAS "--status ran" "no operation in flight"
_HM223_L2
_ST_EQ "the next landing brings it along, the edit kept" "$RC:$(tr '\n' ' ' < f)" "0:1 2 3-L1-mine 4 5 6 7-L1 8 9 10-L2 "
_ST_OUT_LACKS "naming no conflict" "conflict with what landed"
_ST_EQ "the record cleared" "$([ -s .git/git-edit-unbrought ] && echo recorded)" ""

# One left as it was keeps its record, the next landing merging from its base
_HM223_REPO hm2
_HM223_L2
_ST_EQ "one left as it was keeps its record, the next landing leaving it too" \
	"$RC:$(tr '\n' ' ' < f):$(cut -d' ' -f5 .git/git-edit-unbrought 2>/dev/null)" "0:1 2 3-mine 4 5 6 7 8 9 10 :$HM_X"
_ST_OUT_HAS "named with the merge from its base" "--filters ${HM_X:0:12}:f > "

# One whose edit rewrote all the landing changed reads the same on either base, so the record stands
_HM223_REPO hm3 7
print -l 1 2 3-L1-mine {4..10} > f
_HM223_L2
_ST_EQ "one whose edit rewrote all the landing changed keeps its record" \
	"$RC:$(sed -n 10p f):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "0:10:f"

# A file a commit was composed from, edited again on a committed line, comes along at the next
# landing – a part standing as it landed tells, though the file held it before
_ST_PZ_NEW hm6
print -l {1..10} > f && git add f && git commit -qm "HM base"
print -l 1 2 3-A-more 4 5 6 7-A 8 9 10 > f
_ST_RUN --commit --text "HM own" --edits='{"f": [["3\n", "3-A\n"], ["7\n", "7-A\n"]]}'
_ST_EQ "a commit from the file, edited again on a committed line, leaves it recorded" \
	"$RC:$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "0:f"
_ST_OUT_LACKS "its own run naming no conflict" "conflict with what landed"
_HM223_L2
_ST_EQ "the next landing brings it along, the later edit kept" \
	"$RC:$(tr '\n' ' ' < f):$([ -s .git/git-edit-unbrought ] && echo recorded)" "0:1 2 3-A-more 4 5 6 7-A 8 9 10-L2 :"

# A landing the checkout missed, its sync unable to run, merged by hand since around the edit, comes
# along at the next landing – the walk over missed landings reading it as a record's file reads
_HM223_REPO hm7 "" _ST_RUN_UNSYNCED
print -l 1 2 3-L1-mine 4 5 6 7-L1 8 9 10 > f
_HM223_L2
_ST_EQ "a landing the checkout missed, merged by hand since, comes along at the next one" \
	"$RC:$(tr '\n' ' ' < f):$([ -s .git/git-edit-unbrought ] && echo recorded)" "0:1 2 3-L1-mine 4 5 6 7-L1 8 9 10-L2 :"

# Makes and enters repo <name>: `f` committed, then a commit of its line 3 beside a peer's line 9
_HM223_PART () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l {1..10} > f && git add f && git commit -qm "HM base"
	print -l 1 2 3-A {4..8} 9-peer 10 > f
	_ST_RUN --commit --text "HM part" --edits='{"f": [["3\n", "3-A\n"]]}'
}
# Lands a peer's change of `f`'s line 6
_HM223_L6 () {
	GIT_EDIT_ACTOR=hm-b _ST_RUN --exec -- sh -c "git show HEAD:f | sed 's/^6\$/6-L/' > f.new && mv f.new f && git commit -qam 'HM L6'"
}

# A file a commit took part of, recorded holding it, then edited again on the committed line or
# undone there, takes the next landing – all that differs since that record came after the commit
_HM223_PART hm8
_ST_EQ "a commit of part of a file records it, holding what it committed" "$RC:$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "0:f"
print -l 1 2 3-A-more {4..8} 9-peer 10 > f
_ST_RUN --status
_ST_OUT_LACKS "its committed line edited again, --status names it no more" "Left unbrought"
_ST_OUT_HAS "--status ran" "no operation in flight"
_HM223_L6
_ST_EQ "and the next landing brings it along, the edit kept" \
	"$RC:$(tr '\n' ' ' < f):$([ -s .git/git-edit-unbrought ] && echo recorded)" "0:1 2 3-A-more 4 5 6-L 7 8 9-peer 10 :"
_ST_OUT_LACKS "naming no conflict" "conflict with what landed"
_HM223_PART hm9
print -l 1 2 3 {4..8} 9-peer 10 > f
_HM223_L6
_ST_EQ "its committed line undone stays undone, the next landing brought along" \
	"$RC:$(tr '\n' ' ' < f):$([ -s .git/git-edit-unbrought ] && echo recorded)" "0:1 2 3 4 5 6-L 7 8 9-peer 10 :"

# A rename's source merged by hand comes along to the new name
_HM223_REPO hm4
print -l 1 2 3-L1-mine 4 5 6 7-L1 8 9 10 > f
GIT_EDIT_ACTOR=hm-b _ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'HM rename'"
_ST_EQ "a rename's source merged by hand comes along to the new name, the record cleared" \
	"$RC:$(tr '\n' ' ' < h 2>/dev/null):$([ -e f ] && echo f):$([ -s .git/git-edit-unbrought ] && echo recorded)" \
	"0:1 2 3-L1-mine 4 5 6 7-L1 8 9 10 ::"
