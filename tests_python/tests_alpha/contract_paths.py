from os import path
from typing import List, Optional, Union
from tools import paths
from tools import utils
from tools.paths import MichelsonScriptLocator, LogicalName, LogicalNameStrTz
from client.client import Client

from . import protocol


MICHELSON_TEST_SCRIPTS = path.join(
    paths.TEZOS_HOME, 'tests_python', 'contracts_alpha'
)

michelson_script_locator = MichelsonScriptLocator(
    MICHELSON_TEST_SCRIPTS, protocol.NUMBER
)


def all_contracts(
    directories: Optional[List[str]] = None,
) -> List[LogicalNameStrTz]:
    """Return all Michelson scripts valid for this protocol. See
    [tools/paths.py::MichelsonScriptLocator] for details."""
    return michelson_script_locator.all_scripts(directories)


def all_legacy_contracts() -> List[LogicalNameStrTz]:
    """Return all Michelson scripts valid for this protocol, delimited
    to the [legacy] directory."""
    return all_contracts(['legacy'])


def find_script(name: LogicalName) -> str:
    """Return the path to a Michelson script denoted by a set of path
    [components] valid for this protocol, or fail if there is no such
    script. See [tools/paths.py::MichelsonScriptLocator] for details.
    """
    return michelson_script_locator.find_script(name)


def find_script_by_name(logical_name_str_tz: LogicalNameStrTz) -> str:
    """Like [find_script], but takes a [LogicalNameStrTz] instead."""
    return michelson_script_locator.find_script_by_name(logical_name_str_tz)


def init_with_transfer(
    client: Client,
    script_name_or_path: Union[LogicalName, str],
    initial_storage: str,
    amount: float,
    sender: str,
    contract_name: str = None,
):
    '''Like [utils.init_with_transfer] but can take a [LogicalName]
    instead of a path.'''
    if isinstance(script_name_or_path, list):
        if contract_name is None:
            contract_name = script_name_or_path[-1]
        contract_path = find_script(script_name_or_path)
    else:
        contract_path = script_name_or_path
    utils.init_with_transfer(
        client,
        contract_path,
        initial_storage,
        amount,
        sender,
        contract_name,
    )
