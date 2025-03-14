from pymavryk.client import PyMavrykClient
from tests.helpers.contracts.contract import ContractHelper
from tests.helpers.utility import (
    get_build_dir,
    originate_from_file,
)
from pymavryk.operation.group import OperationGroup
from os.path import join


class RollupMock(ContractHelper):
    @classmethod
    def originate(self, client: PyMavrykClient) -> OperationGroup:
        """Deploys Rollup Mock"""

        storage = bytes.fromhex('00')
        filename = join(get_build_dir(), 'test/rollup_mock.mv')

        return originate_from_file(filename, client, storage)
    