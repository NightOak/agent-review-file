# Single-Agent Task Template

Use this with `AGENT-POLICY.md`.

Fill only the fields that matter. Omit optional sections that do not apply.

## Required

### Objective

[STATE THE DESIRED FINAL OUTCOME]

### Scope

[IDENTIFY THE COMPONENTS OR BEHAVIOR IN SCOPE]

### Source of truth

- authoritative source/location: [SOURCE OF TRUTH]
- current accepted files/components: [FILES OR COMPONENTS, IF KNOWN]
- existing behavior to preserve: [BEHAVIORAL BASELINE, IF KNOWN]

### Constraints

Defaults unless explicitly overridden:

- substantive implementation language: Rust
- existing non-Rust code: preserve unless a language migration is explicitly required; use Rust for new substantive components when practical
- thin runner/bootstrap language: Bash/native shell only when needed
- Python: prohibited by default; explicit exception required
- compatibility/interface requirement: [REQUIREMENT]
- explicitly out-of-scope areas: [AREAS]
- response/output constraint: compact browser output; large artifacts saved as files

### Acceptance criteria

- [OBSERVABLE REQUIREMENT 1]
- [OBSERVABLE REQUIREMENT 2]
- [REQUIRED SECURITY INVARIANT, IF ANY]
- [REQUIRED VALIDATION]

### Authorization boundaries

State only the categories relevant to the task:

- destructive changes: [yes/no]
- privileged operations: [yes/no]
- production changes: [yes/no]
- credential changes: [yes/no]
- deployment/release/promotion: [yes/no]

If a sensitive authorization category is relevant but omitted, do not infer authorization.

## Optional / Advanced

### Environment

- operating/runtime environment: [ENVIRONMENT]
- architecture/target: [TARGET]
- available tools: [TOOLS]
- privilege level: [PRIVILEGE]
- relevant paths: [PATHS]

### Stable Termux runner

Use when the project exposes a Termux command.

- command name: [COMMAND]
- PATH installation directory: [`$PREFIX/bin` OR OTHER EXISTING PATH DIRECTORY]
- authoritative master artifact/manifest location: [LOCATION]
- preferred master artifact: compiled Rust binary
- authenticity mechanism: [SIGNED MANIFEST / PINNED TRUST ROOT / APPROVED EQUIVALENT]
- integrity mechanism: SHA-256
- runner responsibility: fetch -> authenticate/verify -> stage safely -> execute

The runner should be stable across normal master releases and must not self-update during normal execution. Do not put project logic, version-specific behavior, or complex validation in it.

### Project-specific security invariants

List only requirements specific to this project. The standing policy already covers generic secure engineering behavior.

- [SECURITY INVARIANT]
- [FAIL-CLOSED CONDITION]
- [POST-CONDITION OR IDENTITY CHECK]

### Architecture boundaries

- [COMPONENT] -> [RESPONSIBILITY]
- [COMPONENT] -> [RESPONSIBILITY]
- interfaces that must remain stable: [INTERFACE/COMMAND/API/WORKFLOW]

### Explicit exclusions

- [WHAT MUST NOT BE CHANGED]
- [DIRECTORIES/COMPONENTS OUT OF SCOPE]
- [PROHIBITED FALLBACKS OR BEHAVIORS]

### Execution-backend restrictions

Use only when the task has special backend restrictions.

- allowed backend/tool: native container/shell unless otherwise specified
- prohibited backend/tool/intermediary: Python-backed execution by default

If omitted, use the normal approved native execution environment.

### Build and distribution

Use only when the project produces or promotes a build artifact.

- toolchain/version: [RUST TOOLCHAIN OR OTHER APPROVED TOOLCHAIN]
- build target: [TARGET]
- build command: [COMMAND OR TO-BE-DERIVED]
- artifact shape: [PREFER SINGLE RUST BINARY WHEN APPROPRIATE]
- runtime dependency constraint: [CONSTRAINT]
- integrity/hash requirement: SHA-256 or stronger project requirement
- promotion location: [LOCATION]

### Required tests

List only tests relevant to the actual change.

- [BASELINE/HAPPY-PATH TEST]
- [FAILURE/EDGE-CASE TEST]
- [SECURITY TEST, IF APPLICABLE]
- [INTEGRATION OR MOCKED E2E TEST, IF APPLICABLE]

### Normal operational flow after completion

[DESCRIBE THE STABLE DAY-TO-DAY USER OR SYSTEM FLOW]

For a Termux runner pattern, the preferred flow is:

`user command -> stable PATH runner -> fetch/verify authoritative master artifact -> execute verified Rust implementation`

### Current subtask

[PASTE ONLY THE CURRENT SUBTASK HERE WHEN RESUMING A LARGE PROJECT]

## Default execution flow

Unless the task requires otherwise:

1. Inspect the minimum authoritative state needed.
2. Establish the behavioral baseline.
3. Plan the smallest compatible change.
4. Implement substantive logic in Rust by default.
5. Keep any runner/bootstrap minimal and stable.
6. Apply proportionate validation as work progresses.
7. Run the required final validation gate.
8. Promote or deploy only when applicable and authorized.
9. Verify promoted authoritative state when applicable.

Do not create build, promotion, deployment, backend, architecture, or security ceremony for a project that does not need it.
