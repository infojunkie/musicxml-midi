#!/bin/bash
if [ ! -d './mma' ]; then
  git clone -b infojunkie git@github.com:infojunkie/mma.git
  mkdir -p cache
  npm run build:mmarc
  npm run build:grooves
fi
