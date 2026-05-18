---
name: recalibrate
argument-hint: [instructions]
description: Re-align with the user after a context compact. Verify nothing important was lost and confirm the next step before resuming work. Does not write a spec or plan file.
---

Use this skill to recover alignment after the conversation was compacted. The goal is to confirm shared context and agree on the next concrete step — not to produce a spec, plan, or file.

Procedure:

1. State, in 2-4 short bullets, what you currently believe is true about the work in progress: the task, what's been done, what's outstanding, and any decisions or constraints the user has set. Pull this from the summarized context and any visible files/state. Be explicit about uncertainty — if you're not sure whether something survived the compact, say so.

2. Use AskUserQuestion to verify the parts that matter. Focus on:
   - Facts that, if wrong, would cause you to do the wrong work next (e.g., which file, which approach, which constraint).
   - Decisions the user made earlier that may not have survived compaction.
   - The immediate next step — what should happen right now.

   Skip obvious questions. Skip anything you can verify yourself by reading files or running a command — do that first.

3. Continue asking until you and the user agree on (a) the current state and (b) the next concrete action. Then stop.

Do NOT:
- Write a spec, plan, or summary file.
- Enter plan mode or call ExitPlanMode.
- Start executing the next step until the user confirms it.

<instructions>$ARGUMENTS</instructions>
