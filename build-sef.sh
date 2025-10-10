#!/bin/bash
mod=1
for xsl in src/xsl/*.xsl;
do
  src=$(basename "$xsl")
  sef=${src/.xsl/.sef.json}
  xslt3 -relocate:on -xsl:$xsl -export:"build/$sef" -nogo:1 -t -ns:##html5
  diff=$(git show HEAD:"build/$sef" | jd "build/$sef" | wc -l)
  if [ $diff -lt 7 ]; then
    git checkout "build/$sef"
  else
    mod=0
  fi
done
exit "$mod"
