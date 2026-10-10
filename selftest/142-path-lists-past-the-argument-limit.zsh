# A landing over more paths than one command line holds re-syncs them all – its flags, an
# intent-to-add entry and a flagged file's hidden edits included – where a git call fed the
# list failed silently and left every entry on the dropped content
_ST_SCENARIO "\e[1;96m[142] a landing past the argument limit re-syncs every path\e[0m"
local AL_D AL_I AL_N=3000 AL_H AL_O AL_PADS
# Paths of ~800 bytes, 3,000 of them – past both macOS's 1 MB and Linux's 2 MB for one exec
AL_D="${(l:200::d:)}/${(l:200::e:)}/${(l:200::f:)}/${(l:200::g:)}"
_ST_PZ_NEW al
mkdir -p "$AL_D"
for AL_I in {1..$AL_N}; do print -r -- $'1\n2\n3' > "$AL_D/f$AL_I.txt"; done
print n > n.txt
git add -A && git commit -qm "AL base"
for AL_I in {1..$AL_N}; do print -r -- $'1\nb\n3' > "$AL_D/f$AL_I.txt"; done
git rm -q n.txt && git add -A && git commit -qm "AL change all"
_ST_PZ_C t.txt t "AL tip"
AL_H=$(git rev-parse HEAD)
# Every entry flagged, and `n.txt` – which the drop brings back – intent-to-add
git ls-files -z | git update-index -z --assume-unchanged --stdin
print mine > n.txt && git add -N n.txt
_ST_RUN -d -y HEAD~1
_ST_EQ "an agent's drop over 3,000 long paths lands" "${RC}:$(git log -1 --format=%s HEAD~1)" "0:AL base"
_ST_EQ "every stranded entry re-synced" "$(git diff --cached --name-only | wc -l | tr -d ' ')" "0"
_ST_EQ "each keeping its assume-unchanged flag" "$(git ls-files -v | grep -c '^h')" "$(( AL_N + 1 ))"
_ST_EQ "and the intent-to-add entry superseded, the file kept" "$(git diff --cached --name-only -- n.txt):$(cat n.txt)" ":mine"
# Unflagged, the same drop leaves the dropped content stale in the checkout – the discard it offers
# over all of it runs, the paths read from a file it names, and the output stays short
git ls-files -z | git update-index -z --no-assume-unchanged --stdin
git reset -q --hard "$AL_H"
_ST_RUN -d -y HEAD~1
AL_H=${(M)${(f)OUT}:#*discard it with: *}
AL_H=${AL_H#*discard it with: }
_ST_EQ "an unflagged drop over them names the stale content in short" "${RC}:$(( ${#OUT} < 20000 ))" "0:1"
_ST_CHECK "and the discard it offers runs" sh -c "${AL_H:-false}"
_ST_EQ "taking the checkout to what landed" "$(git status --porcelain | wc -l | tr -d ' ')" "0"
# A terminal sync finds the one flagged file among them and merges its hidden edit
git reset -q --hard
for AL_I in {1..$AL_N}; do print -r -- $'1\nc\n3' > "$AL_D/f$AL_I.txt"; done
git add -A && git commit -qm "AL change again"
_ST_PZ_C t.txt t2 "AL tip 2"
git update-index --assume-unchanged "$AL_D/f7.txt" && print -r -- $'1\nc\n3\nmine' > "$AL_D/f7.txt"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a terminal drop over them lands" "${RC}:$(git log -1 --format=%s HEAD~1)" "0:AL tip"
_ST_EQ "the flagged file's hidden edit merged onto what landed" "$(cat "$AL_D/f7.txt")" $'1\n2\n3\nmine'
_ST_EQ "the rest brought along" "$(cat "$AL_D/f8.txt")" $'1\n2\n3'
# A stop staging 1,000 paths of ~930 bytes reads them from the whole index, counted in bytes – an
# environment padded to the limit's rest makes their one command line too long – so a resolution
# staged without the bit the replay carries is still refused
_ST_PZ_NEW al2
AL_O="${(l:230::o:)}/${(l:230::p:)}/${(l:230::q:)}/${(l:230::r:)}"
printf '#!/bin/sh\necho al1\n' > al.sh && chmod +x al.sh && mkdir -p "$AL_O"
for AL_I in {1..999}; do print a > "$AL_O/f$AL_I.txt"; done
git add -A && git commit -qm "AL2 base"
printf '#!/bin/sh\necho al2\n' > al.sh
for AL_I in {1..999}; do print b > "$AL_O/f$AL_I.txt"; done
git add -A && git commit -qm "AL2 later"
_ST_PZ_C top.txt top "AL2 top"
printf '#!/bin/sh\necho al1-folded\n' > al.sh && git add al.sh
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- al.sh
AL_I=$(_ST_PZ_WT)
_ST_RESOLVE "$AL_I" al.sh $'#!/bin/sh\necho al1-folded'
_ST_RUN --continue
_ST_OUT_HAS "a fold reaches the stop of a commit touching 999 more files" 'AL2 later'
_ST_REWRITE "$AL_I" al.sh $'#!/bin/sh\necho al2-resolved'
# 64 KB a variable, as Linux caps one string at 128 KB
AL_PADS=$(( ( $(getconf ARG_MAX) - 999 * (${#AL_O} + 10) + 131072 ) / 65536 ))
for (( AL_I = 1; AL_I <= AL_PADS; AL_I++ )); do export "AL_PAD$AL_I=${(l:65535::x:)}"; done
_ST_RUN --continue
for (( AL_I = 1; AL_I <= AL_PADS; AL_I++ )); do unset "AL_PAD$AL_I"; done
_ST_OUT_HAS "where a resolution staged without the bit is refused" 'al\.sh: staged 100644, the replay carries 100755'
_ST_RUN --abort
