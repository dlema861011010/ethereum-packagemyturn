constants = import_module("../../package_io/constants.star")

# ---------------------------------------------------------------------------
# Behavioral markers that a Fusespark node MUST exhibit
# ---------------------------------------------------------------------------

# Network identity
FUSESPARK_CHAIN_ID = constants.FUSESPARK_CHAIN_ID
FUSESPARK_NETWORK_ID = constants.FUSESPARK_NETWORK_ID
FUSESPARK_CHAIN_ID_HEX = constants.FUSESPARK_CHAIN_ID_HEX

# Required RPC namespaces
FUSESPARK_REQUIRED_RPC_NAMESPACES = [
    "admin",
    "engine",
    "net",
    "eth",
    "web3",
    "debug",
    "txpool",
    "fuse",
]

# Minimum volume allocation for validator operations
FUSESPARK_MIN_VALIDATOR_VOLUME_MB = constants.FUSESPARK_MIN_VALIDATOR_VOLUME_MB

# Authoritative Fuse Network bootnode addresses
FUSE_BOOTNODE_REGISTRY = constants.FUSE_BOOTNODE_REGISTRY


def validate_fusespark_cmd(cmd):
    """
    Validates that a Fusespark geth command list contains all required flags.

    Args:
        cmd (list): The geth command argument list.

    Returns:
        struct: A validation result with fields:
            - passed (bool): True if all checks pass.
            - failures (list): Descriptions of any failed checks.
    """
    failures = []

    # 1. Verify --networkid=123 is present
    network_id_flag = "--networkid={0}".format(FUSESPARK_NETWORK_ID)
    found_network_id = False
    for arg in cmd:
        if arg == network_id_flag or arg.startswith("--networkid="):
            if str(FUSESPARK_NETWORK_ID) in arg:
                found_network_id = True
            break
    if not found_network_id:
        failures.append(
            "Missing --networkid={0} flag (required for Fuse Network isolation)".format(
                FUSESPARK_NETWORK_ID
            )
        )

    # 2. Verify --http.api includes the "fuse" namespace
    found_fuse_namespace = False
    for arg in cmd:
        if arg.startswith("--http.api="):
            if "fuse" in arg:
                found_fuse_namespace = True
            break
    if not found_fuse_namespace:
        failures.append(
            'Missing "fuse" namespace in --http.api (required for Fuse-specific RPC methods)'
        )

    # 3. Verify at least one Fuse Network bootnode is configured
    found_fuse_bootnode = False
    for arg in cmd:
        if arg.startswith("--bootnodes="):
            for bootnode in FUSE_BOOTNODE_REGISTRY:
                if bootnode in arg:
                    found_fuse_bootnode = True
                    break
            break
    if not found_fuse_bootnode:
        failures.append(
            "No Fuse Network bootnode addresses found in --bootnodes flag"
        )

    return struct(
        passed=len(failures) == 0,
        failures=failures,
    )


def validate_fusespark_volume(volume_size_mb):
    """
    Validates that the allocated volume meets Fusespark validator requirements.

    Args:
        volume_size_mb (int): Allocated volume size in MB.

    Returns:
        struct: A validation result with fields:
            - passed (bool): True if the volume is sufficient.
            - failures (list): Descriptions of any failed checks.
    """
    failures = []
    if volume_size_mb < FUSESPARK_MIN_VALIDATOR_VOLUME_MB:
        failures.append(
            "Volume size {0} MB is below the Fusespark validator minimum of {1} MB".format(
                volume_size_mb, FUSESPARK_MIN_VALIDATOR_VOLUME_MB
            )
        )
    return struct(
        passed=len(failures) == 0,
        failures=failures,
    )


def validate_bootnode_isolation(bootnode_arg):
    """
    Validates that bootnode addresses belong exclusively to the Fuse Network registry,
    ensuring the node will not peer with Ethereum Mainnet or other networks.

    Args:
        bootnode_arg (str): The raw --bootnodes=... argument value (everything after '=').

    Returns:
        struct: A validation result with fields:
            - passed (bool): True if all bootnodes are from the Fuse Network registry.
            - failures (list): Descriptions of any non-Fuse bootnodes detected.
    """
    failures = []
    bootnodes = bootnode_arg.split(",")
    for node in bootnodes:
        node = node.strip()
        if node == "":
            continue
        is_fuse_node = False
        for registered in FUSE_BOOTNODE_REGISTRY:
            if node == registered:
                is_fuse_node = True
                break
        if not is_fuse_node:
            failures.append(
                "Bootnode '{0}' is not in the Fuse Network registry – possible cross-network contamination".format(
                    node
                )
            )
    return struct(
        passed=len(failures) == 0,
        failures=failures,
    )
