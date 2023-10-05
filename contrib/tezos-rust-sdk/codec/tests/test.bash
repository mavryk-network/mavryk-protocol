#!/bin/bash

tmp1=$(mktemp)
tmp2=$(mktemp)
bad=0

while read l ; do
    ./target/debug/codec $l | tee $tmp1
    ../../octez-codec $l | tee $tmp2
    (diff $tmp1 $tmp2 && echo "OK") || (echo "KO" ; $((bad++)))
done <<EOF
encode alpha.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode alpha.contract from "tz3RDC3Jdn4j15J7bBHZd29EUee9gVB1CxD9"
encode alpha.contract from "KT1TxqZ8QtKvLu3V3JH7Gx58n7Co8pgtpQU5"
encode alpha.contract from "tz1irJKkXS2DBWkU1NnmFQx1c1L7pbGg4yhk"
encode alpha.contract from "tz1cig1EHyvZd7J2k389moM9PxVgPQvmFkvi"
encode alpha.contract from "tz2FCNBrERXtaTtNX6iimR1UJ5JSDxvdHM93"
encode alpha.contract from "tz1gfArv665EUkSg2ojMBzcbfwuPxAvqPvjo"
encode alpha.contract from "tz3dKooaL9Av4UY15AUx9uRGL5H6YyqoGSPV"
encode alpha.contract from "tz1NEKxGEHsFufk87CVZcrqWu8o22qh46GK6"
encode alpha.contract from "tz1dRKU4FQ9QRRQPdaH4zCR6gmCmXfcvcgtB"
encode alpha.contract from "tz1VQnqCCqX4K5sP3FNkVSNKTdCAMJDd3E1n"
decode 005-PsBabyM1.contract from 00000000000000000000000000000000000000000000
decode 005-PsBabyM1.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 006-PsCARTHA.contract from 00000000000000000000000000000000000000000000
decode 006-PsCARTHA.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 007-PsDELPH1.contract from 00000000000000000000000000000000000000000000
decode 007-PsDELPH1.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 008-PtEdo2Zk.contract from 00000000000000000000000000000000000000000000
decode 008-PtEdo2Zk.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 009-PsFLoren.contract from 00000000000000000000000000000000000000000000
decode 009-PsFLoren.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 010-PtGRANAD.contract from 00000000000000000000000000000000000000000000
decode 010-PtGRANAD.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 011-PtHangz2.contract from 00000000000000000000000000000000000000000000
decode 011-PtHangz2.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 012-Psithaca.contract from 00000000000000000000000000000000000000000000
decode 012-Psithaca.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 013-PtJakart.contract from 00000000000000000000000000000000000000000000
decode 013-PtJakart.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 014-PtKathma.contract from 00000000000000000000000000000000000000000000
decode 014-PtKathma.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 015-PtLimaPt.contract from 00000000000000000000000000000000000000000000
decode 015-PtLimaPt.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 016-PtMumbai.contract from 00000000000000000000000000000000000000000000
decode 016-PtMumbai.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 016-PtMumbai.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode 017-PtNairob.contract from 00000000000000000000000000000000000000000000
decode 017-PtNairob.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode alpha.contract from 00000000000000000000000000000000000000000000
decode alpha.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
encode 005-PsBabyM1.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 005-PsBabyM1.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 006-PsCARTHA.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 006-PsCARTHA.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 007-PsDELPH1.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 007-PsDELPH1.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 008-PtEdo2Zk.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 008-PtEdo2Zk.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 009-PsFLoren.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 009-PsFLoren.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 010-PtGRANAD.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 010-PtGRANAD.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 011-PtHangz2.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 011-PtHangz2.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 012-Psithaca.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 012-Psithaca.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 013-PtJakart.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 013-PtJakart.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 014-PtKathma.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 014-PtKathma.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 015-PtLimaPt.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 015-PtLimaPt.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 016-PtMumbai.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 016-PtMumbai.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode 017-PtNairob.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
encode 017-PtNairob.contract from "tz1PJ5xxUFDAwgKHLMUPe5SL3eJkVehfiDL6"
encode alpha.contract from "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"
decode alpha.contract from 0000281aea86d1cf8b0c74f1be3eeb67c516cdcc2abf
decode alpha.contract from 0002358cbffa97149631cfb999fa47f0035fb1ea8636
decode alpha.contract from 01d496def47a3be89f5d54c6e6bb13cc6645d6e16600
decode alpha.contract from 0000fe9ceee394b26880e978fd409967f8c0d84c923a
decode alpha.contract from 0000bb5af2e9614920eb50e30712009216aca1c3a577
decode alpha.contract from 00014b7c404fd4fbcf931cde0a8971caf76f53c8e5c0
decode alpha.contract from 0000e691e06161be1502199bd068259d81901c8039f5
decode alpha.contract from 0002ba6e9bd91e252732e2db32d2ccfcf27cae151502
decode alpha.contract from 00001c6ccd98ed64ff64dc01650a34f936157063395c
decode alpha.contract from 0000c30adc07a256bf2ebcaaf869fe200f4f7c0297cd
decode alpha.contract from 00006b3047aa0e3adc3b972aca3ae6a3d0c7c232cd5d
EOF

if (( bad > 0 )) ; then
    echo "FAIL: some differences were detected."
    exit 1
else
    echo "No differences were detected."
    exit 0
fi
