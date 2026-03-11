#!/usr/bin/env bats
# Tests for CLI argument routing and input validation

load helpers/common

SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/step-certctl"

@test "no arguments: exits 1 and shows usage" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "unknown command: exits 1 with error message" {
    run "$SCRIPT" foobar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "issue without name: exits 1" {
    run "$SCRIPT" issue
    [ "$status" -eq 1 ]
}

@test "renew without name: exits 1" {
    run "$SCRIPT" renew
    [ "$status" -eq 1 ]
}

@test "validate without name: exits 1" {
    run "$SCRIPT" validate
    [ "$status" -eq 1 ]
}

@test "install-timer without name: exits 1" {
    run "$SCRIPT" install-timer
    [ "$status" -eq 1 ]
}

@test "remove-timer without name: exits 1" {
    run "$SCRIPT" remove-timer
    [ "$status" -eq 1 ]
}

@test "version: exits 0 and prints version number" {
    run "$SCRIPT" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.1.1"* ]]
}

@test "--help: exits 0 and shows usage" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "help: exits 0 and shows usage" {
    run "$SCRIPT" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
