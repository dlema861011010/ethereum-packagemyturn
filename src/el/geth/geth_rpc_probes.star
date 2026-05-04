constants = import_module("../../package_io/constants.star")

# ---------------------------------------------------------------------------
# RPC health-check probe definitions for Fusespark nodes.
#
# Each probe describes a JSON-RPC call and the expected response characteristics
# that confirm the node is running the Fuse Network fork (Chain ID 123).
# ---------------------------------------------------------------------------

# Expected response values for a correctly configured Fusespark node
EXPECTED_CLIENT_VERSION_CONTAINS = "fusespark"
EXPECTED_CHAIN_ID_HEX = constants.FUSESPARK_CHAIN_ID_HEX  # "0x7b" == 123
EXPECTED_NET_VERSION = constants.FUSESPARK_NETWORK_VERSION  # "123"

# Ordered list of RPC probes. Each entry is a struct describing one call.
FUSESPARK_RPC_PROBES = [
    struct(
        id="web3_clientVersion",
        method="web3_clientVersion",
        params=[],
        description="Client version must identify as Fusespark",
        # The result field should CONTAIN this string (case-insensitive check
        # is left to the caller since Starlark has no built-in lower()).
        expected_contains=EXPECTED_CLIENT_VERSION_CONTAINS,
        critical=True,
    ),
    struct(
        id="eth_chainId",
        method="eth_chainId",
        params=[],
        description="Chain ID must be 0x7b (123 decimal) for Fuse Network",
        expected_equals=EXPECTED_CHAIN_ID_HEX,
        critical=True,
    ),
    struct(
        id="net_version",
        method="net_version",
        params=[],
        description="Network version must be '123' for Fuse Network",
        expected_equals=EXPECTED_NET_VERSION,
        critical=True,
    ),
    struct(
        id="admin_nodeInfo",
        method="admin_nodeInfo",
        params=[],
        description="Node info must expose a valid enode URL",
        expected_field="enode",
        critical=False,
    ),
    struct(
        id="eth_syncing",
        method="eth_syncing",
        params=[],
        description="Node sync state (false = fully synced)",
        expected_field=None,  # informational only
        critical=False,
    ),
]


def build_rpc_request(method, params, request_id=1):
    """
    Builds a JSON-RPC 2.0 request body dict for use with plan.request().

    Args:
        method (str): The RPC method name.
        params (list): The method parameters.
        request_id (int): The JSON-RPC request id.

    Returns:
        dict: A request body dict compatible with Kurtosis plan.request().
    """
    return {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": request_id,
    }


def get_critical_probes():
    """Returns only the probes marked as critical."""
    critical = []
    for probe in FUSESPARK_RPC_PROBES:
        if probe.critical:
            critical.append(probe)
    return critical


def get_all_probes():
    """Returns all defined RPC probes."""
    return FUSESPARK_RPC_PROBES
