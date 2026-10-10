#!/bin/zsh
# Prints the `--selftest` pick for slice <k> of <n> – the suite in its own order, cut into <n> runs
# of about equal time by `selftest-times.tsv`, a scenario it lacks weighed by its line count
# Args: <k> <n>
emulate zsh
K=${1:?slice} N=${2:?slices}
typeset -A ID_OF SIZE_OF SECS
typeset -a CONTENT PICK
typeset -F RATE=1 W TOTAL=0 SUM=0 TIMED=0 TIMED_LINES=0
typeset -i AT
for ROW in "${(@f)$(<${0:A:h}/selftest-times.tsv)}"; do
	[[ $ROW == [0-9]* ]] && SECS[${ROW%%$'\t'*}]=${ROW#*$'\t'}
done
for F in ${0:A:h:h}/selftest/[0-9]*.zsh; do
	[[ ${F:t} =~ '^0*([0-9]+)([a-z]?)-' ]] || continue
	# Number and letter apart, the order git-edit runs them in
	KEY=$(printf '%06d%s' $match[1] "$match[2]")
	ID_OF[$KEY]=$match[1]$match[2]
	CONTENT=("${(@f)$(<$F)}")
	SIZE_OF[$KEY]=${#CONTENT}
	(( ${+SECS[$ID_OF[$KEY]]} )) && (( TIMED += SECS[$ID_OF[$KEY]], TIMED_LINES += ${#CONTENT} ))
done
(( TIMED_LINES )) && (( RATE = TIMED / TIMED_LINES ))
for KEY in ${(k)ID_OF}; do
	(( TOTAL += ${+SECS[$ID_OF[$KEY]]} ? SECS[$ID_OF[$KEY]] : SIZE_OF[$KEY] * RATE ))
done
# Each scenario goes to the slice its midpoint falls in, so the slices stay contiguous
for KEY in ${(o)${(k)ID_OF}}; do
	(( W = ${+SECS[$ID_OF[$KEY]]} ? SECS[$ID_OF[$KEY]] : SIZE_OF[$KEY] * RATE ))
	(( SUM += W ))
	(( AT = (2 * SUM - W) * N / (2 * TOTAL) + 1 ))
	(( AT > N )) && AT=N
	(( AT == K )) && PICK+=($ID_OF[$KEY])
done
(( ${#PICK} )) || exit 1
print -r -- "$PICK[1]-$PICK[-1]"
