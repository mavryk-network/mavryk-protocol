from pymavryk.client import PyMavrykClient
from pymavryk.contract.interface import ContractInterface
from pymavryk.operation.group import OperationGroup
from os.path import dirname
from os.path import join
from pymavryk.michelson.parse import michelson_to_micheline
from pymavryk.michelson.types.base import MichelsonType
from typing import Any


DEFAULT_ADDRESS = 'mv2burnburnburnburnburnburnbur7hzNeg'
DEFAULT_VOTING_POWER = 4000000000000
DEFAULT_TOTAL_VOTING_POWER = 20000000000000

TEST_ADDRESSES_SET = [
    'mv1HeC2GcVY4hKbr1fSs6gvJw4BsoEXz6vHZ',
    'mv1Vqb16tSut8SPMZBnJ3DupkjYyZjk1XEfC',
    'mv1PTAmhSt7sBJoNs3CmKzmbsza6ZXDtUziE',
    'mv1NQHLibsEhbvHrYYFq5LQstknuQgKeLRjw',
    'mv1CMFefFzcDD7iR4DH4wBo5aapZPTeC9syY',
    'mv1DrRTigJPtEpoo6J8EC7pKfmnjUuVoH1e1',
    'mv1G8oZM2T1bPTjHor4r36ie55RKtgys1oUJ',
    'mv1Qt4gJ2k8MXgMbzmXWQT2yZi9qmLMTiCfJ',
    'mv1VF5WbEHEAs3kCnRvxcEiCQVnWtdrKzo4f',
    'mv1HiGYmpNb6h8Rq4w4L36XdTq6YC4vwWww9',
    'mv3CxH6hSUqgTZg5GcEgSRgVg8jDYJTCN6Do',
    'mv1VyFZQuvm7EgF1uh2u58NxsD3s7tFi9Qxu',
    'mv1EuH4Bx4xsvgk614bvWGh43BPpSJ1JgsJ2',
    'mv1H3fMPfsoZrjt3JP8EQFob2baPC7DnDqB7',
    'mv1BwiZEDDxHst8bePGyWCqxBU985FWkm97H',
    'mv1WezSVD8qYXzqF2GcD24KJATsLt5J3P2GZ',
    'mv1RkojPoAYHvK4W5CAbP5YnzYfZtgXhRb55',
    'mv19ska1Up7mWnNsqJTwHv7QG1C26xfFesdR',
    'mv3GMZQ3BaMuwCHM6VzZtCGPM5vB6nNjSEnX',
    'mv1JWfLywqWVMV5rHuFxS7yrfP4zgMr7Ukep',
    'mv1JRTyBgVJF8Hy1grSr3PDFC11fvxcU16Z4',
]
TEST_ADDRESSES_SET.sort()


def pkh(client: PyMavrykClient) -> str:
    """Returns public key hash of given client"""

    return str(client.key.public_key_hash())


def find_op_by_hash(client: PyMavrykClient, opg: OperationGroup) -> dict:
    """Finds operation group by operation hash"""

    op = client.shell.blocks[-10:].find_operation(opg.hash())
    return op  # type: ignore


def get_address_from_op(op: dict) -> str:
    """Returns originated contract address from given operation dict"""

    contents = op['contents']
    assert len(contents) == 1, 'multiple origination not supported'
    op_result: dict = contents[0]['metadata']['operation_result']
    contracts = op_result['originated_contracts']
    assert len(contracts) == 1, 'multiple origination not supported'
    originated_contract = contracts[0]
    assert isinstance(originated_contract, str)
    return originated_contract


def get_build_dir() -> str:
    """Returns path to the build directory"""

    return join(dirname(__file__), '..', '..', 'build')

def get_tests_dir() -> str:
    """Returns path to the test directory"""

    return join(dirname(__file__), '..')


def load_contract_from_address(
    client: PyMavrykClient, contract_address: str
) -> ContractInterface:
    """Loads contract from given address using given client"""

    contract = client.contract(contract_address)
    contract = contract.using(shell=client.shell, key=client.key)
    return contract


def to_micheline(type_expression: str) -> dict:
    """Converts Michelson type expression string to Micheline expression
    (reusing pymavryk.michelson.parse.michelson_to_micheline) with
    type checking
    """

    return michelson_to_micheline(type_expression)  # type: ignore


def to_michelson_type(object: Any, type_expression: str) -> MichelsonType:
    """Converts Python object to Michelson type using given type expression"""

    micheline_expression = to_micheline(type_expression)
    michelson_type = MichelsonType.match(micheline_expression)
    return michelson_type.from_python_object(object)


def pack(object: Any, type_expression: str) -> bytes:
    """Packs Python object to bytes using given type expression"""

    return to_michelson_type(object, type_expression).pack()


def pack_sequencer_payload(payload):
    return {
        'sequencer_pk': payload['sequencer_pk'],
        'pool_address': bytes.fromhex(payload['pool_address'])
    }

def originate_from_file(
    filename: str, client: PyMavrykClient, storage: Any
) -> OperationGroup:
    """Deploys contract from filename with given storage
    using given client and returns OperationGroup"""

    print(f'deploying contract from filename {filename}')
    raw_contract = ContractInterface.from_file(filename)
    contract = raw_contract.using(key=client.key, shell=client.shell)
    return contract.originate(initial_storage=storage)

def get_digits(value: float) -> int:
    result = 0
    while(value % 1 != 0):
        result += 1
        value *= 10
    return result

def normalize_params(values : list[float]) -> list[int]:
    max_digits = max(map(get_digits, values))
    return list(map(lambda v: int(v * 10**max_digits), values))

def validate_percent_value(value : float):
    if(not (0 <= value <= 100)):
        raise Exception(f'Incorrect percentage value \'{value}\'. Should be in range [0, 100]') 
