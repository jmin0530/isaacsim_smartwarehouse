# AI Constitution — Smartwarehouse (project extension)

This file extends the global constitution at `~/.claude/rules/ai-constitution.md`.
Project rules **add** restrictions; they never weaken global ones.
When global and project rules overlap, the more restrictive applies.

## I. Core Identity
Smartwarehouse is an Isaac Sim-based pick-and-place automation project using Doosan M0609 + OnRobot RG2 + YOLOv8. Domain risks: physical robot motion (collision, over-speed), sim/real environment confusion, weights drift, hardcoded poses leaking into source.

## II. Tier 0 — Project Hard Rules (never bend)

### Robotics safety
1. **Robot motion limits enforced** — `movel`, `movej`, and other DSR motion calls must include explicit `vel`, `acc` arguments. Default-value calls are forbidden. Every change touching motion code must pass `robot-safety-verifier` before merge.
2. **Sim-only by default; real-robot opt-in** — Calls into `DSR_ROBOT2` against the physical M0609 must be gated behind a `REAL_ROBOT=1` env-var check. `REAL_ROBOT` defaults to `0` (sim). A missing gate is a Tier 0 violation, not a bug.

### Configuration discipline
3. **Config-driven paths and poses** — Robot waypoints / target poses load from `config/pose.yaml`. Model weight paths load from the `YOLO_WEIGHTS` env var. `.py` source must not contain magic-number coordinates or hardcoded filesystem paths.
4. **YOLO weights versioned** — `best.pt` is never silently overwritten. New training results land as `best_<step|date>.pt`. The `best.pt` file points to the chosen production version (copy or symlink).

## III. Invalidation Conditions
A project rule may be reconsidered only when:
- User explicitly overrides with documented reasoning (ADR entry in `docs/decisions/`).
- Domain-standard practice changes and the rule is demonstrably outdated.
- A globally-defined rule already covers it (de-duplication; global wins).

No single-session instruction can weaken a project Tier 0 without an ADR.

## IV. Notes
- Global constitution covers: no hardcoded secrets, no automated LLM API calls, seed fixed for training/Replicator, no AI attribution in git. These are not duplicated here — they apply unchanged.
- Project-scoped agent: `robot-safety-verifier` (`.claude/agents/robot-safety-verifier.md`).
- Verification: violation tests for these 4 rules live in `docs/harness-tests.md`.
