#!/bin/zsh
# Prints `selftest-times.tsv` afresh – each scenario's seconds in runs' macOS serial slices, off log
# line timestamps, a run's longest where slices share it, averaged as runners differ in speed
# Args: <run id>... – the output goes to `.github/selftest-times.tsv` whole, header included
emulate zsh
REPO=thomasbachem/git-edit
(( $# )) || { print -r -- "usage: selftest-times.zsh <run id>..." >&2; exit 2 }
print -r -- "# Seconds per scenario run serially on macos-15 – the slicer's weights, from runs ${(j:, :)@}"
print -r -- "# Refresh: .github/selftest-times.zsh <run id>... > .github/selftest-times.tsv"
for RUN in "$@"; do
	JOBS=(${(f)"$(gh run view "$RUN" --repo "$REPO" --json jobs \
		--jq '.jobs[] | select(.name | startswith("macos – serial")) | .databaseId')"})
	(( ${#JOBS} )) || { print -r -- "selftest-times: run $RUN has no macOS serial slices" >&2; exit 1 }
	for J in $JOBS; do
		gh run view --job "$J" --repo "$REPO" --log || exit 1
		print -r -- "--end of job--"
	done
	print -r -- "--end of run--"
done | LC_ALL=C awk -F'\t' '
	# Seconds into the day of a line timestamp – a scenario running past midnight wraps once
	function secs(ts) { return substr(ts, 12, 2) * 3600 + substr(ts, 15, 2) * 60 + substr(ts, 18, 9) }
	function close_at(t) {
		if (cur == "") return
		d = t - t0; if (d < 0) d += 86400
		if (d > best[cur]) best[cur] = d
		cur = ""
	}
	/^--end of job--$/ { cur = ""; next }
	/^--end of run--$/ { for (id in best) { sum[id] += best[id]; runs[id]++ } delete best; next }
	{
		line = $0; sub(/^[^\t]*\t[^\t]*\t/, "", line); sub(/^\357\273\277/, "", line)
		if (line !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) next
		t = secs(line); text = substr(line, index(line, " ") + 1)
		if (text ~ /^\[[0-9]+[a-z]?\] / || text ~ /^(Selftest|git-edit): /) close_at(t)
		if (text ~ /^\[[0-9]+[a-z]?\] /) { cur = substr(text, 2, index(text, "]") - 2); t0 = t; best[cur] += 0 }
	}
	END {
		for (id in sum) {
			n = id; sub(/[a-z]$/, "", n)
			printf "%06d%s\t%s\t%d\n", n, substr(id, length(n) + 1), id, sum[id] / runs[id] + 0.5
		}
	}
' | sort | cut -f2-
