#!/usr/bin/env bash
# Note: do NOT use `exec "$@"` — when python becomes PID 1, rclpy callback dispatch
# fails to receive ROS messages despite subscriptions being registered. Running as
# a child process of bash works correctly. (Verified 2026-04-29.)
set -e
source /opt/ros/humble/setup.bash
"$@"
