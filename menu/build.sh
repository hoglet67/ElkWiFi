#!/bin/bash

cd java
javac ProcessIndex.java
java ProcessIndex > ../asm/data.asm
cd ..

cd asm
beebasm -v -i menu.asm > menu.log
cp MENU /var/www/html
cd ..
