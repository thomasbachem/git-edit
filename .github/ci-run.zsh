#!/bin/zsh
# Runs the release test on GitHub for a commit – pushed as `ci/<name>`, its run waited for, each
# leg's verdict and minutes printed, the branch deleted again – exiting 0 only if every leg passed
# Args: <commit> [<name>] – run from a checkout of this repo, with `gh` signed in
emulate zsh
REPO=thomasbachem/git-edit
URL=https://github.com/${REPO}
C=$(git rev-parse --verify -q "${1:?commit}^{commit}") || { print -r -- "ci-run: no commit $1"; exit 2 }
B=ci/${2:-${C:0:12}}
git cat-file -e "${C}:.github/workflows/selftest.yml" 2>/dev/null || { print -r -- "ci-run: ${C:0:12} has no workflow"; exit 2 }
# GitHub's offer of a pull request for the new branch printed only where the push fails
OUT=$(git push -q "$URL" "${C}:refs/heads/${B}" 2>&1) || { print -r -- "$OUT"; exit 2 }
# The run that push started, listed a few seconds late
for I in {1..36}; do
	ID=$(gh run list --repo "$REPO" --branch "$B" --workflow selftest.yml --json databaseId,headSha \
		--jq ".[] | select(.headSha == \"${C}\") | .databaseId" 2>/dev/null | head -1)
	[ -n "$ID" ] && break
	sleep 5
done
if [ -z "$ID" ]; then
	print -r -- "ci-run: no run started for $B"
	git push -q "$URL" --delete "$B"
	exit 2
fi
print -r -- "ci-run: ${URL}/actions/runs/${ID}"
# Polled, as `gh run watch` ends on the first dropped connection, which reads as a failed run –
# each read retried, until ten in a row go unanswered
FAILS=0 ST=""
while (( FAILS < 10 )); do
	if S=$(gh run view "$ID" --repo "$REPO" --json status,conclusion --jq '"\(.status) \(.conclusion)"' 2>/dev/null) && [ -n "$S" ]; then
		FAILS=0 ST=$S
		[ "${ST%% *}" = completed ] && break
	else
		FAILS=$(( FAILS + 1 ))
	fi
	sleep 30
done
for I in {1..5}; do
	gh run view "$ID" --repo "$REPO" --json jobs --jq '.jobs[] |
		"\(.conclusion // .status)\t\((((.completedAt | fromdate) - (.startedAt | fromdate)) / 60) | floor) min\t\(.name)"' 2>/dev/null && break
	sleep 10
done
git push -q "$URL" --delete "$B"
# A fetch while the run ran leaves a tracking ref, which makes `git edit` read the commit as pushed
git branch -r -d "origin/$B" >/dev/null 2>&1
case $ST in
	"completed success") print -r -- "ci-run: ok – ${C:0:12}"; exit 0 ;;
	completed\ *) print -r -- "ci-run: failed – gh run view $ID --repo $REPO --log-failed"; exit 1 ;;
	*) print -r -- "ci-run: no answer from GitHub – the run's verdict is at ${URL}/actions/runs/${ID}"; exit 2 ;;
esac
