---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Red-Green-Refactor

```dot
digraph tdd_cycle {
    rankdir=LR;
    red [label="RED\nWrite failing test", shape=box, style=filled, fillcolor="#ffcccc"];
    verify_red [label="Verify fails\ncorrectly", shape=diamond];
    green [label="GREEN\nMinimal code", shape=box, style=filled, fillcolor="#ccffcc"];
    verify_green [label="Verify passes\nAll green", shape=diamond];
    refactor [label="REFACTOR\nClean up", shape=box, style=filled, fillcolor="#ccccff"];
    next [label="Next", shape=ellipse];

    red -> verify_red;
    verify_red -> green [label="yes"];
    verify_red -> red [label="wrong\nfailure"];
    green -> verify_green;
    verify_green -> refactor [label="yes"];
    verify_green -> green [label="no"];
    refactor -> verify_green [label="stay\ngreen"];
    verify_green -> next;
    next -> red;
}
```

### RED - Write Failing Test

Write one minimal test showing what should happen.

<Good>
```swift
@Test func completingTaskMarksItCompleted() {
    let state = reduce([.taskCreated(id: taskID, title: "Buy milk"), .taskCompleted(id: taskID)])
    #expect(state.tasks[taskID]?.isCompleted == true)
}
```
Clear name, tests real behavior, one thing.
</Good>

<Bad>
```swift
@Test func test1() {
    let store = MockStore()
    store.stubbedState = AppState(completed: [taskID])
    _ = store.load()
    #expect(store.loadCallCount == 1)
}
```
Vague name, tests mock not code.
</Bad>

**Requirements:**
- One behavior per test
- Clear name describing expected behavior: a sentence in camelCase, e.g. `deferredTaskIsUnavailableBeforeDeferDate`
- Real code (no mocks; use in-memory fakes only at boundaries such as Dropbox)

### Verify RED - Watch It Fail

**MANDATORY. Never skip.**

```bash
swift test --filter completingTaskMarksItCompleted
```

Confirm:
- Test fails (not a compile error)
- Failure message is what you expect
- Fails because the feature is missing, not due to typos

**Test passes?** You're testing existing behavior. Fix the test.

**Test won't compile?** Fix the error, re-run until it fails correctly.

### GREEN - Minimal Code

Write the simplest code that makes the test pass.

<Good>
```swift
case .taskCompleted(let id):
    state.tasks[id]?.isCompleted = true
```
Just enough to pass.
</Good>

<Bad>
```swift
case .taskCompleted(let id):
    // also complete subtasks, advance sequential project, schedule repeat...
```
Over-engineered before there are tests for those cases.
</Bad>

Don't add features, refactor other code, or "improve" beyond what the failing test needs.

### Verify GREEN - Watch It Pass

**MANDATORY.**

```bash
swift test
```

Confirm:
- The target test passes
- All other tests still pass
- Output is pristine (no errors, warnings)

**Test fails?** Fix the code, not the test.

**Other tests fail?** Fix them now.

### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers

Keep tests green throughout. Don't add new behavior.

### Repeat

Next failing test for the next behavior.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One behavior. "and" in name? Split it. | `completeTaskAndAdvanceProjectAndUpdateReview` |
| **Clear** | Name describes expected behavior | `testReducer`, `test1` |
| **Real** | Tests production code paths | Tests mock return values |

## Why Order Matters

**"I'll write tests after to verify it works"**

Tests written after code pass immediately. Passing immediately proves nothing:
- Might test the wrong thing
- Might test implementation, not behavior
- Might miss edge cases you forgot
- You never saw it catch the bug

Test-first forces you to see the test fail, proving it actually tests something.

**"Deleting X hours of work is wasteful"**

Sunk cost fallacy. The time is already gone:
- Delete and rewrite with TDD (X more hours, high confidence)
- Keep it and add tests after (30 min, low confidence, likely bugs)

The "waste" is keeping code you can't trust.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Need to explore first" | Fine. Throw away the exploration, start with TDD. |
| "Test is hard to write" | Listen to it. Hard to test = hard to use. Simplify the design. |
| "TDD will slow me down" | TDD is faster than debugging. Pragmatic = test-first. |
| "Existing code has no tests" | You're improving it. Add tests for what you touch. |

## Red Flags — STOP and Start Over

- Code written before the test
- Test added after implementation
- Test passes immediately without any implementation
- Can't explain why the test failed
- "I'll add tests later"
- Rationalizing "just this once"

**All of these mean: delete the code, start over with TDD.**

## Example: Bug Fix

**Bug:** Completing an already-completed task (a duplicate event from sync) changes its completion date.

**RED**
```swift
@Test func duplicateCompletionKeepsFirstCompletionDate() {
    let state = reduce([created, completed(at: monday), completed(at: tuesday)])
    #expect(state.tasks[taskID]?.completedAt == monday)
}
```

**Verify RED**
```bash
$ swift test --filter duplicateCompletionKeepsFirstCompletionDate
✘ Expectation failed: (state.tasks[taskID]?.completedAt → tuesday) == (monday → monday)
```

**GREEN**
```swift
case .taskCompleted(let id, let at):
    guard state.tasks[id]?.completedAt == nil else { break }
    state.tasks[id]?.completedAt = at
```

**Verify GREEN**
```bash
$ swift test
✔ Test duplicateCompletionKeepsFirstCompletionDate() passed
```

**REFACTOR** — extract an idempotency guard if other events need it.

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason (feature missing, not import error)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass: `swift test`
- [ ] Full QA passes: `make check-ci` (once the Makefile exists)

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the wished-for function call first. Write the assertion. Ask your human partner. |
| Test too complicated | Design too complicated. Simplify the interface. |
| Must mock everything | Code too coupled. Inject dependencies or extract a protocol. |
| Test setup is huge | Extract event builders to the test support target. Still complex? Simplify the design. |

## Final Rule

```
Production code → a test exists that failed before this code was written
Otherwise → not TDD
```

No exceptions without your human partner's permission.
