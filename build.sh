#!/bin/bash
set -e

GAME_PATH=""
KARL2D_PATH="./karl2d"
OUT="./bin/desktop/cvcatcher"

mkdir -p "$(dirname "$OUT")"
odin build ./src -out:$OUT -debug -vet
$OUT
