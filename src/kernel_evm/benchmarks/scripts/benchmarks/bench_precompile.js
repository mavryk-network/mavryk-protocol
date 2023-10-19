const utils = require('./utils');
const { contracts_directory, compile_contract_file } = require("../lib/contract");
let faucet = require('./players/faucet.json');
let player1 = require('./players/player1.json');

let contract = compile_contract_file(contracts_directory, "precompile.sol")[0];
let create_data = contract.bytecode;
let identity = contract.interface.encodeFunctionData("identity_precompile", []);
let sha = contract.interface.encodeFunctionData("sha_precompile", []);
let ripemd160 = contract.interface.encodeFunctionData("ripemd160_precompile", []);
let withdraw = contract.interface.encodeFunctionData("withdraw_precompile", []);

let txs = [];

txs.push(utils.transfer(faucet, player1, 100000000))

let create = utils.create(player1, 0, create_data)
txs.push(create.tx)

txs.push(utils.send(player1, create.addr, 0, identity))
txs.push(utils.send(player1, create.addr, 0, sha))
txs.push(utils.send(player1, create.addr, 0, ripemd160))
txs.push(utils.send(player1, create.addr, 0, withdraw))

utils.print_bench([txs])
