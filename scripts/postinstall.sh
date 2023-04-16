#!/bin/bash
if [ ! -d './mma' ]; then
  git clone -b infojunkie git@github.com:infojunkie/mma.git;
  pwd=$(pwd); sed -r "s#/full/path/to/musicxml-mma#$pwd#" mmarc.example > mmarc
  ./mma/mma.py -G
fi
