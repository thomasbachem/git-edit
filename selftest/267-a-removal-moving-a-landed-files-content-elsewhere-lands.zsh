# A removal moving its file's content into files the commit adds or changes keeps what another
# caller landed on it – whatever route took them, paired as a rename or not – where they gained it
_ST_SCENARIO "\e[1;96m[267] a removal moving a landed file's content elsewhere lands\e[0m"
local RV_OLD=$'\t– pinned by `dev/tests/security/`' RV_NEW=$'\t– pinned by `dev/tests/app/security/`' RV_T
local -a RV_BODY=('export const gate = (event) => allowed(event.sender)' 'export const scopes = new Map()')
local -a RV_MORE=('export const init = ({ ipcMain }) => ipcMain' 'export const on = (name, fn) => [name, fn]' \
	'export const handle = (name, fn) => [name, fn]' 'export const off = (name) => name' \
	'export const once = (name, fn) => [name, fn]' 'export const list = () => [...scopes.keys()]')

# Commits `senders.js` unjournaled, then lands its header moved on as a peer
_RV_NEW () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l '/*' "$RV_OLD" '*/' "${RV_BODY[@]}" > senders.js && git add senders.js && git commit -qm "RV base"
	print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" > senders.js
	GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV peer" -- senders.js
	RV_T=$(git rev-parse HEAD)
}
export GIT_EDIT_ACTOR=rv-self

# Into a new file holding more besides, which git pairs with no rename – the removal by --rm
_RV_NEW rv1
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[@]}" > ipc.js
_ST_RUN --commit --text "RV moved" --rm senders.js -- ipc.js
_ST_EQ "a removal whose content moved, the landed line with it, lands" \
	"$RC:$(git log -1 --format=%s):$(git ls-tree --name-only HEAD | tr '\n' ' ')" "0:RV moved:ipc.js "
_ST_EQ "git pairing the two as no rename" "$(git diff -M --name-status HEAD~1 HEAD | cut -c1 | tr '\n' ' ')" "A D "
# Nor one moving the content as it was before the landing
_RV_NEW rv2
print -l '/*' "$RV_OLD" '*/' "${RV_BODY[@]}" "${RV_MORE[@]}" > ipc.js
_ST_RUN --commit --text "RV moved stale" --rm senders.js -- ipc.js
_ST_EQ "one whose content moved without the landed line refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_OUT_HAS "naming the file it removes" "senders.js – rv-peer's commit run .*which edited it"
_ST_OUT_HAS "and the remedy for a move" "Where the content of senders.js moved, carry what landed on it"
rm senders.js
_ST_RUN --commit --text "RV moved stale whole" -- senders.js ipc.js
_ST_OUT_HAS "as files taken whole name it" "Where the content of senders.js moved"
git add -A senders.js ipc.js && git diff --cached > "$TMP/rv2.patch" && git reset -q
_ST_RUN --commit --text "RV moved stale patch" --patch "$TMP/rv2.patch"
_ST_EQ "as does a patch moving it" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_OUT_HAS "naming it too" "Where the content of senders.js moved"
# Nor one gaining back a line the landing removed beside the one it added
_RV_NEW rv2b
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[@]}" "$RV_OLD" > ipc.js
_ST_RUN --commit --text "RV moved twice" --rm senders.js -- ipc.js
_ST_EQ "one gaining back the line the landing removed refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
# Into a new file git pairs as its rename, the removal by --rm all the same
_RV_NEW rv3
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[1]}" > ipc.js
_ST_RUN --commit --text "RV renamed" --rm senders.js -- ipc.js
_ST_EQ "as does a rename taken apart into a removal and a file" "$RC:$(git log -1 --format=%s)" "0:RV renamed"
# Into a file the tip holds already
_RV_NEW rv4
print -l "${RV_MORE[@]}" > ipc.js && git add ipc.js && git commit -qm "RV ipc"
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" >> ipc.js
_ST_RUN --commit --text "RV merged" --rm senders.js -- ipc.js
_ST_EQ "as does one merging it into a file the tip holds" "$RC:$(git log -1 --format=%s)" "0:RV merged"
# Nor a plain removal beside a file gaining other lines
_RV_NEW rv5
print -l "${RV_MORE[@]}" > other.js
_ST_RUN --commit --text "RV removed" --rm senders.js -- other.js
_ST_EQ "a removal beside a file gaining other lines refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
# Both taken whole
_RV_NEW rv6
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[@]}" > ipc.js && rm senders.js
_ST_RUN --commit --text "RV moved whole" -- senders.js ipc.js
_ST_EQ "as files taken whole as much" "$RC:$(git log -1 --format=%s)" "0:RV moved whole"
# Where the caller rewrote part of what landed since, what the tip still holds of it moved
_RV_NEW rv8
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[1]}" > senders.js
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV8 peer adds a line" -- senders.js
RV_T=$(git rev-parse HEAD)
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[2]}" > senders.js
_ST_RUN --commit --text "RV8 rewritten" --base="$RV_T" -- senders.js
print -l '/*' "$RV_NEW" '*/' "${RV_BODY[@]}" "${RV_MORE[2,-1]}" > ipc.js
_ST_RUN --commit --text "RV8 moved" --rm senders.js -- ipc.js
_ST_EQ "a removal moving what the tip still holds of a landing lands" "$RC:$(git log -2 --format=%s | tr '\n' ' ')" "0:RV8 moved RV8 rewritten "
# As does a plain removal of a file a landing only took a line out of, joining the two beside it
_ST_PZ_NEW rv9
_ST_PZ_C senders.js "${(F)RV_MORE[1,3]}" "RV9 base"
print -l "${RV_MORE[1]}" "${RV_MORE[3]}" > senders.js
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV9 peer cuts a line" -- senders.js
_ST_RUN --commit --text "RV9 removed" --rm senders.js
_ST_EQ "a removal of a file a landing only cut lines from lands" "$RC:$(git log -1 --format=%s)" "0:RV9 removed"
# Nor one moving a stale copy where the landing doubled a line the file held
_ST_PZ_NEW rv10
_ST_PZ_C senders.js "${(F)RV_BODY}" "RV10 base"
print -l "${RV_BODY[@]}" "${RV_BODY[2]}" > senders.js
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV10 peer doubles a line" -- senders.js
RV_T=$(git rev-parse HEAD)
print -l "${RV_BODY[@]}" "${RV_MORE[@]}" > ipc.js
_ST_RUN --commit --text "RV10 moved stale" --rm senders.js -- ipc.js
_ST_EQ "a copy lacking a line the landing doubled refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
print -l "${RV_BODY[@]}" "${RV_BODY[2]}" "${RV_MORE[@]}" > ipc.js
_ST_RUN --commit --text "RV10 moved" --rm senders.js -- ipc.js
_ST_EQ "while one holding it lands" "$RC:$(git log -1 --format=%s)" "0:RV10 moved"
# Nor one whose stale copy gains a closing line the landing added from code of its own
_ST_PZ_NEW rv11
_ST_PZ_C senders.js $'export function f () {\n\tgo()' "RV11 base"
print -l 'export function f () {' $'\tgo()' '}' > senders.js
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV11 peer closes f" -- senders.js
RV_T=$(git rev-parse HEAD)
print -l 'export function f () {' $'\tgo()' 'export function g () {' $'\tstop()' '}' > ipc.js
_ST_RUN --commit --text "RV11 moved stale" --rm senders.js -- ipc.js
_ST_EQ "a copy gaining the landed line elsewhere refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
print -l 'export function f () {' $'\tgo()' '' '}' 'export function g () {' $'\tstop()' '}' > ipc.js
_ST_RUN --commit --text "RV11 moved" --rm senders.js -- ipc.js
_ST_EQ "while one holding it in place lands, a blank line put in" "$RC:$(git log -1 --format=%s)" "0:RV11 moved"
# Nor one editing a line beside the landed one as it moves
_RV_NEW rv12
print -l '/*' "$RV_NEW" ' */' "${RV_BODY[@]}" "${RV_MORE[@]}" > ipc.js
_ST_RUN --commit --text "RV12 moved" --rm senders.js -- ipc.js
_ST_EQ "a move editing a line beside the landed one refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_OUT_HAS "naming the lines beside it in the remedy" "into the file it went to, beside the same lines"
# Nor the removal of an empty file the landing added, a binary it cut from or a submodule it bumped
_ST_PZ_NEW rv13
printf 'x\0\nb\nc\n' > bin.dat && git add bin.dat && git commit -qm "RV13 base"
: > keep
printf 'x\0\nc\n' > bin.dat
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV13 peer adds an empty file" -- keep bin.dat
git update-index --add --cacheinfo 160000,"$(git rev-parse HEAD)",sub && git commit -qm "RV13 sub"
GIT_EDIT_ACTOR=rv-peer _ST_RUN --exec -- sh -c "git update-index --cacheinfo 160000,$(git rev-parse HEAD),sub && git commit -qm 'RV13 peer bumps sub'"
RV_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "RV13 empty removed" --rm keep
_ST_EQ "the removal of an empty file another caller added refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_OUT_LACKS "naming no move where nothing else gained lines" "Where the content"
_ST_RUN --commit --text "RV13 binary removed" --rm bin.dat
_ST_EQ "as does that of a binary it cut from" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_RUN --commit --text "RV13 sub removed" --rm sub
_ST_EQ "as does that of a submodule it moved on" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
print other > other.txt
_ST_RUN --commit --text "RV13 sub removed beside" --rm sub -- other.txt
_ST_EQ "beside a file gaining lines too" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_OUT_LACKS "naming no move for a submodule" "Where the content"
# A file the peer added, moved into another
_ST_PZ_NEW rv7
_ST_PZ_C base.txt base "RV7 base"
print -l "${RV_BODY[@]}" > added.js
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV7 peer adds" -- added.js
print -l "${RV_MORE[@]}" "${RV_BODY[@]}" > ipc.js
_ST_RUN --commit --text "RV7 moved" --rm added.js -- ipc.js
_ST_EQ "a file another caller added, its content moved, lands" "$RC:$(git log -1 --format=%s)" "0:RV7 moved"
# While moving a peer's rename back takes it back, named by the file it removes
_ST_PZ_C guard.js "${(F)RV_MORE}" "RV7 guard"
git mv guard.js moved.js
GIT_EDIT_ACTOR=rv-peer _ST_RUN --commit --text "RV7 peer renames" -- guard.js moved.js
RV_T=$(git rev-parse HEAD)
git show HEAD:moved.js > guard.js
_ST_RUN --commit --text "RV7 renamed back" --rm moved.js -- guard.js
_ST_EQ "moving a peer's rename back refuses" "$RC:$(git rev-parse HEAD)" "1:$RV_T"
_ST_OUT_HAS "naming the file it removes" "moved.js – rv-peer's commit run .*which added it"
export GIT_EDIT_ACTOR=
unfunction _RV_NEW
cd "$TMP/repo"
