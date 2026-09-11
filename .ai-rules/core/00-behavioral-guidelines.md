# 00 - Behavioral Guidelines (Core - Always Load)

These rules govern the AI's internal reasoning and every code edit. They are non-negotiable.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before writing code, proposing architecture, or making any decision:

- Explicitly state all assumptions.
- If uncertain or multiple valid interpretations exist, present them clearly and ask for resolution. Never silently choose one.
- If a simpler approach exists that meets the stated requirements, recommend it and explain the tradeoffs.
- If anything is unclear or ambiguous, **stop**. Name the exact point of confusion and ask targeted questions.

**When to apply most rigorously**: Specify, Clarify, and Plan phases. Also before starting any implementation task.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- Implement *only* what is explicitly required by the current task/acceptance criteria.
- No abstractions, base classes, interfaces, configuration systems, or "future-proofing" unless the spec or tasks explicitly demand them.
- No error handling or defensive code for scenarios the requirements do not cover.
- If the solution can be 50 lines instead of 200, rewrite it. Ask: *"Would a senior engineer call this overcomplicated for the stated requirements?"* If yes, simplify.

**When to apply most rigorously**: Plan phase (avoid over-design) and Implement phase (write only the necessary code).

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When modifying existing code:

- Change **only** the files and sections directly required by the current task.
- Never refactor, reformat, rename, or "improve" adjacent code, comments, or style for its own sake.
- Match the existing coding style exactly (even if you would do it differently).
- If you discover pre-existing dead code, duplication, or issues unrelated to your change, **mention it** in the task notes or review but **do not touch it**.

When your changes make something unused:

- Remove only the imports/variables/functions *your changes* rendered dead.
- Leave all pre-existing dead code untouched.

**Test for compliance**: Every changed line must be directly traceable to a line in the current feature's `tasks.md` or acceptance criteria (or to a specific project hard rule / `.ai-rules` reference file).

**When to apply most rigorously**: Implement phase and any subsequent fixes.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Never treat a task as "done" because "it works" or "I think it's complete."

For every task:

- Convert it into **verifiable success criteria** before starting work.
  - Bad: "Add input validation"
  - Good: "Write unit tests covering all invalid cases listed in the spec. Implement code until all new tests pass and existing tests still pass."
- For bug fixes: First write a test that reproduces the exact bug, then make it pass.
- For any change: Ensure relevant tests/linting/type-checking pass **before and after**.

For multi-step work, always publish a brief plan with verification steps:

```text
1. [Specific action] -> Verify: [exact command or observable outcome]
2. [Specific action] -> Verify: [exact command or observable outcome]
```

Use this format in `plan.md` and `tasks.md`. During implementation, self-verify against the criteria before marking a task complete.

**When to apply most rigorously**: Plan, Tasks, Implement, and QA/Security/Review phases.

### Verification Gate (evidence before claims)

Never claim completion without fresh verification evidence. Every claim must be proven by a command in the same turn.

| Claim | Requires (fresh run) | Not sufficient |
|-------|----------------------|----------------|
| Tests pass | `dotnet test` — 0 failures | Previous run, "should pass" |
| Build succeeds | `dotnet build` — exit 0 | Linter passing, "looks good" |
| Bug fixed | Reproduce test: RED -> GREEN | Code changed, assumed fixed |

Forbidden: `should`, `probably`, `seems to pass`. Run the command, read exit code, then claim.

### TDD Iron Law

`NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.` Write the test, watch it fail correctly, then write minimal code to pass. Code written before its test must be deleted and rewritten from the test.

### Debugging Discipline

Bug fix = `Reproduce -> Root cause -> Fix -> Verify`. No fixes without root-cause investigation first. Reproduce with a failing test before touching production code.
