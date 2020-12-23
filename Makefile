.PHONY: test install
install:
	npm i -g xslt3
test:
	./test/libs/bats/bin/bats test/*.bats
convert:
	xslt3 -xsl:musicxml-mma.xsl -s:${FILE}