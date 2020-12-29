MMA_HOME := $(or ${MMA_HOME},'../mma')

.PHONY: test install
install:
	npm i -g xslt3
	${MMA_HOME}/mma.py -G
test:
	./test/libs/bats/bin/bats test/*.bats
convert:
	xslt3 -xsl:musicxml-mma.xsl -s:${FILE}
