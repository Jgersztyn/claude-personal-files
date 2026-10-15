---
name: jg-linqpad-scripts
description: Create lightweight, minimal LINQPad scripts that isolate a feature from a larger application so it can be tested independently. Use when writing, scaffolding, simplifying or reviewing LINQPad (.linq) scripts, when the user wants to test or prototype a feature outside the main app, and especially when the user references "a LINQPad script", "a linq script", "test this in LINQPad", "in LINQPad" or "my LINQPad standard".
---

# JG LINQPad Scripts

Creates LINQPad scripts that are as lightweight and simple as possible.
The purpose of a script is to isolate a feature from a larger
application and test it independently. This skill is self-contained —
the standard is stated inline.

> **Status: template.** Structure only. Detailed rules will be added
> as the standard is defined.

---

## When to apply this skill

- Writing a new LINQPad script.
- Isolating a feature from a larger app to test it on its own.
- Simplifying or reviewing an existing LINQPad script.
- The user references "a LINQPad script" or "test this in LINQPad".

---

## Hard rules (never skip)

These are non-negotiable. If something here conflicts with the rest
of the document, the hard rule wins.

1. **Keep it lightweight.** The simplest script that tests the
   feature is the correct one. Add nothing that is not needed.

2. **Isolate the feature.** The script tests one feature
   independently of the larger app's environment.

3. *(More hard rules to be defined.)*

---

## Area 1 — Script structure

*(To be defined.)*

---

## Area 2 — Isolating the environment

*(To be defined.)*

---

## Not covered here

*(To be defined — state which cases are out of scope so the skill is
not force-fitted.)*

---

## Further Reading

No companion reference yet. This skill is complete on its own.

---

## How to apply this standard in practice

1. **Start with the smallest script** that exercises the feature.
2. **Isolate before adding.** Prefer stubbing or inlining a
   dependency over pulling in more of the host app.
3. **When unsure**, the sections above are the authoritative source.
