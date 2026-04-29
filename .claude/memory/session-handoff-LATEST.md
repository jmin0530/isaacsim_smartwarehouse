# Session Handoff — LATEST

> SessionStart hook reads this file. Update at session checkpoint, never archive completed items.

## Next Actions (priority order)

1. **Commit current uncommitted changes** — explicit user authorization required before commit. AI attribution forbidden in commit message (Hard Rule). Example:
   ```bash
   cd /home/rokey/Smartwarehouse
   git status
   # User-authored commit message, no Co-Authored-By
   ```
2. **Investigate detections=0 issue** — pipeline works (181 frames at ~4.4 fps), but YOLO finds 0 objects in every frame. Likely Isaac Sim camera view doesn't contain clock/lemon/dice, OR confidence threshold mismatch. Check: camera FOV in Isaac Sim, object positions in `smartwarehouse.usd`, default ultralytics conf threshold (0.25).
3. **Roadmap Phase 2** — close YOLO → control loop. Steps in `docs/DEVELOPMENT_ROADMAP.md` Phase 2-1 through 2-4. Define detection result topic schema (custom msg with class, confidence, world-frame pose), `main_controller` subscribes instead of phase-hardcoded targets.

## Current Work State

- **Container running** — `smartwarehouse-yolo:latest` started at session checkpoint, will keep running until user stops it. ID changes per restart; check `sg docker -c 'docker ps'`. Logs at `/tmp/claude-1000/.../tasks/b8yss2ivg.output`. Stop with `sg docker -c 'docker ps -q --filter ancestor=smartwarehouse-yolo:latest | xargs -r docker stop'`.
- **Isaac Sim** — assumed still running with `smartwarehouse.usd` open and Play active. If user closes Sim, container will idle (no /rgb).
- No code mid-edit.

## Open Decisions

- **`tini` / `dumb-init` for graceful Python shutdown**: bash-as-PID-1 means SIGTERM doesn't reach Python until SIGKILL grace expires. Acceptable for stateless YoloNode now. Revisit if YoloNode ever needs flush-on-shutdown semantics. (Recorded in ADR-003 consequences.)

## Remaining Issues

- **Detections = 0 across all frames** — see Next Action #2. Pipeline-unrelated.
- **Image size 15.3 GB** — torch 2.11 bundles full CUDA 13 over base image's CUDA 12.4. Backlog item, not blocking.

## Context Notes (needed next session)

### Verified working pipeline (2026-04-29)
- Isaac Sim → `/rgb` (FastDDS publisher, RELIABLE) → container subscriber (CycloneDDS, BEST_EFFORT) → YOLO inference (~4.4 fps, RTX 4090) → `/yolo_labeled` → host (cross-vendor DDS interop OK).
- `ros2 topic echo --once --qos-reliability best_effort /yolo_labeled` from host returns immediately.

### Sharp edges discovered (full detail in ADR-003)
1. **`docker run -it` fails non-TTY contexts** — drop for background/CI runs.
2. **FastDDS SHM transport breaks across container boundary**, even with `--ipc host`. Topic discovery succeeds, data does not flow. → Switch container to CycloneDDS.
3. **rclpy callback dispatch fails when Python is PID 1.** Same code, same RMW, same QoS works as PID 2+. `entrypoint.sh` must NOT use `exec "$@"` — keep bash as PID 1, Python as child. Empirically verified, no upstream issue found.
4. **Container stdout block-buffered without TTY** — set `PYTHONUNBUFFERED=1` to see logs immediately.

### Critical files
- `yolo_dockerfile/Dockerfile` — installs `ros-humble-rmw-cyclonedds-cpp`, sets `ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`
- `yolo_dockerfile/entrypoint.sh` — bash-as-PID-1 (no `exec`)
- `yolo_dockerfile/run.sh` — `--ipc host`, no `-it` on `run`, env vars for RMW + YOLO_WEIGHTS + PYTHONUNBUFFERED
- `smartwarehouse/yolo.py` — SENSOR_QOS (BEST_EFFORT), spin_once loop (NOT `rclpy.spin`), debug frame logging at frame 1/2/3 + every 30
- `docs/decisions/README.md` — ADR-001 (stack), ADR-002 (vision-control split), ADR-003 (DDS config)

### Dead ends (do not retry)
- `--ipc host` alone with FastDDS in container — does NOT fix data flow.
- `rclpy.spin(node)` blocking call when Python is PID 1 — never dispatches `/rgb` callback. Use spin_once loop.
- Forcing `numpy<2` in Dockerfile via separate `pip install` line — gets overridden by ultralytics dependency resolution in next pip line. Modern stack supports numpy 2.x; the pin was a 2024 workaround.

## Current Focus

- **Top priority**: commit checkpoint or proceed to Roadmap Phase 2.
- **Friction**: none active. All session blockers resolved.
