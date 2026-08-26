---
name: braintrust
description: Navigate Braintrust logs/traces/experiments via the `bt` CLI. Parse a natural-language request (experiment, time window, what to look for) and run it. Flagship recipe - audit whether the agent invoked the `Skill` tool in an experiment. Triggers on "/braintrust", "bt cli", "braintrust logs/traces/experiment", "did the agent call Skill", "pull braintrust logs".
argument-hint: "e.g. skills from rsv11-stndrd4-psv2 in the last 12 hours"
---

# Braintrust navigator

The user's request: <request>$ARGUMENTS</request>

Parse it into: PROJECT (default `greptile-production`), EXPERIMENT (the experimentId string), WINDOW (e.g. `12h`, `3d`; default `12h`), and INTENT (what to look for -- Skill tool usage, errors, counts, raw export, a specific tool/string). If the request is just an experiment + window with no verb, assume the **Skill-tool audit** recipe below.

The `bt` CLI is at `~/.local/bin/bt`, authed locally.

## STEP 0 -- set project context + resolve the UUID (required prestep)

`bt` is stateful; queries hit whatever project is active. Switch first, confirm:

```
bt switch --project PROJECT 2>&1 | head
bt status 2>&1
```

CRITICAL: `project_logs('...')` in `bt sql` requires the project **UUID**, not the name -- passing the name gives `403 Forbidden / Missing read access`. Resolve it once:

```
bt projects list --json 2>&1 | python3 -c "import json,sys; [print(p['id'],'|',p['name']) for p in json.load(sys.stdin)]" | grep -i PROJECT
```

Use that UUID (call it `$P`) everywhere below. (greptile-production = `787b4dde-8a8e-409b-a9fa-96f6635b1278`.)

## Data model (load-bearing -- learned the hard way, respect these)

- experimentId lives in BOTH `input.experimentId` AND `metadata.experimentId`. Root spans carry `input.experimentId`; child LLM spans filter reliably on `metadata.experimentId`.
- The root span of a trace has `span_id == root_span_id`; its `metadata.repo` is the repo under review. Useful root metadata keys: `repo`, `prNumber`, `platform`, `harnessType`, `harnessModel`, `correlationId`.
- WHERE Skill (and any tool) calls actually live -- this is the part that bites:
  - A **real, newly-emitted** tool call is in the span's **`output`**, in **OpenAI serialization**: `output[].message.tool_calls[].function` = `{"name":"Skill","arguments":"<JSON string>"}`. There is NO `type:"tool_use"` field here. `arguments` is a JSON *string* -- `json.loads` it to get `{"skill":"next-best-practices"}`.
  - The **Anthropic** shape `{"type":"tool_use","name":"Skill","input":{...}}` shows up in the NEXT span's **`input`** (conversation-history echo), NOT as the originating call. Counting those double-counts.
  - So: to count REAL calls, scan **`output` only**, and handle BOTH formats (some harnesses emit Anthropic-native in output). The harness here serializes Claude calls in OpenAI format even though the model is `claude-sonnet-4-6`.
- Substring matching `'%Skill%'` is NOISE -- the skill-catalog system-reminder ("The following skills are available for use with the Skill tool") contains "Skill", and history echoes double it. A raw `grep -c '"name":"Skill"'` over-counts (~2x real). Always parse, output-side.
- Use `bt sql --non-interactive --json` for scriptable output. Pipe through `python3`/`jq`.

## Flagship recipe -- did the agent invoke the Skill tool?

### 1. Scope check (cheap, confirms the experiment is live in the window)

```
P=<project UUID from STEP 0>
LB=$(gdate -u -d '12 hours ago' +%Y-%m-%dT%H:%M:%SZ)   # GNU coreutils; BSD date differs
bt sql --non-interactive --json "SELECT count(DISTINCT root_span_id) AS traces,
  min(created) AS first, max(created) AS last
  FROM project_logs('$P')
  WHERE created >= '$LB' AND metadata.experimentId = 'EXPERIMENT'"
```

### 2. Export traces locally (reliable path, not raw bt sql)

```
cd /tmp && rm -rf bt-sync
bt sync pull "project_logs:$P" \
  --filter "metadata.experimentId = 'EXPERIMENT'" \
  --window WINDOW --traces 1000 --workers 16
```

Output lands in `/tmp/bt-sync/project_logs_<UUID>/<hash>/data/part-*.jsonl`. Find it with `find /tmp/bt-sync -name 'part-*.jsonl'`. (You can also target an experiment object directly: `bt sync pull "experiment:EXPERIMENT" -p PROJECT --window WINDOW`.)

### 3. Scan for real Skill tool calls (parse OUTPUT, both formats -- do NOT grep)

`cd` into the `data/` dir, then run. Scans `output` only (real calls), handles OpenAI + Anthropic serialization, dedups the history echoes:

```python
import json, glob, collections
calls=[]                              # (root, fmt, skill_name)
roots_with=set(); total_roots=set(); repo={}
def skills_in_output(out):
    found=[]
    def walk(n):
        if isinstance(n, dict):
            fn=n.get('function')                      # OpenAI: {function:{name,arguments(JSON str)}}
            if isinstance(fn, dict) and fn.get('name')=='Skill':
                try: a=json.loads(fn.get('arguments') or '{}')
                except: a={}
                found.append(('openai', a.get('skill','?')))
            if n.get('type')=='tool_use' and n.get('name')=='Skill':   # Anthropic-native, if any
                found.append(('anthropic', (n.get('input') or {}).get('skill','?')))
            for v in n.values(): walk(v)
        elif isinstance(n, list):
            for v in n: walk(v)
    walk(out); return found
for fn in glob.glob('*.jsonl'):
    for line in open(fn):
        try: s=json.loads(line)
        except: continue
        root=s.get('root_span_id'); total_roots.add(root)
        if s.get('span_id')==root: repo[root]=(s.get('metadata') or {}).get('repo')
        for fmt,sk in skills_in_output(s.get('output')):    # OUTPUT only
            calls.append((root,fmt,sk)); roots_with.add(root)
print('total traces:', len(total_roots))
print('real Skill calls:', len(calls))
print('traces that loaded a skill:', len(roots_with),
      f'= {100*len(roots_with)/max(len(total_roots),1):.1f}%')
print('skill names:', dict(collections.Counter(c[2] for c in calls)))
for r,fmt,sk in calls: print(f'  {r}  fmt={fmt}  skill={sk}  repo={repo.get(r)}')
```

### 4. Report

Total real Skill calls, which skill names, traces that loaded a skill vs total (rate: X of Y reviews = Z%), each call's trace + repo, and a repo cross-tab (with-skill / total). Sanity flag: if `grep -c '"name":"Skill"' *.jsonl` is ~2x the parsed count, that's the expected history-echo doubling -- trust the parser.

## Other moves (wizard kit)

(All `bt sql` below use `$P` = the project UUID from STEP 0, not the name.)

- List experiments: `bt experiments ls` (after STEP 0).
- Inspect one trace's spans: `bt sql --non-interactive --json "SELECT span_id, span_attributes.name AS name, span_attributes.type AS type FROM project_logs('$P') WHERE root_span_id = '<ROOT>' LIMIT 100"`.
- Per-day volume: `bt sql ... "SELECT slice(created,0,10) AS day, count(1) AS n FROM project_logs('$P') WHERE input.experimentId='EXPERIMENT' AND is_root GROUP BY day ORDER BY day"`.
- Pull one span's raw payload: `SELECT input, output, metadata, span_attributes FROM project_logs('$P') WHERE span_id = '<ID>'`.
- Generic "did tool X get called" -> same STEP 1-3 recipe, swap `'Skill'` for the target tool name in `skills_in_output` (both the OpenAI `function.name` and Anthropic `name` checks).

For any new intent, fall back to: scope with `bt sql`, export with `bt sync pull` when you need full payloads, parse JSON locally.
