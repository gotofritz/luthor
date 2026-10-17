# Luthor

A GTD system loosely inspired by OmniFocus: local-first and event-sourced.
See `AGENTS.md` and `docs/plans/` for the architecture and roadmap.

## CLI

```bash
swift build -c release
export LUTHOR_LOG=~/.luthor/events.jsonl           # the event log; created on first add
export LUTHOR_DEVICE_ID=macbook                   # optional, default: local

.build/release/luthor add "buy milk"
.build/release/luthor list
.build/release/luthor done 9afc                    # any unique prefix of a task ID
```

## Development

```bash
make tools hooks   # once
make check-ci      # what CI runs
```
