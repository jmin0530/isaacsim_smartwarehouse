#!/usr/bin/env bash
# Build and run the YOLO detection container.
# Subscribes /rgb, publishes /yolo_labeled. Uses --network host so DDS
# discovery shares the host's loopback with main_controller and Isaac Sim.
#
# Usage:
#   ./run.sh build        # build image
#   ./run.sh run          # run detector (default)
#   ./run.sh shell        # interactive bash inside container

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-smartwarehouse-yolo:latest}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
WEIGHTS_PATH="${WEIGHTS_PATH:-${REPO_ROOT}/best.pt}"

cmd="${1:-run}"

case "$cmd" in
    build)
        docker build -t "$IMAGE_NAME" "${REPO_ROOT}/yolo_dockerfile"
        ;;
    run)
        if [ ! -f "$WEIGHTS_PATH" ]; then
            echo "Error: weights not found at $WEIGHTS_PATH" >&2
            exit 1
        fi
        # No -it: allow non-TTY invocation (background runs, CI). Use shell subcommand for interactive.
        docker run --rm \
            --network host \
            --ipc host \
            --gpus all \
            -e ROS_DOMAIN_ID="$ROS_DOMAIN_ID" \
            -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
            -e YOLO_WEIGHTS=/weights/best.pt \
            -e PYTHONPATH=/workspace \
            -e PYTHONUNBUFFERED=1 \
            -v "$WEIGHTS_PATH:/weights/best.pt:ro" \
            -v "${REPO_ROOT}/smartwarehouse:/workspace/smartwarehouse:ro" \
            "$IMAGE_NAME" \
            python3 -m smartwarehouse.yolo
        ;;
    shell)
        docker run --rm -it \
            --network host \
            --gpus all \
            -e ROS_DOMAIN_ID="$ROS_DOMAIN_ID" \
            -e YOLO_WEIGHTS=/weights/best.pt \
            -e PYTHONPATH=/workspace \
            -v "$WEIGHTS_PATH:/weights/best.pt:ro" \
            -v "${REPO_ROOT}/smartwarehouse:/workspace/smartwarehouse:ro" \
            "$IMAGE_NAME" \
            bash
        ;;
    *)
        echo "Usage: $0 [build|run|shell]" >&2
        exit 1
        ;;
esac
