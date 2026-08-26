---
name: xan
description: Ad-hoc CSV work in the shell with `xan` ("jq for CSVs"). Use when reading, filtering, aggregating, sorting, joining, or converting CSV/TSV/NDJSON files from the command line, or when the user mentions xan.
---

Default output is plain CSV (agent-friendly, pipeable); reach for `xan view` / `xan flatten` only when showing data to the user. Use `xan to json` / `xan from json` for CSV<->JSON conversion.

## Format auto-detection by extension

- `.csv` (comma), `.tsv`/`.tab` (tab), `.scsv`/`.ssv` (semicolon), `.psv` (pipe), `.cdx` (space, magic bytes stripped)
- `.ndjson`/`.jsonl`: treated as headless tab-separated null-quoted -- good for piping into xan expressions; use `xan from -f ndjson` for a real conversion
- Bioinformatics: `.vcf`/`.gtf`/`.gff2`/`.sam`/`.bed` (header stripped, tab-delimited)
- Gzip- and zstd-compressed variants of any of these are read transparently
- Override with `-d/--delimiter`. Formats like `.gff`/`.gff3` need normalization via `xan input` first.

## Gotchas

- Comparisons use word operators: `eq ne gt ge lt le`. `==` is numeric-only; on strings it errors with "cannot safely cast Bytes(...)".
- `xan map 'EXPR as colname[, EXPR as colname]' file.csv` -- `as colname` is part of the expression string, not a flag.
- Substrings: `slice(s, start, end)` (no `left`/`right`/`substr`).
- `xan view` has no `-l/--limit`; cap rows upstream with `xan slice -l N`.
- Group-by-day pattern: `xan map 'slice(created_at, 0, 10) as day' | xan groupby day 'mean(x) as x, count() as n' | xan sort -s day`.
