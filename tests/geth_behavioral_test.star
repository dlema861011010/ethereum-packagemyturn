geth_launcher = import_module("../src/el/geth/geth_launcher.star")
behavioral_validation = import_module("../src/el/geth/geth_behavioral_validation.star")
network_isolation = import_module("../src/el/geth/geth_network_isolation.star")
rpc_probes = import_module("../src/el/geth/geth_rpc_probes.star")
constants = import_module("../src/package_io/constants.star")

# ---------------------------------------------------------------------------
# Test suite: Fusespark variant detection and behavioral validation
#
# These tests are designed to be evaluated at plan-interpretation time by the
# Kurtosis runtime.  Each test_ function asserts an expected outcome and calls
# fail() if the assertion does not hold.
# ---------------------------------------------------------------------------


def _assert(condition, message):
    """Minimal assertion helper that calls fail() on failure."""
    if not condition:
        fail(message)


# ---------------------------------------------------------------------------
# 1. identify_el_variant – image string classification
# ---------------------------------------------------------------------------

def test_repo_pattern_fuse_network_dlemaandliz():
    result = geth_launcher.identify_el_variant("fuse-network-dlemaandliz:v1.0")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


def test_repo_pattern_fuseio_geth():
    result = geth_launcher.identify_el_variant("fuseio/geth:v1.2.3")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


def test_repo_pattern_dlema_fuse():
    result = geth_launcher.identify_el_variant("dlema861011010/fuse:latest")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


def test_tag_based_fusespark():
    result = geth_launcher.identify_el_variant("eth-builder-fusespark-v1")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


def test_generic_fusespark_tag():
    result = geth_launcher.identify_el_variant("custom-geth-fusespark-v1")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


def test_standard_geth():
    result = geth_launcher.identify_el_variant("geth:v1.13.0")
    _assert(result == "geth", "Expected 'geth', got '{0}'".format(result))


def test_ethereum_client_go():
    result = geth_launcher.identify_el_variant("ethereum/client-go:latest")
    _assert(result == "geth", "Expected 'geth', got '{0}'".format(result))


def test_builder_variant():
    result = geth_launcher.identify_el_variant("flashbots/builder:latest")
    _assert(result == "builder", "Expected 'builder', got '{0}'".format(result))


def test_suave_variant():
    result = geth_launcher.identify_el_variant("flashbots/suave-geth:latest")
    _assert(result == "suave", "Expected 'suave', got '{0}'".format(result))


def test_fusespark_takes_priority_over_builder():
    # An image containing both "fusespark" and "builder" in the name should be
    # classified as fusespark (higher priority).
    result = geth_launcher.identify_el_variant("my-builder-fusespark-image:v1")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


def test_fuse_network_repo_takes_priority_over_suave():
    result = geth_launcher.identify_el_variant("fuse-network/suave-style-geth:v1")
    _assert(result == "fusespark", "Expected 'fusespark', got '{0}'".format(result))


# ---------------------------------------------------------------------------
# 2. behavioral_validation – cmd flag checks
# ---------------------------------------------------------------------------

def test_validate_fusespark_cmd_passes():
    cmd = [
        "geth",
        "--http.api=admin,engine,net,eth,web3,debug,txpool,fuse",
        "--ws.api=admin,engine,net,eth,web3,debug,txpool,fuse",
        "--networkid=123",
        "--bootnodes=" + ",".join(constants.FUSE_BOOTNODE_REGISTRY),
    ]
    result = behavioral_validation.validate_fusespark_cmd(cmd)
    _assert(result.passed, "Expected validation to pass, failures: {0}".format(result.failures))


def test_validate_fusespark_cmd_missing_networkid():
    cmd = [
        "geth",
        "--http.api=admin,engine,net,eth,web3,debug,txpool,fuse",
        "--bootnodes=" + ",".join(constants.FUSE_BOOTNODE_REGISTRY),
    ]
    result = behavioral_validation.validate_fusespark_cmd(cmd)
    _assert(not result.passed, "Expected validation to fail due to missing --networkid")


def test_validate_fusespark_cmd_missing_fuse_namespace():
    cmd = [
        "geth",
        "--http.api=admin,engine,net,eth,web3,debug,txpool",
        "--networkid=123",
        "--bootnodes=" + ",".join(constants.FUSE_BOOTNODE_REGISTRY),
    ]
    result = behavioral_validation.validate_fusespark_cmd(cmd)
    _assert(not result.passed, "Expected validation to fail due to missing 'fuse' namespace")


def test_validate_fusespark_volume_sufficient():
    result = behavioral_validation.validate_fusespark_volume(500000)
    _assert(result.passed, "Expected volume validation to pass for 500 GB")


def test_validate_fusespark_volume_insufficient():
    result = behavioral_validation.validate_fusespark_volume(10000)
    _assert(not result.passed, "Expected volume validation to fail for 10 GB")


# ---------------------------------------------------------------------------
# 3. network_isolation – bootnode and flag validation
# ---------------------------------------------------------------------------

def test_fuse_bootnode_recognized():
    for node in constants.FUSE_BOOTNODE_REGISTRY:
        _assert(
            network_isolation.is_fuse_bootnode(node),
            "Expected '{0}' to be recognized as a Fuse bootnode".format(node),
        )


def test_non_fuse_bootnode_rejected():
    fake_node = "enode://aabbcc@1.2.3.4:30303"
    _assert(
        not network_isolation.is_fuse_bootnode(fake_node),
        "Expected non-Fuse bootnode to be rejected",
    )


def test_validate_bootnode_addresses_all_fuse():
    result = network_isolation.validate_bootnode_addresses(constants.FUSE_BOOTNODE_REGISTRY)
    _assert(result.passed, "Expected all Fuse bootnodes to pass: {0}".format(result.message))


def test_validate_bootnode_addresses_with_foreign_node():
    mixed = list(constants.FUSE_BOOTNODE_REGISTRY) + ["enode://aabbcc@1.2.3.4:30303"]
    result = network_isolation.validate_bootnode_addresses(mixed)
    _assert(not result.passed, "Expected mixed bootnode list to fail validation")


def test_validate_network_isolation_flags_passes():
    cmd = [
        "geth",
        "--networkid=123",
        "--bootnodes=" + ",".join(constants.FUSE_BOOTNODE_REGISTRY),
    ]
    result = network_isolation.validate_network_isolation_flags(cmd)
    _assert(result.passed, "Expected isolation flags to pass, failures: {0}".format(result.failures))


def test_validate_network_isolation_flags_wrong_networkid():
    cmd = [
        "geth",
        "--networkid=1",  # Ethereum Mainnet – should fail
        "--bootnodes=" + ",".join(constants.FUSE_BOOTNODE_REGISTRY),
    ]
    result = network_isolation.validate_network_isolation_flags(cmd)
    _assert(not result.passed, "Expected validation to fail for wrong networkid")


# ---------------------------------------------------------------------------
# 4. rpc_probes – sanity checks on probe definitions
# ---------------------------------------------------------------------------

def test_rpc_probes_include_critical_methods():
    critical_methods = [p.method for p in rpc_probes.get_critical_probes()]
    _assert("web3_clientVersion" in critical_methods, "web3_clientVersion must be a critical probe")
    _assert("eth_chainId" in critical_methods, "eth_chainId must be a critical probe")
    _assert("net_version" in critical_methods, "net_version must be a critical probe")


def test_rpc_probe_chain_id_hex():
    for probe in rpc_probes.get_all_probes():
        if probe.id == "eth_chainId":
            _assert(
                probe.expected_equals == constants.FUSESPARK_CHAIN_ID_HEX,
                "eth_chainId probe must expect {0}".format(constants.FUSESPARK_CHAIN_ID_HEX),
            )


def test_rpc_probe_net_version():
    for probe in rpc_probes.get_all_probes():
        if probe.id == "net_version":
            _assert(
                probe.expected_equals == constants.FUSESPARK_NETWORK_VERSION,
                "net_version probe must expect '{0}'".format(constants.FUSESPARK_NETWORK_VERSION),
            )


# ---------------------------------------------------------------------------
# Entry point: run all tests and report results
# ---------------------------------------------------------------------------

def run(plan):
    """
    Executes the Fusespark behavioral validation test suite.

    Call this from the Kurtosis plan to validate the variant detection and
    configuration logic without deploying any services.
    """
    tests = [
        # identify_el_variant tests
        test_repo_pattern_fuse_network_dlemaandliz,
        test_repo_pattern_fuseio_geth,
        test_repo_pattern_dlema_fuse,
        test_tag_based_fusespark,
        test_generic_fusespark_tag,
        test_standard_geth,
        test_ethereum_client_go,
        test_builder_variant,
        test_suave_variant,
        test_fusespark_takes_priority_over_builder,
        test_fuse_network_repo_takes_priority_over_suave,
        # behavioral_validation tests
        test_validate_fusespark_cmd_passes,
        test_validate_fusespark_cmd_missing_networkid,
        test_validate_fusespark_cmd_missing_fuse_namespace,
        test_validate_fusespark_volume_sufficient,
        test_validate_fusespark_volume_insufficient,
        # network_isolation tests
        test_fuse_bootnode_recognized,
        test_non_fuse_bootnode_rejected,
        test_validate_bootnode_addresses_all_fuse,
        test_validate_bootnode_addresses_with_foreign_node,
        test_validate_network_isolation_flags_passes,
        test_validate_network_isolation_flags_wrong_networkid,
        # rpc_probes tests
        test_rpc_probes_include_critical_methods,
        test_rpc_probe_chain_id_hex,
        test_rpc_probe_net_version,
    ]

    passed = 0
    for test_fn in tests:
        test_fn()
        passed = passed + 1

    plan.print("Fusespark behavioral test suite: {0} passed".format(passed))
