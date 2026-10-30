# A squash whose replay ends off the tip's content refuses, naming the commits the lines came from:
# • A resolution's line names its stop's commit as the one to rework, a clean pick's named too
# • `--status` reads the pause as that refusal, and a resume of an untouched result refuses at once
# • That commit reworked in the replay kept, the resume lands the tip's content
_ST_SCENARIO "\e[1;96m[240] a squash refused at the tip names its lines' commits and keeps the replay\e[0m"
_ST_PZ_NEW sq
print -l x a b c d > f && git add f && git commit -qm "SQ base"
print -l x1 a b c d > f && git commit -qam "SQ target"
local SQ_T=$(git rev-parse HEAD)
print -l y1 a b c d > f && git commit -qam "SQ later rewrite"
_ST_PZ_C g m "SQ unrelated"
print -l y1z a b c d > f && git commit -qam "SQ append z"
local SQ_Z=$(git rev-parse HEAD)
_ST_PZ_C h h "SQ top"
local SQ_TIP=$(git rev-parse HEAD)
_ST_RUN -s="$SQ_T" "$SQ_Z"
local SQ_WT=$(_ST_PZ_WT)
# Resolved to the target's own line, plus one the tip never holds
[ -n "$SQ_WT" ] && print -l x1 a b c d P > "$SQ_WT/f" && git -C "$SQ_WT" add f
_ST_RUN --continue
_ST_EQ "a resolution adding what the tip lacks refuses, paused, the branch untouched" "$RC:$(git rev-parse HEAD)" "2:$SQ_TIP"
_ST_OUT_HAS "naming the clean pick's line" 'f:1 – [0-9a-f]* (SQ later rewrite)$'
_ST_OUT_HAS "and the line the resolution made" 'f:6 – [0-9a-f]* (SQ target), resolved at its stop$'
local SQ_AT=$(git -C "${SQ_WT:-$ST_NO_WT}" log --format='%H %s' 2>/dev/null | awk 'NF == 3 && $2 == "SQ" && $3 == "target" { print $1 }')
_ST_OUT_HAS "offering to rework that commit in the replay kept" "Rework ${SQ_AT:0:12} in the replay kept there"
_ST_RUN --status
_ST_OUT_HAS "--status reads the pause as that refusal" "^git-edit: paused – squash of ${SQ_Z:0:7} would change the tip's content"
_ST_OUT_LACKS "never as a conflict" '^git-edit: conflict'
_ST_RUN --continue
_ST_EQ "a resume finding the result untouched refuses again" "$RC:$(git rev-parse HEAD)" "2:$SQ_TIP"
_ST_OUT_HAS "naming the commit again" "Rework ${SQ_AT:0:12} in the replay kept there"
_ST_OUT_LACKS "at once, never read as a replay finished by hand" 'Rebase already completed'
# Reworked in place – the target taking the squashed change, the later rewrite resolved on top –
# `--status` reading the rework as a rebase begun by hand, then the replay as finished
[ -n "$SQ_WT" ] && [ -n "$SQ_AT" ] && GIT_SEQUENCE_EDITOR="sed -i.bak '1s/^pick/edit/'" git -C "$SQ_WT" rebase -i "$SQ_AT^" >/dev/null 2>&1
_ST_RUN --status
_ST_OUT_HAS "--status reads the rework as a rebase begun by hand" "^git-edit: paused – a rebase begun by hand is in progress in .*; finish or abort it there"
_ST_OUT_LACKS "never with a stop's detail sending it on" 'Currently failing on'
_ST_RUN --continue
_ST_EQ "a resume amid it refuses" "$RC:$(git rev-parse HEAD)" "1:$SQ_TIP"
_ST_OUT_HAS "naming how to finish it" "rebase --continue') or abort it"
if [ -n "$SQ_WT" ] && [ -n "$SQ_AT" ]; then
	print -l x1z a b c d > "$SQ_WT/f" && git -C "$SQ_WT" add f && GIT_EDITOR=true git -C "$SQ_WT" commit -q --amend --no-edit
	GIT_EDITOR=true git -C "$SQ_WT" rebase --continue >/dev/null 2>&1
	print -l y1z a b c d > "$SQ_WT/f" && git -C "$SQ_WT" add f && GIT_EDITOR=true git -C "$SQ_WT" rebase --continue >/dev/null 2>&1
fi
_ST_RUN --status
_ST_OUT_HAS "and the replay once finished as such" "^git-edit: paused – the replay in .* is finished, nothing applied"
_ST_RUN --continue
_ST_EQ "that commit reworked there, the resume lands the tip's content" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse 'HEAD^{tree}')" \
	"0:SQ top|SQ unrelated|SQ later rewrite|SQ target|SQ base|:$(git rev-parse "$SQ_TIP^{tree}")"
_ST_EQ "the target holding the squashed change" "$(git show HEAD~3:f | head -1)" "x1z"
cd "$TMP/repo"
