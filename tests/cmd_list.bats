#!/usr/bin/env bats
# Tests for cmd_list

load helpers/common

setup() {
    setup_test_env
    make_mock systemctl
}

teardown() {
    teardown_test_env
}

@test "list: no config directory warns and exits 0" {
    rmdir "$CONFIG_DIR"
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "list: empty config directory reports no certificates" {
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No certificates configured"* ]]
}

@test "list: single config shows name and common name" {
    make_cert "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "myapp.local"
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"myapp"* ]]
    [[ "$output" == *"myapp.local"* ]]
}

@test "list: cert not yet issued shows 'not issued'" {
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"not issued"* ]]
}

@test "list: multiple configs all appear in output" {
    for name in app1 app2 app3; do
        make_config "$name" <<EOF
CERT_FILE=$CERT_DIR/${name}.pem
KEY_FILE=$CERT_DIR/${name}.key
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=${name}.local
EOF
    done
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"app1"* ]]
    [[ "$output" == *"app2"* ]]
    [[ "$output" == *"app3"* ]]
}

@test "list: valid cert shows expiry date" {
    make_cert "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "myapp.local"
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"valid until"* ]]
}
