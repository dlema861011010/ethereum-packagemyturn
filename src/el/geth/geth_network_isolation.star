constants = import_module("../../package_io/constants.star")

# ---------------------------------------------------------------------------
# P2P Network Isolation Validation for Fuse Network (Sparknet)
#
# Fusespark nodes must NOT connect to Ethereum Mainnet or other EVM networks.
# Isolation is enforced by:
#   1. Setting --networkid=123 (Sparknet)
#   2. Restricting --bootnodes to the Fuse Network bootnode registry
#   3. Ensuring no non-Fuse peers are discovered
# ---------------------------------------------------------------------------

FUSE_NETWORK_BOOTNODE_REGISTRY = constants.FUSE_BOOTNODE_REGISTRY
FUSESPARK_NETWORK_ID = constants.FUSESPARK_NETWORK_ID
FUSESPARK_CHAIN_ID = constants.FUSESPARK_CHAIN_ID


def validate_bootnode_addresses(bootnode_list):
    """
    Validates that every bootnode address in the provided list belongs to the
    authoritative Fuse Network registry, preventing cross-network contamination.

    Args:
        bootnode_list (list): A list of enode URL strings.

    Returns:
        struct: A validation result with fields:
            - passed (bool): True if all bootnodes are in the Fuse registry.
            - invalid_nodes (list): Enode URLs not found in the registry.
            - message (str): A human-readable summary.
    """
    invalid_nodes = []
    for node in bootnode_list:
        node = node.strip()
        if node == "":
            continue
        if node not in FUSE_NETWORK_BOOTNODE_REGISTRY:
            invalid_nodes.append(node)

    if len(invalid_nodes) == 0:
        return struct(
            passed=True,
            invalid_nodes=[],
            message="All bootnode addresses are valid Fuse Network nodes",
        )
    else:
        return struct(
            passed=False,
            invalid_nodes=invalid_nodes,
            message="Detected {0} non-Fuse bootnode(s): {1}".format(
                len(invalid_nodes), ", ".join(invalid_nodes)
            ),
        )


def validate_network_isolation_flags(cmd):
    """
    Checks that the command-line flags for a Fusespark node enforce network
    isolation from Ethereum Mainnet and other testnets.

    Specifically verifies:
      - --networkid=123 is present
      - --bootnodes references only Fuse Network registry entries

    Args:
        cmd (list): The geth command argument list.

    Returns:
        struct: A validation result with fields:
            - passed (bool): True if all isolation requirements are met.
            - failures (list): Descriptions of any failed isolation checks.
    """
    failures = []

    # Check --networkid=123
    network_id_ok = False
    for arg in cmd:
        if arg.startswith("--networkid="):
            if str(FUSESPARK_NETWORK_ID) in arg:
                network_id_ok = True
            break
    if not network_id_ok:
        failures.append(
            "--networkid={0} is required to isolate the node to Sparknet".format(
                FUSESPARK_NETWORK_ID
            )
        )

    # Check --bootnodes only contains Fuse Network addresses
    for arg in cmd:
        if arg.startswith("--bootnodes="):
            bootnode_value = arg[len("--bootnodes="):]
            result = validate_bootnode_addresses(bootnode_value.split(","))
            if not result.passed:
                failures.append(result.message)
            break

    return struct(
        passed=len(failures) == 0,
        failures=failures,
    )


def get_fuse_bootnode_registry():
    """Returns the authoritative list of Fuse Network bootnode addresses."""
    return FUSE_NETWORK_BOOTNODE_REGISTRY


def is_fuse_bootnode(enode_url):
    """
    Checks whether a single enode URL is an authoritative Fuse Network bootnode.

    Args:
        enode_url (str): The enode URL to check.

    Returns:
        bool: True if the address is in the Fuse Network registry.
    """
    return enode_url.strip() in FUSE_NETWORK_BOOTNODE_REGISTRY
