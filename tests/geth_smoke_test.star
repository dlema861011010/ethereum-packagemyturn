# Unit tests for geth_smoke_test.star
# These tests validate the pre-flight smoke test logic for Fusespark/Geth image
# detection and split-brain prevention.
#
# Run with: kurtosis run . --enclave test -- '{"_test": "geth_smoke_test"}'
#
# Each test_* function exercises the validate_image_volume_alignment function
# and asserts the expected outcome (passed/failed, number of violations, etc.).

geth_smoke_test = import_module("../src/el/geth/geth_smoke_test.star")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_network_params(network):
    """Build a minimal network_params struct for testing."""
    return struct(network=network)


def _assert_passed(result, test_name):
    if not result.passed:
        fail(
            "{0}: expected smoke test to PASS but got violations: {1}".format(
                test_name, result.violations
            )
        )


def _assert_failed(result, test_name, expected_violation_count=None):
    if result.passed:
        fail(
            "{0}: expected smoke test to FAIL but it passed".format(test_name)
        )
    if expected_violation_count != None and len(result.violations) != expected_violation_count:
        fail(
            "{0}: expected {1} violations, got {2}: {3}".format(
                test_name,
                expected_violation_count,
                len(result.violations),
                result.violations,
            )
        )


# ---------------------------------------------------------------------------
# Tests: Image-Network alignment
# ---------------------------------------------------------------------------

def test_standard_geth_on_mainnet_passes():
    """Standard geth image on mainnet should pass."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="ethereum/client-go:latest",
        network_params=_make_network_params("mainnet"),
        volume_size=1000000,
        el_storage_type="pruned",
    )
    _assert_passed(result, "test_standard_geth_on_mainnet_passes")


def test_fusespark_on_mainnet_fails():
    """Fusespark image on mainnet is a split-brain violation."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="fusespark/geth-fusespark:v1.1.0",
        network_params=_make_network_params("mainnet"),
        volume_size=500000,
        el_storage_type="archive",
    )
    _assert_failed(result, "test_fusespark_on_mainnet_fails", expected_violation_count=1)


def test_fusespark_on_sepolia_fails():
    """Fusespark image on sepolia is a split-brain violation."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="fusespark/geth-fusespark:v1.1.0",
        network_params=_make_network_params("sepolia"),
        volume_size=300000,
        el_storage_type="archive",
    )
    _assert_failed(result, "test_fusespark_on_sepolia_fails", expected_violation_count=1)


def test_standard_geth_on_sparknet_fails():
    """Standard geth image on sparknet is a split-brain violation."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="ethereum/client-go:latest",
        network_params=_make_network_params("sparknet"),
        volume_size=500000,
        el_storage_type="archive",
    )
    _assert_failed(result, "test_standard_geth_on_sparknet_fails", expected_violation_count=1)


def test_fusespark_on_sparknet_passes():
    """Fusespark image on sparknet with archive mode should pass."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="fusespark/geth-fusespark:v1.1.0",
        network_params=_make_network_params("sparknet"),
        volume_size=2000000,
        el_storage_type="archive",
    )
    _assert_passed(result, "test_fusespark_on_sparknet_passes")


# ---------------------------------------------------------------------------
# Tests: Storage mode incompatibility
# ---------------------------------------------------------------------------

def test_fusespark_pruned_mode_fails():
    """Fusespark image in pruned mode is a violation (validators must use archive)."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="fusespark/geth-fusespark:v1.1.0",
        network_params=_make_network_params("sparknet"),
        volume_size=2000000,
        el_storage_type="pruned",
    )
    # Two violations: storage mode + (pruned is also invalid for sparknet image but
    # storage mode violation is the primary one)
    _assert_failed(result, "test_fusespark_pruned_mode_fails")


# ---------------------------------------------------------------------------
# Tests: Volume sizing recommendations
# ---------------------------------------------------------------------------

def test_fusespark_archive_undersized_volume_is_recommendation():
    """Fusespark archive with small volume emits a recommendation, not a violation."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="fusespark/geth-fusespark:v1.1.0",
        network_params=_make_network_params("sparknet"),
        volume_size=100000,  # 100GB < 2TB required
        el_storage_type="archive",
    )
    # Should PASS (not a hard violation) but have a recommendation
    _assert_passed(result, "test_fusespark_archive_undersized_volume_is_recommendation")
    if len(result.recommendations) == 0:
        fail(
            "test_fusespark_archive_undersized_volume_is_recommendation: "
            + "expected at least one recommendation for undersized volume"
        )


def test_zero_volume_size_skips_sizing_check():
    """Volume size of 0 (use default) should skip volume sizing checks."""
    result = geth_smoke_test.validate_image_volume_alignment(
        image_string="fusespark/geth-fusespark:v1.1.0",
        network_params=_make_network_params("sparknet"),
        volume_size=0,  # 0 = use default
        el_storage_type="archive",
    )
    _assert_passed(result, "test_zero_volume_size_skips_sizing_check")


# ---------------------------------------------------------------------------
# Tests: detect_geth_variant priority
# ---------------------------------------------------------------------------

def test_detect_variant_fusespark_priority():
    """fusespark takes priority over suave and builder in image strings."""
    variant = geth_smoke_test.detect_geth_variant("geth-fusespark-suave-builder:v1.0")
    if variant != "fusespark":
        fail(
            "test_detect_variant_fusespark_priority: expected 'fusespark', got '{0}'".format(
                variant
            )
        )


def test_detect_variant_suave_priority():
    """suave takes priority over builder when fusespark is absent."""
    variant = geth_smoke_test.detect_geth_variant("geth-suave-builder:v1.0")
    if variant != "suave":
        fail(
            "test_detect_variant_suave_priority: expected 'suave', got '{0}'".format(
                variant
            )
        )


def test_detect_variant_builder():
    """builder is detected when fusespark and suave are absent."""
    variant = geth_smoke_test.detect_geth_variant("geth-builder:v1.0")
    if variant != "builder":
        fail(
            "test_detect_variant_builder: expected 'builder', got '{0}'".format(variant)
        )


def test_detect_variant_standard():
    """Standard geth image maps to 'standard'."""
    variant = geth_smoke_test.detect_geth_variant("ethereum/client-go:latest")
    if variant != "standard":
        fail(
            "test_detect_variant_standard: expected 'standard', got '{0}'".format(variant)
        )


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

def run_all_tests():
    """Run all unit tests and report results."""
    tests = [
        test_standard_geth_on_mainnet_passes,
        test_fusespark_on_mainnet_fails,
        test_fusespark_on_sepolia_fails,
        test_standard_geth_on_sparknet_fails,
        test_fusespark_on_sparknet_passes,
        test_fusespark_pruned_mode_fails,
        test_fusespark_archive_undersized_volume_is_recommendation,
        test_zero_volume_size_skips_sizing_check,
        test_detect_variant_fusespark_priority,
        test_detect_variant_suave_priority,
        test_detect_variant_builder,
        test_detect_variant_standard,
    ]

    passed = 0
    failed = 0
    for test_fn in tests:
        test_fn()
        passed = passed + 1

    return struct(
        passed=passed,
        failed=failed,
        total=len(tests),
    )
