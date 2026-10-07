# Below 2.31 some checks read as off rather than failing, so the floor has to hold before any
# of them runs – the shim answers `--version` alone and hands every other call to the real git
_ST_SCENARIO "\e[1;96m[71] a git older than 2.31 is refused up front\e[0m"
mkdir -p "$TMP/shim-gitversion"
local GV_CASE GV GV_RC
for GV_CASE in "2.30.2:1" "1.9.5:1" "2.31.0:0" "2.50.1 (Apple Git-155):0" "unknown:0"; do
	GV=${GV_CASE%:*}
	GV_RC=${GV_CASE##*:}
	printf '#!/bin/zsh\nif [[ "$1" == "--version" ]]; then echo "git version %s"; exit 0; fi\nexec %s "$@"\n' "$GV" "$(whence -p git)" > "$TMP/shim-gitversion/git"
	chmod +x "$TMP/shim-gitversion/git"
	PATH="$TMP/shim-gitversion:$PATH" _ST_RUN --status
	if [ "$GV_RC" = "1" ]; then
		_ST_EQ "git $GV is refused" "$RC" "1"
		_ST_OUT_HAS "naming the floor and what it found" "^git-edit: error – git 2.31 or later is required, found $GV\$"
	else
		_ST_EQ "git $GV is let through" "$RC" "0"
	fi
done
# The two answers that name no repository still come from an outdated git
printf '#!/bin/zsh\nif [[ "$1" == "--version" ]]; then echo "git version 2.30.2"; exit 0; fi\nexec %s "$@"\n' "$(whence -p git)" > "$TMP/shim-gitversion/git"
PATH="$TMP/shim-gitversion:$PATH" _ST_RUN --version
_ST_EQ "while --version still answers" "$RC" "0"
PATH="$TMP/shim-gitversion:$PATH" _ST_RUN -h
_ST_EQ "and so does -h" "$RC" "0"
