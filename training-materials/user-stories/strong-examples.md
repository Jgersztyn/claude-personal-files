# Strong user story examples

Reference examples for the `jg-user-stories` skill — see
[`../../skills/jg-user-stories/SKILL.md`](../../skills/jg-user-stories/SKILL.md). These seven are the
stories judged concise, effective, and clear enough in their acceptance criteria that a developer knows
what to complete. They are also the **length to aim for**.

Six of these seven are reproduced verbatim from Climavision Jira (reporter: Jason Gersztyn), extracted
2026-08-07. `WI-645` is reproduced verbatim from a separate ticket note file, captured 2026-09-16, with
no Jira or company metadata included — none was available, and none is wanted in this reference file.
Wording is unchanged — including the flaws noted below.

## Reading notes

The examples predate the standard, so their field names vary. Map them as follows:

| In these examples | In the standard |
|---|---|
| `Notes` (PD-2047) | **Dev Notes** |
| `Other information` (Fit all Maps) | **Other Details** |
| `Context` (Fit all Maps) | fold into **Description**, or **Other Details** if it is background |
| `Improvements to implement` (PD-2046) | non-standard — see below |

Four deliberate caveats, so nothing here gets copied as a pattern when it shouldn't be:

- **PD-2187 has no real acceptance criteria.** Its second bullet is the literal placeholder
  `More AC here…` and the first has no measurable threshold. It is an exemplar of **structure and
  length only** — never of acceptance criteria.
- **PD-2046 uses `Improvements to implement`.** This is *the* specific case where a non-standard field
  earns its place: a worklist that genuinely is not acceptance criteria. Do not adopt it by default.
- **"Fit all Maps in one View" has no Jira key.** Nothing links to it and its screenshot did not show
  one, so none was invented.
- **WI-645 skips Other Details.** The section was omitted because there was nothing real to add, per
  the standard's "an empty field is worse than a missing one" rule. It does include Acceptance
  Criteria, as any standard story should. (The general note that bugs typically don't need Acceptance
  Criteria lives in the skill itself, not here — WI-645 is a standard story, not a bug.)

---

## PD-1945 — Edit Signal in Athena

**Type:** Task · **Status:** Done · **Created:** 2025-08-13 · **Resolved:** 2025-09-25
**Jira:** https://climavision.atlassian.net/browse/PD-1945

### Description

Add the ability to edit a signal given the new features that were added in https://climavision.atlassian.net/browse/PD-1836

As a user managing Smart Behaviors, I want to open an existing Signal and edit its configuration, so that I can update the Signal's parameters, criteria, or metadata without recreating it from scratch.

### Acceptance Criteria

1. Open for Editing
   - Given I am on the Signals List page, when I click on an existing Signal, then the system opens the Signal in an editable form.
2. Pre-Populated Fields
   - The edit form displays all the same fields as the Add Signal form (Name, Tags, Urgency, Criteria, etc.).
   - All fields are pre-populated with the Signal's current values.
   - The same validation rules from Signal creation apply during editing.
3. Save Changes
   - When changes are made and the user clicks Save, then the Signal is updated in the system with the new values.
4. Cancel Changes
   - If Cancel is clicked, no changes are applied.
   - User is redirected back to the Signals List view.

---

## PD-2000 — Configure Prism.Service Release Pipeline

**Type:** Task · **Status:** Done · **Created:** 2025-09-25 · **Resolved:** 2025-10-01
**Jira:** https://climavision.atlassian.net/browse/PD-2000

### Description

Set up the Octopus Project for the Prism.Service.

It needs to be configured with environment-specific settings, supporting both Dev and Prod environments, and at least one tenant. Configuration should include database connectivity and blob storage endpoints, with variables managed through Octopus so that the app can consume them cleanly via standard configuration providers.

Verify that the releases are created via GitHub Actions. Similar to other projects, each successful pull request build should trigger a release, which is then pushed to Octopus. This applies not only when a PR is opened but also when commits are added to an existing PR.

### Acceptance Criteria

- Creating a new pull request, or updating an existing pull request, for the Prism.Service, creates a new release
- This release is pushed to Octo
- In Octo, the environment variables that are required for the Prism.Service are specified and configured
- The correct variables are applied depending on the environment selected (e.g. dev or prod)

### Dev Notes

- Since there is currently only a dev database, the values for prod can be copied from dev or be left blank.
- As such, configuration variables are subject to change. Make them easily editable.

---

## PD-2046 — Stabilize Database in Prism.Service

**Type:** Task · **Status:** Done · **Created:** 2025-11-06 · **Resolved:** 2025-11-22
**Jira:** https://climavision.atlassian.net/browse/PD-2046

### Description

Prism.Service currently encounters multiple issues related to its Marten and PostgreSQL database integration. The following areas need to be addressed to ensure proper database stability and alignment with production requirements.

### Improvements to implement

1. Fix DateTime Issues
   - Review all database interactions (read/write) to ensure DateTime usage aligns with Marten's expectations.
   - Resolve issues caused by UTC vs local timestamp mismatches by standardizing to either DateTimeOffset or Postgres timestamptz fields.
2. Consider how to handle Duplicate Records
   - Identify where duplicate key conflicts occur during insert operations. Currently, this breaks the program when they are encountered. Execution cannot continue beyond this point.
   - Implement a fix to prevent Marten exceptions that block program flow.
3. Marten Migrations and Build-Time Schema Generation
   - Update the program setup flow so that Marten migrations are properly applied in the development environment.
   - Ensure schema SQL is generated and applied at build time rather than dynamically at runtime in production deployments.
4. Additional Database Stabilization Items
   - Investigate and address any other issues discovered during testing or setup related to schema generation, environment configuration, or Marten/Postgres connectivity.

### Acceptance Criteria

- Database migrations apply cleanly via Marten in all dev environments.
- No UTC DateTime errors occur during read/write operations.
- Duplicate record insertions do not block program execution.
- Production builds use pre-generated SQL scripts with no dynamic schema creation at runtime.
- Basically, the database just WORKS!

---

## PD-2047 — GR2HistoricalService - Change File System for Devops

**Type:** Task · **Status:** Done · **Created:** 2025-11-07 · **Resolved:** 2025-11-24
**Jira:** https://climavision.atlassian.net/browse/PD-2047

### Description

Following recent DevOps changes, the Docker containers running in Kubernetes now enforce a read-only file system, allowing write access only to specific mounted volumes (/tmp and /data).

The GR2-HistoricalDataService currently attempts to write files to locations that are not writable under this new configuration, resulting in a "read-only file system" error when the service is executed (e.g., when GR2-Admin calls the historic data endpoint).

To comply with the updated container restrictions, the service code needs to be modified to write temporary or output files to one of the writable mount paths:

- /tmp → scratch volume for temporary file writes
- /data → data volume for persistent storage (if applicable)

### Acceptance Criteria

- All temporary or generated files are written to /tmp or /data instead of restricted paths.
- The service runs successfully inside the read-only container configuration.
- Confirm integration with GR2-Admin endpoint (https://gr2-admin.climavision.dev/historic-data) functions without "read-only file system" errors.

### Notes

- DevOps has temporarily rolled back the read-only restriction and added the scratch volume for testing.
- Once the code change is complete, DevOps will re-enable the read-only configuration.

---

## PD-2187 — Populate Heatmap with Climatological Data

**Type:** Story · **Status:** Done · **Created:** 2026-03-13 · **Resolved:** 2026-03-24
**Jira:** https://climavision.atlassian.net/browse/PD-2187

> Exemplar for **structure and length only** — the acceptance criteria below are unfinished.

### Description

As a user of Athena, I want to populate the Heatmap widget with climatological data, so that I can view temperature anomalies quickly in real time.

A continuation of: https://climavision.atlassian.net/browse/PD-2169

Use the Prism Service to calculate the 30-year averages for weather stations. Since Prism operates based on spatial entities, each station will need to be assigned via polygonal data. This can be done by wrapping the station in its approximate GPS coordinates.

New API endpoints need to be added to Prism to send this data to Athena.

Prism should replace the API calls to OpenMeteo with these calls directly.

Currently, Prism also supports 5-year averages. It has no support for 10-year averages. That could be added in another feature later on.

### Acceptance Criteria

- Data loads quickly! (ASAP is ideal but definitely less than a second, right?)
- More AC here…

### Dev Notes

- Sync with @Dan Fearing in regards to setting up spatial entities correctly via Smart Behaviors.

Key Cities with WBAN Code [image]

---

## Fit all Maps in one View

**Type:** — · **Status:** — · **Jira key:** unknown
**Captured from:** screenshot, 2026-08-07

### Description

As a user of the Views page, when I open a view, I want the run/view selection and time selection controls to be combined into one row so that I can fit all map panels in the viewport without a vertical scrollbar.

### Context

The Views page currently uses two full-width control rows above the maps.
The issue is to consolidate those rows into one and make the view fit all map panels on screen.

### Acceptance criteria

- Run/view selection and time selection share a single row, each about half its width.
- All controls from both rows remain present and functional.
- A view fits every panel in the viewport with no vertical scrollbar.
- The setting persists for that view.

### Other information

Current controls on the Views page:

- Run / view selection — `RUN 12Z Aug 3, 2026`, the view group tabs, the edit button.
- Time selection — forecast hour readout, the D1–D17 hour scrubber, and the `Latest` / `Latest Complete` toggles.

---

## WI-645 — Deleting a Panel View Does Nothing

### Description

Panel views need to actually be deletable. Clicking **Delete** on a view (via the "⋮" menu in the
Panel Views dialog, screenshot: `delete_panel_does_nothing.png`) shows a green "View deleted."
success message, but nothing is removed — the view still appears in the Panel Views list and in
the view tabs.

### Acceptance Criteria

- Clicking Delete and confirming removes the view from the Panel Views list immediately.
- The deleted view no longer appears in the view tabs.
- The deletion persists after refreshing the page or reopening the Panel Views dialog.
- The "View deleted." confirmation only appears when the view was actually deleted.

### Dev Notes

- Delete handling is `DeleteView()` in `src/UI/Components/Views/PanelViewEditorDialog.razor`
  (~line 345) — it calls `NWPClient.DeleteUserViewState(view.Id)` and removes the view from local
  state on success. Confirm the request actually succeeds server-side, and that whatever
  repopulates the view list/tabs is reading from the same updated source afterward.
