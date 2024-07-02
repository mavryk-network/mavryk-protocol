from tests.base import BaseTestCase
from tests.helpers.errors import NOT_IMPLICIT_ADDRESS

class PayloadDecorationTestCase(BaseTestCase):
    def test_address_to_key_hash(self) -> None:
        proxy = self.deploy_internal_test_proxy()

        assert proxy.address_to_key_hash('mv18Cw7psUrAAPBpXYd9CtCpHg9EgjHP9KTe') == 'mv18Cw7psUrAAPBpXYd9CtCpHg9EgjHP9KTe'
        assert proxy.address_to_key_hash('mv2Ms2ww2MDq88NtTDoAi5YXwNc5Rhkf1ZCW') == 'mv2Ms2ww2MDq88NtTDoAi5YXwNc5Rhkf1ZCW'
        assert proxy.address_to_key_hash('mv3SQDtnFQGs49sZuxcuLkFNioZovhHU5Z75') == 'mv3SQDtnFQGs49sZuxcuLkFNioZovhHU5Z75'
        assert proxy.address_to_key_hash('mv4b621g9B8y9iN2YKbPM7sNE37uu6w9McXG') == 'mv4b621g9B8y9iN2YKbPM7sNE37uu6w9McXG'

        with self.raisesMichelsonError(NOT_IMPLICIT_ADDRESS):
            proxy.address_to_key_hash('KT1ThEdxfUcWUwqsdergy3QnbCWGHSUHeHJq')

        with self.raisesMichelsonError(NOT_IMPLICIT_ADDRESS):
            proxy.address_to_key_hash('sr1EStimadnRRA3vnjpWV1RwNAsDbM3JaDt6')