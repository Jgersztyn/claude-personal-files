---
name: jg-user-stories
description: Apply JG's user story standard — a four-field structure where Description and Acceptance Criteria are always required, Dev Notes and Other Details appear only when context demands, and short bullets are used everywhere except Description. Use when writing, refining, splitting, sizing or reviewing user stories, tickets, Jira issues or backlog items, when turning requirements or meeting notes into stories, when judging whether a story is too verbose or too large, and especially when the user references "my story format", "the story standard", or asks for stories written the way they like them.
---

# JG User Stories

Applies JG's user story structure. This skill is self-contained — the
standard is stated inline, and the reference file holds worked examples
only. Use it as the authoritative source when writing, refining or
reviewing user stories.

---

## When to apply this skill

- Writing a new user story, ticket or backlog item.
- Refining or rewriting an existing story that is too verbose.
- Turning requirements, notes or a conversation into stories.
- Reviewing a story for structure, clarity or size.
- Deciding whether a story should be split.
- The user references "my story format" or "the story standard".

---

## Hard rules (never skip)

These are non-negotiable. If something here conflicts with the rest
of the document, the hard rule wins.

1. **Description and Acceptance Criteria are ALWAYS present.** No
   story ships without both. Everything else is contextual.

2. **Four fields, in this order.** `Description`, `Acceptance
   Criteria`, `Dev Notes`, `Other Details`. Do not reorder them and
   do not invent a fifth without a specific reason.

3. **Description is the only field allowed prose.** Everywhere else
   uses short bullets. If a bullet needs a second sentence, it is
   probably two bullets or belongs in Description.

4. **Length is a sizing signal, not a budget.** If the detail count
   keeps growing, the story is too big — split it. Never treat a
   long story as well-documented.

5. **No Jira chrome.** `Resolution Details`, `Tech Debt`, `Sprint`,
   `Story Points` and similar are Jira fields, not story content.
   They never appear in the body.

---

## The four fields

| Field | Required | Purpose | Form |
|---|---|---|---|
| **Description** | **Always** | High-level what and why, with the necessary information | Paragraphs allowed — and still concise. Bulleted lists fine. |
| **Acceptance Criteria** | **Always** | What must be true for the story to be done | Short bullets |
| **Dev Notes** | Contextual | What the implementer needs to know: dependencies on other projects, stories or people | Short bullets |
| **Other Details** | Contextual | Gotchas and good-to-know information; external contacts and teams to coordinate with | Short bullets |

Dev Notes and Other Details appear only when there is something real
to say. An empty field is worse than a missing one.

### Telling Dev Notes from Other Details

- **Dev Notes** → things that change what the implementer *does*:
  blocking stories, required variables, a library quirk, a
  dependency on another team's work landing first.
- **Other Details** → things that change what the implementer
  *watches out for*: failure modes, undecided questions, who to
  coordinate with, why an obvious approach is wrong.

When a note fits both, prefer Dev Notes — it is the field an
implementer reads first.

---

## Banned and discouraged fields

| Field | Verdict |
|---|---|
| `Context` | **No.** Fold into Description, or Other Details if it is background rather than requirement. |
| `Improvements to Implement` | **Not by default.** Only when a story genuinely needs a worklist that is *not* acceptance criteria. See `PD-2046` in the reference file — that is the bar. |
| `Verification` / `Definition of Done` | **No.** This is Acceptance Criteria under another name. Merge it. |
| `Why this matters` / rationale essays | **No.** Compress to one Other Details bullet, or cut. |
| `Resolution Details`, `Tech Debt` | **No.** Jira chrome. |

---

## Writing Acceptance Criteria

- **One testable behaviour per bullet.** If a bullet contains
  "and", check whether it is two criteria.
- **Given/When/Then is optional.** Use it when the state matters;
  drop the scaffolding when a plain sentence is clearer. Do not pad
  criteria into ceremony.
- **Numbered groups with sub-bullets are fine** when criteria
  cluster around distinct behaviours — see `PD-1945`.
- **Never ship a placeholder.** `More AC here…` is an unfinished
  story, not a written one.
- **Prefer a threshold to an adjective.** "loads quickly" is not
  testable; "loads in under one second" is.

---

## Length

Aim for roughly 10–25 lines of content. A very simple story may be
far shorter — two AC bullets and two notes is fine. A complex story
may need a longer Description or more Other Details.

Past that, treat it as a sizing problem:

- **Two unrelated concerns in one story** → split along the seam.
- **A story that ships nothing on its own** → it is probably an
  internal seam, not a story. Merge it upward instead.
- **Acceptance criteria past ~8 bullets** → check for a hidden
  second story.

---

## Not covered here

Bugs, spikes and epics may use different fields. Do not force the
four-field story structure onto them. Where an epic or spike keeps
its own shape, say so in the ticket so nobody reads it as a
non-conforming story.

**When the ticket type is unclear, ask — don't guess.** Whether
something is a bug, task, user story or spike changes which fields
apply (bugs, for instance, typically don't need Acceptance
Criteria). Ideally the user states the type up front when asking
for a ticket. If they don't, and the type can't be determined with
confidence from context, stop and ask before writing it.

---

## Further Reading

Worked examples of the length and structure to aim for:

- `../../training-materials/user-stories/strong-examples.md` (relative
  to this skill's directory)

Read the caveats at the top of that file before copying any example.
Two matter most: `PD-2187` has an unfinished placeholder for its
acceptance criteria and is an exemplar of structure and length only,
and `PD-2046` is the single justified use of a non-standard field.

If the reference file is unavailable, this skill remains complete;
the examples are supplementary.

---

## How to apply this standard in practice

1. **Start with the two required fields.** Write Description and
   Acceptance Criteria first. Add Dev Notes and Other Details only
   if something real belongs there.
2. **Draft the Description as prose, then cut it.** Say what and
   why. Delete any sentence that justifies the story's existence to
   a reader who already agreed to it.
3. **Turn each acceptance criterion into one testable statement.**
   Split on "and". Replace adjectives with thresholds.
4. **Sort the leftovers.** Blocking dependency or required config →
   Dev Notes. Gotcha, failure mode, open question, person to talk
   to → Other Details.
5. **Compress open questions to one line each**, prefixed
   `Undecided:`. Do not give them a section.
6. **Existing ticket with a house style** → match the ticket's
   conventions where they conflict with this skill, and note the
   deviation rather than silently reformatting someone else's
   backlog.
7. **Count the lines.** Past ~25, ask what the second story is
   before adding anything else.
8. **When unsure about a field**, consult the table above — it is
   the authoritative source.
