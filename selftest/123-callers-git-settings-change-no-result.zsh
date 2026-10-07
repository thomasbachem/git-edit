# The suite runs on git's defaults, while a caller's config colors, lists in columns, hides
# untracked files, autosquashes, skips blame revisions and spells renames `copies` – set in
# the suite's own global config here, each case in a repo of its own
_ST_SCENARIO "\e[1;96m[123] a caller's git settings change no result\e[0m"
local RS_WT RS_T RS_N RS_K RS_V RS_HOME
for RS_K RS_V in color.ui always column.ui always status.showUntrackedFiles no rebase.autoSquash true \
		rebase.instructionFormat '%s [%an]' blame.ignoreRevsFile .git-blame-ignore-revs; do
	git config --file "$GIT_CONFIG_GLOBAL" "$RS_K" "$RS_V"
done
# A line's owner, whatever color does to the diff and a missing ignore-revs file to blame
_ST_PZ_NEW rs1
printf 'b1\nb2\nb3\nb4\nb5\nb6\n' > bl.txt && git add bl.txt && git commit -qm "RS base"
printf 'b1\nA\nb3\nb4\nb5\nb6\n' > bl.txt && git commit -qam "RS add A"
printf 'b1\nA\nb3\nb4\nb5\nB\n' > bl.txt && git commit -qam "RS add B"
printf 'b1\nA2\nb3\nb4\nb5\nB\n' > bl.txt && git add bl.txt
_ST_RUN --amend-into=auto
_ST_EQ "auto-target folds into the line's owner" "$RC:$(git show HEAD~1:bl.txt | sed -n 2p):$(git log -1 --format=%s)" "0:A2:RS add B"
_ST_OUT_LACKS "printing its stat without raw escapes" '\^\['
# The same owner whatever else a caller configured – an ignore-revs file that exists and lists
# it, an external diff tool, a textconv driver shifting the lines, a repo trusted by the global
# config alone, which the retry past a missing ignore-revs file must keep
printf '#!/bin/sh\necho external\n' > "$TMP/rs-ext" && chmod +x "$TMP/rs-ext"
mkdir -p "$TMP/rs-home" && printf '[blame]\n\tignoreRevsFile = .git-blame-ignore-revs\n' > "$TMP/rs-home/.gitconfig"
for RS_N in ign ext tc tc2 safe home; do
	_ST_PZ_NEW rs1-$RS_N
	RS_HOME=$HOME
	# A line close to the one it replaced, which blame passes on to the parent when told to skip
	printf 'b1\nb2\nb3\nb4\nb5\nb6\n' > bl.txt && git add bl.txt && git commit -qm "RS base"
	printf 'b1\nb2 A\nb3\nb4\nb5\nb6\n' > bl.txt && git commit -qam "RS add A"
	printf 'b1\nb2 A\nb3\nb4\nb5\nB\n' > bl.txt && git commit -qam "RS add B"
	case $RS_N in
		ign) git rev-parse HEAD~1 > .git-blame-ignore-revs ;;
		ext) git config diff.external "$TMP/rs-ext" ;;
		# In the repo, which the retry reads too – `tc2`'s ignore-revs file lets the first blame pass
		tc|tc2) git config diff.rstc.textconv "awk 'BEGIN { print \"header\" } { print }'"
			print -r -- 'bl.txt diff=rstc' > .git/info/attributes
			[ $RS_N = tc2 ] && : > .git-blame-ignore-revs ;;
		# Only where git reads this config at all – one before 2.32 passes `GIT_CONFIG_GLOBAL` by
		safe) git config --file "$GIT_CONFIG_GLOBAL" safe.directory '*'
			[ "$(git config --get safe.directory)" = '*' ] && export GIT_TEST_ASSUME_DIFFERENT_OWNER=1 ;;
		# The `HOME` config a git before 2.32 reads past `GIT_CONFIG_GLOBAL`, which the retry skips too
		home) RS_HOME="$TMP/rs-home" ;;
	esac
	printf 'b1\nb2 A2\nb3\nb4\nb5\nB\n' > bl.txt && git add bl.txt
	HOME=$RS_HOME _ST_RUN --amend-into=auto
	unset GIT_TEST_ASSUME_DIFFERENT_OWNER
	_ST_EQ "auto-target folds into the line's owner – $RS_N" "$RC:$(git show HEAD~1:bl.txt | sed -n 2p)" "0:b2 A2"
done
git config --file "$GIT_CONFIG_GLOBAL" --unset safe.directory
# A submodule's pointer has no lines to blame, so its bump folds into the commit that last moved it
_ST_PZ_NEW rs1-sm
_ST_PZ_C f.txt f "RS sm base"
git update-index --add --cacheinfo 160000,"$(git rev-parse HEAD)",sub && git commit -qm "RS sm add sub"
_ST_PZ_C g.txt g "RS sm later"
RS_T=$(git rev-parse HEAD)
git update-index --cacheinfo 160000,"$RS_T",sub
_ST_RUN --amend-into=auto
_ST_EQ "a submodule bump folds into the commit that last moved it" "$RC:$(git log -1 --format=%s HEAD~1):$(git rev-parse HEAD~1:sub)" "0:RS sm add sub:$RS_T"
# Insertions alone carry no owner, however close a caller's hunk context draws them to a line
_ST_PZ_NEW rs1-ihc
printf 'l%s\n' {1..12} > f.txt && git add f.txt && git commit -qm "RS ihc base"
sed 's/^l4$/l4 A/' f.txt > f.tmp && mv f.tmp f.txt && git commit -qam "RS ihc A"
sed 's/^l11$/l11 B/' f.txt > f.tmp && mv f.tmp f.txt && git commit -qam "RS ihc B"
git config diff.interHunkContext 10
awk '{ print } /^l3$/ { print "ins" } /^l4 A$/ { print "ins" }' f.txt > f.tmp && mv f.tmp f.txt && git add f.txt
_ST_RUN --amend-into=auto
_ST_EQ "insertions fold into the newest commit, whatever hunk context a caller set" \
	"$RC:$(git show HEAD~1:f.txt | grep -c ins):$(git show HEAD:f.txt | grep -c ins)" "0:0:2"
# A file an edit adds is a change, whatever hides untracked files from `git status`
_ST_PZ_NEW rs2
for RS_N in a b; do _ST_PZ_C "$RS_N.txt" "$RS_N" "RS $RS_N"; done
_ST_RUN HEAD~1
RS_WT=$(_ST_PZ_WT)
print -r -- new > "${RS_WT:-$ST_NO_WT}/new.txt"
_ST_RUN --continue
_ST_EQ "an edit adding a file alone lands it" "$RC:$(git cat-file -t HEAD~1:new.txt 2>/dev/null)" "0:blob"
# Another caller's pending `fixup!` stays its own commit through a drop below its target
_ST_PZ_NEW rs3
for RS_N in base X A; do _ST_PZ_C "$RS_N.txt" "$RS_N" "RS $RS_N"; done
print -r -- A2 > A.txt && git commit -qam "fixup! RS A"
_ST_PZ_C C.txt C "RS C"
_ST_RUN -d HEAD~3
_ST_EQ "a drop leaves another's fixup! alone" "$RC:$(git log --format=%s | grep -c '^fixup! RS A$')" "0:1"
# Two tags in the rewritten span are named apart, whatever columns `git tag` lists them in
_ST_PZ_NEW rs4
for RS_N in a b c; do _ST_PZ_C "$RS_N.txt" "$RS_N" "RS $RS_N"; done
git tag rs-one HEAD && git tag rs-two HEAD
_ST_RUN -M --text "RS below the tags" HEAD~1
_ST_OUT_HAS "a tag in the rewritten span is named alone" 'Tag rs-one points into'
_ST_OUT_HAS "as is the other" 'Tag rs-two points into'
# A conflict's remaining steps read as git's default todo, whatever format a caller set
_ST_PZ_NEW rs5
_ST_PZ_C cf.txt 1 "RS cf base"
_ST_PZ_C cf.txt 2 "RS cf one"
_ST_PZ_C cf.txt 3 "RS cf two"
_ST_PZ_C cg.txt g "RS cf three"
print -r -- x > cf.txt && git add cf.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- cf.txt
_ST_OUT_HAS "a fold conflicting downstream lists what remains" 'RS cf three'
_ST_OUT_LACKS "in the default form" 'RS cf three \[P\]'
_ST_RUN --abort
# As do an edit's, its replay conflicting the same way
_ST_PZ_NEW rs5b
_ST_PZ_C ef.txt 1 "RS ef base"
_ST_PZ_C ef.txt 2 "RS ef one"
_ST_PZ_C ef.txt 3 "RS ef two"
_ST_PZ_C eg.txt g "RS ef three"
_ST_RUN HEAD~2
RS_WT=$(_ST_PZ_WT)
print -r -- x > "${RS_WT:-$ST_NO_WT}/ef.txt"
_ST_RUN --continue
_ST_OUT_HAS "an edit conflicting downstream lists what remains" 'RS ef three'
_ST_OUT_LACKS "in the default form too" 'RS ef three \[P\]'
_ST_RUN --abort
# A rename the merge won't pair is refused, whatever `copies` another config file says
_ST_PZ_NEW rs6
git config --file "$GIT_CONFIG_GLOBAL" diff.renames copies
git config diff.renames ''
for RS_N in {1..12}; do print -r -- "rn line $RS_N"; done > rn_old.txt && git add rn_old.txt && git commit -qm "RS rn base"
RS_T=$(git rev-parse HEAD)
git mv rn_old.txt rn_new.txt && git commit -qm "RS rename"
sed 's/^rn line 3$/rn line 3 fixed/' rn_new.txt > rn_new.tmp && mv rn_new.tmp rn_new.txt && git add rn_new.txt
_ST_RUN --amend-into="$RS_T" -- rn_new.txt
_ST_EQ "a fold the merge can't pair is refused" "$RC" "1"
_ST_OUT_HAS "naming where the path arrives" 'rn_new.txt – arrives in'
_ST_RUN --abort
git config --file "$GIT_CONFIG_GLOBAL" --unset diff.renames
# Nor does `log.follow` hide where the path arrives, and `merge.renames` reads as git's merge
# reads it – `0x0` as false, a key with no value as the fatal error that pairs nothing
for RS_N in follow zero valueless; do
	_ST_PZ_NEW rs6-$RS_N
	case $RS_N in
		follow) git config --file "$GIT_CONFIG_GLOBAL" log.follow true
			git config diff.renames false ;;
		zero) git config merge.renames 0x0 ;;
		valueless) printf '[merge]\n\trenames\n' >> .git/config ;;
	esac
	for RS_K in {1..12}; do print -r -- "rn line $RS_K"; done > rn_old.txt && git add rn_old.txt && git commit -qm "RS rn base"
	RS_T=$(git rev-parse HEAD)
	git mv rn_old.txt rn_new.txt && git commit -qm "RS rename"
	sed 's/^rn line 3$/rn line 3 fixed/' rn_new.txt > rn_new.tmp && mv rn_new.tmp rn_new.txt && git add rn_new.txt
	_ST_RUN --amend-into="$RS_T" -- rn_new.txt
	_ST_EQ "a fold the merge can't pair is refused – $RS_N" "$RC" "1"
	_ST_OUT_HAS "naming where the path arrives" 'rn_new.txt – arrives in'
	_ST_RUN --abort
done
git config --file "$GIT_CONFIG_GLOBAL" --unset log.follow
# A repo hiding its untracked files has them left as they are – the run never touches the checkout
# but to bring it along, and a stash would have taken every one of them
_ST_PZ_NEW rs7
# In the repo, as a git before 2.32 reads no `GIT_CONFIG_GLOBAL`
git config status.showUntrackedFiles no
for RS_N in a b c; do _ST_PZ_C "$RS_N.txt" "$RS_N" "RS $RS_N"; done
print -r -- scratch > rs-untracked.txt
_ST_TTY -- -d -y HEAD
_ST_EQ "a terminal run where untracked files are hidden lands, leaving one as it was" "$RC:$(git log -1 --format=%s):$(<rs-untracked.txt)" "0:RS b:scratch"
_ST_OUT_LACKS "stashing none of them" 'git stash'
# A pushed commit is named as pushed, whatever columns list the remote branches holding it
_ST_PZ_NEW rs8
_ST_PZ_C a.txt a "RS pushed"
rm -rf "$TMP/pz-rs8-origin.git" && git init -q --bare "$TMP/pz-rs8-origin.git"
git remote add origin "$TMP/pz-rs8-origin.git" && git push -q origin main 2>/dev/null && git remote set-head origin main
_ST_PZ_C b.txt b "RS local"
_ST_RUN -M --text "RS reworded" HEAD~1
_ST_EQ "a pushed commit refuses its reword" "$RC" "1"
_ST_OUT_HAS "naming the remote branch holding it" 'already pushed (on: origin/main)'
for RS_K in color.ui column.ui status.showUntrackedFiles rebase.autoSquash rebase.instructionFormat blame.ignoreRevsFile; do
	git config --file "$GIT_CONFIG_GLOBAL" --unset "$RS_K"
done
cd "$TMP/repo"
