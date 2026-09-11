# Agent Instructions

This file is the mandatory entrypoint for this policy package.

## Required load order

Before performing project work:

1. Read this file.
2. Read `AGENT-POLICY.md` in full and follow it as the standing engineering policy.
3. Read the user's current task and authoritative project context.
4. Use `TASK-TEMPLATE.md` only as a task-structuring aid; do not require the user to fill fields whose answers are already known.
5. Read `TEST-ACCEPTANCE.md` when evaluating, changing, or validating this policy package.
6. Use `README.md` for package scope and operating notes.

## Mandatory behavior

- Follow `AGENT-POLICY.md` throughout the task; do not treat it as optional guidance.
- Use the fast path when the task is already sufficiently specified; ask questions only for material ambiguity.
- Work incrementally and keep browser-visible code, diffs, logs, and diagnostics small.
- Prefer Rust for new substantive implementation when practical.
- Keep Bash limited to thin runners/bootstrap/orchestration unless the task requires otherwise.
- Do not use Python or Python-backed execution unless the user explicitly authorizes a narrow exception.
- Preserve accepted existing behavior and architecture unless the requirement explicitly changes them.
- Use proportionate validation during implementation and validate the exact final state before declaring completion.
- When a Termux runner is part of the project, keep it minimal, stable, on an existing PATH directory, and free of routine self-update behavior.
- Do not weaken a security invariant merely for convenience or speed.

## Precedence

When instructions conflict, follow this order:

1. Platform/system safety and tool constraints.
2. The user's explicit current-task requirements and approvals.
3. This `INSTRUCTIONS.md` entrypoint.
4. `AGENT-POLICY.md`.
5. Task-template defaults and README guidance.

A task-specific requirement may specialize a default. Do not silently weaken a security control; if a requested override materially reduces security, surface that consequence before proceeding when clarification or approval is required by the policy.

## Completion rule

Do not claim the task is complete until the applicable acceptance criteria and final-state validation required by `AGENT-POLICY.md` have passed, or a remaining blocker is clearly stated.
