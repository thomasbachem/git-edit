# A squash's, a placement's or a move's stop of edits to touching lines, git refusing them as
# touching, resolves itself with each side's edits where its commits' line replacements can't
# – here as one adds a line between twins elsewhere, which the anchor rule leaves:
# • A squash's and a placement's landing with every commit holding its own change, the tip as it
#   began or was built – a move's own resolver still first
# • Never where both change one line or one spot, a side rewrites half the file, a changed line's
#   text is held twice or a line moves within the conflict – nor in a fold, a drop, an edit's
#   replay or a plain reorder, nor with self-resolution off
# • A file ending on blank lines, a heading's underline or a config fusing hunks, merging alike
_ST_SCENARIO "\e[1;96m[285] a stop of edits to touching lines resolves itself\e[0m"
local AJ_T AJ_A
local -a AJ_PAD=(p01 p02 p03 p04 p05 p06 p07 p08 p09 p10)

# Writes `f` as <lines>, comma-separated, between ten filler lines each side
_AJ_F () {
	# Args: <lines>
	print -l "${AJ_PAD[@]}" "${(@s:,:)1}" "${AJ_PAD[@]/p/q}" > f
}
# Prints `f`'s lines between the fillers at <rev> on one line
_AJ_AT () {
	# Args: <rev>
	local -a L=("${(@f)$(git show "${1}:f")}")
	print -rn -- "${(j: :)L[11,-11]} "
}
# Prints the last run's code and the commit its pause stopped at, as `code:subject`
_AJ_STOP () {
	print -rn -- "$RC:$(git -C "$(_ST_PZ_WT)" log -1 --format=%s REBASE_HEAD 2>/dev/null)"
}
# Makes repo <name>: a target writing <target> to `f`, a later commit making it <later>, then a
# fixup of the target making <fix> – each as `_AJ_F` takes it – sets `AJ_T` to the tip's tree
_AJ_SQUASH () {
	# Args: <name> <target> <later> <fix>
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	_AJ_F "$2" && git add f && git commit -qm "$1 target"
	_AJ_F "$3" && git commit -qam "$1 later"
	_AJ_F "$4" && git commit -qam "fixup! $1 target"
	AJ_T=$(git rev-parse 'HEAD^{tree}')
}

# A squash's stops, at its fixup and the later commit, each resolving itself
_AJ_SQUASH as "h,R,y,},},z" "h,R,y2,},},z" "h,R2,y2,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a squash whose stops are edits to touching lines lands, the tip as it was" "$RC:$(git rev-parse 'HEAD^{tree}')" "0:$AJ_T"
_ST_EQ "its target holding the fixup's lines beside its own" "$(_AJ_AT HEAD~1)" "h R2 y } new } z "
_ST_OUT_HAS "naming each stop so resolved" "Merged both sides' edits to touching lines of f at [0-9a-f]\{7\} fixup! as target"
_ST_OUT_HAS "the later commit's too" "Merged both sides' edits to touching lines of f at [0-9a-f]\{7\} as later"

# A placement's, its final step left to the tree it built
_ST_PZ_NEW ap
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && git add f && git commit -qm "ap base" && AJ_A=$(git rev-parse HEAD)
_AJ_F "h,R,y2,},},z" && git commit -qam "ap later"
_AJ_F "h,R2,y2,},new,},z"
_ST_RUN --commit --text "ap fix" --after="$AJ_A" -- f
_ST_EQ "a placement whose stop is edits to touching lines lands beside its anchor" \
	"$RC:$(git log --format=%s | tr '\n' ,):$(_AJ_AT HEAD)" "0:ap later,ap fix,ap base,:h R2 y2 } new } z "
_ST_EQ "the placed commit holding its own change" "$(_AJ_AT HEAD~1)" "h R2 y } new } z "
_ST_OUT_LACKS "never merging the final step" "Merged both sides' edits to touching lines of f at [0-9a-f]\{7\} ap later"

# A move past a commit editing the line beside its own lands as before, its own resolver first
_ST_PZ_NEW am
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && git add f && git commit -qm "am base"
_AJ_F "h,R,y2,},},z" && git commit -qam "am a"
_AJ_F "h,R2,y2,},new,},z" && git commit -qam "am b"
AJ_T=$(git rev-parse 'HEAD^{tree}')
_ST_RUN --move=HEAD --before=HEAD~1
_ST_EQ "a move across a commit editing the line beside its own lands, the tip as it was" \
	"$RC:$(git rev-parse 'HEAD^{tree}'):$(git log --format=%s -2 | tr '\n' ,)" "0:${AJ_T}:am a,am b,"
_ST_EQ "the moved commit holding its own change" "$(_AJ_AT HEAD~1)" "h R2 y } new } z "

# One line both change stops for the hand, as does one point both insert at, an insertion inside
# lines the other replaces, or beside one the other changes
_AJ_SQUASH ao "h,R,y,},},z" "h,R9,y,},},z" "h,R2,y,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a squash changing the line the later commit changes stops" "$(_AJ_STOP)" "2:fixup! ao target"
_ST_OUT_LACKS "never merged by line" "Merged both sides' edits"
_ST_RUN --abort
_AJ_SQUASH ai "h,R,old,y,},},z" "h,R,y,},},z" "h,R,F1,y,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup inserting where the target holds a line the later commit took out stops" "$(_AJ_STOP)" "2:fixup! ai target"
_ST_OUT_LACKS "never ordering the two" "Merged both sides' edits"
_ST_RUN --abort
_AJ_SQUASH ar "h,p,q,y,},},z" "h,pL,qL,y,},},z" "h,pL,mid,qL,y,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup inserting inside lines the later commit rewrites stops" "$(_AJ_STOP)" "2:fixup! ar target"
_ST_OUT_LACKS "never merging it beside them" "Merged both sides' edits"
_ST_RUN --abort
_AJ_SQUASH ib "h,m,q,y,},},z" "h,q,y,},},z" "h,qL,y,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup rewriting a line the target holds another just before stops" "$(_AJ_STOP)" "2:fixup! ib target"
_ST_OUT_LACKS "never merging the two" "Merged both sides' edits"
_ST_RUN --abort
_AJ_SQUASH it "h,R,y,},},z" "h,R,y2,},},z" "h,R,F1,y2,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup inserting just before a line the later commit rewrote stops" "$(_AJ_STOP)" "2:fixup! it target"
_ST_OUT_LACKS "never ordering the two" "Merged both sides' edits"
_ST_RUN --abort

# Nor where position alone would place a side's edit: a line whose text is held twice, a side
# rewriting half the file, a commit copying another file over this one or one writing a line anew
_ST_PZ_NEW ag
git config rerere.enabled false
print -l a1 a2 a3 a4 a5 a6 a7 "}" a8 a9 a10 a11 a12 a13 a14 R "}" "}" z > f && git add f && git commit -qm "ag target"
print -l b1 b2 b3 b4 b5 b6 b7 "}" b8 b9 b10 b11 b12 b13 b14 R "}" "}" z > f && git commit -qam "ag rewrites most"
print -l b1 b2 b3 b4 b5 b6 b7 "}" b8 b9 b10 b11 b12 b13 b14 R2 "}" new "}" z > f && git commit -qam "fixup! ag target"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup beside lines a later commit rewrote, most of the file split by one they share, stops" "$(_AJ_STOP)" "2:fixup! ag target"
_ST_OUT_LACKS "never merging across that rewrite" "Merged both sides' edits"
_ST_RUN --abort
# Nor a file holding a conflict marker's look-alike
_AJ_SQUASH mk "h,R,y,},},z,=======" "h,R,y2,},},z,=======" "h,R2,y2,},new,},z,======="
_ST_RUN -s=auto HEAD
_ST_EQ "a file holding a conflict marker's look-alike stops" "$(_AJ_STOP)" "2:fixup! mk target"
_ST_OUT_LACKS "never reading it as one" "Merged both sides' edits"
_ST_RUN --abort
# While a heading's underline, no marker line, merges as any line – here within the conflict
_AJ_SQUASH hd "h,Old title,=========,y,},},z" "h,Old title,=========,y2,},},z" "h,New title here,================,y2,},new,},z"
_ST_RUN -s=auto HEAD
_ST_EQ "a heading retitled beside a line the later commit edits lands, the tip as it was" "$RC:$(git rev-parse 'HEAD^{tree}')" "0:$AJ_T"
_ST_EQ "its target holding the new heading" "$(_AJ_AT HEAD~1)" "h New title here ================ y } new } z "
_ST_OUT_HAS "by touching lines" "Merged both sides' edits to touching lines of f at [0-9a-f]\{7\} fixup! hd target"
_AJ_SQUASH at "h,R,y,},},z,R" "h,R,y2,},},z,R" "h,R2,y2,},new,},z,R"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup of a line held twice stops" "$(_AJ_STOP)" "2:fixup! at target"
_ST_OUT_LACKS "never placing it by position" "Merged both sides' edits"
_ST_RUN --abort
_ST_PZ_NEW ac
git config rerere.enabled false
print -l h0 P l1 l2 l3 l4 l5 l6 l7 l8 > f && git add f && git commit -qm "ac target"
print -l k1 k2 k3 k4 k5 k6 k7 k8 k9 P > f && git commit -qam "ac copies over it"
print -l k1 k2 k3 k4 k5 k6 k7 k8 k9 Q > f && git commit -qam "fixup! ac target"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup past a commit rewriting the whole file stops" "$(_AJ_STOP)" "2:fixup! ac target"
_ST_OUT_LACKS "never landing its line on the newcomer's" "Merged both sides' edits"
_ST_RUN --abort
_ST_PZ_NEW aw
git config rerere.enabled false
_AJ_F "foo,k26,k17,t,k5" && git add f && git commit -qm "aw target"
_AJ_F "foo,k26,k11,t,k5,k17" && git commit -qam "aw moves"
_AJ_F "k26,k11,foo,k5,k17" && git commit -qam "aw writes anew"
_AJ_F "k26,k11,FOO,k5,k17" && git commit -qam "fixup! aw target"
_ST_RUN -s=auto HEAD
_ST_EQ "a fixup of a line written anew beside a moved one stops" "$(_AJ_STOP)" "2:fixup! aw target"
_ST_OUT_LACKS "never taking the moved line for the old" "Merged both sides' edits"
_ST_RUN --abort

# Nor in a fold, a drop or an edit's replay, none refusing a tip off the one it began with – each
# stop here before the last, which a fold's staged tree would resolve
_ST_PZ_NEW af
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && git add f && git commit -qm "af target" && AJ_A=$(git rev-parse HEAD)
_AJ_F "h,R,y2,},},z" && git commit -qam "af later"
_ST_PZ_C g g1 "af last"
_AJ_F "h,R2,y2,},new,},z" && git add f
_ST_RUN --amend-into="$AJ_A" -- f
_ST_RESOLVE "$(_ST_PZ_WT)" f "$(print -l "${AJ_PAD[@]}" h R2 y "}" new "}" z "${AJ_PAD[@]/p/q}")"
_ST_RUN --continue
_ST_EQ "a fold's resume past its own stop stops at the later commit's" "$(_AJ_STOP)" "2:af later"
_ST_OUT_LACKS "merging nothing by line" "Merged both sides' edits"
_ST_RUN --abort
git checkout -q -- f
_ST_PZ_NEW ad
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && git add f && git commit -qm "ad base"
_AJ_F "h,R2,y,},new,},z" && git commit -qam "ad dropped"
_AJ_F "h,R2,y2,},new,},z" && git commit -qam "ad later"
_ST_RUN -d HEAD~1 --yes
_ST_EQ "a drop past a commit editing the line beside the dropped one's stops" "$(_AJ_STOP)" "2:ad later"
_ST_OUT_LACKS "merging nothing by line" "Merged both sides' edits"
_ST_RUN --abort
# Nor a plain reorder's resume, which pauses as its first run does
_ST_PZ_NEW ro
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && git add f && git commit -qm "ro base"
_AJ_F "h,R,y2,},},z" && git commit -qam "ro a"
_AJ_F "h,R2,y2,},new,},z" && git commit -qam "ro b"
_ST_PZ_C g g1 "ro c"
_ST_RUN --reorder HEAD~1 HEAD~2 HEAD
_ST_RESOLVE "$(_ST_PZ_WT)" f "$(print -l "${AJ_PAD[@]}" h R2 y "}" new "}" z "${AJ_PAD[@]/p/q}")"
_ST_RUN --continue
_ST_EQ "a plain reorder's resume stops at the next commit's" "$(_AJ_STOP)" "2:ro a"
_ST_OUT_LACKS "merging nothing by line" "Merged both sides' edits"
_ST_RUN --abort
_ST_PZ_NEW ae
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && git add f && git commit -qm "ae target"
_AJ_F "h,R,y2,},},z" && git commit -qam "ae later"
_ST_PZ_C g g1 "ae last"
_ST_RUN HEAD~2
_AJ_F "h,R2,y,},new,},z" > /dev/null && cp f "$(_ST_PZ_WT)/f" && git checkout -q -- f
_ST_RUN --continue
_ST_EQ "an edit's replay past a commit editing the line beside its own stops" "$(_AJ_STOP)" "2:ae later"
_ST_OUT_LACKS "merging nothing by line" "Merged both sides' edits"
_ST_RUN --abort

# Nor a file not ending on a line end, nor any where self-resolution is off
_ST_PZ_NEW an
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && print -n end >> f && git add f && git commit -qm "an target"
_AJ_F "h,R,y2,},},z" && print -n end >> f && git commit -qam "an later"
_AJ_F "h,R2,y2,},new,},z" && print -n end >> f && git commit -qam "fixup! an target"
_ST_RUN -s=auto HEAD
_ST_OUT_LACKS "a file not ending on a line end merges nothing by line" "Merged both sides' edits"
_ST_RUN --abort
_AJ_SQUASH ax "h,R,y,},},z" "h,R,y2,},},z" "h,R2,y2,},new,},z"
GIT_EDIT_NO_SELF_RESOLVE=1 _ST_RUN -s=auto HEAD
_ST_EQ "with self-resolution off, the touching lines stop" "$(_AJ_STOP)" "2:fixup! ax target"
_ST_RUN --abort

# A file ending on blank lines keeps them
_ST_PZ_NEW ab
git config rerere.enabled false
_AJ_F "h,R,y,},},z" && print -l "" "" >> f && git add f && git commit -qm "ab target"
_AJ_F "h,R,y2,},},z" && print -l "" "" >> f && git commit -qam "ab later"
_AJ_F "h,R2,y2,},new,},z" && print -l "" "" >> f && git commit -qam "fixup! ab target"
AJ_T=$(git rev-parse 'HEAD^{tree}')
_ST_RUN -s=auto HEAD
_ST_EQ "a file ending on blank lines lands with them, its target too" "$RC:$(git rev-parse 'HEAD^{tree}'):$(git rev-parse HEAD~1:f)" \
	"0:${AJ_T}:$(_AJ_F "h,R2,y,},new,},z" && print -l "" "" >> f && git hash-object f)"
git checkout -q -- f
# And a config fusing hunks across lines both leave alone – the later commit's two around the
# fixup's pair, which one fused hunk would take as overlapping it
_AJ_SQUASH ah "h,p,a,b,q,y,},},z" "h,P,a,b,Q,y,},},z" "h,P,a2,b3,Q,y,},new,},z"
git config diff.interHunkContext 2
_ST_RUN -s=auto HEAD
_ST_EQ "a config fusing hunks merges each line alike" "$RC:$(git rev-parse 'HEAD^{tree}'):$(_AJ_AT HEAD~1)" "0:${AJ_T}:h p a2 b3 q y } new } z "
_ST_OUT_HAS "by touching lines" "Merged both sides' edits to touching lines of f"

unfunction _AJ_F _AJ_AT _AJ_STOP _AJ_SQUASH
cd "$TMP/repo"
