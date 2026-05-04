constants = import_module("../../package_io/constants.star")

# Fusespark image identifier string
FUSESPARK_IMAGE_STR = "fusespark"

# Sparknet network identifier
SPARKNET_NETWORK = "sparknet"

# Fuse Network Chain ID — imported from constants as single source of truth
SPARKNET_CHAIN_ID = constants.FUSESPARK_CHAIN_ID

# Minimum volume sizes for Fusespark nodes (in MB)
FUSESPARK_ARCHIVE_MIN_VOLUME_SIZE = 2000000  # 2TB
FUSESPARK_PRUNED_MIN_VOLUME_SIZE = 300000  # 300GB

# Configuration alignment matrix describing allowed/blocked combinations
# | Image Type | Network  | Min Volume | Storage Mode | Status  |
# |------------|----------|-----------|--------------|---------|
# | fusespark  | sparknet | 500000MB  | archive      | ALLOWED |
# | fusespark  | mainnet  | -         | -            | BLOCKED |
# | fusespark  | sepolia  | -         | -            | BLOCKED |
# | geth       | mainnet  | 1000000MB | pruned/arch  | ALLOWED |
# | geth       | sparknet | -         | -            | BLOCKED |


def validate_image_volume_alignment(
    image_string,
    network_params,
    volume_size,
    el_storage_type,
):
    """
    Pre-flight smoke test to prevent split-brain scenarios.

    Validates:
    1. Image variant matches network type
    2. Volume size is appropriate for network
    3. Storage mode (archive/pruned) matches network requirements
    4. No leftover state from previous incompatible run

    Args:
        image_string (str): Docker image reference
        network_params (struct): Network configuration with .network field
        volume_size (int): Allocated volume size in MB (0 means use default)
        el_storage_type (str): "archive" or "pruned"

    Returns:
        struct: {
            "passed": bool,
            "violations": list of violation strings,
            "recommendations": list of recommendation strings
        }
    """
    violations = []
    recommendations = []

    is_fusespark = FUSESPARK_IMAGE_STR in image_string
    network = network_params.network

    # A. Image-Network Mismatch checks

    # VIOLATION: Fusespark image with Mainnet network
    if is_fusespark and network == constants.NETWORK_NAME.mainnet:
        violations.append(
            "Split-Brain Risk: Fusespark image cannot sync with Mainnet genesis\n"
            + "  Image:    {0}\n".format(image_string)
            + "  Network:  mainnet (Chain ID 1)\n"
            + "  Mismatch: Fusespark targets Chain ID {0}, not 1".format(
                SPARKNET_CHAIN_ID
            )
        )
        recommendations.append(
            "1. Use standard geth image for Mainnet: geth:latest\n"
            + "2. Or use Fusespark only on Sparknet: "
            + 'network_params.network = "sparknet"'
        )

    # VIOLATION: Fusespark image with Sepolia testnet
    if is_fusespark and network == constants.NETWORK_NAME.sepolia:
        violations.append(
            "Split-Brain Risk: Fusespark image configured for wrong testnet\n"
            + "  Image:    {0}\n".format(image_string)
            + "  Network:  sepolia (Chain ID 11155111)\n"
            + "  Mismatch: Fusespark targets Chain ID {0}, not 11155111".format(
                SPARKNET_CHAIN_ID
            )
        )
        recommendations.append(
            "1. Use standard geth image for Sepolia: geth:latest\n"
            + "2. Or use Fusespark only on Sparknet: "
            + 'network_params.network = "sparknet"'
        )

    # VIOLATION: Standard Geth image with Sparknet network
    if not is_fusespark and network == SPARKNET_NETWORK:
        violations.append(
            "Split-Brain Risk: Standard Geth image cannot sync with Fusespark genesis\n"
            + "  Image:    {0}\n".format(image_string)
            + "  Network:  sparknet (Chain ID {0})\n".format(SPARKNET_CHAIN_ID)
            + "  Mismatch: Standard Geth expects Ethereum genesis, not Fuse Network genesis"
        )
        recommendations.append(
            "1. Use Fusespark image for Sparknet: geth-fusespark:latest\n"
            + "2. Or use standard geth with a standard network (mainnet/sepolia/etc.)"
        )

    # B. Storage Mode Incompatibility
    # VIOLATION: Fusespark validator trying to run pruned mode
    if is_fusespark and el_storage_type == "pruned":
        violations.append(
            "Split-Brain Risk: Fusespark validators must run in archive mode\n"
            + "  Image:        {0}\n".format(image_string)
            + "  Storage Mode: pruned\n"
            + "  Required:     archive (Fuse Network validators must maintain full history)"
        )
        recommendations.append(
            'Set el_storage_type = "archive" for all Fusespark nodes'
        )

    # C. Volume Sizing Misalignment (warnings recorded as recommendations)
    if is_fusespark and el_storage_type == "archive" and volume_size > 0 and volume_size < FUSESPARK_ARCHIVE_MIN_VOLUME_SIZE:
        recommendations.append(
            "WARNING: Undersized volume for Fusespark archive node\n"
            + "  Volume Size: {0}MB (allocated)\n".format(volume_size)
            + "  Required:    >= {0}MB (2TB) for archive mode\n".format(
                FUSESPARK_ARCHIVE_MIN_VOLUME_SIZE
            )
            + "  Fix: Set el_volume_size = {0}".format(FUSESPARK_ARCHIVE_MIN_VOLUME_SIZE)
        )

    if is_fusespark and el_storage_type == "pruned" and volume_size > 0 and volume_size < FUSESPARK_PRUNED_MIN_VOLUME_SIZE:
        recommendations.append(
            "WARNING: Undersized volume for Fusespark node\n"
            + "  Volume Size: {0}MB (allocated)\n".format(volume_size)
            + "  Required:    >= {0}MB (300GB) for pruned mode\n".format(
                FUSESPARK_PRUNED_MIN_VOLUME_SIZE
            )
            + "  Fix: Set el_volume_size = {0}".format(FUSESPARK_PRUNED_MIN_VOLUME_SIZE)
        )

    passed = len(violations) == 0

    return struct(
        passed=passed,
        violations=violations,
        recommendations=recommendations,
    )


def detect_geth_variant(el_image):
    """
    Detects the Geth variant from the image string with explicit priority ranking.

    Priority: fusespark > suave > builder > standard

    Args:
        el_image (str): The Docker image string

    Returns:
        str: One of "fusespark", "suave", "builder", or "standard"
    """
    if FUSESPARK_IMAGE_STR in el_image:
        return "fusespark"
    elif "suave" in el_image:
        return "suave"
    elif "builder" in el_image:
        return "builder"
    else:
        return "standard"
