#!/bin/bash
if [ ! -d './mma' ]; then
  git clone -b infojunkie git@github.com:infojunkie/mma.git
fi
if [ ! -f './mmarc' ]; then
  cp mmarc.example mmarc
fi
if [ ! -L './plugins' ]; then
  ln -s ./src/plugins .
fi
./mma/mma.py -G
mkdir -p cache
