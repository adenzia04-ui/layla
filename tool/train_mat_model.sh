#!/bin/bash
# Trains the prayer-mat classifier. See training/README.md.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift "$ROOT/tool/train_mat_model.swift" "$ROOT"
