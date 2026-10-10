# A whole file, a put or a staged fold holding a peer's landed lines word for word lands where
# the caller's edit sits on the line beside them – the merge conflicting there, and `diff -U0`
# folding the landed line into the caller's hunk – while one lacking a landed line, or holding
# one it removed, still refuses – each line counted as often as it occurs
_ST_SCENARIO "\e[1;96m[211] whole files holding a landing beside an edit land, ones lacking it refuse\e[0m"
local W211_TIP W211_OWN W211_PUT=$TMP/w211-put

# Commits <file> holding <before> unjournaled, then lands <after> on it as a peer
_W211_LAND () {
	# Args: <file> <before> <after>
	printf "$2" > "$1" && git add -- "$1" && git commit -qm "W211 base $1" -- "$1"
	printf "$3" > "$1"
	GIT_EDIT_ACTOR=w211-peer _ST_RUN --commit --text "W211 peer lands $1" -- "$1"
}
export GIT_EDIT_ACTOR=w211-self

# An edit on the line beside a peer's appended line
_W211_LAND w211-a.txt 'aitch\n' 'aitch\npeer h\n'
printf 'AITCH\npeer h\n' > w211-a.txt
W211_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "W211 mine beside the peer's" -- w211-a.txt
_ST_EQ "a whole file holding a peer's appended line, edited on the line beside it, lands" \
	"$RC:$(git show HEAD:w211-a.txt | tr '\n' ' '):$(git rev-parse HEAD~1)" "0:AITCH peer h :$W211_TIP"
_W211_LAND w211-b.txt 'bee\n' 'bee\npeer b\n'
printf 'BEE\npeer b\n' > "$W211_PUT"
git checkout -q -- w211-b.txt
_ST_RUN --commit --text "W211 put beside the peer's" --put="w211-b.txt=$W211_PUT"
_ST_EQ "as does a put" "$RC:$(git show HEAD:w211-b.txt | tr '\n' ' ')" "0:BEE peer b "
_W211_LAND w211-c.txt 'cee\n' 'cee\npeer c\n'
printf 'own\n' > w211-own.txt && git add w211-own.txt
_ST_RUN --commit --text "W211 own commit to fold into" -- w211-own.txt
W211_OWN=$(git rev-parse HEAD)
printf 'CEE\npeer c\n' > w211-c.txt && git add w211-c.txt
_ST_RUN --amend-into="$W211_OWN" -- w211-c.txt
_ST_EQ "and a staged fold" "$RC:$(git show HEAD:w211-c.txt | tr '\n' ' ')" "0:CEE peer c "

# An edit inside the landed line itself takes it back
_W211_LAND w211-d.txt 'dee\n' 'dee\npeer d\n'
printf 'DEE\npeer D!\n' > w211-d.txt
W211_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- w211-d.txt
_ST_OUT_HAS "a whole file holding the landed line edited still refuses" 'would take back what another caller landed: w211-d.txt'
printf 'DEE\npeer D!\n' > "$W211_PUT"
git checkout -q -- w211-d.txt
_ST_RUN --commit --text "x" --put="w211-d.txt=$W211_PUT"
_ST_OUT_HAS "as does such a put" 'would take back what another caller landed: w211-d.txt'
_ST_EQ "neither moving the branch" "$(git rev-parse HEAD)" "$W211_TIP"

# A multi-line landing kept in part
_W211_LAND w211-e.txt 'ee\n' 'ee\np1\np2\np3\n'
printf 'EE\np1\np3\n' > w211-e.txt
_ST_RUN --commit --text "x" -- w211-e.txt
_ST_OUT_HAS "a whole file keeping part of a multi-line landing refuses" 'would take back what another caller landed: w211-e.txt'
printf 'EE\np1\np2\np3\n' > w211-e.txt
_ST_RUN --commit --text "W211 all of a multi-line landing" -- w211-e.txt
_ST_EQ "one keeping all of it lands" "$RC:$(git show HEAD:w211-e.txt | tr '\n' ' ')" "0:EE p1 p2 p3 "

# A line the landing removed, put back beside an edit
_W211_LAND w211-f.txt 'one\ntwo\nthree\n' 'one\ntwo\n'
printf 'one\nTWO\nthree\n' > w211-f.txt
_ST_RUN --commit --text "x" -- w211-f.txt
_ST_OUT_HAS "a whole file holding a line the landing removed refuses" 'would take back what another caller landed: w211-f.txt'
printf 'one\nTWO\n' > w211-f.txt
_ST_RUN --commit --text "W211 beside a removal" -- w211-f.txt
_ST_EQ "one without it lands" "$RC:$(git show HEAD:w211-f.txt | tr '\n' ' ')" "0:one TWO "

# A landed line the file held before elsewhere counts by its occurrences
_W211_LAND w211-g.txt 'end\ngee\n' 'end\ngee\nend\n'
printf 'end\nGEE\n' > w211-g.txt
_ST_RUN --commit --text "x" -- w211-g.txt
_ST_OUT_HAS "a whole file holding a landed line only as often as before refuses" 'would take back what another caller landed: w211-g.txt'
printf 'end\nGEE\nend\n' > w211-g.txt
_ST_RUN --commit --text "W211 a repeated line kept" -- w211-g.txt
_ST_EQ "one holding it once more lands" "$RC:$(git show HEAD:w211-g.txt | tr '\n' ' ')" "0:end GEE end "
export GIT_EDIT_ACTOR=
