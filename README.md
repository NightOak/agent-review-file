# Single-Agent Coding Policy Test

This is a standalone, project-agnostic test package for one agent performing an engineering task from clarification through final validation.

`INSTRUCTIONS.md` is the mandatory agent entrypoint and directs the agent to load and follow the standing policy before project work begins.

## Load order

1. `INSTRUCTIONS.md`
2. `AGENT-POLICY.md`
3. `TASK-TEMPLATE.md`
4. `TEST-ACCEPTANCE.md` when evaluating behavior

## Intended behavior

The agent should:

- use a fast path when the task is already sufficiently specified;
- clarify only material ambiguity before committing to implementation;
- read the minimum authoritative state needed;
- treat existing accepted behavior as the baseline;
- plan and implement the smallest coherent change sequence;
- preserve architecture and interface boundaries;
- keep browser-visible code, logs, and large payloads small;
- use task-specific execution-backend restrictions only when relevant;
- apply fail-closed security behavior when required invariants cannot be proven;
- validate proportionately while work is in progress;
- continue through safe batches without repeatedly asking the user to say `continue`;
- run build, integration, promotion, and readback gates only when applicable;
- stop for material ambiguity, required authorization, a blocker, or completion;
- perform final validation on the exact final state before declaring completion.

## Default implementation and runner model

Substantive implementation is Rust-first. Existing accepted non-Rust code is not rewritten merely to change languages; new substantive components should prefer Rust when practical. Bash is reserved for thin launchers/bootstrap glue, and Python is prohibited by default unless the user explicitly approves a narrowly scoped exception.

For Termux commands, prefer a tiny stable runner installed in an existing PATH directory (normally `$PREFIX/bin`). The runner fetches and verifies the authoritative master artifact, preferably a compiled Rust binary, then executes it. Ordinary master releases should not require runner changes, and the runner must not self-update during normal operation.

## Using the template

Fill only the sections relevant to the project. The **Required** section is intentionally short. Optional/Advanced sections should be omitted when they do not apply.

`TASK-TEMPLATE.md` is deliberately generic. Rust-first, minimal Bash, and zero-Python-by-default are standing defaults; project-specific overrides, platforms, storage systems, runner details, build targets, execution-backend restrictions, and security invariants belong in the task instance.

## Testing cadence

Use the Core scenarios in `TEST-ACCEPTANCE.md` during normal policy iteration. Use the Extended scenarios before treating a revised policy as a stable baseline or when changing security-sensitive rules.

## Package integrity

`SHA256SUMS.txt` is for packaged/release integrity. It does not need to be regenerated after every draft edit; regenerate it when producing a new test package or stable candidate.

## Scope

This package is intentionally standalone. It contains no multi-agent routing, numbered-project workflow, or project-specific implementation requirements.
