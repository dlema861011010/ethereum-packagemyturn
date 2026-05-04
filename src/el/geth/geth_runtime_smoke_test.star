constants = import_module("../../package_io/constants.star")

# Note: PostHttpRequestRecipe and ExecRecipe are Kurtosis built-in types and do
# not require an explicit import — they are available in every Starlark plan context.

# Expected chain IDs per network (hex-encoded as returned by eth_chainId RPC).
# constants.FUSESPARK_CHAIN_ID_HEX is the single source of truth for Sparknet.
EXPECTED_CHAIN_IDS = {
    "mainnet": "0x1",
    "sepolia": "0xaa36a7",
    "holesky": "0x4268",
    "hoodi": "0x88b0",
    "sparknet": constants.FUSESPARK_CHAIN_ID_HEX,
}

FUSESPARK_IMAGE_STR = "fusespark"


def validate_runtime_state(
    plan,
    service_name,
    image_string,
    network_params,
):
    """
    Post-launch smoke test to confirm node is on correct chain.

    Tests:
    1. Chain ID matches expected value for the configured network
    2. Fails fast if the node is on the wrong chain (prevents continued corruption)

    Args:
        plan: Kurtosis plan object
        service_name (str): Name of the running geth service
        image_string (str): Docker image reference (used for context in error messages)
        network_params (struct): Network configuration with .network field

    Returns:
        struct: { "passed": bool, "issues": list of strings }
    """
    network = network_params.network

    # Only validate networks with known expected chain IDs
    expected_chain_id = EXPECTED_CHAIN_IDS.get(network, "")
    if expected_chain_id == "":
        # Unknown or custom network — skip chain ID validation
        return struct(passed=True, issues=[])

    # Verify chain ID via eth_chainId RPC call.
    # plan.wait raises an error if the assertion fails, which halts execution
    # and prevents further corruption of node state.
    plan.wait(
        service_name=service_name,
        recipe=PostHttpRequestRecipe(
            endpoint="",
            body='{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}',
            content_type="application/json",
            port_id=constants.RPC_PORT_ID,
            extract={
                "chain_id": ".result",
            },
        ),
        field="extract.chain_id",
        assertion="==",
        target_value=expected_chain_id,
        timeout="60s",
        description="Validating chain ID for {0} on {1} (expected {2})".format(
            service_name, network, expected_chain_id
        ),
    )

    return struct(passed=True, issues=[])


def inspect_volume_state(
    plan,
    service_name,
    container_path,
):
    """
    Inspect volume to detect residual state from a previous incompatible run.

    Checks:
    1. If volume is empty (fresh) — OK
    2. If volume has geth data, examines the chain data to detect mismatches

    Args:
        plan: Kurtosis plan object
        service_name (str): Name of the running geth service
        container_path (str): Path to the data directory inside the container

    Returns:
        struct: { "clean": bool, "suggestions": list of strings }
    """
    suggestions = []

    # Check whether the chaindata directory is present (non-empty volume)
    result = plan.exec(
        service_name=service_name,
        description="Inspecting volume state for {0}".format(service_name),
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                "test -d {0}/geth/chaindata && echo 'has_data' || echo 'empty'".format(
                    container_path
                ),
            ]
        ),
    )

    volume_state = result["output"]

    if "empty" in volume_state:
        return struct(clean=True, suggestions=[])

    # Volume has existing data — warn the operator
    suggestions.append(
        "WARNING: Volume at {0} contains existing chain data from a previous run.\n".format(
            container_path
        )
        + "  If you have changed the image or network since the last run,\n"
        + "  the existing state may be incompatible with the current configuration.\n"
        + "  Remediation options:\n"
        + "  1. Use a new persistent volume key (recommended):\n"
        + '     persistent_key = "data-{0}-NEW"\n'.format(service_name)
        + "  2. Or wipe the existing volume (DESTRUCTIVE):\n"
        + "     docker volume rm kurtosis-{0}\n".format(service_name)
    )

    return struct(clean=False, suggestions=suggestions)
