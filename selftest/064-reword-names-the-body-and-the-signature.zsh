# A reword names what it discarded: message body, signature
# Both summary lines above are subjects, so a caller comparing those reads a body-dropping
# `--text` as clean – and a rebuild mints new objects, so a signature cannot come along
# either, with neither showing in a tree or a subject
_ST_SCENARIO "\e[1;96m[64] a reword names the body and the signature it drops\e[0m"
git reset -q --hard
printf 'nb\n' > nb.txt && git add nb.txt
git commit -q -F - <<-'NBMSG'
	NB subject

	• first body line
	• second body line
NBMSG
local NB_TARGET=$(git rev-parse HEAD)
_ST_RUN -M --text="NB subject reworded" "$NB_TARGET"
_ST_EQ "the body-dropping reword applies" "$RC" "0"
_ST_OUT_HAS "names the dropped body, with its length" 'carried a 2-line body'
_ST_OUT_HAS "and where it stays readable" 'still readable at [0-9a-f]\{12\}'
# Neighbor: a `--text` that restates the body discards nothing
_ST_RUN -M --text="$(printf 'NB kept\n\n• first body line')" HEAD
_ST_EQ "a body-preserving reword applies" "$RC" "0"
_ST_OUT_LACKS "a restated body draws no notice" 'carried a .*-line body'
# Nor does one that restates every old line and adds to them
_ST_RUN -M --text="$(printf 'NB kept more\n\n• first body line\n• added body line')" HEAD
_ST_EQ "a body-extending reword applies" "$RC" "0"
_ST_OUT_LACKS "an extended body draws no notice either" 'carried a .*-line body'
# A `--text` carrying a body of its own can still cut lines – a whole-body check reads that as
# clean, and a count alone would not say which lines went, so they print
_ST_RUN -M --text="$(printf 'NB cut\n\n• added body line')" HEAD
_ST_EQ "a body-cutting reword applies" "$RC" "0"
_ST_OUT_HAS "names the lines the new body lacks" 'carried a 2-line body – the new one lacks 1 of its lines, still readable at [0-9a-f]\{12\}'
_ST_EQ "and prints the missing line, once" "$(print -r -- "$OUT" | grep -c '    • first body line')" "1"
_ST_EQ "not the kept one" "$(print -r -- "$OUT" | grep -c '    • added body line')" "1"
# Negative: a subject-only message has no body to lose
printf 'nb2\n' > nb2.txt && git add nb2.txt && git commit -qm "NB plain"
_ST_RUN -M --text="NB plain reworded" HEAD
_ST_OUT_LACKS "nor does a subject-only message" 'carried a .*-line body'
# The signature header is read raw, not through `%G?`, so this holds on a
# machine with no gpg at all – which is why the fixture can forge one
printf 'ns\n' > ns.txt && git add ns.txt && git commit -qm "NS target"
local NS_TARGET=$(git rev-parse HEAD)
printf 'ns2\n' > ns2.txt && git add ns2.txt && git commit -qm "NS signed descendant"
local NS_RAW=$TMP/ns-raw
git cat-file commit HEAD | awk '{ print } /^committer /{ print "gpgsig -----BEGIN PGP SIGNATURE-----"; print " selftest-only, never verified"; print " -----END PGP SIGNATURE-----" }' > "$NS_RAW"
git update-ref refs/heads/main "$(git hash-object -w -t commit "$NS_RAW")"
_ST_RUN -M --text="NS target reworded" "$NS_TARGET"
_ST_EQ "a reword under a signed descendant applies" "$RC" "0"
_ST_OUT_HAS "names the signature the rebuild could not carry" 'carried [0-9]* signature'
# The notice sits on the shared ref-move path, so it covers every mode –
# pin a second, non-reword one rather than trusting that by construction
printf 'nr\n' > nr.txt && git add nr.txt && git commit -qm "NR first"
printf 'nr2\n' > nr2.txt && git add nr2.txt && git commit -qm "NR second"
printf 'nr3\n' > nr3.txt && git add nr3.txt && git commit -qm "NR signed tip"
local NR_RAW=$TMP/nr-raw
git cat-file commit HEAD | awk '{ print } /^committer /{ print "gpgsig -----BEGIN PGP SIGNATURE-----"; print " selftest-only, never verified"; print " -----END PGP SIGNATURE-----" }' > "$NR_RAW"
git update-ref refs/heads/main "$(git hash-object -w -t commit "$NR_RAW")"
_ST_RUN -S HEAD~2 HEAD~1
_ST_EQ "a resquash under a signed tip applies" "$RC" "0"
_ST_OUT_HAS "and a non-reword mode names the signature too" 'carried [0-9]* signature'
# A SHA-256 signature and a merged tag's are signatures as much
printf 'nh\n' > nh.txt && git add nh.txt && git commit -qm "NH signed tip"
git cat-file commit HEAD | awk '{ print } /^committer /{ print "gpgsig-sha256 -----BEGIN PGP SIGNATURE-----"; print " selftest-only"; print " -----END PGP SIGNATURE-----"; print "mergetag object 0000000000000000000000000000000000000000"; print " type commit" }' > "$NR_RAW"
git update-ref refs/heads/main "$(git hash-object -w -t commit "$NR_RAW")"
_ST_RUN -M --text="NH signed tip reworded" HEAD
_ST_OUT_HAS "a gpgsig-sha256 and a mergetag header count as signatures" 'carried 2 signature'
# Negative: unsigned history says nothing about signatures
_ST_RUN -M --text="NS reworded again" HEAD~1
_ST_OUT_LACKS "unsigned history draws no signature notice" 'carried [0-9]* signature'
git reset -q --hard
