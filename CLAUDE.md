# Smartwarehouse v1.0

Isaac Sim 기반 스마트 물류 창고 시뮬레이션. Doosan M0609 + OnRobot RG2 + YOLOv8로 pick-and-place 자동화.

## Hard Rules (never bend)

Hard Rules → see [.claude/rules/ai-constitution.md](.claude/rules/ai-constitution.md) (project) and [`~/.claude/rules/ai-constitution.md`](~/.claude/rules/ai-constitution.md) (global).

Single source of truth for rules. Do not duplicate them here — to add or modify a rule, edit the constitution files directly.

## Quick Ref

**Workspace** (build from workspace root, not project root):
- Build: `cd ~/IsaacSim-ros_workspaces/humble_ws && colcon build --packages-select smartwarehouse`
- Source: `source ~/IsaacSim-ros_workspaces/humble_ws/install/setup.bash`

**Run** (host):
- DSR control node: `ros2 launch smartwarehouse dsr_bringup.launch.py`
- Main controller: `ros2 run smartwarehouse main`
- Pose finder: `ros2 run smartwarehouse find_pos`
- DSR test: `ros2 run smartwarehouse dsr_test`

**YOLO inference (Docker container)**:
- Build: `./yolo_dockerfile/run.sh build`
- Run: `./yolo_dockerfile/run.sh run`
- Shell: `./yolo_dockerfile/run.sh shell`
- One-time host setup: `./yolo_dockerfile/install_docker.sh`

**Tests**: `pytest test/`

## Secrets Policy
- Never read, print, or log `.env` — use environment variables only.
- Never commit `.env` — `.env.example` is the template (no real values).
- New API keys / robot IPs → add placeholder to `.env.example` + load via env var.

## Dev Conventions
- Tests before merge. Never declare done without a passing test.
- New features: opt-in via env var, default OFF.
- Logs: append-only (never overwrite log/jsonl files).
- YOLO weights: never overwrite `best.pt` — save as `best_<step|date>.pt`.
- Pose / waypoint values: edit `config/pose.yaml`, not Python source.
- Commits: one logical change per commit — independently revertable.
- Commit only when explicitly requested.

## Architecture Notes
- **Vision-control split**: YOLO inference runs in a separate Docker container (CUDA + ultralytics). Communicates with `main_controller` via ROS 2 topics (Isaac Sim → `/rgb` → container → `/yolo_labeled`). DDS shared with host via `--network host`. Decision: `docs/decisions/README.md` ADR-002.
- **Open loop today**: `main_controller.py` does not consume `/yolo_labeled` for control logic — target poses are phase-hardcoded. Closing this loop is Roadmap Phase 2.

## Compact Instructions
Preserve on compaction:
1. Hard Rules
2. Current active branch / uncommitted file list
3. Pending tasks and their status
4. Active errors or bugs being investigated
5. Dev Conventions
6. File paths modified in this session
