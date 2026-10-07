# The plumbing modes cannot sign, so the notice fires for them – but a rebase re-signs
# under `commit.gpgsign` and a mode that drops a commit takes its signature along, so a
# shortfall alone would cry wolf, and only a real key proves the quiet half
_ST_SCENARIO "\e[1;96m[66] a re-signing rebase draws no signature notice\e[0m"
git reset -q --hard
local GPG_HOME=$TMP/gnupg
local GPG_OK=false
if command -v gpg >/dev/null 2>&1; then
	mkdir -p "$GPG_HOME" && chmod 700 "$GPG_HOME"
	print -r -- 'pinentry-mode loopback' > "$GPG_HOME/gpg.conf"
	print -r -- 'allow-loopback-pinentry' > "$GPG_HOME/gpg-agent.conf"
	# A long `$TMPDIR` can push the agent socket past the ~104-char sun_path
	# limit, so a failure here is "no usable gpg" rather than a test failure
	GNUPGHOME=$GPG_HOME gpg --batch --yes --passphrase '' --quick-generate-key \
		"git-edit selftest <selftest@example.invalid>" default default never \
		>/dev/null 2>&1 && GPG_OK=true
fi
if [ "$GPG_OK" != "true" ]; then
	ECHO_E "\e[0;90m  skipped – no usable gpg on this machine\e[0m"
else
	local GPG_KEY=$(GNUPGHOME=$GPG_HOME gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
	local SR=$TMP/signed
	git init -q -b main "$SR"
	git -C "$SR" config user.email selftest@example.invalid
	git -C "$SR" config user.name "git-edit selftest"
	git -C "$SR" config user.signingkey "$GPG_KEY"
	git -C "$SR" config commit.gpgsign true
	git -C "$SR" config gpg.program gpg
	export GNUPGHOME=$GPG_HOME
	cd "$SR"
	local SN
	for SN in 1 2 3; do
		print -r -- "s$SN" > "s$SN.txt"
		git add "s$SN.txt" && git commit -qm "SG $SN"
	done
	_ST_CHECK "the fixture really produced signed commits" \
		sh -c "[ \"\$(git -C '$SR' log -1 --format='%G?')\" != 'N' ]"
	# A reorder replays through rebase, which re-signs under the config above
	_ST_RUN --reorder HEAD~1 HEAD
	_ST_EQ "the reorder applies" "$RC" "0"
	_ST_CHECK "its tip is still signed" \
		sh -c "[ \"\$(git -C '$SR' log -1 --format='%G?')\" != 'N' ]"
	_ST_OUT_LACKS "and no signature notice is printed" 'carried [0-9]* signature'
	# The plumbing counterpart, against a real signature rather than a forged
	# header: `commit-tree` takes no key, so this one must speak up
	_ST_RUN -M --text="SG 1 reworded" HEAD~2
	_ST_EQ "the reword applies" "$RC" "0"
	_ST_OUT_HAS "while a plumbing rewrite names the lost signatures" 'carried [0-9]* signature'
	_ST_CHECK "and its tip really did lose the signature" \
		sh -c "[ \"\$(git -C '$SR' log -1 --format='%G?')\" = 'N' ]"
	gpgconf --homedir "$GPG_HOME" --kill all >/dev/null 2>&1
	unset GNUPGHOME
	cd "$TMP/repo"
fi
