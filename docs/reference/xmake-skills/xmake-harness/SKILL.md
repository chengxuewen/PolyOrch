---
name: xmake-harness
description: Use when running or configuring `xmake ai` — the terminal coding agent provided by the xmake-harness addon. Covers installing it, setting an llm provider and api key, sessions (`-c`/`-r`), permission modes, the non-interactive `--print` mode for scripts and CI, and listing its skills/agents/tools/commands.
---

# xmake-harness (`xmake ai`)

[xmake-harness](https://github.com/xmake-addons/xmake-harness) is an agent harness written
in xmake lua. As an addon it exposes `xmake ai`, a claude-code style terminal agent that
knows how to build the project it is sitting in.

## Install

```bash
xmake addon --install xmake-harness
xmake ai --setup                     # interactive wizard: provider, api key, model
```

Or from the source:

```bash
xmake addon --install github:xmake-addons/xmake-harness
```

## Configure a provider

```bash
xmake ai --config=providers.deepseek.apikey=sk-xxxxxx
xmake ai --apikey=sk-xxxxxx                 # api key of the current provider
xmake ai --provider=deepseek --model=deepseek-chat
xmake ai --smallmodel=deepseek-chat         # used by the title/summary/light subagents
xmake ai --showconfig                       # the resolved configuration
xmake ai --doctor                           # check the environment
```

## Run it

```bash
xmake ai                                    # interactive tui
xmake ai "add a unit test for foo"          # start with a prompt
xmake ai -c                                 # continue the last session of this directory
xmake ai -c "and now add the tests"
xmake ai -r                                 # pick a session to resume
xmake ai -r 6a86cfc5-bbda-14ce
xmake ai --new                              # force a new session
```

## Non-interactive

For scripts, hooks and CI — it prints the result and exits:

```bash
xmake ai --print "what does this build produce?"
xmake ai --command=doctor                   # run one slash command and exit
xmake ai --command='model deepseek-reasoner'
```

## Permissions and sandbox

```bash
xmake ai --mode=plan          # read-only, it plans before touching anything
xmake ai --mode=acceptedits   # auto-accept file edits, still asks for commands
xmake ai --mode=bypass        # no prompts (use with care)
xmake ai --sandbox            # confine the commands it runs
xmake ai --notools            # chat only, no tools at all
```

`--mode=plan` is the right default when you let it look at an unfamiliar repository.

## What it carries

```bash
xmake ai --list=skills        # also: agents, tools, commands, plugins, providers, sessions
```

Skills are the same shape as this repository's — dropping
[xmake-skills](https://github.com/xmake-io/xmake-skills) into it teaches it xmake in the
same way it teaches Claude Code.

## Gotchas

- It needs an api key and network access; `--doctor` tells you which part is missing.
- Sessions are per directory, so `-c` in another directory continues a different thread.
- `--print` is the only mode safe to run from a script — the tui expects a real terminal.
