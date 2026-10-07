# --version reports the version the script declares
# It is the number a bug report names, so a stale literal or the wrong variable has to fail
# here rather than misidentify the copy that broke
_ST_SCENARIO "\e[1;96m[70] --version reports the declared version\e[0m"
local DECLARED=$(command grep -m1 '^GIT_EDIT_VERSION=' "$SELF" | sed 's/^[^"]*"//; s/".*$//')
_ST_CHECK "the script declares a version" test -n "$DECLARED"
_ST_RUN --version
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "prints a release number" '^git-edit [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'
_ST_OUT_HAS "matching the declared one" "^git-edit ${DECLARED}\$"
# The dispatch sits above everything that needs a repository, and a version is most often
# asked for while filing a report from somewhere else
cd "$TMP"
_ST_RUN --version
_ST_EQ "answers outside a repository too" "$RC" "0"
_ST_OUT_HAS "with the same version" "^git-edit ${DECLARED}\$"
cd "$TMP/repo"
