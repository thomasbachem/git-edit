# The landings guard judges an edit landed with a rename as an edit, and a staged fold's remedy
# stages nothing but the caller's own:
# • A landing that edits a file and renames it in one move – one commit, or a `--land` of an edit
#   then a rename – is named on its old name where a file moved to the new name by hand lacks the
#   edit, committed whole, folded `--whole` or staged – followed as printed, every edit stays
# • A file of the caller's own in the renamed file's place keeps the addition's remedy, and one
#   carried as the landing said lands
# • A staged fold's remedy says to stage the checkout file again only where it holds just what was
#   staged – else it rebuilds the staging alone, what landed merged in, at the entry's own mode, or,
#   where that conflicts, names a replay with `--edits` – followed as printed, another caller's
#   unstaged line never lands
_ST_SCENARIO "\e[1;96m[193] whole files judge a renaming edit, a staged fold's remedy restages only its own\e[0m"
local GA_T GA_CMD GA_I GA_C1 GA_IDX GA_REB
# Follows a printed command step by step – its `git edit` steps through `_ST_RUN`, the rest as
# printed – stopping at a step that fails
_GA_FOLLOW () {
	# Args: <command as printed>
	local STEP
	local -a W
	for STEP in "${(@s: && :)1}"; do
		W=("${(@Q)${(z)STEP}}")
		if [ "${W[1]} ${W[2]}" = "git edit" ]; then
			_ST_RUN "${(@)W[3,-1]}"
			[ "$RC" = 0 ] || return 1
		else
			eval "$STEP" || return 1
		fi
	done
}
# The lines a file holds of what the caller, the landing and a bystander put there
_GA_KEPT () {
	# Args: <file content>
	LC_ALL=C grep -cE 'A-EDIT| B$|alice' <<<"$1"
}
# Makes a repo whose `f` a peer edits on line 8 and renames to `h` in one commit, while the caller
# holds an edit on line 1 – left untracked at `f`, as the landing reconciles it
_GA_SETUP () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l "f line "{1..20} > f && print -r -- x > t && git add -A && git commit -qm "GA base"
	print -l "f line "{1..7} "f line 8 B" "f line "{9..20} > "$TMP/$1-h"
	print -l "f line 1 A-EDIT" "f line "{2..20} > f
	GIT_EDIT_ACTOR=ga-b _ST_RUN --exec -- sh -c "git mv f h && cat ${(q)TMP}/$1-h > h && git commit -qam 'GA B'"
}

# A file moved to the new name by hand, committed whole or folded `--whole`, lacks the edit landed
# with the rename – refused on its old name, with the move back and the carry, which land both
for GA_I in commit whole; do
	_GA_SETUP ga1-$GA_I
	GA_T=$(git rev-parse HEAD~1)
	_ST_EQ "an edit and a rename land as one move ($GA_I)" "$RC:$(git show HEAD:h | sed -n 8p):$([ -e f ] && print f)" "0:f line 8 B:f"
	mv f h
	if [ $GA_I = commit ]; then
		GIT_EDIT_ACTOR=ga-a _ST_RUN --commit --text "GA A" -- h
	else
		_ST_PZ_C t y "GA target" && GA_T=$(git rev-parse HEAD)
		GIT_EDIT_ACTOR=ga-a _ST_RUN --amend-into="$GA_T" --whole -- h
	fi
	_ST_EQ "the file taken whole without the edit refuses ($GA_I)" "$RC:$(git show HEAD:h | sed -n 8p)" "1:f line 8 B"
	_ST_OUT_HAS "naming the landing on the old name ($GA_I)" "^ *h – ga-b's exec run .* ago ([0-9a-f]*\.\.[0-9a-f]*), on its old name f$"
	_ST_OUT_HAS "with the move back and the carry from before it ($GA_I)" \
		"where the carry takes the edits from, with: \[ ! -e f \] && \[ ! -L f \] && mv -- h f && git edit --carry=[0-9a-f]\{12\} – then run this again\.$"
	GA_CMD=$(sed -n 's/.*where the carry takes the edits from, with: \(.*\) – then run this again\.$/\1/p' <<<"$OUT")
	GIT_EDIT_ACTOR=ga-a _GA_FOLLOW "$GA_CMD"
	_ST_EQ "followed as printed, the checkout holds both edits at the new name ($GA_I)" "$?:$(_GA_KEPT "$(<h)"):$([ -e f ] && print f)" "0:2:"
	if [ $GA_I = commit ]; then
		GIT_EDIT_ACTOR=ga-a _ST_RUN --commit --text "GA A" -- h
	else
		GIT_EDIT_ACTOR=ga-a _ST_RUN --amend-into="$GA_T" --whole -- h
	fi
	_ST_EQ "and taken whole again, it lands keeping the landing ($GA_I)" "$RC:$(_GA_KEPT "$(git show HEAD:h)")" "0:2"
done

# Staged so, a fold names the unstaging, the move back and the carry, then the staging again,
# the checkout holding just what was staged – followed as printed, both edits fold
_GA_SETUP ga2
_ST_PZ_C t y "GA target" && GA_T=$(git rev-parse HEAD)
mv f h && git add h
GIT_EDIT_ACTOR=ga-a _ST_RUN --amend-into="$GA_T" -- h
_ST_EQ "a staged fold without the edit refuses" "$RC" "1"
_ST_OUT_HAS "naming the landing on the old name" "^ *h – ga-b's exec run .*, on its old name f$"
_ST_OUT_HAS "with the unstaging, the move back and the carry" \
	"which leaves the rest of the staging as it is, with: git restore --staged -- h && \[ ! -e f \] && \[ ! -L f \] && mv -- h f && git edit --carry=[0-9a-f]\{12\}$"
_ST_OUT_HAS "and the staging again" "^  Then stage them again with: git add -- h (each holding just what you staged) – and run this again\.$"
GA_CMD=$(sed -n 's/.*which leaves the rest of the staging as it is, with: //p' <<<"$OUT")
GA_REB=$(sed -n 's/^  Then stage them again with: \(.*\) (each holding just what you staged) – and run this again\.$/\1/p' <<<"$OUT")
GIT_EDIT_ACTOR=ga-a _GA_FOLLOW "$GA_CMD" && eval "$GA_REB"
GIT_EDIT_ACTOR=ga-a _ST_RUN --amend-into="$GA_T" -- h
_ST_EQ "followed as printed, the fold keeps the landing" "$RC:$(_GA_KEPT "$(git show HEAD:h)")" "0:2"

# A `--land` of an edit, then a rename, is one move – judged the same, and followed it lands
_ST_PZ_NEW ga3
print -l "f line "{1..20} > f && print -r -- x > t && git add -A && git commit -qm "GA3 base"
GA_C1=$(_ST_COMPOSE f "$(print -l "f line "{1..7} "f line 8 B" "f line "{9..20})")
GA_IDX="$TMP/ga3-index"
rm -f "$GA_IDX"
GIT_INDEX_FILE=$GA_IDX git read-tree "$GA_C1"
GIT_INDEX_FILE=$GA_IDX git update-index --force-remove f
GIT_INDEX_FILE=$GA_IDX git update-index --add --cacheinfo "100644,$(git rev-parse "$GA_C1:f"),h"
git branch ga3b "$(git commit-tree "$(GIT_INDEX_FILE=$GA_IDX git write-tree)" -p "$GA_C1" -m "GA3 rename")"
print -l "f line 1 A-EDIT" "f line "{2..20} > f
GIT_EDIT_ACTOR=ga-b _ST_RUN --land=ga3b
_ST_EQ "a land of an edit then a rename lands both" "$RC:$(git log --format=%s -2 | tr '\n' '|')" "0:GA3 rename|composed|"
mv f h
GIT_EDIT_ACTOR=ga-a _ST_RUN --commit --text "GA3 A" -- h
_ST_EQ "the file committed whole without the edit refuses" "$RC" "1"
_ST_OUT_HAS "naming the land on the old name" "^ *h – ga-b's land run .*, on its old name f$"
GA_CMD=$(sed -n 's/.*where the carry takes the edits from, with: \(.*\) – then run this again\.$/\1/p' <<<"$OUT")
GIT_EDIT_ACTOR=ga-a _GA_FOLLOW "$GA_CMD"
GIT_EDIT_ACTOR=ga-a _ST_RUN --commit --text "GA3 A" -- h
_ST_EQ "followed as printed, the file lands keeping the land" "$RC:$(_GA_KEPT "$(git show HEAD:h)")" "0:2"

# A file of the caller's own in the renamed file's place keeps the addition's remedy, and one
# carried as the landing said, so holding the edit, lands
_GA_SETUP ga4
GA_CMD=$(sed -n 's/^Merge those edits onto the new content with: //p' <<<"$OUT")
print -l "own "{1..20} > h
GIT_EDIT_ACTOR=ga-a _ST_RUN --commit --text "GA4 A" -- h
_ST_EQ "a file of the caller's own in its place refuses" "$RC" "1"
_ST_OUT_HAS "as one standing where another caller added one" "Your own h stands where another caller added one"
_ST_OUT_LACKS "never on the old name" "on its old name"
rm -f h
GIT_EDIT_ACTOR=ga-a _GA_FOLLOW "$GA_CMD"
GIT_EDIT_ACTOR=ga-a _ST_RUN --commit --text "GA4 A" -- h
_ST_EQ "one carried as the landing said lands" "$RC:$(_GA_KEPT "$(git show HEAD:h)")" "0:2"

# Another caller's unstaged line in a file staged for a fold: the remedy rebuilds the staging alone,
# the bit kept, never staging the checkout file whole – followed as printed, that line never lands
for GA_I in alice alone; do
	_ST_PZ_NEW gb1-$GA_I
	print -l "doc line "{1..40} > doc && chmod +x doc && print -r -- x > t && git add -A && git commit -qm "GB base"
	_ST_PZ_C t y "GB target" && GA_T=$(git rev-parse HEAD)
	print -l "doc line "{1..29} "doc line 30 bob" "doc line "{31..40} > doc && git add doc
	[ $GA_I = alice ] && print -l "doc line "{1..9} "doc line 10 alice" "doc line "{11..29} "doc line 30 bob" "doc line "{31..40} > doc
	GIT_EDIT_ACTOR=gb-cy _ST_RUN --commit --text "GB cy" --edits '{"doc": [["doc line 4\n", "doc line 4 cy\n"]]}'
	GIT_EDIT_ACTOR=gb-bob _ST_RUN --amend-into="$GA_T" -- doc
	_ST_EQ "a staged fold without the landing refuses ($GA_I)" "$RC" "1"
	GA_C1=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
	if [ $GA_I = alice ]; then
		_ST_OUT_LACKS "with another caller's line in the checkout, no 'git add' of it" "git add --"
		_ST_OUT_HAS "but the staging rebuilt alone, at the entry's mode" \
			"^  Then rebuild the staging of doc alone, what landed merged in, as the checkout holds more than you staged there, which 'git add' would take in too: git cat-file blob .* && git merge-file -- .* && git update-index --add --cacheinfo 100755,\$(git hash-object -w --no-filters -- .*),doc; rm -f .* – and run this again\.$"
		GA_REB=$(sed -n "s/^  Then rebuild the staging of doc alone, .*, which 'git add' would take in too: \\(.*\\) – and run this again\\.\$/\\1/p" <<<"$OUT")
		# Else whatever stages it again – once, a `git add` of the checkout file took in alice's line
		[ -n "$GA_REB" ] || GA_REB=$(sed -n 's/^  Then stage them again with: \(.*\) (.*$/\1/p' <<<"$OUT")
	else
		_ST_OUT_HAS "the checkout holding just the staging, the staging again ($GA_I)" \
			"^  Then stage them again with: git add -- doc (each holding just what you staged) – and run this again\.$"
		_ST_OUT_LACKS "and no rebuild ($GA_I)" "rebuild the staging"
		GA_REB=$(sed -n 's/^  Then stage them again with: \(.*\) (each holding just what you staged) – and run this again\.$/\1/p' <<<"$OUT")
	fi
	GIT_EDIT_ACTOR=gb-bob _ST_RUN "$GA_C1"
	_ST_EQ "the carry named merges the landing into the checkout ($GA_I)" "$RC:$(LC_ALL=C grep -c 'cy$' doc)" "0:1"
	eval "$GA_REB"
	_ST_EQ "the staging then holds the landing and bob's line alone ($GA_I)" \
		"$?:$(git diff --cached -- doc | LC_ALL=C grep -c '^+doc'):$(git show :doc | LC_ALL=C grep -cE 'cy$|bob$|alice$'):$(git ls-files -s -- doc | cut -c1-6)" "0:1:2:100755"
	GIT_EDIT_ACTOR=gb-bob _ST_RUN --amend-into="$GA_T" -- doc
	_ST_EQ "the fold then lands bob's line beside the landing, the bit kept ($GA_I)" \
		"$RC:$(git show HEAD:doc | LC_ALL=C grep -cE 'cy$|bob$'):$(git ls-tree HEAD -- doc | cut -c1-6)" "0:2:100755"
	_ST_EQ "another caller's line never lands, staying in the checkout ($GA_I)" \
		"$(git log --format=%h -S'alice' | wc -l | tr -d ' '):$(LC_ALL=C grep -c 'alice$' doc)" "0:$([ $GA_I = alice ] && print 1 || print 0)"
done

# The staging conflicting with what landed, a rebuild can't be printed – a replay with `--edits` is
# named instead, which then lands bob's change alone
_ST_PZ_NEW gb2
print -l "doc line "{1..40} > doc && print -r -- x > t && git add -A && git commit -qm "GB2 base"
print -l "doc line "{1..4} "doc line 5 bob" "doc line "{6..40} > doc && git add doc
print -l "doc line "{1..4} "doc line 5 bob" "doc line "{6..29} "doc line 30 alice" "doc line "{31..40} > doc
GIT_EDIT_ACTOR=gb-cy _ST_RUN --commit --text "GB2 cy" --edits '{"doc": [["doc line 6\n", "doc line 6 cy\n"]]}'
# Past the landing, so the replay onto it rebuilds no commit holding the line beside
print -r -- y > t && git commit -qm "GB2 target" -- t && GA_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=gb-bob _ST_RUN --amend-into="$GA_T" -- doc
_ST_EQ "a staged fold conflicting with the landing refuses" "$RC" "1"
_ST_OUT_HAS "naming a replay with --edits" \
	"^  The checkout holds more than you staged in doc, which 'git add' would take in too, and what landed can't be merged into the staging alone – replay your change onto the tip with --edits or --patch instead, which read neither, then drop the staging it leaves behind with: git restore --staged -- doc$"
_ST_OUT_LACKS "never a 'git add' of it" "git add --"
_ST_OUT_LACKS "nor a rebuild" "rebuild the staging"
GA_CMD=$(sed -n 's/.*then drop the staging it leaves behind with: //p' <<<"$OUT")
GIT_EDIT_ACTOR=gb-bob _ST_RUN --amend-into="$GA_T" --edits '{"doc": [["doc line 5\n", "doc line 5 bob\n"]]}'
_ST_EQ "the replay named lands bob's change beside the landing, never another caller's line" \
	"$RC:$(git show HEAD:doc | LC_ALL=C grep -cE 'cy$|bob$'):$(git log --format=%h -S'alice' | wc -l | tr -d ' ')" "0:2:0"
eval "$GA_CMD"
_ST_EQ "and the staging dropped as printed, nothing staged takes the landing back" "$?:$(git diff --cached --name-only)" "0:"

# Staged over a file renamed with an edit, with another caller's line beside: the unstaging, the
# move back and the carry, then the staging rebuilt alone – followed, that line never lands
_GA_SETUP gb3
_ST_PZ_C t y "GB3 target" && GA_T=$(git rev-parse HEAD)
mv f h && git add h
print -l "f line 1 A-EDIT" "f line "{2..14} "f line 15 alice" "f line "{16..20} > h
GIT_EDIT_ACTOR=ga-a _ST_RUN --amend-into="$GA_T" -- h
_ST_EQ "a staged fold over the renaming edit refuses" "$RC" "1"
_ST_OUT_LACKS "with another caller's line beside, no 'git add' of it" "git add --"
GA_CMD=$(sed -n 's/.*which leaves the rest of the staging as it is, with: //p' <<<"$OUT")
GA_REB=$(sed -n "s/^  Then rebuild the staging of h alone, .*, which 'git add' would take in too: \\(.*\\) – and run this again\\.\$/\\1/p" <<<"$OUT")
_ST_EQ "but the move back and carry, then the staging rebuilt alone" "${GA_CMD:+cmd}:${GA_REB:+rebuild}" "cmd:rebuild"
GIT_EDIT_ACTOR=ga-a _GA_FOLLOW "$GA_CMD" && eval "$GA_REB"
GIT_EDIT_ACTOR=ga-a _ST_RUN --amend-into="$GA_T" -- h
_ST_EQ "followed as printed, the fold keeps the landing, another caller's line staying in the checkout" \
	"$RC:$(_GA_KEPT "$(git show HEAD:h)"):$(git log --format=%h -S'alice' | wc -l | tr -d ' '):$(_GA_KEPT "$(<h)")" "0:2:0:3"
