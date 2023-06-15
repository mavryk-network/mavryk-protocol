#!/bin/bash

input="$(cat "${1}")"
instances_per_node="${2}"
rollups_per_instance="${3}"
rollups_per_node=$(( ${instances_per_node} * ${rollups_per_instance} ))
files_servers="${4:-1}"
identity="${5:-~/.ssh/demo}"
port="${6:-30000}"

i=0
j=0
length="$(echo "${input}" | jq 'length')"
k=0

while [ ${k} -lt ${files_servers} ]; do
cat <<EOF
  - name: files-$k
    address: $(echo "${input}" | jq ".[${k}]")
    user: root
    port: ${port}
    identity: ${identity}
EOF
k=$(( $k + 1 ))
done

while [ $(( ${k} + 1 + ${instances_per_node} )) -le ${length} ]; do
  cat <<EOF
  - name: node-${i}
    address: $(echo "${input}" | jq ".[${k}]")
    user: root
    port: ${port}
    identity: ${identity}
EOF
    k=$(( $k + 1 ))

  for l in $(seq 0 $(( $instances_per_node - 1 ))); do
    cat <<EOF
  - name: sr-nodes-${i}-${j}
    address: $(echo "${input}" | jq ".[${k}]")
    user: root
    port: ${port}
    identity: ${identity}
EOF
    j=$(( ${j} + ${rollups_per_instance} ))
    k=$(( $k + 1 ))
  done

  i=${j}
done

