# The amend's `-m` replaces the whole message and the summary's `edited:` line is a subject,
# as a reword's are – and a `--- <commit>` record replaces its message whole the same way
_ST_SCENARIO "\e[1;96m[76] an edit's --continue --text and a reword record name the body they drop\e[0m"
printf 'eb1\nEB-ME\n' > eb.txt && git add eb.txt
git commit -q -F - <<-'EBMSG'
	EB target

	• first body line
	• second body line
EBMSG
local EB_TARGET=$(git rev-parse HEAD)
echo "eb-later" > eb2.txt && git add eb2.txt && git commit -qm "EB later"
_ST_RUN "$EB_TARGET"
_ST_EQ "edit pauses (exit 2)" "$RC" "2"
local EB_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \(.*\); then.*/\1/p')
printf 'eb1\nEB-EDITED\n' > "${EB_WT:-$ST_NO_WT}/eb.txt"
_ST_RUN --continue --text "EB target, edited"
_ST_EQ "the body-dropping continue applies" "$RC" "0"
_ST_OUT_HAS "names the dropped body, with its length" "carried a 2-line body the new one drops – it is still readable at ${EB_TARGET:0:12}"
_ST_OUT_HAS "and prints its lines" '    • second body line'
# Neighbor: a continue without --text keeps the message whole
printf 'ec1\nEC-ME\n' > ec.txt && git add ec.txt
git commit -q -F - <<-'ECMSG'
	EC target

	• a body line
ECMSG
local EC_TARGET=$(git rev-parse HEAD)
echo "ec-later" > ec2.txt && git add ec2.txt && git commit -qm "EC later"
_ST_RUN "$EC_TARGET"
local EC_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \(.*\); then.*/\1/p')
printf 'ec1\nEC-EDITED\n' > "${EC_WT:-$ST_NO_WT}/ec.txt"
_ST_RUN --continue
_ST_EQ "a content-only continue applies" "$RC" "0"
_ST_OUT_LACKS "and draws no notice" 'carried a .*-line body'
# The records form of reword
printf 'bb1\n' > bb.txt && git add bb.txt
git commit -q -F - <<-'BBMSG'
	BB target

	• body line to lose
BBMSG
local BB_TARGET=$(git rev-parse HEAD)
_ST_RUN_IN "$(printf -- '--- %s\nBB target reworded\n' "$BB_TARGET")" -M --text -
_ST_EQ "a body-dropping record applies" "$RC" "0"
_ST_OUT_HAS "names the dropped body" "carried a 1-line body the new one drops – it is still readable at ${BB_TARGET:0:12}"
_ST_OUT_HAS "and prints its line" '    • body line to lose'
git reset -q --hard
