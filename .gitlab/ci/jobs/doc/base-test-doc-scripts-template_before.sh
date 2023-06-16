#!/bin/sh

# Trigger an allowed fail on runner that do not have the tezos tag
# This condition mean this job MUST be run under Tezos namespace
if ! echo "$CI_RUNNER_TAGS" | grep -qe '\btezos\b'; then
    # shellcheck disable=SC3037
    echo -e "\e[33m/.\ This test is skipped on runners lacking the tezos tag\e[0m";
    exit 137;
fi
