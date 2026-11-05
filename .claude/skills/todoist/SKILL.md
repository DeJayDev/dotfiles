---
name: todoist
description: Add or update Todoist tasks for the current work, labeled with the repo and package it belongs to. Use for /todoist, "add a todo", "put this in Todoist", or handing a task to someone through Todoist.
---

Load the `todoist-cli` skill first and use `td` for everything.

## Labels

Every task gets these labels, plus any the user names:

- The repo: the basename of `git rev-parse --show-toplevel`, or of the working directory outside a git repo. `~/greptile/greptilia` becomes `greptilia`.
- The package, in a monorepo: the `name` in the nearest `package.json` between the working directory (or the files the task is about) and the repo root, excluding the root's own. Drop the scope: `@heythere/hello` becomes `hello`.

When the task is about files somewhere other than the working directory, use those files' location. Pass labels bare (`--labels "greptilia,webhook"`); Todoist creates missing labels.

## Project

Use the project the user names. Otherwise put work in `work`. List projects with `td project list --json` rather than guessing the name.

## Content

The title is one line saying what needs to happen. The description is the handoff: the failure, the proposed fix, and what's left, with `file:line` references and PR numbers. Write it to a file and pass it with `--stdin`. Read back the created task (`--json`) and give the user its URL.

## Installing td

`td` comes from `@doist/todoist-cli`, not the `td` npm package (that's Treasure Data). If it's missing, run `npm install -g --allow-scripts=@doist/todoist-cli @doist/todoist-cli`.
