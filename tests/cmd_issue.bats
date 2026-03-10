#!/usr/bin/env bats
# Tests for cmd_issue: step flags for provisioner and template

load helpers/common

setup() {
    setup_test_env
    make_mock chown
    make_mock chmod

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

step_calls() {
    cat "$TEST_DIR/step.calls" 2>/dev/null || true
}

@test "issue: succeeds with minimal config" {
    make_recording_mock step
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
}

@test "issue: step failure exits 1" {
    make_recording_mock step 1
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to issue"* ]]
}

@test "issue: no PROVISIONER — --provisioner flag not passed to step" {
    make_recording_mock step
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" != *"--provisioner"* ]]
}

@test "issue: PROVISIONER set — --provisioner flag passed to step" {
    make_recording_mock step
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
PROVISIONER=my-jwk
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" == *"--provisioner=my-jwk"* ]]
}

@test "issue: PROVISIONER_PASSWORD_FILE set — flag passed to step" {
    make_recording_mock step
    local pass_file="$TEST_DIR/provisioner.pass"
    echo "secret" > "$pass_file"
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
PROVISIONER=my-jwk
PROVISIONER_PASSWORD_FILE=$pass_file
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" == *"--provisioner-password-file=$pass_file"* ]]
}

@test "issue: no PROVISIONER_PASSWORD_FILE — flag not passed to step" {
    make_recording_mock step
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" != *"--provisioner-password-file"* ]]
}

@test "issue: CERT_TEMPLATE set — --set-file flag passed to step" {
    make_recording_mock step
    local tpl_file="$TEST_DIR/default.tpl"
    echo '{"OU":"Infra"}' > "$tpl_file"
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
CERT_TEMPLATE=$tpl_file
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" == *"--set-file=$tpl_file"* ]]
}

@test "issue: no CERT_TEMPLATE — --set-file flag not passed to step" {
    make_recording_mock step
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" != *"--set-file"* ]]
}

@test "issue: all three optional flags passed together" {
    make_recording_mock step
    local pass_file="$TEST_DIR/provisioner.pass"
    local tpl_file="$TEST_DIR/default.tpl"
    echo "secret" > "$pass_file"
    echo '{"OU":"Infra"}' > "$tpl_file"
    make_config myapp <<EOF
CERT_FILE=$CERT_DIR/cert.pem
KEY_FILE=$CERT_DIR/key.pem
CA_URL=https://ca.local
ROOT_CA=$CERT_DIR/root.crt
COMMON_NAME=myapp.local
PROVISIONER=my-jwk
PROVISIONER_PASSWORD_FILE=$pass_file
CERT_TEMPLATE=$tpl_file
EOF
    run env CONFIG_DIR="$CONFIG_DIR" "$SCRIPT" issue myapp
    [ "$status" -eq 0 ]
    [[ "$(step_calls)" == *"--provisioner=my-jwk"* ]]
    [[ "$(step_calls)" == *"--provisioner-password-file=$pass_file"* ]]
    [[ "$(step_calls)" == *"--set-file=$tpl_file"* ]]
}
