#!/usr/bin/env bash

set -e

#cargo build --release

# rm -rf ../artifacts/rollup-keys
# rm -rf ../artifacts/rollup-messages
# rm -rf ../artifacts/rollup.no_pixel_addr

mkdir -p ../artifacts/rollup-keys
mkdir -p ../artifacts/rollup-messages
mkdir -p ../artifacts/rollup.no_pixel_addr

N=10

#../target/release/account_diff_tx_gen generate-account-keys --accounts-output-file "../artifacts/rollup-keys"

no_pixel_addr="$(cat ../artifacts/rollup-keys/rollup0.keys/keys-0 | jq ".no_pixel_account.tz1" -r)"

echo "no_pixel_addr=$no_pixel_addr"

for rollup_id in {0..999}
do
    (
    rm -rf ../artifacts/rollup-keys/rollup$rollup_id.keys
    mkdir -p ../artifacts/rollup-keys/rollup$rollup_id.keys
    cp ../artifacts/keys.json ../artifacts/rollup-keys/rollup$rollup_id.keys/keys-0

    rm -rf ../artifacts/rollup-messages/rollup$rollup_id.messages
    mkdir -p ../artifacts/rollup-messages/rollup$rollup_id.messages

    rm -rf ../artifacts/rollup.no_pixel_addr/rollup.$rollup_id.no_pixel_addr

     echo -n "$no_pixel_addr" > ../artifacts/rollup.no_pixel_addr/rollup.$rollup_id.no_pixel_addr

    COUNT="$(ls -d ../image-diff/level*.diff | wc -l | xargs)"
    for i in $(seq 1 $COUNT)
    do
        ORDER="random"
        if [ $i -eq 1 ]
        then
            ORDER="ordered"
        fi

        echo "ROLLUP: $rollup_id | LEVEL: $i | $ORDER"

        target/release/account_diff_tx_gen account-diffs-to-tx --accounts-file ../artifacts/rollup-keys/rollup$rollup_id.keys/keys-$(($i - 1)) --accounts-output-file ../artifacts/rollup-keys/rollup$rollup_id.keys/keys-$i \
            --account-diff-file ../image-diff/level$i.diff/rollup$rollup_id.diff --tx-output-file ../artifacts/rollup-messages/rollup$rollup_id.messages/$i-transfers.out $ORDER
    done
    ) &

    if [[ $(jobs -r -p | wc -l) -ge $N ]]; then
        wait -n
    fi
done

wait
