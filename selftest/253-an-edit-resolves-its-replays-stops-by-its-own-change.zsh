# An edit's replay resolves its stops as a fold's does, the change from the paused commit
# to what it became playing the fold's – on the continue that amends it, and on a resume
# past a stop resolved by hand – while a stop its replacements can't make, or the switch, pauses
_ST_SCENARIO "\e[1;96m[253] an edit resolves its replay's stops by its own change\e[0m"
local ER_T ER_WT ER_F ER_G ER_K
local -a ER_A ER_B
# Commits a line, a commit rewriting another file's first line, one rewriting the line's
# neighbors and one beside – sets `ER_T`, then pauses the edit of the first
_ER_PAUSED () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l x1 "the comment" x3 > f && print -l h1 h2 > h && git add f h && git commit -qm "ER target"
	ER_T=$(git rev-parse HEAD)
	print -l "h1 other" h2 > h && git commit -qam "ER h"
	print -l y1 "the comment" y3 > f && git commit -qam "ER around it"
	_ST_PZ_C g g1 "ER beside"
	_ST_RUN "$ER_T"
	ER_WT=$(_ST_PZ_WT)
}
# Prints <rev>'s `f` on one line
_ER_AT () {
	# Args: <rev>
	git show "$1:f" | tr '\n' '|'
}

_ER_PAUSED er
print -l x1 "the fixed comment" x3 > "$ER_WT/f"
_ST_RUN --continue
_ST_EQ "the continue amending it lands, the stop it met resolved" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_ER_AT HEAD~3):$(_ER_AT HEAD~1)" \
	"0:ER beside|ER around it|ER h|ER target|:x1|the fixed comment|x3|:y1|the fixed comment|y3|"
_ST_OUT_HAS "saying so" "Made the edit's line replacements in the 1 commit(s) the replay stopped at"

# A stop its replacements can't make pauses, and the resume goes on resolving those after it
_ER_PAUSED er-resume
print -l x1 "the fixed comment" x3 > "$ER_WT/f" && print -l "h1 changed" h2 > "$ER_WT/h"
_ST_RUN --continue
_ST_EQ "a stop on a line both rewrote pauses" "$RC:$(git -C "$ER_WT" diff --name-only --diff-filter=U | tr '\n' ' ')" "2:h "
print -l "h1 changed other" h2 > "$ER_WT/h" && git -C "$ER_WT" add h
_ST_RUN --continue
_ST_EQ "its resume lands, the next stop resolved" \
	"$RC:$(_ER_AT HEAD~1):$(git show HEAD:h | tr '\n' '|')" "0:y1|the fixed comment|y3|:h1 changed other|h2|"
_ST_OUT_HAS "saying so" "Made the edit's line replacements in the 1 later commit(s)"

# The switch leaves every stop to the resolver
_ER_PAUSED er-off
print -l x1 "the fixed comment" x3 > "$ER_WT/f"
OUT=$(GIT_EDIT_NO_SELF_RESOLVE=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null 2>&1)
RC=$?
_ST_EQ "GIT_EDIT_NO_SELF_RESOLVE leaves an edit's stop" "$RC:$(git -C "$ER_WT" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# Pauses an edit whose change a later commit may have shifted, rewritten or moved onto a neighbor
# – its final step as much as any, which no tree proves – by editing a target and continuing
_ER_REWRITTEN () {
	# Args: <repo name> <target's lines> <later commit's lines> <edited lines>
	_ST_PZ_NEW "$1"
	print -l ${(s:|:)2} > f && git add f && git commit -qm "ER target"
	ER_T=$(git rev-parse HEAD)
	print -l ${(s:|:)3} > f && git commit -qam "ER rewrites"
	_ST_RUN "$ER_T"
	print -l ${(s:|:)4} > "$(_ST_PZ_WT)/f"
	_ST_RUN --continue
}
_ER_REWRITTEN er-shifted "foo|baz" "bar|foo" "qux|baz"
_ST_EQ "an edit follows its line where the next commit's own change only shifted it" \
	"$RC:$(_ER_AT HEAD~1):$(_ER_AT HEAD)" "0:qux|baz|:bar|qux|"
_ER_REWRITTEN er-pairs "1|a|b|a|z" "1|a|z" "X|A|b|a|z"
_ST_EQ "but pauses where another line of its text beside that change could as well pair" \
	"$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ER_REWRITTEN er-pairs-far "h|P|a|a|b|a" "H|P|a|a|a|b" "h|Q|A|a|b|a"
_ST_EQ "as does one past a line of its text beyond that change's next hunk" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ER_REWRITTEN er-pairs-braces $'// head|\tx = 1|}|}|\tcall()|}' $'// head v2|\tx = 1|}|}|}|\tcall()' $'// head|\tx = 2|};|}|\tcall()|}'
_ST_EQ "a closing brace among them alike" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ER_REWRITTEN er-pairs-words "top|h P a a b a|end" "top|H P a a a b|end" "top|h P A a b a|end"
_ST_EQ "and a word past one of its text beyond that line's next word hunk" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# A CRLF line's words read as its LF twin's – a removed line holding all of a moved one's pauses
_ST_PZ_NEW er-crlf-words
git config core.autocrlf false
printf 'w0\r\ny a\r\na y a b\r\na\r\ntail\r\n' > f && git add f && git commit -qm "ER target"
ER_T=$(git rev-parse HEAD)
printf 'w0\r\ny\r\na a b\r\ny a\r\na\r\ntail\r\n' > f && git commit -qam "ER moves words"
_ST_PZ_C g g1 "ER beside"
_ST_RUN "$ER_T"
printf 'w0\r\nY2 a\r\na y a b\r\na\r\ntail\r\n' > "$(_ST_PZ_WT)/f"
_ST_RUN --continue
_ST_EQ "a CRLF line beside a removed one holding all its words pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# A commit swapping two files, each its own diff a rewrite as git's break detection reads it
_ST_PZ_NEW er-swap
ER_F=$'h0\nP\n' ER_G=''
for ER_T in {1..30}; do ER_F+="line of f number $ER_T"$'\n' ER_G+="other g text $ER_T"$'\n'; done
ER_G+=$'P\n'
print -rn -- "$ER_F" > f && print -rn -- "$ER_G" > g && git add f g && git commit -qm "ER target"
ER_T=$(git rev-parse HEAD)
print -rn -- "${ER_F/h0/h1}" > g && print -rn -- "$ER_G" > f && git commit -qam "ER swaps the files"
_ST_PZ_C x x1 "ER beside"
_ST_RUN "$ER_T"
print -rn -- "${ER_F/P/Q}" > "$(_ST_PZ_WT)/f"
_ST_RUN --continue
_ST_EQ "an edit across a commit swapping its file with another pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# Swapping two files too small for git to break, or copying one it leaves
# alone over its own, keeps one coincident line of ten – which pauses as well
for ER_K in swap copy; do
	_ST_PZ_NEW er-small-$ER_K
	print -l h0 P l1 l2 l3 l4 l5 l6 l7 l8 > f && print -l k1 k2 k3 k4 k5 k6 k7 k8 k9 P > g && git add f g && git commit -qm "ER small target"
	ER_T=$(git rev-parse HEAD)
	[ $ER_K = swap ] && cp f h
	cp g f && { [ $ER_K = copy ] || mv h g; } && git commit -qam "ER small $ER_K"
	_ST_PZ_C x x1 "ER small beside"
	_ST_RUN "$ER_T"
	print -l h0 Q l1 l2 l3 l4 l5 l6 l7 l8 > "$(_ST_PZ_WT)/f"
	_ST_RUN --continue
	_ST_EQ "an edit across a small file's $ER_K pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
	_ST_RUN --abort
done
# A swap only the CRs git skips in CRLF lines make a rewrite pauses as well, while its LF
# twin, no rewrite to git, lands the edit where its unchanged line stays
for ER_K in $'\r\n' $'\n'; do
	_ST_PZ_NEW er-eol-swap-${#ER_K}
	git config core.autocrlf false
	ER_A=() ER_B=()
	for ER_T in {1..150}; do
		ER_F=${(#)$(( 97 + (ER_T - 1) / 26 ))}${(#)$(( 97 + (ER_T - 1) % 26 ))}
		ER_A+=($ER_F)
		(( ER_T % 5 == 1 )) && ER_B+=(${ER_F:u}) || ER_B+=($ER_F)
	done
	print -rn -- "${(pj::)${(@)ER_A/%/$ER_K}}" > f && print -rn -- "${(pj::)${(@)ER_B/%/$ER_K}}" > g && git add f g && git commit -qm "ER eol target"
	ER_T=$(git rev-parse HEAD)
	print -rn -- "${(pj::)${(@)ER_B/%/$ER_K}}" > f && print -rn -- "${(pj::)${(@)ER_A/%/$ER_K}}" > g && git commit -qam "ER eol swap"
	_ST_PZ_C x x1 "ER eol beside"
	_ST_RUN "$ER_T"
	ER_A[50]=EDITED
	print -rn -- "${(pj::)${(@)ER_A/%/$ER_K}}" > "$(_ST_PZ_WT)/f"
	_ST_RUN --continue
	if (( ${#ER_K} == 2 )); then
		_ST_EQ "an edit across a CRLF swap pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
		_ST_RUN --abort
	else
		_ST_EQ "its LF twin lands" "$RC:$(git show HEAD~1:f | grep -c EDITED)" "0:1"
	fi
done
# A rename git pairs by likeness is never weighed for a rewrite, however heavily edited
_ST_PZ_NEW er-rename-heavy
ER_A=(h0 P) ER_B=(h1 P)
for ER_T in {1..60}; do
	ER_A+=("body line number $ER_T of the file")
	(( ER_T * 100 / 60 < 45 )) && ER_B+=("rewritten $ER_T entirely") || ER_B+=("body line number $ER_T of the file")
done
print -rl -- "${ER_A[@]}" > f && git add f && git commit -qm "ER rename target"
ER_T=$(git rev-parse HEAD)
git mv f g && print -rl -- "${ER_B[@]}" > g && git add g && git commit -qm "ER renames and rewrites"
_ST_PZ_C x x1 "ER rename beside"
_ST_RUN "$ER_T"
ER_A[2]=Q
print -rl -- "${ER_A[@]}" > "$(_ST_PZ_WT)/f"
_ST_RUN --continue
_ST_EQ "an edit across a heavily edited rename resolves" "$RC:$(git show HEAD~1:g | sed -n 2p)" "0:Q"
_ER_REWRITTEN er-relocated "1|foo|3|4|baz|6" "1|bar|3|4|foo|6" "1|qux|3|4|baz|6"
_ST_EQ "as does one whose text the next commit wrote elsewhere" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ER_REWRITTEN er-neighbor "p alpha beta delta q|z alpha beta gamma w" "p alpha beta gamma q|z alpha beta delta w" "p alpha BETA delta q|z alpha beta gamma w"
_ST_EQ "and one whose changed words a neighbor holds" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# Followed through each commit's own change – a later commit writing
# the text anew, after another moved the lines between, never takes the edit
_ST_PZ_NEW er-anew
print -l k4 k24 foo k16 k26 k0 > f && git add f && git commit -qm "ER target"
ER_T=$(git rev-parse HEAD)
print -l k26 k24 foo k16 k0 k5 > f && git commit -qam "ER moves"
print -l foo k26 k24 t k16 k0 k5 > f && git commit -qam "ER writes anew"
_ST_RUN "$ER_T"
print -l k4 k24 FOO k16 k26 k0 > "$(_ST_PZ_WT)/f"
_ST_RUN --continue
_ST_EQ "an edit whose line a later commit wrote anew pauses there" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
unfunction _ER_PAUSED _ER_AT _ER_REWRITTEN
cd "$TMP/repo"
