#!/usr/bin/env bats
# Tests for load_config: required variables, missing file, defaults

load helpers/common

setup() {
    setup_test_env
    # Silence external calls that load_config itself doesn't need,
    # but downstream commands (issue/validate) will invoke
    make_mock chown
    make_mock chmod
    make_mock step
    make_mock openssl
    make_mock curl
    make_mock systemctl
}

teardown() {
    teardown_test_env
}

# Helper: run any command that triggers load_config for <name>
run_with_config() {
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate "$1"
}

@test "missing config file: exits 1 with descriptive error" {
    run_with_config nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" == *"Config file not found"* ]]
}

@test "missing CERT_FILE: exits 1 naming the variable" {
    make_config myapp <<EOF
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    run_with_config myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"CERT_FILE"* ]]
}

@test "missing KEY_FILE: exits 1 naming the variable" {
    make_config myapp <<EOF
CERT_FILE=/tmp/cert.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    run_with_config myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"KEY_FILE"* ]]
}

@test "missing CA_URL: exits 1 naming the variable" {
    make_config myapp <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    run_with_config myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"CA_URL"* ]]
}

@test "missing ROOT_CA: exits 1 naming the variable" {
    make_config myapp <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
COMMON_NAME=myapp.local
EOF
    run_with_config myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"ROOT_CA"* ]]
}

@test "missing COMMON_NAME: exits 1 naming the variable" {
    make_config myapp <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
EOF
    run_with_config myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"COMMON_NAME"* ]]
}

@test "all required variables present: load_config succeeds" {
    make_config myapp <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    # validate proceeds past load_config; ROOT_CA check may warn but won't crash
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" validate myapp
    # Should not fail with a "not set" error
    [[ "$output" != *"not set"* ]]
}

@test "SAN defaults to COMMON_NAME when not set" {
    # Verified by sourcing the script and inspecting the variable
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testsan <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    load_config testsan
    [ "$SAN" = "myapp.local" ]
}

@test "EXPIRES_IN defaults to 8h when not set" {
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testexp <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    load_config testexp
    [ "$EXPIRES_IN" = "8h" ]
}

@test "OWNER defaults to root when not set" {
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testowner <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    load_config testowner
    [ "$OWNER" = "root" ]
}

@test "explicit SAN overrides COMMON_NAME default" {
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testsan2 <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
SAN=alt.local
EOF
    load_config testsan2
    [ "$SAN" = "alt.local" ]
}

@test "PROVISIONER defaults to empty when not set" {
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testprov <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    load_config testprov
    [ "${PROVISIONER}" = "" ]
}

@test "PROVISIONER_PASSWORD_FILE defaults to empty when not set" {
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testprovpass <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    load_config testprovpass
    [ "${PROVISIONER_PASSWORD_FILE}" = "" ]
}

@test "CERT_TEMPLATE defaults to empty when not set" {
    export CONFIG_DIR
    # shellcheck disable=SC1090
    source "$SCRIPT"
    make_config testtpl <<EOF
CERT_FILE=/tmp/cert.pem
KEY_FILE=/tmp/key.pem
CA_URL=https://ca.local
ROOT_CA=/tmp/root.crt
COMMON_NAME=myapp.local
EOF
    load_config testtpl
    [ "${CERT_TEMPLATE}" = "" ]
}
