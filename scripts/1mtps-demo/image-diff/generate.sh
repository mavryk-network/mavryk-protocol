#!/bin/bash

rm -rf output
mkdir output

COUNT=$(($(ls ../imgs | wc -l | xargs) - 1))
for i in $(seq 1 $COUNT)
do 
    echo "LEVEL: $i"
    cargo run --release -- "../imgs/$(($i - 1)).ppm" "../imgs/$i.ppm" 

    mkdir "level$i.diff"
    mv output/* "level$i.diff"/
done
