#!/usr/bin/env bash
# Remaps right command to alt-gr/Option/Meta
hidutil property --set '{"UserKeyMapping":
  [{"HIDKeyboardModifierMappingSrc":0x7000000e7,
    "HIDKeyboardModifierMappingDst":0x7000000e6}]
}'
