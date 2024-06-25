// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

// This script runs the benchmarks for the EVM kernel and writes the result to benchmark_result.csv

// Before running this script, run the following commands to build the debugger and the benchmark kernel
// $ make
// $ make -C etherlink/kernel_evm/

// Then run this script using the following command
// $ node etherlink/kernel_evm/kernel_benchmark/scripts/run_benchmarks.js

// Each row of the output file represents the processing of one message in the kernel
// Each value represents a cost. "gas_cost" is the cost in gas in the EVM, and the other values are costs in ticks in the PVM

var fs = require('fs');
var readline = require('readline');
const { spawn } = require('child_process');
const { execSync } = require('child_process');
const external = require("./lib/external")
const path = require('node:path')
const { timestamp } = require("./lib/timestamp")
const csv = require('csv-stringify/sync');
const commander = require('commander');
const { mkdirSync } = require('node:fs');
const { exit } = require('process');

function parse_mode(mode, _) {
    if (mode != "sequencer" && mode != "proxy") {
        console.error("Mode can be either `proxy` or `sequencer`");
        exit(2)
    } else {
        return mode
    }
}

commander
    .usage('[OPTIONS]')
    .option('-i, --include <regex>', 'Only consider benchmark scripts matching <regex>')
    .option('-e, --exclude <regex>', 'Exclude benchmark scripts matching <regex>')
    .option('-o, --output-dir <path>', "Output directory")
    .option('--fast-mode', "Launch kernel in fast mode, but less information is collected", false)
    .option('--keep-temp', "Keep temporary files", false)
    .option('--mode <mode>', 'Kernel mode: `proxy` or `sequencer`', parse_mode)
    .option('--no-computation', 'Don\'t expect stage 2', true)
    .parse(process.argv);

let INCLUDE_REGEX = commander.opts().include
let EXCLUDE_REGEX = commander.opts().exclude
function filter_name(name) {
    return (INCLUDE_REGEX === undefined
        || name.match(INCLUDE_REGEX))
        && (EXCLUDE_REGEX === undefined
            || !name.match(EXCLUDE_REGEX))
}
let COMPUTATION = commander.opts().computation;
let MODE = commander.opts().mode || "proxy";
let KEEP_TEMP = commander.opts().keepTemp;
let FAST_MODE = commander.opts().fastMode;
const RUN_DEBUGGER_COMMAND = external.bin('./mavkit-smart-rollup-wasm-debugger');
const EVM_INSTALLER_KERNEL_PATH = external.resource('evm_benchmark_kernel.wasm');
const EVM_BENCHMARK_CONFIG_PATH = external.resource('etherlink/config/benchmarking.yaml');
const EVM_BENCHMARK_SEQUENCER_CONFIG_PATH = external.resource('etherlink/config/benchmarking_sequencer.yaml');
const OUTPUT_DIRECTORY = commander.opts().outputDir ? commander.opts().outputDir : external.output()
mkdirSync(OUTPUT_DIRECTORY, { recursive: true })
console.log(`Output directory ${OUTPUT_DIRECTORY}`)

// This key corresponds to bootstrap1 in `src/tezt/lib_tezos/account.ml`
const SEQUENCER_KEY = "unencrypted:edsk3gUfUPyBSfrS9CCgmCiQsTCHGkviBDusMxDJstFtojtc1zcpsh";

function sumArray(arr) {
    return arr?.reduce((acc, curr) => acc + curr, 0) ?? 0;
}

function push_match(output, array, regexp) {
    var match;
    while ((match = regexp.exec(output))) {
        array.push(match[1]);
    }
}

/// Parses the data from the `Section` output. See
/// `evm_execution/src/handler.rs` for the format.
function parse_data(opcode, gas_and_result) {
    if (gas_and_result.length != 18) { return undefined };

    let gas_data = gas_and_result.substring(0, 16);
    let step_result = parseInt('0x' + gas_and_result.substring(16));
    // parse little endian integers
    let gas = parseInt('0x' + gas_data.match(/../g).reverse().join(''));
    return { opcode, gas, step_result }
}

/// Parses the section and push the sample into the set of opcodes.
function push_profiler_sections(output, opcodes, precompiles) {
    const section_regex = /\__wasm_debugger__::Section{ticks:(\d+);data:\((0x[0-9a-fA-F]*),0x([0-9a-fA-F]*)\)}/g;
    let precompiled_address_set = new Set([
        "0x0000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000002",
        "0x0000000000000000000000000000000000000003",
        "0x0000000000000000000000000000000000000004",
        "0x0000000000000000000000000000000000000005",
        "0x0000000000000000000000000000000000000006",
        "0x0000000000000000000000000000000000000007",
        "0x0000000000000000000000000000000000000008",
        "0x0000000000000000000000000000000000000009",
        "0xff00000000000000000000000000000000000001"
    ]);

    for (const match of output.matchAll(section_regex)) {
        let is_opcode_data = match[2].length == 4;
        if (is_opcode_data) {
            let { opcode, gas, step_result } = parse_data(match[2], match[3]);
            let ticks = parseInt(match[1]);
            let result = { ticks, gas, step_result };
            if (opcodes[opcode] == undefined) {
                opcodes[opcode] = [result]
            } else {
                opcodes[opcode].push(result)
            }
        } else {
            let ticks = parseInt(match[1]);
            let address = match[2].substring(0, 42);
            let data_size = parseInt("0x" + match[2].substring(42));
            if (precompiled_address_set.has(address)) {
                precompiles.push({ "address": address, "data_size": data_size, "ticks": ticks })
            }
        }
    }
    return opcodes;
}

/// Raise an error if cmp(expected,actual), with a given message.
/// In the message, potential $? are replaced by a breakdown of expected and actual:w
function check(expected, actual, msg, cmp = (x, y) => x == y) {
    if (!cmp(expected, actual)) {
        console.log(new Error(msg.replace("$?", `(expected: ${expected}, actual: ${actual})`)))
    }
}

function run_profiler(path, logs) {

    profiler_result = new Promise((resolve, _) => {

        let results = {
            profiler_output_path: "",
            gas_costs: [],
            tx_status: [],
            estimated_ticks: [],
            estimated_ticks_per_tx: [],
            tx_size: [],
            block_in_progress_store: [],
            block_in_progress_read: [],
            receipt_size: [],
            opcodes: {},
            bloom_size: [],
            precompiles: [],
            blueprint_chunks: [],
            tx_type: [],
            reason: []
        }
        let nb_reboots = 0;


        let config =
            MODE == "proxy" ?
                EVM_BENCHMARK_CONFIG_PATH :
                EVM_BENCHMARK_SEQUENCER_CONFIG_PATH;

        const args = ["--kernel", EVM_INSTALLER_KERNEL_PATH, "--inputs", path, "--flamecharts-dir", PROFILER_OUTPUT_DIRECTORY, "--installer-config", config];

        const childProcess = spawn(RUN_DEBUGGER_COMMAND, args, {});


        if (FAST_MODE)
            childProcess.stdin.write("step inbox\n");
        else
            childProcess.stdin.write("profile\n");

        childProcess.stdin.end();

        childProcess.stderr.on('data', (data) => {
            const output = data.toString();
            console.error(`stderr: ${output}`);
            fs.appendFileSync(logs, output);
        });

        childProcess.stdout.on('data', (data) => {
            const output = data.toString();
            if (!output.includes("__wasm_debugger__")) fs.appendFileSync(logs, output)
            const profiler_output_path_regex = /Profiling result can be found in (.+)/;
            const profiler_output_path_match = output.match(profiler_output_path_regex);
            const profiler_output_path_result = profiler_output_path_match
                ? profiler_output_path_match[1]
                : null;
            if (profiler_output_path_result !== null) {
                results.profiler_output_path = profiler_output_path_result;
                if (KEEP_TEMP) console.log(`Flamechart: ${profiler_output_path_result}`)
            }
            push_match(output, results.gas_costs, /\[Benchmarking\] gas_used:\s*(\d+)/g)
            push_match(output, results.tx_status, /\[Benchmarking\] Transaction status: (OK_[a-zA-Z09]+|ERROR_[A-Z_]+)\b/g)
            push_match(output, results.estimated_ticks, /\[Benchmarking\] Estimated ticks:\s*(\d+)/g)
            push_match(output, results.estimated_ticks_per_tx, /\[Benchmarking\] Estimated ticks after tx:\s*(\d+)/g)
            push_match(output, results.tx_size, /\[Benchmarking\] Storing transaction object of size\s*(\d+)/g)
            push_match(output, results.block_in_progress_store, /\[Benchmarking\] Storing Block In Progress of size\s*(\d+)/g)
            push_match(output, results.block_in_progress_read, /\[Benchmarking\] Reading Block In Progress of size\s*(\d+)/g)
            push_match(output, results.receipt_size, /\[Benchmarking\] Storing receipt of size \s*(\d+)/g)
            push_match(output, results.bloom_size, /\[Benchmarking\] bloom size:\s*(\d+)/g)
            push_match(output, results.blueprint_chunks, /\[Benchmarking\] number of blueprint chunks read:\s*(\d+)/g)
            push_match(output, results.tx_type, /\[Benchmarking\] Transaction type: ([A-Z]+)\b/g)
            push_match(output, results.reason, /\[Benchmarking\] reason: ([A-Za-z()_]+)\b/g)
            push_profiler_sections(output, results.opcodes, results.precompiles);
            if (output.includes("Kernel was rebooted.")) nb_reboots++;
        });
        childProcess.on('close', _ => {
            if (!FAST_MODE && results.profiler_output_path == "") {
                console.log(new Error("Profiler output path not found"));
            }
            if (COMPUTATION) {
                check([], results.gas_used, "Gas usage data not found", (x, y) => x != y);
                check(0, results.tx_status.length, "Status data not found", (x, y) => x != y);
                check(results.tx_status.length, results.estimated_ticks_per_tx.length, "Missing estimated ticks per tx info $?");
                check(results.tx_status.length, results.tx_size.length, "Missing transaction size data $?");
                check(results.tx_status.length, results.receipt_size.length, "Missing receipt size value $?");
                check(results.tx_status.length, results.bloom_size.length, "Missing bloom size value $?")
                check(results.block_in_progress_store.length, nb_reboots, "Missing stored block size value $?")
                check(results.block_in_progress_read.length, nb_reboots, "Missing read bip size value $?")
                check(results.tx_status.length, results.tx_type.length, "Missing transaction type $?")
                check(results.tx_status.length, results.reason.length, "Missing transaction exit reason $?")
            }
            resolve(results);
        });
    })
    return profiler_result;
}

// Helper function to count the number of ticks of given function call
async function get_ticks(path, function_call_keyword) {
    const fileStream = fs.createReadStream(path);
    var ticks_count_for_transactions = [];
    var previous_row_is_given_function_call = false;

    const rl = readline.createInterface({
        input: fileStream,
        crlfDelay: Infinity
    });

    for await (const l of rl) {
        if (l !== "") {
            tokens = l.split(" ");
            calls = tokens[0];
            ticks = tokens[1];
            if (calls.includes(function_call_keyword)) {
                if (previous_row_is_given_function_call) {
                    ticks_count_for_transactions[ticks_count_for_transactions.length - 1] += parseInt(ticks);
                } else {
                    ticks_count_for_transactions.push(parseInt(ticks));
                    previous_row_is_given_function_call = true
                }
            } else {
                previous_row_is_given_function_call = false;
            }
        }
    }

    return ticks_count_for_transactions;
}

// Parse the profiler output file and get the tick counts of the differerent function calls
async function analyze_profiler_output(path) {
    let results = Object();
    results.kernel_run_ticks = await get_ticks(path, "kernel_run");
    results.run_transaction_ticks = await get_ticks(path, "run_transaction");
    results.signature_verification_ticks = await get_ticks(path, "25EthereumTransactionCommon6caller");
    results.sputnik_runtime_ticks = await get_ticks(path, "EvmHandler$LT$Host$GT$7execute");
    results.store_transaction_object_ticks = await get_ticks(path, "storage24store_transaction_object");
    results.store_receipt_ticks = await get_ticks(path, "store_transaction_receipt");
    results.interpreter_init_ticks = await get_ticks(path, "interpreter(init)");
    results.interpreter_decode_ticks = await get_ticks(path, "interpreter(decode)");
    results.stage_one_ticks = await get_ticks(path, "stage_one");
    results.block_finalize = await get_ticks(path, "store_current_block");
    results.logs_to_bloom = await get_ticks(path, "logs_to_bloom");
    results.block_in_progress_store_ticks = await get_ticks(path, "store_block_in_progress");
    results.block_in_progress_read_ticks = await get_ticks(path, "read_block_in_progress");
    return results;
}

// Run given benchmark
async function run_benchmark(path, logs) {
    var inbox_size = fs.statSync(path).size
    run_profiler_result = await run_profiler(path, logs);
    profiler_output_analysis_result = FAST_MODE ? {} : await analyze_profiler_output(run_profiler_result.profiler_output_path);
    if (!KEEP_TEMP && !FAST_MODE) {
        fs.unlink(run_profiler_result.profiler_output_path, (err) => {
            if (err) {
                console.error(err);
            } else {
                console.log(`Profiler output ${run_profiler_result.profiler_output_path} removed.`);
            }
        });
    }
    return {
        inbox_size,
        ...profiler_output_analysis_result,
        ...run_profiler_result
    }
}

function build_benchmark_scenario(benchmark_script) {
    try {
        let bench_path = path.format({ dir: __dirname, base: benchmark_script })
        let extra = MODE == 'sequencer' ? `--sequencer ${SEQUENCER_KEY}` : "";
        execSync(`node ${bench_path} ${extra} > transactions.json`);
    } catch (error) {
        console.log(`Error running script ${benchmark_script}. Please fixed the error in the script before running this benchmark script`)
        console.error(error);
    }
}

function log_benchmark_result(benchmark_name, data) {
    rows = [];

    console.log(`Number of transactions: ${data.tx_status.length}`)
    gas_cost_index = 0;
    for (var j = 0; j < data.tx_status.length; j++) {
        let status = data.tx_status[j];
        let row = {
            benchmark_name,
            signature_verification_ticks: data.signature_verification_ticks?.[j],
            status,
            estimated_ticks: data.estimated_ticks_per_tx[j],
            tx_type: data.tx_type[j],
        }
        if (status.includes("OK_UNKNOWN")) {
            // no outcome should mean never invoking sputnik
            Object.assign(row,
                {
                    gas_cost: 21000,
                    run_transaction_ticks: data.run_transaction_ticks?.[j],
                    sputnik_runtime_ticks: 0,
                    store_transaction_object_ticks: data.store_transaction_object_ticks?.[j],

                });

        }
        else if (status.includes("OK")) {

            Object.assign(row,
                {
                    gas_cost: data.gas_costs[gas_cost_index],
                    reason: data.reason?.[j],
                    run_transaction_ticks: data.run_transaction_ticks?.[j],
                    sputnik_runtime_ticks: data.sputnik_runtime_ticks?.[j],
                    store_transaction_object_ticks: data.store_transaction_object_ticks?.[j],
                    store_receipt_ticks: data.store_receipt_ticks?.[j],
                    receipt_size: data.receipt_size[j],
                    tx_size: data.tx_size[j],
                    logs_to_bloom: data.logs_to_bloom?.[j],
                    bloom_size: data.bloom_size[j],
                });
            gas_cost_index += 1;
        } else {
            // we can expect no gas cost, no storage of the tx object, and no run transaction, but there will be signature verification
            // invalide transaction detected: ERROR_NONCE, ERROR_PRE_PAY and ERROR_SIGNATURE, in all cases `caller` is called.
        }
        rows.push(row)
    }

    // first kernel run
    // the nb of tx correspond to the full inbox, not just those done in first run
    // FIXME: bip_idx unreliable in FAST_MODE
    let bip_idx = 0
    rows.push({
        benchmark_name: benchmark_name + "(all)",
        interpreter_init_ticks: data.interpreter_init_ticks?.[0],
        interpreter_decode_ticks: data.interpreter_decode_ticks?.[0],
        stage_one_ticks: data.stage_one_ticks?.[0],
        blueprint_chunks: data.blueprint_chunks?.[0],
        kernel_run_ticks: data.kernel_run_ticks?.[0],
        estimated_ticks: data.estimated_ticks?.[0],
        inbox_size: data.inbox_size,
        nb_tx: data.tx_status.length,
        block_in_progress_store: data.block_in_progress_store[0] ? data.block_in_progress_store[0] : '',
        block_in_progress_store_ticks: data.block_in_progress_store[0] ? data.block_in_progress_store_ticks?.[bip_idx++] : ''
    });

    //reboots
    for (var j = 1; j < data.kernel_run_ticks?.length; j++) {
        rows.push({
            benchmark_name: benchmark_name + "(all)",
            interpreter_init_ticks: data.interpreter_init_ticks?.[j],
            interpreter_decode_ticks: data.interpreter_decode_ticks?.[j],
            stage_one_ticks: data.stage_one_ticks?.[j],
            blueprint_chunks: data.blueprint_chunks?.[j],
            kernel_run_ticks: data.kernel_run_ticks?.[j],
            estimated_ticks: data.estimated_ticks?.[j],
            block_in_progress_store: data.block_in_progress_store[j] ? data.block_in_progress_store[j] : '',
            block_in_progress_store_ticks: data.block_in_progress_store[j] ? data.block_in_progress_store_ticks?.[bip_idx] : '',
            block_in_progress_read: data.block_in_progress_read[j - 1], // the first read correspond to second run
            block_in_progress_read_ticks: data.block_in_progress_read[j - 1] ? data.block_in_progress_read_ticks?.[bip_idx - 1] : ''
        });
        if (data.block_in_progress_read[j - 1]) bip_idx++
    }

    // ticks that are not covered by identified area of interest
    finalize_ticks = sumArray(data.block_finalize)
    unaccounted_ticks =
        sumArray(data.kernel_run_ticks)
        - sumArray(data.stage_one)
        - sumArray(data.run_transaction_ticks)
        - sumArray(data.signature_verification_ticks)
        - sumArray(data.store_transaction_object_ticks)
        - sumArray(data.store_receipt_ticks)
        - finalize_ticks

    // row concerning all runs
    rows.push({
        benchmark_name: benchmark_name + "(all)",
        unaccounted_ticks,
        block_finalize: finalize_ticks
    });
    return rows;
}

function logs_filename(time) {
    return path.format({ dir: OUTPUT_DIRECTORY, base: `logs_${time}.log` })
}

function output_filename(time) {
    return path.format({ dir: OUTPUT_DIRECTORY, base: `benchmark_result_${time}.csv` })
}

function opcodes_dump_filename(time) {
    return path.format({ dir: OUTPUT_DIRECTORY, base: `dump_opcodes_${time}.json` })
}

function precompiles_filename(time) {
    return path.format({ dir: OUTPUT_DIRECTORY, base: `precompiles_${time}.csv` })
}

function dump_bench_opcode(filename, benchmark_name, opcodes, is_first) {
    if (!is_first)
        fs.appendFileSync(filename, ",")
    fs.appendFileSync(filename, `"${benchmark_name}":${JSON.stringify(opcodes)}`);
}

const PROFILER_OUTPUT_DIRECTORY = OUTPUT_DIRECTORY + "/profiling"
mkdirSync(PROFILER_OUTPUT_DIRECTORY, { recursive: true })

// Determine the header list by looking at object properties
function get_headers(array, seed) {
    let acc = seed;
    array.forEach((value) => acc.push(...Object.getOwnPropertyNames(value)))
    return acc.filter((v, i) => acc.indexOf(v) === i);
}

function initialize_headers(output, benchmark_log) {
    let headers = get_headers(benchmark_log, ["benchmark_name", "status", "tx_type", "reason"]);
    let benchmark_csv_config = { columns: headers }
    fs.writeFileSync(output, csv.stringify([], { header: true, ...benchmark_csv_config }));
    return benchmark_csv_config;
}

// Run the benchmark suite and write the result to benchmark_result_${TIMESTAMP}.csv
async function run_all_benchmarks(benchmark_scripts) {
    console.log(`Running benchmarks on: \n[ ${benchmark_scripts.join(',\n  ')}]`);
    var precompiles_field = [
        "address",
        "data_size",
        "ticks",
    ]
    let time = timestamp();
    let output = output_filename(time);
    let opcodes_dump = opcodes_dump_filename(time);
    let precompiles_output = precompiles_filename(time);
    let logs = logs_filename(time)
    console.log(`Output in ${output}`);
    console.log(`Dumped opcodes in ${opcodes_dump}`);
    console.log(`Precompiles in ${precompiles_output}`);
    const precompile_csv_config = { columns: precompiles_field };
    fs.writeFileSync(precompiles_output, csv.stringify([], { header: true, ...precompile_csv_config }));
    fs.writeFileSync(logs, "Logging debugger\n")
    fs.writeFileSync(opcodes_dump, "{");
    console.log(`Full logs in ${logs}`)
    let benchmark_csv_config = Object();
    for (var i = 0; i < benchmark_scripts.length; i++) {
        var benchmark_script = benchmark_scripts[i];
        var parts = benchmark_script.split("/");
        var benchmark_name = parts[parts.length - 1].split(".")[0];
        console.log(`Benchmarking ${benchmark_script} (mode: ${MODE})`);
        fs.appendFileSync(logs, `=================================================\nBenchmarking ${benchmark_script}\n`)
        build_benchmark_scenario(benchmark_script);
        run_benchmark_result = await run_benchmark("transactions.json", logs);
        benchmark_log = log_benchmark_result(benchmark_name, run_benchmark_result);
        if (i == 0) benchmark_csv_config = initialize_headers(output, benchmark_log);
        fs.appendFileSync(output, csv.stringify(benchmark_log, benchmark_csv_config))
        fs.appendFileSync(precompiles_output, csv.stringify(run_benchmark_result.precompiles, precompile_csv_config))
        dump_bench_opcode(opcodes_dump, benchmark_name, run_benchmark_result.opcodes, i == 0);
    }
    fs.appendFileSync(opcodes_dump, "}");
    console.log("Benchmarking complete");
    fs.appendFileSync(logs, "=================================================\nBenchmarking complete.\n")
    execSync("rm transactions.json");
}

// we exclude bench_loop_calldataload because with the current tick model it
// puts the kernel in a stuck mode
const excluded_benchmark = ["benchmarks/bench_loop_calldataload.js"]
benchmark_scripts = require("./benchmarks_list.json").filter((name) => !excluded_benchmark.includes(name))

run_all_benchmarks(benchmark_scripts.filter(filter_name));
