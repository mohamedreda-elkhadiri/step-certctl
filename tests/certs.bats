#!/usr/bin/env bats
# Tests for certs_are_different and get_pubkey_from_cert

load helpers/common

setup() {
    setup_test_env
    export CONFIG_DIR
    # Source the script to access internal functions directly.
    # set -euo pipefail from the script propagates here; reset after sourcing.
    # shellcheck disable=SC1090
    source "$SCRIPT"
    set +euo pipefail

    CERT_A="$CERT_DIR/cert_a.pem"
    KEY_A="$CERT_DIR/key_a.pem"
    CERT_B="$CERT_DIR/cert_b.pem"
    KEY_B="$CERT_DIR/key_b.pem"

    make_cert "$CERT_A" "$KEY_A" "host-a.local"
    make_cert "$CERT_B" "$KEY_B" "host-b.local"
}

teardown() {
    teardown_test_env
}

@test "get_pubkey_from_cert: returns pubkey for valid cert" {
    run get_pubkey_from_cert "$CERT_A"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PUBLIC KEY"* ]]
}

@test "get_pubkey_from_cert: returns 1 for missing file" {
    run get_pubkey_from_cert "$CERT_DIR/nonexistent.pem"
    [ "$status" -eq 1 ]
}

@test "certs_are_different: two different certs returns 0 (different)" {
    run certs_are_different "$CERT_A" "$CERT_B"
    [ "$status" -eq 0 ]
}

@test "certs_are_different: same cert compared to itself returns 1 (same)" {
    run certs_are_different "$CERT_A" "$CERT_A"
    [ "$status" -eq 1 ]
}

@test "certs_are_different: missing old cert returns 0 (treat as different)" {
    run certs_are_different "$CERT_DIR/no-old-cert.pem" "$CERT_A"
    [ "$status" -eq 0 ]
}

@test "certs_are_different: copy of cert is treated as same" {
    cp "$CERT_A" "$CERT_DIR/cert_a_copy.pem"
    run certs_are_different "$CERT_A" "$CERT_DIR/cert_a_copy.pem"
    [ "$status" -eq 1 ]
}
