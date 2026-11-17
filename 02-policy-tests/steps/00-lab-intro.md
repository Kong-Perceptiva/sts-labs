# Lab 2. Rate limiting policies

The lab shows three rate limits on one chat model. The client calls the local proxy. Kong holds the OpenAI credential and sends the request upstream. The calls do not go to OpenAI directly.

The Data Plane runs locally and takes its configuration from a Konnect AI Gateway. `kongctl` talks to Konnect. It does not use the Admin API inside the Data Plane. This lab does not create a Control Plane or a Data Plane.

Each YAML under `config/` is applied from a reviewed plan. `kongctl plan --mode apply` compares that file with the gateway and writes the difference under `plans/`. Konnect stays unchanged. Read the plan before continuing. `kongctl apply --plan` then performs the saved file. It does not read the YAML again.

`--mode apply` keeps the plan to that file. The default plan mode is sync. A sync plan also deletes gateway resources that are absent from the file.

When a step shows more than one `kongctl` command, paste and run each one on its own. Pasting the block at once runs them together, and the output does not show which command printed which lines.

## What this lab creates

Step 2 creates the Config Store `sts-lab02-config-store`, the vault `sts-lab02-vault`, and the provider `sts-lab02-openai`. The OpenAI key is written to the Config Store and read through the vault. Step 3 creates the auth strategy `sts-lab02-key-auth`, three consumers, and three consumer groups. The client sends the header `apikey`, and the Data Plane removes it before calling OpenAI. Step 4 creates the model `sts-lab02-chat`, which routes to `gpt-4o-mini`, with an empty policy list. Steps 5, 6, and 7 attach one scenario at a time. Step 8 is optional. It deletes the Lab 2 resources and this lab's `plans/`, `artifacts/`, and `out/`. The shared `.env` is kept.

`LABS_DIR` is the `labs` directory. Step 1 sets it. This lab is `$LABS_DIR/02-policy-tests`. The shared `.env` is `$LABS_DIR/.env`.

| Path | Contents |
|---|---|
| `$LABS_DIR/.env.example` | Shared names of the values to fill in. Copy it to `$LABS_DIR/.env`. Do not commit `.env`. |
| `$LABS_DIR/.env` | Shared Konnect, gateway, proxy, and key values. |
| `$LABS_DIR/02-policy-tests/steps/` | These instructions, in order. |
| `$LABS_DIR/02-policy-tests/config/` | Declarative YAML for the provider, auth, model, consumers, groups, and policies. |
| `$LABS_DIR/02-policy-tests/plans/` | Local `kongctl` plan output. Not committed. |
| `$LABS_DIR/02-policy-tests/artifacts/` | Response headers and bodies from the test script. Not committed. |
| `$LABS_DIR/02-policy-tests/test-chat.sh` | Bounded chat calls used in steps 5, 6, and 7. |
| `$LABS_DIR/02-policy-tests/cleanup.sh` | Optional step 8. Deletes the Lab 2 resources, then the generated files in this lab. |

## Scenarios

Only one scenario is active at a time. Activating the next one re-applies the model or the groups so the previous attachment is cleared. Policy objects may remain on the gateway after they are detached. A detached policy does not run.

| Scenario | Active attachment | Limit |
|---|---|---|
| 1 | `sts-lab02-rate-basic` on `sts-lab02-chat` | 3 requests per minute, per consumer |
| 2 | `sts-lab02-rate-tier-1`, `sts-lab02-rate-tier-2`, `sts-lab02-rate-tier-3` on the matching groups | 2, 4, and 6 requests per minute, per consumer |
| 3 | `sts-lab02-rate-tokens` on `sts-lab02-chat` | 100, 200, and 400 total tokens per 60 seconds, per consumer |
| Baseline | Model policies empty, group policies empty | No Lab 2 rate limit |

## Switch scenarios

Every switch is a `kongctl plan --mode apply` of an existing file. The provider, consumers, and credentials stay as they are.

| Change | Apply these files, in order |
|---|---|
| Activate scenario 1 | `config/07-policy-rate-basic.yaml`, then `config/07-model-attach-rate-basic.yaml` |
| Scenario 1 to scenario 2 | `config/04-model.yaml`, then `config/08-policies-rate-tiers.yaml`, then `config/08-groups-attach-rate-tiers.yaml` |
| Scenario 2 to scenario 3 | `config/06-consumer-groups.yaml`, then `config/09-policy-rate-tokens.yaml`, then `config/09-model-attach-rate-tokens.yaml` |
| Return to the baseline | `config/04-model.yaml`, then `config/06-consumer-groups.yaml` |

`config/04-model.yaml` sets the model policy list to empty. `config/06-consumer-groups.yaml` sets each group policy list to empty and keeps the same member in each group.
