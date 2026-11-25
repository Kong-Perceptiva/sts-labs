# Lab 4. Rate limits by Identity principal

This lab reproduces the three rate-limiting scenarios from Lab 2 on one chat model, but identifies callers as Kong Identity principals instead of AI Consumers. The client calls the local proxy with the model name `sts-lab04-chat`. Kong selects `gpt-4o-mini` and attaches the OpenAI credential from the provider `sts-lab04-openai`. The client does not call OpenAI directly.

The caller is a Kong Identity principal. This lab does not create an AI Consumer or an AI Consumer Group. The three principals and their imported API keys live in the existing Identity directory named `default`.

Three scenarios, run one at a time:

1. The same request limit for every principal of `sts-lab04-chat`: 3 requests per 60-second fixed window, counted per principal.
2. A different request limit on each principal: 2, 4, and 6 requests per 60-second fixed window. The counter is still per principal.
3. A token quota on the same model: 100, 200, and 400 total tokens per 60 seconds, one quota per tier, counted per principal.

Scenario 1 and scenario 2 count HTTP requests. Scenario 3 counts `total_tokens`. None of the three counts cost.

Resources are declared in `config/` and applied with `kongctl plan --mode apply`, then `kongctl apply --plan`. Read the plan before applying it. `--mode apply` limits the change to that file. The default plan mode, sync, also deletes resources that are absent from the file.

Lab 4 uses the gateway, Data Plane, and `$LABS_DIR/.env` from the parent directory. Every new Kong name starts with `sts-lab04-`. The lab does not read or change Lab 1, Lab 2, or Lab 3 resources. Cleanup deletes the three principals. It does not delete the directory `default`.

## AI Consumers and Identity principals

AI Consumers and Kong Identity principals both represent an authenticated caller, but they are different resource types and are not interchangeable.

An **AI Consumer** is an AI Gateway resource. It belongs to an AI Gateway, owns gateway credentials, and can be added to an AI Consumer Group. An AI Consumer Group can attach AI Gateway policies. In Lab 2 scenario 2, group membership selects one of three request-limit policies, while `limit_by: consumer` keeps a separate counter for each consumer.

A **principal** is an identity in a Kong Identity directory. In this lab, each principal has type `agent`, metadata, and an imported API key. The auth strategy reads the client `apikey`, resolves it against the directory `default`, and makes the authenticated principal available to AI Gateway policies. The client is therefore identified as a principal rather than as an AI Consumer.

The important policy differences are:

- A principal is not an AI Consumer and does not require an AI Consumer intermediary.
- An Identity group cannot attach an AI Gateway policy in the way an AI Consumer Group can.
- The basic `rate-limiting` policy supports `limit_by: consumer`, but not `limit_by: principal`.
- `rate-limiting-advanced` supports `identifier: principal`, so request counters can be separated directly by principal.
- Principal metadata can be read by supported policy matches and CEL expressions. This lab uses `metadata.tier` to select a limit and `metadata.counter_key` where a unique token counter key is required.

For that reason, Lab 4 reproduces the behavior of Lab 2 without reproducing its resource graph. It uses principals instead of AI Consumers, principal metadata instead of AI Consumer Group policy selection, and principal-based counter keys instead of consumer-based counter keys.

## Difference from Lab 2

| Lab 2 | Lab 4 |
|---|---|
| AI Consumers `sts-lab02-consumer-t1`, `sts-lab02-consumer-t2`, and `sts-lab02-consumer-t3` | Identity principals `sts-lab04-principal-t1`, `sts-lab04-principal-t2`, and `sts-lab04-principal-t3` |
| Consumer API key credentials | Imported principal API keys |
| AI Consumer Groups select the request policy | `metadata.tier` selects the tier; the request policy maps `t1`, `t2`, and `t3` to 2, 4, and 6 |
| `rate-limiting` with `limit_by: consumer` and `minute: 3`, `2`, `4`, or `6` | `rate-limiting-advanced` with `identifier: principal` and a fixed 60-second window |
| `ai-rate-limiting-advanced` matches `consumer_group` and partitions by `consumer` | It matches each principal's `metadata.tier` and uses `metadata.counter_key` as the per-principal counter key |

Lab 2 scenario 2 does not share one counter across a group. The group selects the limit, while each consumer keeps a separate counter. Lab 4 preserves that behavior: `metadata.tier` selects the tier, the policy defines the three limits, and `identifier: principal` gives every principal a separate counter even when two principals use the same tier.

This is a behavioral replacement for the Consumer Groups in Lab 2, not an Identity-group implementation. Identity groups cannot attach AI Gateway policies, and the basic `rate-limiting` policy cannot use a principal as `limit_by`. Lab 4 therefore does not create a group. Its single `rate-limiting-advanced` policy uses CEL to choose the limit from `principal.metadata.tier`, then uses `identifier: principal` to keep the counters independent. The principal stores the tier name only; the values 2, 4, and 6 live in the policy.

## Start

Complete the shared setup in the parent directory: copy `.env.example` to `.env`, fill the values, and export `LABS_DIR`. Add the three Lab 4 keys. Then follow the steps in order.

| Step | File | What it does |
|---|---|---|
| 0 | `steps/00-lab-intro.md` | Scope, the principal substitution, and how the three scenarios are switched. |
| 1 | `steps/01-prerequisites.md` | Sets `LABS_DIR`. Installs `kongctl` and `jq` when they are missing. |
| 2 | `steps/02-provider-setup.md` | Config Store, vault, and provider `sts-lab04-openai`. |
| 3 | `steps/03-auth-and-principals.md` | Key auth against the directory, three principals, and one imported key each. |
| 4 | `steps/04-model-setup.md` | Model `sts-lab04-chat` with no policy, then a 401 and one chat call. |
| 5 | `steps/05-rate-limiting-basic.md` | Scenario 1. Three requests per 60 seconds per principal. |
| 6 | `steps/06-rate-limiting-tiers.md` | Scenario 2. Replaces scenario 1 with the per-principal limits 2, 4, and 6. |
| 7 | `steps/07-rate-limiting-tokens.md` | Scenario 3. Replaces scenario 2 with the token quotas. |
| 8 | `steps/08-cleanup.md` | Optional. Deletes the Lab 4 resources and the generated local files. `.env` and the directory stay. |

Start at `steps/00-lab-intro.md`.
