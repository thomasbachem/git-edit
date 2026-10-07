# GNU sed reads BSD's `sed -i ""` as a file named "", which failed every rebase todo edit on Linux
# – a check of the source, as a run on macOS reads either form
_ST_SCENARIO "\e[1;96m[117] sed runs in forms GNU and BSD sed both read\e[0m"
local SI_OUT=$(grep -nE 'sed -i( |$)' "$SELF" | grep -vE '^[0-9]+:[[:space:]]*#')
_ST_EQ "no sed -i lacks an attached suffix" "$SI_OUT" ""
_ST_CHECK "while the suffixed form is the one in use" grep -q 'sed -i\.git-edit' "$SELF"
# BSD sed in a UTF-8 locale dies on a byte no UTF-8 holds, so a listing's runs under `LC_ALL=C`
_ST_EQ "no sed reads the caller's locale" "$(awk '!/^[[:space:]]*#/ { n = gsub(/(^|[^A-Za-z_-])sed /, "&"); m = gsub(/LC_ALL=C sed /, "&"); if (n > m) print NR }' "$SELF")" ""
