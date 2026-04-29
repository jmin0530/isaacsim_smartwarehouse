# Smartwarehouse Memory Index

Project knowledge base. Add an entry only when a fact has hardened — not for in-progress work (use plans / tasks for that).

## Architecture
- Vision-control split: YOLO inference runs in Docker container (`smartwarehouse-yolo:latest`), ROS control on host. Topics: `/rgb` (Isaac Sim → container), `/yolo_labeled` (container → host visualization). DDS shared via `--network host`. See `docs/decisions/README.md` ADR-002.
- `main_controller` does **not** consume YOLO output for control logic (target poses are phase-hardcoded). Closing the loop is Roadmap Phase 2.

## Hard rules surface area
- Project Tier 0 #1 (motion limits), #2 (sim/real gating), #3 (config-driven paths), #4 (YOLO weights versioning).
- Project verifier: `.claude/agents/robot-safety-verifier.md` — static checks for #1, #2, #3, #4.
- Global Tier 0 (no secrets, no LLM API, seed fixed, no AI attribution) inherited from `~/.claude/rules/ai-constitution.md`.

## Verified state (2026-04-29)
- Docker build OK on RTX 4090 / driver 580.126.09 / CUDA 13 (forward-compat).
- Image `smartwarehouse-yolo:latest`: 15.3 GB.
- numpy 2.2.6 + torch 2.11.0+cu130 + ultralytics 8.4.42 + rclpy: import + dummy inference OK.
- **Live ROS round-trip VERIFIED** (Isaac Sim → /rgb → container → YOLO → /yolo_labeled → host). Sustained ~4.4 fps for 181 frames in 41s. See ADR-003.
- DDS configuration: container uses CycloneDDS (`rmw_cyclonedds_cpp`), Isaac Sim uses FastDDS — cross-vendor interop confirmed working.

## Container DDS configuration (do not change without re-verifying)
- `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` in Dockerfile ENV + run.sh `-e` (belt+suspenders).
- `--ipc host` for SHM segment access; `--network host` for DDS discovery.
- `entrypoint.sh` MUST run python as bash child (no `exec`) — PID 1 Python breaks rclpy callback dispatch.
- Subscriber QoS: BEST_EFFORT (matches Isaac Sim Replicator publisher's RELIABLE via downgrade).
- Use `rclpy.spin_once` loop, NOT `rclpy.spin(node)` — the latter doesn't dispatch callbacks in this stack.

## Known sharp edges
- Image is 15.3 GB because torch 2.11 bundles full CUDA 13 over base image's CUDA 12.4. Optimization (`base` → `runtime` swap) is on the backlog, not blocking.
- `pose.yaml` expected keys: `Pick`, `Place`, `Home`, `Waypoint`. `action_build()` will SyntaxError if missing.
- `main_controller.py:91` has `time.sleep(2)` after `home` for Isaac Sim camera warmup; removing it without sync replacement risks pre-detection pick attempts.
- `numpy<2` pin in original Dockerfile was a 2024-era workaround; removed 2026-04-29 because modern ultralytics + torch officially support numpy 2.x.
- Bash-as-PID-1 means `docker stop` SIGTERM does NOT reach Python; bash stays alive, Python gets SIGKILL after 10s grace. Acceptable for stateless YoloNode. If graceful shutdown needed → switch to `tini` / `dumb-init` (ADR-003 consequences).
- `ros2 topic hz` CLI does not accept `--qos-reliability` flag. Use `ros2 topic echo --qos-reliability best_effort` to verify topic flow when QoS handshake is suspect.

## External references
- README.md — Tech stack, Change Log, install/run instructions
- docs/TROUBLESHOOTING.md — known integration issues
- docs/ENVIRONMENTBUILD.md — Isaac Sim + ROS environment construction
- docs/decisions/README.md — ADRs (ADR-001 stack, ADR-002 vision-control split, ADR-003 container DDS config)
- docs/DEVELOPMENT_ROADMAP.md — Phase 1 / 2 / 3 + backlog
