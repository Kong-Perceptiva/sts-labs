# Lab 4. Rate limits by Identity principal

The lab reproduces the three rate-limiting scenarios from Lab 2 on one chat model, but identifies callers as Kong Identity principals instead of AI Consumers. The client calls the local proxy. Kong holds the OpenAI credential and sends the request upstream. The client does not send the OpenAI credential or call OpenAI directly.

The authenticated caller is a Kong Identity principal. The lab does not create an AI Consumer. The Data Plane runs locally and takes its configuration from a Konnect AI Gateway. `kongctl` talks to Konnect. It does not use the Admin API inside the Data Plane. This lab does not create a Control Plane, a Data Plane, or an Identity directory.

Each YAML under `config/` is applied from a reviewed plan. `kongctl plan --mode apply` compares that file with Konnect and writes the difference under `plans/`. Konnect stays unchanged. Read the plan before continuing. `kongctl apply --plan` then performs the saved file. It does not read the YAML again.

`--mode apply` limits the plan to resources declared in that file. The default plan mode is sync, which can also delete managed resources absent from the file. Always use `--mode apply` with this lab, especially for the Identity manifest. The directory `default` is only looked up; this lab must not reconcile all principals in that directory.

When a step shows more than one `kongctl` command, paste and run each one on its own. Pasting the block at once runs them together, and the output does not show which command printed which lines.

## What this lab creates

Step 2 creates the Config Store `sts-lab04-config-store`, the vault `sts-lab04-vault`, and the provider `sts-lab04-openai`. The OpenAI key is written to the Config Store and read through the vault. Step 3 creates the auth strategy `sts-lab04-key-auth` and three principals in the existing directory `default`. The client sends the header `apikey`, and the Data Plane removes it before calling OpenAI. Step 4 creates the model `sts-lab04-chat`, which routes to `gpt-4o-mini`, with an empty policy list. Steps 5, 6, and 7 attach one scenario at a time. Step 8 is optional. It deletes the Lab 4 gateway resources, the OpenAI secret, the three principals, and this lab's `plans/`, `artifacts/`, and `out/`. The shared `.env`, the directory `default`, and the Config Store `sts-lab04-config-store` are kept.

`LABS_DIR` is the `labs` directory. Step 1 sets it. This lab is `$LABS_DIR/04-principal-rate-limiting`. The shared `.env` is `$LABS_DIR/.env`.

| Path | Contents |
|---|---|
| `$LABS_DIR/.env.example` | Shared names of the values to fill in. Copy it to `$LABS_DIR/.env`. Do not commit `.env`. |
| `$LABS_DIR/.env` | Shared Konnect, gateway, proxy, and key values. |
| `$LABS_DIR/04-principal-rate-limiting/steps/` | These instructions, in order. |
| `$LABS_DIR/04-principal-rate-limiting/config/` | Declarative YAML for the provider, auth, model, principals, and policies. |
| `$LABS_DIR/04-principal-rate-limiting/plans/` | Local `kongctl` plan output. Not committed. |
| `$LABS_DIR/04-principal-rate-limiting/artifacts/` | Response headers and bodies from the test script. Not committed. |
| `$LABS_DIR/04-principal-rate-limiting/test-chat.sh` | Bounded chat calls used in steps 5, 6, and 7. |
| `$LABS_DIR/04-principal-rate-limiting/cleanup.sh` | Optional step 8. Deletes the Lab 4 resources, then the generated files in this lab. |

## What changes from Lab 2

Lab 2 authenticates AI Consumers and, in scenario 2, attaches one `rate-limiting` policy to each AI Consumer Group. Because `limit_by` remains `consumer`, the group selects the limit but each consumer keeps a separate counter. The group does not share one counter among all its members.

This lab keeps those limits, windows, and metrics:

| Scenario | What is counted | Limit | Counter |
|---|---|---|---|
| 1 | HTTP requests | 3 per 60 seconds | Per principal |
| 2 | HTTP requests | 2, 4, and 6 per 60 seconds | Per principal |
| 3 | `total_tokens` | 100, 200, and 400 per 60 seconds | Per principal |

Three compatibility differences require a different declarative configuration:

- The `rate-limiting` policy does not accept `principal` in `limit_by`. Scenarios 1 and 2 therefore use `rate-limiting-advanced` with `identifier: principal`. It still counts HTTP requests. A fixed 60-second window reproduces Lab 2's minute window.
- Identity groups cannot attach AI Gateway policies. Scenario 2 therefore does not create a group. It uses one policy whose CEL expression maps `principal.metadata.tier` to 2, 4, or 6 requests. This reproduces the tier-selection role of the Consumer Groups in Lab 2: the metadata chooses the limit, but it is not a group membership or a shared counter. The numeric limits live only in the policy; principals store only the tier name. `identifier: principal` keeps a separate counter for every principal, including principals that share a tier. A missing or unrecognized tier receives 2, the smallest configured limit.
- The `ai-rate-limiting-advanced` policy cannot use `principal` as its top-level `identifier`, but its match rules can read principal fields. Scenario 3 matches `principal.metadata.tier` to select 100, 200, or 400 tokens and uses `principal.metadata.counter_key` as the counter key.

No scenario limits by cost.

## Scenarios

Only one scenario is active at a time. Activating the next one re-applies the model so the previous attachment is cleared. Policy objects may remain on the gateway after they are detached. A detached policy does not run.

| Scenario | Active attachment | Limit |
|---|---|---|
| 1 | `sts-lab04-rate-basic` on `sts-lab04-chat` | 3 requests per 60 seconds, per principal |
| 2 | `sts-lab04-rate-tiers` on `sts-lab04-chat` | 2, 4, and 6 requests per 60 seconds, per principal |
| 3 | `sts-lab04-rate-tokens` on `sts-lab04-chat` | 100, 200, and 400 total tokens per 60 seconds, per principal |
| Baseline | Model policies empty | No Lab 4 rate limit |

## Switch scenarios

Every switch is a `kongctl plan --mode apply` of an existing file. The provider, principals, and credentials stay as they are.

| Change | Apply these files, in order |
|---|---|
| Activate scenario 1 | `config/07-policy-rate-basic.yaml`, then `config/07-model-attach-rate-basic.yaml` |
| Scenario 1 to scenario 2 | `config/08-policy-rate-tiers.yaml`, then `config/08-model-attach-rate-tiers.yaml` |
| Scenario 2 to scenario 3 | `config/09-policy-rate-tokens.yaml`, then `config/09-model-attach-rate-tokens.yaml` |
| Return to the baseline | `config/04-model.yaml` |

`config/04-model.yaml` sets the model policy list to empty. The attachment files set that list to exactly one policy name, so the previous policy stops running.
