---
name: launch-job
description: Create a laptop-local scheduled job (launchd LaunchAgent) in the jobs-repo pattern — scaffold the folder, wire the schedule, and gate it before it runs unattended.
disable-model-invocation: true
---

# launch-job

Add a scheduled job to a jobs repo. `$ARGUMENTS` describes what should run, and how often.

**`launchd` owns the schedule.** A job is a **one-shot**: it does one unit of work and exits,
woken fresh each interval. Nothing of ours stays resident, and no `run.sh` ever contains its own
`while true; sleep` loop — that fights the scheduler, which already guarantees a single instance.

`launch-job.sh` beside this skill does every mechanical part — foundations, scaffold, and the gate.
Your work is the four judgements below and proving the thing actually runs.

## The boundary — decide this first

A job is **execution, not logic**. The behaviour belongs to the project that owns it, where it can
be tested, shared and read in context; the jobs repo owns only *when and how to run* — the agent,
the schedule, the frozen env, the logs. `run.sh` sets up PATH and env, then `exec`s the owning
project's entry point.

So before scaffolding anything: **find or create the entry point in the owning project.** If you
are about to put domain logic in a `run.sh`, you are writing it in the wrong repo. A wrapper that
is more than about twenty lines is the smell.

## Scaffold

```
~/.claude/skills/launch-job/launch-job.sh setup --dir <path>     # foundations, idempotent
~/.claude/skills/launch-job/launch-job.sh new <name> --repo <path> --command "<cmd>" \
    (--every <seconds> | --at HH:MM) [--notify --timeout <budget>] \
    [--preflight "<cmd>"] [--env NAME,NAME]
```

`setup` lays `bin/jobctl`, `lib/common.sh`, `Makefile` and `.gitignore` into any directory and is
safe to re-run — a foundation file you have since edited is reported as drift, never silently
overwritten. Run it once per jobs repo; skip it when the directory already has `bin/jobctl`.

**It is also where this device is configured, once.** `setup --dir ~/dev/jobs --prefix com.local`
records both settings, and every later `new` and `check` finds them with no flag at all — a machine
that keeps its jobs somewhere else is configured by running setup there. `launch-job.sh config`
prints what is resolved and from where; its header explains which setting is owned by the device
and which by the repo.

`new` writes the job folder and gates it. The flags are the four judgements:

1. **Cadence** — `--every <seconds>` for a poll, `--at HH:MM` for a fixed clock time. Pick the
   loosest cadence that still answers in time; a tighter one buys nothing and costs wake-ups.
2. **`--notify`** — for any job whose cadence is slow enough that **silence is ambiguous**. A job
   that fails into a log file nobody opens is indistinguishable from a job that never fired, and
   the rarer the schedule the longer that survives. This picks a `run.sh` that inspects its own
   exit status instead of `exec`ing, because `exec` would replace the shell that does the
   reporting.
3. **`--preflight "<cmd>"`** — whenever the job reads a secret, token or URL from its project's
   `.env`. Those are invisible to the jobs repo by design, so nothing else checks them, and a
   revoked one FATAL-s every tick forever while the agent still looks healthy. `start` is the
   human-present moment; make the failure land there. The check belongs to the owning project and
   must **exercise** the credential with one live call — presence is not usability.
4. **`--env NAME,...`** — shell-only vars (`PROJECT_ROOT` and friends) that `~/.zshrc` sets and
   `launchd` never will. They are frozen from your shell at `make start`; changing one later means
   re-running `start`. Only what the *wrapper* needs to locate the project — a job's own secrets
   stay in the project's `.env`.

`--timeout` bounds the run, and the notify template wraps it in `caffeinate -is`. Both matter for
anything longer than a few minutes: a hang is the one failure a job cannot report, and on battery
this laptop idle-sleeps and the run is **stretched** rather than killed — a 35-minute sweep
measured 4h48m, with tokens expiring and in-flight requests returning as read timeouts along the
way. Size the budget well above the worst legitimate run; it is there to catch a hang, not to
police a slow day.

Then edit `run.sh`: replace the TODO header line with what this job does and, if the reason it
exists is non-obvious, why. `indexation-sweep/run.sh` is the reference for a job that reports.

## Prove it

Not done until, from the jobs repo:

1. `launch-job.sh check <name>` is clean — no ERROR, and every warning either fixed or a decision
   you can defend.
2. `make start JOB=<name>` completes — which means env froze and preflight passed.
3. `make run JOB=<name>` then `make tail JOB=<name>` shows the job's own log line and exit 0.
4. If the job notifies, **kick the real job to test it** (`make run`), never call `notify` from
   your shell: notifications only render from the launchd context, so a terminal test is a false
   negative that sends you chasing a permissions problem you do not have. Exercise the path where
   the *command* fails, not an early-exit guard — that is the branch that matters.

## When launchd is the wrong home

Agents run only while you are logged in and the system is awake. Anything that must survive a shut
lid on battery, a reboot, or being off-network belongs on the always-on droplet instead. Say so
rather than scaffolding a job that will quietly miss half its runs.

## The repo is the source of truth

The jobs repo's own `CLAUDE.md` documents the full pattern, including the incidents behind each
rule. Read it when a decision here is not covered; the gate enforces only the mechanical subset.
