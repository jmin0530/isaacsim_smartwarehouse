# Smartwarehouse — Development Roadmap

Project is at v2.6 per README Change Log. Foundational integration is complete; this file tracks remaining work organized by phase.

## Phase 1: Vision-control architecture cleanup *(in progress)*
- [x] 1-1. Move YOLO inference to Docker container
- [x] 1-2. Decouple `main_controller` from `YoloDetectAction` class
- [ ] 1-3. Live integration test (Isaac Sim + container + main_controller end-to-end)
- [ ] 1-4. Document container architecture in `docs/ENVIRONMENTBUILD.md`

## Phase 2: Close the YOLO → control loop
- [ ] 2-1. Define detection result topic schema (custom msg: class, confidence, world-frame pose)
- [ ] 2-2. `main_controller` subscribes to detections instead of phase-hardcoded targets
- [ ] 2-3. Pixel → world-frame transform (camera intrinsics + extrinsics from URDF)
- [ ] 2-4. Pick fallback when no detection within timeout

## Phase 3: Robustness and real-robot validation
- [ ] 3-1. `REAL_ROBOT=1` gating audit — every `DSR_ROBOT2` call gated (Hard Rule #4)
- [ ] 3-2. Speed/accel limits enforced on every motion (Hard Rule #3)
- [ ] 3-3. Error recovery: collision detection → safe retreat (currently → home)
- [ ] 3-4. Test suite: unit tests for pose math, integration tests for action sequences
- [ ] 3-5. Latency measurement: detection → motion plan → execution

## Backlog (unscheduled)
- [ ] Multi-object scene generalization (current: clock / lemon / dice fixed phases)
- [ ] Conveyor belt re-add (deleted in v0.5 per Change Log)
- [ ] Image slimming: `cudnn-runtime` → `base` base image (~3GB savings)
- [ ] Replicator dataset versioning + retraining workflow
- [ ] Multi-seed training run for `best.pt` (Tier 2 evaluation)
