# An option taking one value refuses to be given twice
# The parser kept the last value alone, so a fold given two targets or two trees took the
# second, and a second message or check replaced the first, with nothing said
_ST_SCENARIO "\e[1;96m[87] an option taking one value refuses a repeat\e[0m"
echo "rp" > rp.txt && git add rp.txt && git commit -qm "RP one"
echo "rp" > rp2.txt && git add rp2.txt && git commit -qm "RP two"
local RP_HEAD=$(git rev-parse HEAD)
echo "folded" >> rp.txt && git add rp.txt
_ST_RUN --amend-into="$(git rev-parse ':/RP one')" --amend-into="$(git rev-parse ':/RP two')" -- rp.txt
_ST_EQ "--amend-into given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming the repeat" '--amend-into given twice'
_ST_RUN --selftest=70 --jobs=1 --jobs=2
_ST_OUT_HAS "--jobs given twice refuses too" '--jobs given twice'
_ST_CHECK "leaving the fold staged" sh -c '! git diff --cached --quiet -- rp.txt'
_ST_RUN --split="$(git rev-parse ':/RP two')" --split="$(git rev-parse ':/RP one')" --text="RP split" -- rp2.txt
_ST_EQ "--split given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming it there" '--split given twice'
_ST_RUN --onto="$(git rev-parse ':/RP one')" --onto="$(git rev-parse ':/RP two')"
_ST_EQ "--onto given twice refuses" "$RC" "1"
_ST_OUT_HAS "and there" '--onto given twice'
_ST_RUN -y -s="$(git rev-parse ':/RP one')" -s="$(git rev-parse ':/RP two')" "$(git rev-parse ':/RP two')"
_ST_EQ "-s= given twice refuses" "$RC" "1"
_ST_OUT_HAS "and there too" 'squash given twice'
# Each second value below would have landed – a fold of the other tree, a reword to the other
# message, a fold the failing check never gated, a pause in the other directory
local RP_TA=$(_ST_COMPOSE rp.txt "rp tree a")
local RP_TB=$(_ST_COMPOSE rp.txt "rp tree b")
_ST_RUN --amend-into="$(git rev-parse ':/RP one')" --tree="$RP_TA" --tree="$RP_TB" -- rp.txt
_ST_EQ "--tree given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming one tree" '--tree given twice – it names one tree'
_ST_RUN -M --text="RP first" --text="RP second" "$(git rev-parse ':/RP two')"
_ST_EQ "--text given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming one message" '--text given twice – it takes one message'
_ST_RUN --amend-into="$(git rev-parse ':/RP one')" --verify=false --verify=true -- rp.txt
_ST_EQ "--verify given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming one command" '--verify given twice – it runs one command'
_ST_RUN -C="$TMP/rp-wt-a" -C="$TMP/rp-wt-b" "$(git rev-parse ':/RP one')"
_ST_EQ "-C given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming one directory" '-C/--dir given twice – it takes one directory'
# Spelled both ways, the two landed apart in the parser even before – and the first one won
_ST_RUN -C="$TMP/rp-wt-a" --dir="$TMP/rp-wt-b" "$(git rev-parse ':/RP one')"
_ST_EQ "-C and --dir together refuse" "$RC" "1"
_ST_OUT_HAS "as one option" '-C/--dir given twice – it takes one directory'
_ST_CHECK "pausing in neither" sh -c '[ ! -e "$1" ] && [ ! -e "$2" ]' _ "$TMP/rp-wt-a" "$TMP/rp-wt-b"
_ST_EQ "none of them moving anything" "$(git rev-parse HEAD)" "$RP_HEAD"
# Given once, the same fold lands – the refusal is the repeat's alone
_ST_RUN --amend-into="$(git rev-parse ':/RP one')" -- rp.txt
_ST_EQ "a single --amend-into folds" "$RC" "0"
_ST_EQ "into the commit it names" "$(git show "$(git rev-parse ':/RP one')":rp.txt | tail -1)" "folded"
