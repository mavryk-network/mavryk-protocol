import pytest
import b58_prefix

@pytest.mark.parametrize("prefix,length,expected_result", [
    ("edpk", 32, (54, [13, 15, 37, 191])),
    ("mv2", 20, (36, [5, 186, 199])),
    ("mv1", 20, (36, [5, 186, 196])),
])
def test_compute_version_bytes(prefix, length, expected_result):
    assert b58_prefix.compute_version_bytes(prefix, length) == expected_result

@pytest.mark.parametrize("word,expected_output", [
    ("1", 0),
    ("mv1", 151090),
])
def test_b58dec(word, expected_output):
    assert b58_prefix.b58dec(word) == expected_output

@pytest.mark.parametrize("val,expected_output", [
    (375492, [5, 186, 196]),
    (797373, [12, 42, 189]),
])
def test_asciidec(val, expected_output):
    assert b58_prefix.asciidec(val) == expected_output

