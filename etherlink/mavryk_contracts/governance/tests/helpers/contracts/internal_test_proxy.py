from pymavryk.client import PyMavrykClient
from tests.helpers.contracts.contract import ContractHelper
from tests.helpers.utility import (
    get_build_dir,
    originate_from_file,
)
from pymavryk.operation.group import OperationGroup
from os.path import join


class InternalTestProxy(ContractHelper):
    @classmethod
    def originate(self, client: PyMavrykClient) -> OperationGroup:
        storage = None
        filename = join(get_build_dir(), 'test/internal_test_proxy.mv')

        return originate_from_file(filename, client, storage)
    
    def get_kernel_upgrade_payload(self, kernel_root_hash : bytes, activation_timestamp : int):
        return self.contract.get_kernel_upgrade_payload(kernel_root_hash, activation_timestamp).run_view()
    
    def get_sequencer_upgrade_payload(self, sequencer_pk : str, pool_address : bytes, activation_timestamp : int):
        return self.contract.get_sequencer_upgrade_payload(sequencer_pk, pool_address, activation_timestamp).run_view()
    
    def address_to_key_hash(self, address : str):
        return self.contract.address_to_key_hash(address).run_view()