# Printed steps run as printed:
# • A body-restore step carries no subject byte – a `!` in the subject runs in an interactive bash,
#   in sh and in an interactive zsh
# • A whole-file guard's "naming <new> in place of <old>" names paths from where the caller stands,
#   and says they run from the top where its step begins with that `cd`
# • A conflict pause passes on none of git's advice to skip or abort the rebase by hand
# • `--status` on a pause whose rebase was aborted by hand gives the resume's verdict
# • A placement's or reorder's stop whose exact answer would empty its commit names the way on the
#   absorption guard names instead of that answer
_ST_SCENARIO "\e[1;96m[199] printed steps run as printed\e[0m"
local PS_SH PS_C PS_T PS_WT PS_CMD PS_NEW PS_MSG PS_S PS_M PS_GITFN PS_AFTER
# Runs `git edit <arg>...` as caller <label>
_P199_AS () {
	# Args: <label> <arg>...
	export GIT_EDIT_ACTOR=$1
	shift
	_ST_RUN "$@"
	export GIT_EDIT_ACTOR=
}

# A body dropped by a subject holding a `!`, put back by its printed step in each shell – the
# step's line fed to an interactive shell, which expands a `!` from its history
PS_GITFN="git () { if [ \"\$1\" = edit ]; then shift; GIT_EDIT_NO_AUTO_OPEN=1 ${(qq)SELF} \"\$@\"; else command git \"\$@\"; fi; }"
for PS_SH in bash-i sh zsh-i; do
	_ST_PZ_NEW ps1-$PS_SH
	_ST_PZ_C a.txt a "PS1 base"
	print b > b.txt && git add b.txt && git commit -qm "PS1 old" -m "PS1 body line"
	PS_C=$(git rev-parse HEAD)
	_ST_RUN -M --text 'PS1 fix!now' HEAD
	_ST_OUT_HAS "a reword dropping a body names the step putting it back ($PS_SH)" '^To put the body back under the new subject: git edit -M'
	PS_CMD=$(sed -n 's/^To put the body back under the new subject: //p' <<<"$OUT" | head -1)
	_ST_EQ "a step carrying no byte of the subject ($PS_SH)" "${PS_CMD//[^!]/}" ""
	[ -n "$PS_CMD" ] || PS_CMD=false
	case $PS_SH in
		bash-i) OUT=$(print -rl -- "$PS_GITFN" "$PS_CMD" | env HOME="$TMP" HISTFILE=/dev/null bash --norc --noprofile -i 2>&1) ;;
		sh) OUT=$(sh -c "$PS_GITFN; $PS_CMD" </dev/null 2>&1) ;;
		zsh-i) OUT=$(print -rl -- "$PS_GITFN" "$PS_CMD" | env HOME="$TMP" ZDOTDIR="$TMP" zsh -f -i 2>&1) ;;
	esac
	PS_MSG=$(git log -1 --format=%B HEAD)
	_ST_EQ "which, run as printed in $PS_SH, puts the body back under the new subject" "$PS_MSG" $'PS1 fix!now\n\nPS1 body line'
	_ST_OUT_LACKS "with no history expansion in the way ($PS_SH)" 'event not found'
done

# A file another caller renamed since, taken whole from a subdirectory – the re-run as told lands
_ST_PZ_NEW ps2
mkdir sub && print -l {1..20} > sub/f && print o > other && git add -A && git commit -qm "PS2 base"
print x >> other && git commit -qam "PS2 other"
cd sub
_P199_AS ps-a --exec -- sh -c 'git mv f g && { echo ONE; sed 1d g; } > g.new && mv g.new g && git commit -qam "PS2 rename f to g"'
{ print -l {1..19}; print TWENTY; } > f
_P199_AS ps-b --commit --text "PS2 B" -- f
_ST_OUT_HAS "a whole file renamed since names its new name from where the caller stands" "then run this again naming g in place of f\.\$"
PS_NEW=$(sed -n 's/.*run this again naming \(.*\) in place of .*/\1/p' <<<"$OUT")
_P199_AS ps-b --carry="$(git rev-parse HEAD~1)"
_P199_AS ps-b --commit --text "PS2 B" -- ${(Q)PS_NEW:-none}
_ST_EQ "and run again as told, it lands" "$RC:$(git show HEAD:sub/g | tail -1):$(git log -1 --format=%s)" "0:TWENTY:PS2 B"
cd ..
# Folded as staged, its steps begin by going to the top, where the names it gives are read from
_ST_PZ_NEW ps3
mkdir sub && print -l {1..20} > sub/f && print o > other && git add -A && git commit -qm "PS3 base"
print x >> other && git commit -qam "PS3 other" && PS_T=$(git rev-parse HEAD)
cd sub
_P199_AS ps-a --exec -- sh -c 'git mv f g && { echo ONE; sed 1d g; } > g.new && mv g.new g && git commit -qam "PS3 rename f to g"'
{ print -l {1..19}; print TWENTY; } > f && git add f
_P199_AS ps-b --amend-into="$PS_T" -- f
_ST_OUT_HAS "a staged fold's renamed path is named from the top, its steps going there first" \
	"Then stage them again with: cd .* && git add -- sub/g .* – and run this again naming sub/g in place of sub/f, paths from the top, where that cd leaves you\.\$"
PS_MSG=$OUT
PS_CMD=$(sed -n 's/.*the files kept as they are: //p' <<<"$PS_MSG")
eval "${PS_CMD:-false}" >/dev/null 2>&1
_P199_AS ps-b --carry="$(sed -n "s/.*'git edit --carry=\([0-9a-f]*\)'.*/\1/p" <<<"$PS_MSG")"
PS_CMD=$(sed -n 's/.*Then stage them again with: \(.*\) (each holding.*/\1/p' <<<"$PS_MSG")
eval "${PS_CMD:-false}" >/dev/null 2>&1
_P199_AS ps-b --amend-into="$PS_T" -- sub/g
_ST_EQ "and run as told from there, it lands" "$RC:$(git show HEAD:sub/g | tail -1):${PWD:A}" "0:TWENTY:${TMP:A}/pz-ps3"
cd "$TMP/pz-ps3"

# A drop's conflict pause, git's advice to skip or abort the rebase left out
_ST_PZ_NEW ps4
git config rerere.enabled false
_ST_PZ_C f.txt 1 "PS4 base" && _ST_PZ_C f.txt 2 "PS4 two" && _ST_PZ_C f.txt 3 "PS4 three" && _ST_PZ_C f.txt 4 "PS4 four"
_P199_AS ps-a -d HEAD~1
_ST_OUT_HAS "a drop pauses on its conflict, git's conflict line passed on" 'CONFLICT (content): Merge conflict in f.txt'
_ST_OUT_LACKS "never git's advice to skip the commit by hand" 'git rebase --skip'
_ST_OUT_LACKS "nor to abort the rebase by hand" 'git rebase --abort'
# Its status, aborted by hand there, gives the resume's verdict – the pause still as it was before
_P199_AS ps-a --status
_ST_OUT_HAS "a paused drop's status sends the caller to resolve it" '^Resolve there, then git edit --continue'
PS_WT=$(_ST_PZ_WT)
git -C "${PS_WT:-$ST_NO_WT}" rebase --abort >/dev/null 2>&1
_P199_AS ps-a --status
_ST_EQ "aborted by hand there, its status refuses" "$RC" "1"
_ST_OUT_HAS "naming the hand abort, as the resume does" 'was aborted by hand – nothing was applied, and .git edit --continue. refuses it'
_ST_OUT_HAS "and the abort that clears it" "Clear the pause with 'git edit --abort'"
_ST_OUT_LACKS "never to resolve and continue" 'Resolve there'
_P199_AS ps-a --abort
_ST_EQ "which clears it" "$RC:$(git log -1 --format=%s)" "0:PS4 four"

# A placement before the commit its change builds on – the stop for that commit has no answer of
# its own, so the pause names the placement past it, which then lands
_ST_PZ_NEW ps5
git config rerere.enabled false
mkdir sub && print -l 1 2 3 > sub/f && print o > o && git add -A && git commit -qm "PS5 base"
print -l 1 X 3 > sub/f && git commit -qam "PS5 C1" && PS_C=$(git rev-parse HEAD)
print p > o && git commit -qam "PS5 C2"
cd sub && print -l 1 Z 3 > f
_P199_AS ps-a --commit --text "PS5 Z" --before=':/PS5 C1' -- f
PS_WT=$(_ST_PZ_WT)
print -l 1 Z 3 > "${PS_WT:-$ST_NO_WT}/sub/f" && git -C "${PS_WT:-$ST_NO_WT}" add sub/f
_P199_AS ps-a --continue
_ST_OUT_HAS "a placement stopping at the commit it builds on says the answer would empty it" \
	"starts from the pre-op content of sub/f already – resolved to it, ${PS_C:0:7} PS5 C1 keeps no change of its own there"
_ST_OUT_HAS "naming the placement past it" "placed past that change: --after=${PS_C:0:12} in place of --before=${PS_C:0:7}\$"
_ST_OUT_LACKS "never the checkout as its answer" 'No later step touches sub/f'
# Its status names the same, read from what the placement built
_P199_AS ps-a --status
_ST_OUT_HAS "as its status does" "placed past that change: --after=${PS_C:0:12} in place of --before=${PS_C:0:7}\$"
_ST_OUT_LACKS "never the checkout as its answer there either" 'No later step touches sub/f'
PS_AFTER=$(sed -n 's/.*placed past that change: \(--after=[0-9a-f]*\) in place of.*/\1/p' <<<"$OUT")
_P199_AS ps-a --abort
_P199_AS ps-a --commit --text "PS5 Z" ${PS_AFTER:---after=none} -- f
_ST_EQ "and run again as named, it lands" "$RC:$(git log --format=%s -3 | tr '\n' '|'):$(git show HEAD:sub/f | tr '\n' '|')" "0:PS5 C2|PS5 Z|PS5 C1|:1|Z|3|"
cd ..
# A reorder moving a commit before the one it builds on names keeping their order, or the squash
_ST_PZ_NEW ps6
git config rerere.enabled false
_ST_PZ_C f.txt $'1\n2\n3' "PS6 base" && _ST_PZ_C o.txt o "PS6 o"
_ST_PZ_C f.txt $'1\nX\n3' "PS6 S" && PS_S=$(git rev-parse HEAD)
_ST_PZ_C o.txt p "PS6 N" && _ST_PZ_C f.txt $'1\nY\n3' "PS6 M" && PS_M=$(git rev-parse HEAD)
_P199_AS ps-a --move="$PS_M" --before="$PS_S"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\nY\n3'
_P199_AS ps-a --continue
_ST_OUT_HAS "a reorder's stop whose answer would empty its commit says so" \
	"resolved to it, ${PS_S:0:7} PS6 S keeps no change of its own there"
_ST_OUT_HAS "naming the move keeping their order, and the squash" \
	"keep their order by moving it right after that commit instead: git edit --move=${PS_M:0:12} --after=${PS_S:0:12}, or squash the two into one: git edit -s=${PS_S:0:12} ${PS_M:0:12}\$"
_ST_OUT_LACKS "never the checkout as its answer" 'No later step touches f.txt'
# Taken anyway, the continue refuses with that same way on
git -C "$(_ST_PZ_WT)" checkout HEAD -- f.txt 2>/dev/null
_P199_AS ps-a --continue
_ST_OUT_HAS "as the refusal the answer meets names it" \
	"git edit --move=${PS_M:0:12} --after=${PS_S:0:12}, or squash the two into one: git edit -s=${PS_S:0:12} ${PS_M:0:12}\$"
_P199_AS ps-a --abort
