#!/bin/bash
if [ ! -d './mma' ]; then
  git clone -b infojunkie git@github.com:infojunkie/mma.git
  mkdir -p cache
  cp mmarc.example mmarc
  ./mma/mma.py -G
  echo $PWD
fi
