#!/usr/bin/env bats
# Tests for cmd_renew: step failures, cert comparison, reload behaviour

load helpers/common

setup() {
    setup_test_env
    make_mock chown
    make_mock chmod

    CERT_A="$CERT_DIR/cert_a.pem"
    KEY_A="$CERT_DIR/key_a.pem"
    CERT_B="$CERT_DIR/cert_b.pem"
    KEY_B="$CERT_DIR/key_b.pem"

    make_cert "$CERT_A" "$KEY_A" "host-a.local"
    make_cert "$CERT_B" "$KEY_B" "host-b.local"

    # Place cert_a as the "currently installed" cert
    cp "$CERT_A" "$CERT_DIR/cert.pem"
    cp "$KEY_A"  "$CERT_DIR/key.pem"

    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
EOF
}

teardown() {
    teardown_test_env
}

@test "renew: step failure exits 1" {
    make_step_renew_mock "$CERT_A" "$KEY_A" 1
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" renew myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to renew"* ]]
}

@test "renew: unchanged cert skips replacement and reload" {
    # step returns the same cert that is currently installed
    make_step_renew_mock "$CERT_A" "$KEY_A" 0
    make_recording_mock reload_test_cmd
    # Override RELOAD_CMD in config
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
RELOAD_CMD=$MOCK_BIN/reload_test_cmd
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" renew myapp
    [ "$status" -eq 0 ]
    [[ "$output" == *"unchanged"* ]]
    # reload command must NOT have been called
    [ ! -f "$TEST_DIR/reload_test_cmd.calls" ]
}

@test "renew: changed cert replaces files" {
    # step returns a different cert (cert_b)
    make_step_renew_mock "$CERT_B" "$KEY_B" 0
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" renew myapp
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed successfully"* ]]
    # The installed cert should now have cert_b's public key
    new_pubkey=$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -pubkey 2>/dev/null)
    b_pubkey=$(openssl x509 -in "$CERT_B" -noout -pubkey 2>/dev/null)
    [ "$new_pubkey" = "$b_pubkey" ]
}

@test "renew: changed cert triggers RELOAD_CMD" {
    make_step_renew_mock "$CERT_B" "$KEY_B" 0
    make_recording_mock reload_test_cmd
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
RELOAD_CMD=$MOCK_BIN/reload_test_cmd
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" renew myapp
    [ "$status" -eq 0 ]
    # reload command must have been called
    [ -f "$TEST_DIR/reload_test_cmd.calls" ]
}

@test "renew: changed cert with no RELOAD_CMD still succeeds" {
    make_step_renew_mock "$CERT_B" "$KEY_B" 0
    # Config has no RELOAD_CMD (default empty)
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" renew myapp
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed successfully"* ]]
}

@test "renew: changed cert creates a backup of the old cert" {
    make_step_renew_mock "$CERT_B" "$KEY_B" 0
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" renew myapp
    [ "$status" -eq 0 ]
    [ -f "$CERT_DIR/cert.pem.bak" ]
    [ -f "$CERT_DIR/key.pem.bak" ]
}
