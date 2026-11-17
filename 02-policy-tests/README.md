# Lab 2. Rate limiting policies

This lab applies rate limits to one chat model through a Kong AI Gateway Data Plane. The client calls the local proxy with the model name `sts-lab02-chat`. Kong selects `gpt-4o-mini` and attaches the OpenAI credential from the provider `sts-lab02-openai`. The client does not call OpenAI directly.

Three scenarios, run one at a time:

1. The same request limit for every consumer of `sts-lab02-chat`: 3 requests per minute, counted per consumer.
2. A different request limit on each consumer group: 2, 4, and 6 requests per minute. The counter is still per consumer.
3. A token quota on the same model: 100, 200, and 400 total tokens per 60 seconds, one quota per tier, counted per consumer.

Resources are declared in `config/` and applied with `kongctl plan --mode apply`, then `kongctl apply --plan`. Read the plan before applying it. `--mode apply` limits the change to that file. The default plan mode, sync, also deletes gateway resources that are absent from the file.

Lab 2 uses the gateway, Data Plane, and `$LABS_DIR/.env` from the parent directory. Every new Kong name starts with `sts-lab02-`. The lab does not read or change Lab 1 resources.

## Start

Complete the shared setup in the parent directory: copy `.env.example` to `.env`, fill the values, and export `LABS_DIR`. Add the three Lab 2 keys. Then follow the steps in order.

| Step | File | What it does |
|---|---|---|
| 0 | `steps/00-lab-intro.md` | Scope, plan-then-apply, and how the three scenarios are switched. |
| 1 | `steps/01-prerequisites.md` | Sets `LABS_DIR`. Installs `kongctl` and `jq` when they are missing. |
| 2 | `steps/02-provider-setup.md` | Config Store, vault, and provider `sts-lab02-openai`. |
| 3 | `steps/03-auth-and-consumers.md` | Key auth, three consumers, three groups, and group membership. |
| 4 | `steps/04-model-setup.md` | Model `sts-lab02-chat` with no policy, then one chat call. |
| 5 | `steps/05-rate-limiting-basic.md` | Scenario 1. Three requests per minute per consumer. |
| 6 | `steps/06-rate-limiting-tiers.md` | Scenario 2. Detaches scenario 1, then applies the tier limits. |
| 7 | `steps/07-rate-limiting-tokens.md` | Scenario 3. Detaches scenario 2, then applies the token quotas. |
| 8 | `steps/08-cleanup.md` | Optional. Deletes the Lab 2 resources and the generated local files. `.env` stays. |

Start at `steps/00-lab-intro.md`.
