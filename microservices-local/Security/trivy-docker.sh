#!/bin/bash
# Trivy Docker wrapper script for Windows
# Convert Windows path to Docker-compatible format
WORKSPACE_PATH=$(pwd | sed 's|^/c/|c:/|')
docker run --rm -v "${WORKSPACE_PATH}:/workspace" aquasec/trivy:latest "$@"
