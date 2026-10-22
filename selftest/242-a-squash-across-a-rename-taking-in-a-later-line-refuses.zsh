# A squash whose member, on a file's new name, rewrites a line a commit between it and its target
# wrote refuses – the target's stop takes that line in, its own lines read through the member's
# change on the path the stop's commit no longer holds
_ST_SCENARIO "\e[1;96m[242] a squash across a rename taking in a later commit's line refuses\e[0m"
_ST_PZ_NEW rs
print -l a b c d e > f && git add f && git commit -qm "RS base"
print -l aT b c d e > f && git commit -qam "RS target"
local RS_T=$(git rev-parse HEAD)
print -l aT bM c d e > f && git commit -qam "RS edit b"
git mv f f2 && git commit -qm "RS rename f to f2"
_ST_PZ_C g z "RS unrelated"
print -l aT bS c d e > f2 && git commit -qam "RS edit b again"
local RS_M=$(git rev-parse HEAD)
_ST_PZ_C h h "RS top"
local RS_TIP=$(git rev-parse HEAD) RS_WT RS_I
_ST_RUN -s="$RS_T" "$RS_M"
RS_WT=$(_ST_PZ_WT)
# Each stop resolved to the squash's final word on b
for RS_I in 1 2 3; do
	[[ "${OUT##*$'\n'}" == "git-edit: conflict"* ]] || break
	print -l aT bS c d e > "${RS_WT:-$ST_NO_WT}/f" && git -C "${RS_WT:-$ST_NO_WT}" add f
	_ST_RUN --continue
done
_ST_EQ "a squash across a rename taking in a later commit's line refuses" "$RC:$(git rev-parse HEAD)" "1:$RS_TIP"
_ST_OUT_HAS "naming the commit whose line it took in" 'RS edit b – f (left out as emptied)$'
_ST_RUN --abort
cd "$TMP/repo"
