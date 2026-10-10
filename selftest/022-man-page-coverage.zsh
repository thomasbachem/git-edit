# Man page, `README` and `-h` document every flag the parser takes
_ST_SCENARIO "\e[1;96m[22] man page coverage\e[0m"
# The suite ships with the script, which sits either in its checkout or in an install prefix
# that puts the manual under `../share/man` – take whichever layout this copy was laid out in,
# so an installed run checks the docs it actually carries instead of failing on their absence
local MANPAGE="$(dirname "$SELF")/man/man1/git-edit.1"
[ -f "$MANPAGE" ] || MANPAGE="$(dirname "$SELF")/../share/man/man1/git-edit.1"
local READMEFILE="$(dirname "$SELF")/README.md"
[ -f "$READMEFILE" ] || READMEFILE="$(dirname "$SELF")/../README.md"
_ST_CHECK "man page present" test -f "$MANPAGE"
if [ -f "$MANPAGE" ]; then
	# Derive the flags from the parser itself – a hardcoded list drifts the moment a mode is
	# added, which is the very drift this check exists to catch
	# Anchored on `^if ! zparseopts` so the match can only ever be the parser
	local -a DOCFLAGS
	local ZLINE=$(command grep -m1 '^if ! zparseopts' "$SELF")
	local ztok zname
	for ztok in ${(z)ZLINE}; do
		[[ "$ztok" != *"=OPT_"* ]] && continue
		ztok=${ztok%%=OPT_*}
		# Cut at the spec's modifiers – `:` for an argument, `+` for an option kept per use
		ztok=${ztok%%[:+]*}
		ztok=${ztok//[\{\}]/}
		# A short name comes bare (`e`), a long one with its second dash (`-edit`)
		for zname in ${(s:,:)ztok}; do
			DOCFLAGS+=("-$zname")
		done
	done
	_ST_CHECK "flag list derived from the parser" test ${#DOCFLAGS[@]} -ge 20
	# Strip roff font and backslash escapes so flag spellings match, with no man or mandoc dep
	local mflag MPAT missing="" rmissing="" hmissing=""
	local MANTEXT=$(sed 's/\\f[BIRP]//g;s/\\//g' "$MANPAGE")
	local HELPTEXT=$("$SELF" -h 2>&1)
	for mflag in "${DOCFLAGS[@]}"; do
		[ -z "$mflag" ] && continue
		# Whole spellings only – `-e` inside `--edit`, `--verify` inside `--verify-span` document nothing
		MPAT="(^|[^-[:alnum:]])${mflag}([^-[:alnum:]]|\$)"
		grep -qE -- "$MPAT" <<<"$MANTEXT" || missing="$missing $mflag"
		[ -f "$READMEFILE" ] && { grep -qE -- "$MPAT" "$READMEFILE" || rmissing="$rmissing $mflag" }
		grep -qE -- "$MPAT" <<<"$HELPTEXT" || hmissing="$hmissing $mflag"
	done
	if [ -z "$missing" ]; then
		PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m man page documents every mode"
	else
		FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m man page missing:$missing"
	fi
	if [ ! -f "$READMEFILE" ]; then
		ECHO_E "\e[0;90m  skipped – no README.md beside this copy\e[0m"
	elif [ -z "$rmissing" ]; then
		PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m README documents every mode"
	else
		FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m README missing:$rmissing"
	fi
	if [ -z "$hmissing" ]; then
		PASS=$((PASS+1)); ECHO_E "  \e[0;32mPASS\e[0m -h documents every mode"
	else
		FAIL=$((FAIL+1)); ECHO_E "  \e[1;31mFAIL\e[0m -h missing:$hmissing"
	fi
	# A flag taken by a mode it was not first written for is documented beside that mode too
	_ST_CHECK "the man synopsis gives --land its --base" grep -qE -- '--land=branch \[--base=sha\]' <<<"$MANTEXT"
	_ST_CHECK "-h gives --land its --base" grep -qE -- '--land=<branch> \[--base=<sha>\]' <<<"$HELPTEXT"
	[ -f "$READMEFILE" ] && _ST_CHECK "README says what --base means with --land" grep -qE -- 'With `--land`, the commit `<branch>` forked from' "$READMEFILE"
	# `-h <topic>` prints one entry of this page as plain text – every flag the parser takes has one
	local HTOPIC hgone=""
	for mflag in "${DOCFLAGS[@]:#--help}"; do
		MPAT="([^-[:alnum:]]|^)${mflag}([^-[:alnum:]]|\$)"
		[ -n "$("$SELF" -h "$mflag" 2>/dev/null | grep -E -- "^[^ ]" | grep -E -- "$MPAT")" ] || hgone="$hgone $mflag"
	done
	_ST_EQ "-h <flag> finds an entry for every flag" "$hgone" ""
	_ST_EQ "-h --help is the -h entry" "$("$SELF" -h --help 2>&1)" "$("$SELF" -h -h 2>&1)"
	HTOPIC=$("$SELF" -h edits 2>&1)
	_ST_CHECK "-h edits prints the --edits entry, placeholders bracketed" grep -qE '^--edits=<file>\|<json>$' <<<"$HTOPIC"
	_ST_CHECK "its body indented, one paragraph a line" grep -qE '^  With --commit or --amend-into, .*exactly once' <<<"$HTOPIC"
	_ST_EQ "never the entries that only mention it" "$(grep -cE '^--commit ' <<<"$HTOPIC")" "0"
	_ST_EQ "a topic spelled as the flag reads the same" "$("$SELF" -h --edits 2>&1)" "$HTOPIC"
	_ST_EQ "as does one with a value" "$("$SELF" -h --edits=x.json 2>&1)" "$HTOPIC"
	_ST_EQ "several topics print each entry" "$("$SELF" -h edits put 2>&1 | grep -cE -- '^(--edits=<file>\|<json>|--put=<path>=<file>)$')" "2"
	_ST_CHECK "an empty topic names nothing, the usage printed" grep -qE '^usage: git edit' <<<"$("$SELF" -h '' 2>&1)"
	_ST_CHECK "-h M is the reword, by case" grep -qE '^-M, --reword$' <<<"$("$SELF" -h M 2>&1)"
	_ST_CHECK "-h m the message flag" grep -qE '^-m, --message$' <<<"$("$SELF" -h m 2>&1)"
	_ST_CHECK "-h fold the --amend-into entry" grep -qE '^--amend-into=' <<<"$("$SELF" -h fold 2>&1)"
	_ST_CHECK "-h checkout the section of that title" grep -qE '^THE CHECKOUT$' <<<"$("$SELF" -h checkout 2>&1)"
	# Every section reads as plain text, no roff escape left over
	local HSECT HLEFT=""
	for HSECT in ${(f)"$(LC_ALL=C sed -n 's/^\.S[HS] "*\([^"]*\)"*$/\1/p' "$MANPAGE")"}; do
		"$SELF" -h "$HSECT" 2>&1 | grep -qE '\\(\(|f[BIRP]|-|&|e)' && HLEFT="$HLEFT [$HSECT]"
	done
	_ST_EQ "no section keeps a roff escape" "$HLEFT" ""
	_ST_CHECK "-h with no topic is the usage still" grep -qE '^usage: git edit' <<<"$("$SELF" -h 2>&1)"
	# One line a flag, so a grep for one returns it whole – the full text is `-h <flag>`'s
	_ST_EQ "-h gives each flag one line" "$("$SELF" -h 2>&1 | grep -cE '^ {39}[^ ]')" "0"
	HTOPIC=$("$SELF" -h put nosuchtopic 2>&1)
	_ST_EQ "an unknown topic refuses" "$?" "1"
	_ST_CHECK "naming the sections it could be" grep -qE "No help topic 'nosuchtopic' – .*THE CHECKOUT" <<<"$HTOPIC"
	_ST_CHECK "once the topics it knows printed" grep -qE -- '^--put=<path>=<file>$' <<<"$HTOPIC"
	_ST_CHECK "a letter names no section" grep -qE "No help topic 'a' –" <<<"$("$SELF" -h a 2>&1)"
	# A copy without its page beside it says so rather than print nothing
	mkdir -p "$TMP/solo" && cp "$SELF" "$TMP/solo/git-edit"
	HTOPIC=$("$TMP/solo/git-edit" -h edits 2>&1)
	_ST_EQ "a copy without its man page refuses a topic" "$?" "1"
	_ST_CHECK "naming the page it lacks" grep -qE "No man page beside this git-edit to read 'edits' from" <<<"$HTOPIC"
fi
