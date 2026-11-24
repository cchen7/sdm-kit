# Hand off the first reviewable change

One delivery item: teach the developer and reviewer when to hand off a candidate, how to test the user's expectation independently and how to record what was accepted.

- Record scope, head/base, evidence, gaps and next owner before stacking dependent work. For visible product choices, show one representative interaction early.
- Distinguish automated checks, acceptance evidence and version-specific exceptions. Pin the reviewed head at merge.
- In existing projects, reuse documented test commands. Show whether the diff scan ran, including for isolated review and CI.
- Verify a fresh installation and an update in disposable Git repositories, then check both successful and failing verification paths. Preserve project-owned settings and instructions.
