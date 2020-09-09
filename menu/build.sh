#!/bin/bash

mkdir -p asm/tmp

cd java
javac ProcessIndex.java
java ProcessIndex -s > ../asm/tmp/suffixes.asm
java ProcessIndex -d > ../asm/tmp/directories.asm
java ProcessIndex -t > ../asm/tmp/titles.asm
cd ..

cd asm
beebasm -v -i menu.asm > menu.log
beebasm -v -i tmp/titles.asm > titles.log

cp MENU /var/www/html
cp TITLES /var/www/html
cd ..
