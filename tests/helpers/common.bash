#!/usr/bin/env bash
# Shared test helpers for step-certctl bats tests

SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$SCRIPT_DIR/bin/step-certctl"

setup_test_env() {
    TEST_DIR="$(mktemp -d)"
    MOCK_BIN="$TEST_DIR/bin"
    CONFIG_DIR="$TEST_DIR/etc/step-certctl"
    CERT_DIR="$TEST_DIR/certs"
    mkdir -p "$MOCK_BIN" "$CONFIG_DIR" "$CERT_DIR"
    export CONFIG_DIR
    export PATH="$MOCK_BIN:$PATH"
}

teardown_test_env() {
    [[ -d "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# Create a simple mock command: make_mock <name> [exit_code] [stdout_line]
make_mock() {
    local name="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    {
        echo "#!/bin/bash"
        [[ -n "$output" ]] && echo "echo $(printf '%q' "$output")"
        echo "exit $exit_code"
    } > "$MOCK_BIN/$name"
    chmod +x "$MOCK_BIN/$name"
}

# Create a mock that appends its arguments to $TEST_DIR/<name>.calls
make_recording_mock() {
    local name="$1"
    local exit_code="${2:-0}"
    local record_file="$TEST_DIR/${name}.calls"
    cat > "$MOCK_BIN/$name" <<EOF
#!/bin/bash
echo "\$*" >> "$record_file"
exit $exit_code
EOF
    chmod +x "$MOCK_BIN/$name"
}

# Write a config file: make_config <name>, read content from stdin
make_config() {
    local name="$1"
    cat > "$CONFIG_DIR/${name}.conf"
}

# Generate a minimal self-signed EC cert+key (fast, ~50ms)
make_cert() {
    local cert_file="$1"
    local key_file="$2"
    local cn="${3:-test.local}"
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
        -keyout "$key_file" -out "$cert_file" \
        -days 365 -nodes -subj "/CN=$cn" 2>/dev/null
}

# Create a step mock that writes $new_cert to --out and $new_key to --key
make_step_renew_mock() {
    local new_cert="$1"
    local new_key="$2"
    local exit_code="${3:-0}"
    cat > "$MOCK_BIN/step" <<EOF
#!/bin/bash
out_file=""
key_file=""
for arg in "\$@"; do
    case "\$arg" in
        --out=*)  out_file="\${arg#--out=}" ;;
        --key=*)  key_file="\${arg#--key=}" ;;
    esac
done
[[ -n "\$out_file" ]] && cp $(printf '%q' "$new_cert") "\$out_file"
[[ -n "\$key_file" ]] && cp $(printf '%q' "$new_key") "\$key_file"
exit $exit_code
EOF
    chmod +x "$MOCK_BIN/step"
}
