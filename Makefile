.PHONY: changelog release

changelog:
	git-chglog -o CHANGELOG.md --next-tag `semtag final -s minor -f -o`

release:
	semtag final -s minor -f
