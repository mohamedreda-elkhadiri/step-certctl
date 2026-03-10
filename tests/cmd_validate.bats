#!/usr/bin/env bats
# Tests for cmd_validate

load helpers/common

setup() {
    setup_test_env
    make_mock systemctl
    make_mock curl
}

teardown() {
    teardown_test_env
}

minimal_config() {
    local name="${1:-myapp}"
    make_config "$name" <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
EOF
}

@test "validate: missing config exits 1" {
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" == *"Config file not found"* ]]
}

@test "validate: missing root CA exits 1" {
    minimal_config myapp
    # root.crt does not exist — do not create it
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"Root CA not found"* ]]
}

@test "validate: missing cert file warns but does not exit 1" {
    minimal_config myapp
    make_cert "$CERT_DIR/root.crt" "$CERT_DIR/root.key" "root-ca"
    # cert.pem not created
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate myapp
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

@test "validate: missing key file warns but does not exit 1" {
    minimal_config myapp
    make_cert "$CERT_DIR/root.crt" "$CERT_DIR/root.key" "root-ca"
    make_cert "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "myapp.local"
    rm "$CERT_DIR/key.pem"
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate myapp
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

@test "validate: valid cert and root CA reports success" {
    minimal_config myapp
    make_cert "$CERT_DIR/root.crt" "$CERT_DIR/root.key" "root-ca"
    make_cert "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "myapp.local"
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate myapp
    [ "$status" -eq 0 ]
    [[ "$output" == *"valid until"* ]]
}

@test "validate: expired cert exits 1" {
    minimal_config myapp
    make_cert "$CERT_DIR/root.crt" "$CERT_DIR/root.key" "root-ca"
    make_cert "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "myapp.local"
    # Create an openssl mock that reports the cert as expired for -checkend
    cat > "$MOCK_BIN/openssl" <<'EOF'
#!/bin/bash
if [[ "$*" == *"-checkend"* ]]; then
    echo "Certificate will expire" >&2
    exit 1
fi
# Pass through all other openssl calls to real openssl
exec /usr/bin/openssl "$@"
EOF
    chmod +x "$MOCK_BIN/openssl"
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"expired"* ]]
}
