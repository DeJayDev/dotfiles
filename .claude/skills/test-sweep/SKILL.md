---
name: test-sweep
argument-hint: [context]
description: Remove unit tests that call internal helpers already covered through the public function, and un-export helpers exported only for tests. Use for /test-sweep or when the user asks to stop testing internals.
---

Sweep the tests in scope: <context>$ARGUMENTS</context>. If the scope isn't clear from that and this session's work, stop and ask for clarification.

In those tests, remove any test case that calls an internal helper directly when a test of the public function that calls it will already test for the same behavior. A helper is internal when all of its callers are in its own module or feature folder. Before you delete a test, find the covering test so you know the behavior is still tested.

If no covering test exists, don't delete the helper test. Rewrite it to go through the public function, so the behavior stays tested without reaching into the helper. Once a helper has no direct tests left, check whether it was exported just for them: grep the whole repo, including scripts. A re-export only counts if non-test code imports through it. If nothing outside tests references it, remove the export.

Tests of real public APIs and shared utilities stay. Change nothing outside these tests and exports. Run a typecheck and the newly modified tests, then report what you deleted, rewrote, or un-exported to the user and how many lines of code it saves.
