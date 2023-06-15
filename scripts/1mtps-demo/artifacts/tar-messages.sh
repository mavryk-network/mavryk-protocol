#!/bin/sh -x

dir=""

for i in $(seq 0 $1); do
  dir="$dir rollup-messages/rollup$i.messages"
done

tar czvf rollup-messages.tar.gz$dir
