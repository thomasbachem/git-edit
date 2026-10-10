# A message the run leaves alone keeps its bytes – re-parented, squashed into, or resumed as a fixup
# chain's target – an editor comments and cleans up as `git commit` would under the caller's
# settings, and a rebuild ends at the tip the run read, refusing a move with the rerun it needs
_ST_SCENARIO "\e[1;96m[150] messages keep their bytes, editors clean up as git commit, rebuilds end at the tip read\e[0m"
local MB_WT MB_T MB_B MB_X MB_TIP
local -a MB_OLD MB_NEW
# Writes a commit on `HEAD` whose message is exactly <printf %b text>, its author zone `-0000`
_MB_MK () {
	local P=$(git rev-parse HEAD) T
	print -r -- "$RANDOM$RANDOM" >> mb.txt && git add mb.txt && T=$(git write-tree)
	T=$(printf 'tree %s\nparent %s\nauthor M B <mb@x.invalid> 1700000000 -0000\ncommitter M B <mb@x.invalid> 1700000000 +0100\n\n%b' "$T" "$P" "$1" | command git hash-object -t commit -w --stdin)
	git update-ref refs/heads/main "$T" && git reset -q --hard
}
# Puts <commit>'s message into `REPLY` as its bytes stand
_MB_BODY () {
	REPLY=$(git cat-file commit "$1"; print -n x)
	REPLY=${${REPLY%x}#*$'\n\n'}
}
# A peer as a `git` in `PATH`: at the `MB_LAND`th `git $MB_SUB` it lands a commit on main – or with
# `MB_ACT=amend` replaces main's tip – and at the `MB_BACK`th it takes that back
mkdir -p "$TMP/mb-shim"
cat > "$TMP/mb-shim/git" <<'SH'
#!/bin/sh
if [ "$1" = "$MB_SUB" ]; then
	N=$(cat "$MB_CNT" 2>/dev/null); N=$((${N:-0} + 1)); echo "$N" > "$MB_CNT"
	if [ "$N" = "$MB_LAND" ]; then
		P=$("$MB_REAL" rev-parse refs/heads/main) B=$P
		[ "$MB_ACT" = amend ] && B=$("$MB_REAL" rev-parse refs/heads/main~1)
		C=$(echo "MB peer commit" | "$MB_REAL" commit-tree "$("$MB_REAL" rev-parse 'refs/heads/main^{tree}')" -p "$B")
		"$MB_REAL" update-ref refs/heads/main "$C" "$P" && echo "$P" > "$MB_CNT.orig"
	elif [ "$N" = "$MB_BACK" ]; then
		"$MB_REAL" update-ref refs/heads/main "$(cat "$MB_CNT.orig")"
	fi
fi
exec "$MB_REAL" "$@"
SH
chmod +x "$TMP/mb-shim/git"
export MB_REAL=$(whence -p git) MB_SUB MB_LAND MB_BACK MB_ACT MB_CNT
# Runs git edit with the peer set to <subcommand> <land at> <take back at, or 0> <land|amend>
_MB_PEER () {
	MB_SUB=$1 MB_LAND=$2 MB_BACK=$3 MB_ACT=$4 MB_CNT=$(mktemp "$TMP/mb-cnt.XXXXXX")
	shift 4
	PATH="$TMP/mb-shim:$PATH" _ST_RUN "$@"
	MB_SUB=""
}

# Makes repo `pz-<name>` of a base and three commits whose messages end unusually, into `MB_OLD`
_MB_FIXTURE () {
	_ST_PZ_NEW "$1"
	_ST_PZ_C base.txt b "MB base"
	MB_B=$(git rev-parse HEAD)
	_MB_MK 'MB trailing ws  \n\nbody with trailing ws  \n'
	_MB_MK 'MB no newline'
	_MB_MK 'MB four newlines\n\n\n\n'
	MB_OLD=($(git rev-list --reverse "$MB_B..HEAD"))
}

# C3-4 – commits a reword only re-parents keep their message bytes and a `-0000` author zone
_MB_FIXTURE mb1
_ST_RUN -M --text "MB base reworded" "$MB_B"
MB_NEW=($(git rev-list --reverse HEAD~3..HEAD))
_MB_BODY "${MB_OLD[1]}"; MB_X=$REPLY; _MB_BODY "${MB_NEW[1]}"
_ST_EQ "a re-parented message keeps its trailing whitespace" "$RC:$REPLY" "0:$MB_X"
_MB_BODY "${MB_OLD[2]}"; MB_X=$REPLY; _MB_BODY "${MB_NEW[2]}"
_ST_EQ "one without a trailing newline gains none" "$REPLY" "$MB_X"
_MB_BODY "${MB_OLD[3]}"; MB_X=$REPLY; _MB_BODY "${MB_NEW[3]}"
_ST_EQ "and trailing blank lines stay" "$REPLY" "$MB_X"
_ST_EQ "an author zone -0000 stays -0000" "$(git cat-file commit HEAD | sed -n 's/^author .* //p')" "-0000"
_ST_EQ "while the reworded one takes its new message" "$(git log -1 --format=%B "$(git rev-parse HEAD~3)")" "MB base reworded"
# A batch reword's walk keeps them as well
_MB_FIXTURE mb1b
_ST_RUN_IN "--- $MB_B
MB base batch" -M --text -
MB_NEW=($(git rev-list --reverse HEAD~3..HEAD))
_MB_BODY "${MB_OLD[2]}"; MB_X=$REPLY; _MB_BODY "${MB_NEW[2]}"
_ST_EQ "a batch reword's rebuild keeps a message without a trailing newline" "$RC:$REPLY" "0:$MB_X"
_MB_BODY "${MB_OLD[3]}"; MB_X=$REPLY; _MB_BODY "${MB_NEW[3]}"
_ST_EQ "and its trailing blank lines" "$REPLY" "$MB_X"
# A plumbing squash keeps the oldest's message as it stands
_MB_FIXTURE mb1c
_ST_RUN -S "${MB_OLD[1]}" "${MB_OLD[2]}"
_MB_BODY "${MB_OLD[1]}"; MB_X=$REPLY; _MB_BODY HEAD~1
_ST_EQ "a squash keeps the message it keeps byte for byte" "$RC:$REPLY" "0:$MB_X"
_MB_BODY "${MB_OLD[3]}"; MB_X=$REPLY; _MB_BODY HEAD
_ST_EQ "and rebuilds the commit above it as it was" "$REPLY" "$MB_X"

# C3-1 – a fixup chain resumed after a conflict keeps its target's own `#` line
_ST_PZ_NEW mb2
# The fold's line abuts the later commit's, so it conflicts on the target, resolved to the target's
# own content plus the fold – the later commit keeping its change
print -l a b c d > f && git add f && git commit -qm "MB2 base"
print -l A b c d > f && git add f && printf 'MB2 target\n\n#123 issue ref\n' > "$TMP/mb-msg" && git commit -q --cleanup=verbatim -F "$TMP/mb-msg"
print -l A b C d > f && print l > g && git add f g && git commit -qm "MB2 later"
print -l A b C D > f && git add f
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- f
MB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$MB_WT" f $'A\nb\nc\nD'
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "$MB_WT" f $'A\nb\nC\nD' && _ST_RUN --continue
_ST_EQ "a fold resumed after its conflict keeps the target's # line" "$RC:$(git log -1 --format=%B HEAD~1 | grep -c '^#123 issue ref$')" "0:1"
# As does a squash's fixup resumed on the rebase path
_ST_PZ_NEW mb3
print 1 > f && git add f && git commit -qm "MB3 base"
print 2 > f && git add f && git commit -q --cleanup=verbatim -F "$TMP/mb-msg"
MB_T=$(git rev-parse HEAD)
print 3 > f && git add f && git commit -qm "MB3 mid"
print 4 > f && git add f && git commit -qm "MB3 fix"
_ST_RUN -s "$MB_T" HEAD
MB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$MB_WT" f 4
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "$MB_WT" f 4 && _ST_RUN --continue
_ST_EQ "a squash's fixup resumed keeps the target's # line" "$RC:$(git log -1 --format=%B ':/^MB2 target' | grep -c '^#123 issue ref$')" "0:1"
# While a resume whose chain combined messages still strips git's template
_RESUME_EDITOR "$PWD"
MB_X=no; grep -q 'stripspace --strip-comments' "$REPLY" && MB_X=yes
_ST_EQ "and a squash's resume keeps stripping git's template" "$MB_X" "yes"

# C3-2 – a terminal editor comments and cleans up as `git commit` would
_ST_PZ_NEW mb4
_ST_PZ_C a.txt a "MB4 base"
print 2 > b.txt && git add b.txt && git commit -q --cleanup=verbatim -F "$TMP/mb-msg"
_ST_PZ_C c.txt c "MB4 mid"
_ST_PZ_C d.txt d "MB4 top"
_ST_PZ_C e.txt e "MB4 top2"
MB_T=$(git rev-parse HEAD~3)
printf '#!/bin/sh\neval "F=\\${$#}"\ncp "$F" %s\nsed -i.bak "1s/\\$/ EDITED/" "$F"\n' "$TMP/mb-seen" > "$TMP/mb-ed"
chmod +x "$TMP/mb-ed"
git config core.commentChar auto
_ST_TTY "GIT_EDITOR=$TMP/mb-ed" -- -M "$MB_T"
MB_T=$(git rev-parse HEAD~3)
_ST_EQ "-M under core.commentChar=auto keeps a # line" "$RC:$(git log -1 --format=%B "$MB_T" | grep -c '^#123 issue ref$')" "0:1"
_ST_EQ "commenting its help with a character the message leaves free" "$(grep -c '^; Lines starting with' "$TMP/mb-seen")" "1"
_ST_TTY "GIT_EDITOR=$TMP/mb-ed" -- -y -S -m "$MB_T" HEAD~2
MB_T=$(git rev-parse HEAD~2)
_ST_EQ "as does -S -m" "$RC:$(git log -1 --format=%B "$MB_T" | grep -c '^#123 issue ref$')" "0:1"
# Apart, so the squash takes the rebase
_ST_TTY "GIT_EDITOR=$TMP/mb-ed" -- -y -s -m "$MB_T" HEAD
MB_X=$(git log -1 --format=%B HEAD~1)
_ST_EQ "and -s -m, git's template and help gone" "$RC:$(grep -c '^#123 issue ref$' <<<"$MB_X"):$(grep -c '^;' <<<"$MB_X")" "0:1:0"
git config --unset core.commentChar
# `commit.cleanup=whitespace` keeps `#` lines and says so, scissors cuts at its line
_ST_PZ_NEW mb5
_ST_PZ_C a.txt a "MB5 base"
print 2 > b.txt && git add b.txt && git commit -q --cleanup=verbatim -F "$TMP/mb-msg"
_ST_PZ_C c.txt c "MB5 top"
git config commit.cleanup whitespace
_ST_TTY "GIT_EDITOR=$TMP/mb-ed" -- -M HEAD~1
_ST_EQ "-M under commit.cleanup=whitespace keeps a # line" "$RC:$(git log -1 --format=%B HEAD~1 | grep -c '^#123 issue ref$')" "0:1"
_ST_EQ "its help saying such lines are kept" "$(grep -c "^# Lines starting with '#' will be kept" "$TMP/mb-seen")" "1"
git config commit.cleanup scissors
_ST_TTY "GIT_EDITOR=$TMP/mb-ed" -- -M HEAD~1
MB_X=$(git log -1 --format=%B HEAD~1)
_ST_EQ "under scissors the # line stays and the cut goes" "$RC:$(grep -c '^#123 issue ref$' <<<"$MB_X"):$(grep -c '>8' <<<"$MB_X")" "0:1:0"
git config --unset commit.cleanup
# Where nothing is configured the `#` line goes, as `git commit --amend` drops it
_ST_TTY "GIT_EDITOR=$TMP/mb-ed" -- -M HEAD~1
MB_X=$(git log -1 --format=%B HEAD~1)
_ST_EQ "while by default -M strips # lines" "$RC:$(grep -c '^#123' <<<"$MB_X"):$(grep -c 'EDITED' <<<"$MB_X")" "0:0:1"
# The editor command runs through `sh`, as git runs it, its words split as there
MB_X=$(git log -1 --format=%s HEAD~1)
_ST_TTY 'GIT_EDITOR=MB_E="'"$TMP/mb-ed"' --flag"; $MB_E' -- -M HEAD~1
_ST_EQ "an editor command is read by sh, as git reads it" "$RC:$(git log -1 --format=%s HEAD~1)" "0:$MB_X EDITED"
# A GUI editor named by a quoted path with spaces is still found
GIT_EDITOR='"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" --wait' _DETECT_GUI_EDITOR
_ST_EQ "a GUI editor at a quoted path with spaces is detected" "$OPEN_EDITOR_NAME" "VS Code"
OPEN_EDITOR_CMD="" OPEN_EDITOR_NAME=""

# C3-3 – a peer's commit landed and taken back mid-rebuild is not landed again
_ST_PZ_NEW mb6
_ST_PZ_C f.txt 0 "MB6 c0" && _ST_PZ_C f.txt 1 "MB6 c1" && _ST_PZ_C f.txt 2 "MB6 c2" && _ST_PZ_C f.txt 3 "MB6 c3"
_MB_PEER commit-tree 1 2 land -M --text "MB6 c1 reworded" HEAD~2
_ST_EQ "a reword lands without a peer's commit taken back mid-rebuild" "$RC:$(git log --format=%s | grep -c 'MB peer')" "0:0"
_MB_PEER commit-tree 1 2 land -S HEAD~3 HEAD~2
_ST_EQ "as does a plumbing squash" "$RC:$(git log --format=%s | grep -c 'MB peer')" "0:0"
print 9 > g.txt && git add g.txt
_MB_PEER commit-tree 1 2 land --amend-into="$(git rev-parse HEAD~1)" --text "MB6 fold reworded" -- g.txt
_ST_EQ "and a fold rewording its target" "$RC:$(git log --format=%s | grep -c 'MB peer')" "0:0"

# C3-5 – a move under a rewrite is refused naming it and the rerun, offering nothing built
_ST_PZ_NEW mb7
_ST_PZ_C f.txt 0 "MB7 c0" && _ST_PZ_C f.txt 1 "MB7 c1" && _ST_PZ_C f.txt 2 "MB7 c2" && _ST_PZ_C f.txt 3 "MB7 c3"
# Past the four `stripspace` calls reading the records before any wait, two a record, the reword's
# second
_MB_PEER stripspace 6 0 amend -M --text "--- $(git rev-parse HEAD~2)
MB7 new c1
--- $(git rev-parse HEAD~1)
MB7 new c2"
_ST_EQ "a batch reword whose tip a peer amends is refused" "$RC:$(git log -1 --format=%s)" "1:MB peer commit"
_ST_OUT_HAS "naming the move" "moved from .* to .* during the reword"
_ST_OUT_LACKS "never as an internal error" 'Internal'
MB_TIP=$(git rev-parse HEAD)
_MB_PEER commit-tree 1 0 land -M --text "MB7 c1 again" HEAD~2
_ST_EQ "a reword a peer lands under is refused" "$RC:$(git rev-parse HEAD~1)" "1:$MB_TIP"
_ST_OUT_HAS "with the rerun it needs" 'Nothing was applied – run the reword again on its new tip'
_ST_OUT_LACKS "and no history to apply over the peer's" 'history is at'
_ST_OUT_LACKS "a --text message kept nowhere, the caller holding it" 'you typed is kept'
_MB_PEER commit-tree 1 0 land -S HEAD~3 HEAD~2
_ST_OUT_HAS "as is a plumbing squash" 'Nothing was applied – run the squash again on its new tip'
_ST_OUT_LACKS "offering nothing it built" 'history is at'

# A message typed in an editor outlives the refusal, in a file it names with the rerun taking it
_ST_PZ_NEW mb8
_ST_PZ_C f.txt 0 "MB8 c0" && _ST_PZ_C f.txt 1 "MB8 c1" && _ST_PZ_C g.txt 2 "MB8 c2" && _ST_PZ_C f.txt 3 "MB8 c3"
MB_T=$(git rev-parse HEAD~2)
MB_SUB=commit-tree MB_LAND=1 MB_BACK=0 MB_ACT=land MB_CNT=$(mktemp "$TMP/mb-cnt.XXXXXX")
_ST_TTY "PATH=$TMP/mb-shim:$PATH" "GIT_EDITOR=$TMP/mb-ed" -- -M "$MB_T"
MB_X=$(sed -n 's/^The message you typed is kept in \(.*\) – reuse it: .*/\1/p' <<<"$OUT")
_ST_EQ "a -M refused after its editor keeps the typed message" "$RC:$(cat -- "$MB_X" 2>/dev/null)" "1:MB8 c1 EDITED"
_ST_OUT_HAS "naming the rerun taking it" "reuse it: git edit -M ${MB_T:0:12} --text - < "
_ST_RUN_IN "$(<"$MB_X")" -M --text - "$MB_T"
_ST_EQ "which rewords with it on the new tip" "$RC:$(git log --format=%s -1 "$(git rev-parse HEAD~3)")" "0:MB8 c1 EDITED"
# As does a squash on the rebase path, refused at its landing
MB_SUB=update-ref MB_LAND=1 MB_BACK=0 MB_ACT=land MB_CNT=$(mktemp "$TMP/mb-cnt.XXXXXX")
_ST_TTY "PATH=$TMP/mb-shim:$PATH" "GIT_EDITOR=$TMP/mb-ed" -- -y -s -m HEAD~3 HEAD~1
MB_X=$(sed -n 's/^The message you typed is kept in \(.*\) – reuse it: .*/\1/p' <<<"$OUT")
_ST_EQ "a -s -m refused at its landing keeps the typed message" "$RC:$(head -1 -- "$MB_X" 2>/dev/null)" "1:MB8 c1 EDITED"
_ST_OUT_HAS "naming its rerun" "reuse it: git edit -s="
MB_SUB=""

unfunction _MB_MK _MB_BODY _MB_PEER _MB_FIXTURE
unset MB_REAL MB_SUB MB_LAND MB_BACK MB_ACT MB_CNT
cd "$TMP/repo"
