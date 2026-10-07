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
fi
