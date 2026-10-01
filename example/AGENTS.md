# Example working notes

Read `RESTART_HANDOFF.md` first, then `CHATGPT_CONTEXT.md`, `MEMORY.md`, and
`ALIGNMENT_PLAN.md` before working on React Native parity. Update context when stable facts change, memory after each
meaningful investigation or implementation session, and plan checkboxes after
verified milestones. Record validation and unresolved issues; distinguish source
changes, packaged artifacts, resolved dependencies, and device-tested behavior.

Preserve existing user changes. For routine React Native parity, native
implementation repositories are reference material and work belongs in the Flutter
app and package wrappers, including native bridges where needed. API-23 support is
an explicit exception: it requires deliberate native dependency/JNI rebuild work in
the order recorded in `RESTART_HANDOFF.md`. Do not publish packages or run broad
native distribution scripts as part of routine alignment. Keep credentials and
proprietary model internals out of notes and logs.
