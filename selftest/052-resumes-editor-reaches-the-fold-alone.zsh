# A resume's editor reaches the fold and nothing else
# `-m` needs a TTY this suite can never present, so its guarantee is asserted
# on the discriminator both message modes route through – driven directly,
# the way git invokes an editor, against a fabricated rebase state
_ST_SCENARIO "\e[1;96m[52] a resume's editor reaches the fold alone\e[0m"
# Stand-ins built here would otherwise wait in `_TEMP_FILES` for the suite's
# own exit – a killed run leaves them behind, so each goes with its last check
local FE_ED_BEFORE=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
local FE=$TMP/fold-editor
rm -rf "$FE" && mkdir -p "$FE" && git -C "$FE" init -q
local FE_REB=$(git -C "$FE" rev-parse --absolute-git-dir)/rebase-merge
mkdir -p "$FE_REB"
local FE_MSG=$FE/folded.txt
local FE_DEST=$FE/COMMIT_EDITMSG
print -r -- "FE folded subject" > "$FE_MSG"
local FE_CMD=$(_FOLD_EDITOR_CMD "cp '$FE_MSG'" "$FE")

# The step that conflicted is committed by the same resume, and its message
# is already right – a stand-in reaching it rewords an untouched commit
print -r -- "pick 1111111 # FE replayed" > "$FE_REB/done"
print -r -- "FE replayed message" > "$FE_DEST"
sh -c "$FE_CMD \"\$@\"" ge-editor "$FE_DEST"
local FE_RC=$?
_ST_EQ "a replayed step keeps its own message" "$(cat "$FE_DEST")" "FE replayed message"
# A non-zero editor makes git abandon the commit, so the no-op must exit clean
_ST_EQ "and the stand-in still exits clean" "$FE_RC" "0"

print -r -- "squash 2222222 # FE victim" > "$FE_REB/done"
sh -c "$FE_CMD \"\$@\"" ge-editor "$FE_DEST"
_ST_EQ "the fold takes the supplied message" "$(cat "$FE_DEST")" "FE folded subject"
print -r -- "fixup 3333333" > "$FE_REB/done"
print -r -- "FE other message" > "$FE_DEST"
sh -c "$FE_CMD \"\$@\"" ge-editor "$FE_DEST"
_ST_EQ "a fixup step is the fold too" "$(cat "$FE_DEST")" "FE folded subject"

# `-m` supplies an editor rather than a message, through the same guard
local FE_LOG=$FE/opened.log
local FE_STUB=$FE/stub-editor.sh
{ echo '#!/bin/sh'; echo "echo opened >> '$FE_LOG'" } > "$FE_STUB"
chmod +x "$FE_STUB"
local FE_ED=$(_FOLD_EDITOR_CMD "$FE_STUB" "$FE")
: > "$FE_LOG"
print -r -- "pick 4444444" > "$FE_REB/done"
sh -c "$FE_ED \"\$@\"" ge-editor "$FE_DEST"
_ST_EQ "-m's editor stays shut on a replayed step" "$(grep -c . "$FE_LOG")" "0"
print -r -- "squash 5555555" > "$FE_REB/done"
sh -c "$FE_ED \"\$@\"" ge-editor "$FE_DEST"
_ST_EQ "-m's editor opens on the fold" "$(grep -c . "$FE_LOG")" "1"
_ST_CHECK "and the -m branch routes through the guard" \
	sh -c "command grep -q '_FOLD_EDITOR_CMD \"\${(qq)_REAL_EDITOR}\"' '$SELF'"

# `sh` parses the emitted command, so a repo living under an apostrophe used
# to close the quote and leave a syntax error – which surfaces only as a
# failed editor, git abandoning the commit and the operation wedging
local FE2="$TMP/it's a \$repo"
rm -rf "$FE2" && mkdir -p "$FE2" && git -C "$FE2" init -q
local FE2_REB=$(git -C "$FE2" rev-parse --absolute-git-dir)/rebase-merge
mkdir -p "$FE2_REB"
print -r -- "squash 6666666" > "$FE2_REB/done"
local FE2_MSG="$FE2/folded msg.txt"
local FE2_DEST="$FE2/COMMIT_EDITMSG"
print -r -- "FE quoted-path subject" > "$FE2_MSG"
print -r -- "FE untouched" > "$FE2_DEST"
local FE2_ED=$(_FOLD_EDITOR_CMD "cp ${(qq)FE2_MSG}" "$FE2")
sh -c "$FE2_ED \"\$@\"" ge-editor "$FE2_DEST"
local FE2_RC=$?
_ST_EQ "a path with an apostrophe still applies the message" \
	"$(cat "$FE2_DEST")" "FE quoted-path subject"
_ST_EQ "and parses cleanly rather than failing the editor" "$FE2_RC" "0"
rm -rf "$FE" "$FE2"
rm -f "$FE_CMD" "$FE_ED" "$FE2_ED"

# The case above quotes the message path itself, so it pins the helper alone –
# drive a real resume for the caller, which has to quote it just the same
local QR="$TMP/quote'd repo"
rm -rf "$QR"
mkdir -p "$QR"
git -C "$QR" init -q
git -C "$QR" config user.email selftest@example.com
git -C "$QR" config user.name "git-edit selftest"
for N in 1 2 3 4; do
	printf 'qr%s\n' {1..$N} > "$QR/qr.txt"
	git -C "$QR" add qr.txt
	git -C "$QR" commit -qm "QR $N"
done
cd "$QR"
_ST_RUN -s="$(git log --format=%H --grep='^QR 2$' -1)" -y --text="QR folded subject" \
	"$(git log --format=%H --grep='^QR 4$' -1)"
_ST_EQ "a repo under an apostrophe still pauses, not errors" "$RC" "2"
local QR_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
_ST_RESOLVE "$QR_WT" qr.txt $'qr1\nqr2\nqr4'
_ST_RUN --continue
_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
_ST_RESOLVE "$QR_WT" qr.txt $'qr1\nqr2\nqr3\nqr4'
_ST_RUN --continue
_ST_EQ "its resume settles" "$RC" "0"
_ST_EQ "and the fold carries --text" "$(git log --format=%s --skip=1 -1)" "QR folded subject"
cd "$TMP/repo"
rm -rf "$QR"

# `-m` wants a TTY no sub-invocation here can present, so build each resume's command in-process
# and read back the editor and cleanup it installs, with nothing executed so no editor can open
local -a _FE_EDS
local FE_GUARD FE_CLEAN FE_CMDLINE FE_IED FE_TXT=$TMP/fe-text.txt
print -r -- "FE inline message" > "$FE_TXT"
# The editor a resume's command installs, unquoted from its `GIT_EDITOR=`
_FE_IEDITOR_OF () {
	FE_IED=${(Q)${${1#*GIT_EDITOR=}%% git *}}
	_FE_EDS+=("$FE_IED")
}

_REBASE_CONTINUE_CMD --continue "$FE_TXT" ""
FE_CMDLINE=$REPLY
_FE_IEDITOR_OF "$FE_CMDLINE"
FE_GUARD=no
[[ -x "$FE_IED" ]] && grep -q 'rebase-merge/done' "$FE_IED" && grep -q 'cp ' "$FE_IED" && FE_GUARD=yes
FE_CLEAN=no; [[ "$FE_CMDLINE" == *commit.cleanup=whitespace* ]] && FE_CLEAN=yes
_ST_EQ "--text installs the stand-in around its message" "$FE_GUARD" "yes"
# Safe only because the stand-in writes each replayed message back itself
_ST_EQ "and the cleanup that keeps its '#' lines" "$FE_CLEAN" "yes"
FE_GUARD=no; grep -q 'git log -1 --format=%B' "$FE_IED" && FE_GUARD=yes
_ST_EQ "every other step is restored from the commit replayed" "$FE_GUARD" "yes"

_REBASE_CONTINUE_CMD --continue "" real
_FE_IEDITOR_OF "$REPLY"
FE_GUARD=no
[[ -x "$FE_IED" ]] && grep -qF -- "$_REAL_EDITOR" "$FE_IED" && grep -qF -- "$(_RESOLVE_EDITOR) " "$_REAL_EDITOR" && FE_GUARD=yes
_ST_EQ "-m installs the stand-in around the real editor" "$FE_GUARD" "yes"
# Which runs in the caller's own environment, git-edit's config pins out of it
FE_GUARD=no; grep -q '^unset GIT_CONFIG_PARAMETERS' "$_REAL_EDITOR" && FE_GUARD=yes
_ST_EQ "and runs it without git-edit's config pins" "$FE_GUARD" "yes"
# Its template is git's own, so that one message keeps the comment stripping
FE_GUARD=no; grep -q 'stripspace --strip-comments' "$FE_IED" && FE_GUARD=yes
_ST_EQ "and strips the template git seeded it with" "$FE_GUARD" "yes"
# The rebase's own output is captured, so the editor a person types into takes the terminal
FE_GUARD=no; grep -qF '</dev/tty >/dev/tty' "$FE_IED" && FE_GUARD=yes
_ST_EQ "and hands it the terminal" "$FE_GUARD" "yes"

_REBASE_CONTINUE_CMD --continue "$FE_TXT" real
_FE_IEDITOR_OF "$REPLY"
FE_GUARD=no; grep -q 'cp ' "$FE_IED" && FE_GUARD=yes
_ST_EQ "given both, --text wins as the initial run had it" "$FE_GUARD" "yes"

# A resume commits its conflicted step too, whose own message git's default cleanup would strip of
# every `#`-led line – so each writes it back, a fold keeping git's
_REBASE_CONTINUE_CMD --continue "" ""
FE_CMDLINE=$REPLY
_FE_IEDITOR_OF "$FE_CMDLINE"
FE_GUARD=no
[[ -x "$FE_IED" ]] && grep -q 'git log -1 --format=%B' "$FE_IED" && grep -q 'stripspace --strip-comments' "$FE_IED" && \
	[[ "$FE_CMDLINE" == *commit.cleanup=whitespace* ]] && FE_GUARD=yes
_ST_EQ "every other resume writes each step's message back" "$FE_GUARD" "yes"

unfunction _FE_EDITOR_OF
unset _REAL_EDITOR
rm -f "$FE_TXT"
# A silenced resume records `true`, which names no file to remove
local FE_INSTALLED
for FE_INSTALLED in "${_FE_EDS[@]}"; do
	[[ "$FE_INSTALLED" == */git-edit-fold-editor.* ]] && rm -f "$FE_INSTALLED"
done
unset _FE_EDS
local FE_ED_AFTER=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
_ST_EQ "and the scenario leaves no stand-in behind" "$FE_ED_AFTER" "$FE_ED_BEFORE"
