# Architecture Decision Records

Decisions that shaped this project. Add an entry whenever you:
add a new dependency, replace an existing pattern, change the data model, or restructure components.

## Template
```markdown
### ADR-NNN: [Decision Title]
**Date**: YYYY-MM-DD
**Context**: 왜 이 결정이 필요한가
**Decision**: 무엇을 선택했는가
**Consequences**: 트레이드오프, 알려진 제약
```

## Decisions

### ADR-001: Initial Stack Decisions
**Date**: 2026-04-29

**Context**: Stack and Hard Rules locked during `/project-init` interview after the project had already reached v2.6.

**Decision**:
- Language: Python 3.10
- Middleware: ROS 2 Humble (ament_python package)
- Robot: Doosan M0609 + OnRobot RG2 (URDF assembled)
- Simulation: Isaac Sim 5.0.0 with custom USD scene (`USD/smartwarehouse.usd`)
- Vision: YOLOv8n weights (`best.pt`) — ultralytics + PyTorch
- No DB; configs in `config/pose.yaml` + USD scene files
- No external LLM API calls (Hard Rule #2)

**Hard Rules** (full list in `CLAUDE.md`):
- Robot safety: explicit speed/accel limits, sim-only by default, real-robot opt-in
- Reproducibility: seeds fixed for training/Replicator; weights versioned, never silently overwritten
- Hygiene: no hardcoded secrets, no AI attribution in git, configs over hardcoding

**Consequences**:
- Hard Rule #4 (`REAL_ROBOT=1` gating) is not yet implemented in source — it is a forward-looking constraint to enforce before first real-robot deployment.
- `config/pose.yaml` already drives waypoint coordinates; Hard Rule #5 codifies the existing convention.

---

### ADR-002: Vision-Control Process Split via Docker
**Date**: 2026-04-29

**Context**:
- Original code coupled YOLO inference inside the `main_controller` Python process — single ament_python package importing `from .yolo import YoloDetectAction`.
- Host environment must satisfy ROS 2 Humble + ultralytics + torch + CUDA simultaneously, which produces fragile dependency trees (e.g. numpy version conflicts observed during the first build).
- `main_controller` does not actually consume YOLO output for target selection — `target_pose` and `target_name` are phase-hardcoded. The vision call only published an annotated image to `/yolo_labeled` for visualization.

**Decision**: Run YOLO detection in a dedicated Docker container with CUDA + ROS 2 Humble + ultralytics. Communicate with the host `main_controller` purely via ROS 2 topics (`/rgb` → container → `/yolo_labeled`). Use `--network host` and shared `ROS_DOMAIN_ID` so DDS discovery is shared with Isaac Sim and the main controller. Container files live in `yolo_dockerfile/`.

**Consequences**:
- (+) Clean dependency isolation: host carries ROS + DSR only; container carries the vision stack.
- (+) Reproducible vision environment via versioned Dockerfile.
- (+) Independent restart of vision vs. control.
- (−) Image size 15.3GB (`torch 2.11` bundles full CUDA 13 libs alongside the base image's CUDA 12.4).
- (−) Build time ~10–15 min first time; ~5 min on incremental changes (pip layer rebuilds).
- (−) `main_controller` no longer blocks on first frame — `time.sleep(2)` added after `home` for camera warmup. Behavior change is invisible because YOLO output was already unused.
- Closing the YOLO → control loop is Roadmap Phase 2 work and will require defining a detection topic schema.

**Verified during decision (2026-04-29)**:
- `nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04` + ROS 2 Humble + ultralytics 8.4.42 builds and runs.
- GPU passthrough works on RTX 4090 / driver 580.126.09 via `nvidia-container-toolkit`.
- `numpy 2.2.6` + `torch 2.11.0+cu130` + ultralytics + rclpy import cleanly inside the container; YOLO inference on a dummy frame succeeds.
- Live ROS topic round-trip verified later — see ADR-003.

---

### ADR-003: Container DDS Configuration for Cross-Boundary ROS 2 Communication
**Date**: 2026-04-29

**Context**:
Initial container built per ADR-002 failed to receive `/rgb` frames from Isaac Sim despite topic discovery succeeding (Subscription count visible from host was correct). Live round-trip verification surfaced four distinct, non-obvious failures that any container-based ROS 2 vision node will hit. Each one in isolation is hard to diagnose because the failure mode is "topic visible, data missing."

**Decision**: Bake all four mitigations into the standard container configuration.

| # | Failure mode | Symptom | Fix |
|---|--------------|---------|-----|
| 1 | `docker run -it` requires TTY | Container exits immediately with "the input device is not a TTY" when launched in background / CI / non-interactive contexts | Drop `-it` from `run` subcommand. Keep on `shell` subcommand for interactive use. |
| 2 | FastDDS shared memory transport breaks across container boundary | Topic discovery succeeds (Subscriber count = 1 visible from publisher side), but no data ever arrives at the subscriber. Affects both small (`/clock`) and large (`/rgb`) messages. `--ipc host` alone does NOT fix it. | Switch container RMW to `rmw_cyclonedds_cpp`. Install `ros-humble-rmw-cyclonedds-cpp` apt package, set `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` in container env. Cross-vendor interop with Isaac Sim's FastDDS publisher works correctly. |
| 3 | **rclpy callback dispatch fails when Python is PID 1** | YoloNode's subscription registers correctly (visible in `ros2 topic info /rgb` from inside container), DDS data arrives in the container (provable: a separate `docker exec`'d Python script with identical code receives 39 frames in 10 seconds), but PID 1 Python's `on_rgb` callback is never invoked. Reproducible across `rclpy.spin()` and `spin_once` loops. | Modify `entrypoint.sh` to NOT use `exec "$@"`. Run the Python process as a child of the bash entrypoint, leaving bash as PID 1. With this change, callbacks dispatch normally. |
| 4 | Container stdout is block-buffered without TTY | Logs appear delayed or never (until 4 KiB accumulates), making debugging the above three issues much harder. | Set `PYTHONUNBUFFERED=1` in container env. |

**Consequences**:
- (+) Verified end-to-end pipeline: Isaac Sim (`/rgb`) → container (CycloneDDS subscriber, BEST_EFFORT QoS) → YOLO inference (~4.4 fps on RTX 4090, 720×1280) → `/yolo_labeled` → host (CycloneDDS-FastDDS cross-vendor interop).
- (+) Each fix is documented with a verified failure mode reproduction; future regressions can be diagnosed quickly.
- (−) Cross-vendor DDS (FastDDS publisher ↔ CycloneDDS subscriber) is officially supported but adds one more "what's different" axis if some future message type fails.
- (−) Bash-as-PID-1 means bash receives `SIGTERM` from `docker stop`. Bash does not forward signals to Python by default — Python gets `SIGKILL` after the 10-second grace period. Acceptable for a stateless inference loop but should be revisited if YoloNode ever holds resources requiring graceful shutdown (e.g., flushing a metrics buffer). Mitigation if needed: use `tini` or `dumb-init` as PID 1.
- The PID-1 rclpy issue is **not** documented in upstream ROS 2 Humble or rclpy issues we found. Treat as project-local discovery; revisit if Iron / Jazzy releases or future rclpy fixes change behavior.

**Verified after decision (2026-04-29)**:
- Live round-trip: 181 frames processed continuously over 41 seconds without drop.
- Host receives `/yolo_labeled` messages on demand (`ros2 topic echo --once --qos-reliability best_effort /yolo_labeled` returns immediately).
- Detections = 0 across all frames in this test, but this is unrelated — it reflects the Isaac Sim camera view contents, not the pipeline.
