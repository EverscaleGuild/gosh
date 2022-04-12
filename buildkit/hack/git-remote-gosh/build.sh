#!/usr/bin/env bash

PROJECT_ROOT=$(realpath ../../..)
docker buildx build --push -f Dockerfile -t tesmgosh/git-remote-gosh "$PROJECT_ROOT"
