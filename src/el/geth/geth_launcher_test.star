# Tests for geth_launcher.star variant detection and RPC API injection logic.
#
# These are pure-Starlark unit tests that can be run outside of Kurtosis.
# Each test function calls fail() if an assertion does not hold.

geth_launcher = import_module("./geth_launcher.star")


# ---------------------------------------------------------------------------
# Image detection tests
# ---------------------------------------------------------------------------

def test_fusespark_detection():
    # Plain fusespark image
    assert_eq(geth_launcher.detect_geth_variant("fusespark-geth:latest"), "fusespark")
    # Ambiguous name: fusespark wins over builder
    assert_eq(geth_launcher.detect_geth_variant("eth-builder-fusespark-v1"), "fusespark")
    # Another ambiguous case
    assert_eq(geth_launcher.detect_geth_variant("custom-geth-fusespark-testnet"), "fusespark")


def test_suave_detection():
    assert_eq(geth_launcher.detect_geth_variant("geth-suave-v1"), "suave")
    assert_eq(geth_launcher.detect_geth_variant("flashbots/suave-geth:latest"), "suave")


def test_builder_detection():
    assert_eq(geth_launcher.detect_geth_variant("geth-builder-v1"), "builder")
    assert_eq(geth_launcher.detect_geth_variant("ethpandaops/geth-builder:develop"), "builder")


def test_standard_geth_detection():
    assert_eq(geth_launcher.detect_geth_variant("ethereum/client-go:latest"), "standard")
    assert_eq(geth_launcher.detect_geth_variant("geth:v1.13.0"), "standard")
    assert_eq(geth_launcher.detect_geth_variant("custom-geth-node:main"), "standard")


# ---------------------------------------------------------------------------
# RPC API injection tests
# ---------------------------------------------------------------------------

def test_rpc_api_injection_fusespark():
    apis = geth_launcher.get_rpc_apis_for_variant("fusespark")
    assert_eq(apis, geth_launcher.FUSESPARK_RPC_APIS)
    assert_contains(apis, "fuse")
    assert_contains(apis, "txpool")


def test_rpc_api_injection_suave():
    apis = geth_launcher.get_rpc_apis_for_variant("suave")
    assert_eq(apis, geth_launcher.SUAVE_RPC_APIS)
    assert_contains(apis, "suavex")


def test_rpc_api_injection_builder():
    apis = geth_launcher.get_rpc_apis_for_variant("builder")
    assert_eq(apis, geth_launcher.BUILDER_RPC_APIS)
    assert_contains(apis, "mev")
    assert_contains(apis, "flashbots")


def test_rpc_api_injection_standard():
    apis = geth_launcher.get_rpc_apis_for_variant("standard")
    assert_eq(apis, geth_launcher.STANDARD_RPC_APIS)
    # Standard must NOT include fork-specific namespaces
    assert_not_contains(apis, "fuse")
    assert_not_contains(apis, "suavex")
    assert_not_contains(apis, "mev")
    assert_not_contains(apis, "flashbots")


# ---------------------------------------------------------------------------
# Volume sizing tests
# ---------------------------------------------------------------------------

def test_volume_sizing_fusespark_node():
    vol = geth_launcher.FUSESPARK_VOLUME_SIZES["node"]
    # Node storage spec: 200–400 GB; current configured value: 300 GB (300000 MB)
    assert_in_range(vol, 200000, 400000)


def test_volume_sizing_fusespark_validator():
    vol = geth_launcher.FUSESPARK_VOLUME_SIZES["validator"]
    # Validator storage spec: 300–500 GB; current configured value: 400 GB (400000 MB)
    assert_in_range(vol, 300000, 500000)


def test_volume_sizing_fusespark_archive():
    vol = geth_launcher.FUSESPARK_VOLUME_SIZES["archive"]
    # Archive storage spec: 2–4 TB; current configured value: 3 TB (3000000 MB)
    assert_in_range(vol, 2000000, 4000000)


# ---------------------------------------------------------------------------
# Helper assertion utilities
# ---------------------------------------------------------------------------

def assert_eq(actual, expected):
    if actual != expected:
        fail("assertion failed: expected {0!r}, got {1!r}".format(expected, actual))


def assert_contains(haystack, needle):
    if needle not in haystack:
        fail("assertion failed: expected {0!r} to contain {1!r}".format(haystack, needle))


def assert_not_contains(haystack, needle):
    if needle in haystack:
        fail("assertion failed: expected {0!r} NOT to contain {1!r}".format(haystack, needle))


def assert_in_range(value, lo, hi):
    if value < lo or value > hi:
        fail(
            "assertion failed: expected {0} to be in range [{1}, {2}]".format(
                value, lo, hi
            )
        )


# ---------------------------------------------------------------------------
# Run all tests when this file is executed directly
# ---------------------------------------------------------------------------

def run_all_tests():
    test_fusespark_detection()
    test_suave_detection()
    test_builder_detection()
    test_standard_geth_detection()
    test_rpc_api_injection_fusespark()
    test_rpc_api_injection_suave()
    test_rpc_api_injection_builder()
    test_rpc_api_injection_standard()
    test_volume_sizing_fusespark_node()
    test_volume_sizing_fusespark_validator()
    test_volume_sizing_fusespark_archive()
