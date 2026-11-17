# Lab 3. Advanced AI Gateway policies

The lab shows six controls on one chat model. The client calls the local proxy. Kong holds the OpenAI credential and sends the request upstream. The calls do not go to OpenAI directly.

The Data Plane runs locally and takes its configuration from a Konnect AI Gateway. `kongctl` talks to Konnect. It does not use the Admin API inside the Data Plane. This lab does not create a Control Plane or a Data Plane.

Each YAML under `config/` is applied from a reviewed plan. `kongctl plan --mode apply` compares that file with the gateway and writes the difference under `plans/`. Konnect stays unchanged. Read the plan before continuing. `kongctl apply --plan` then performs the saved file. It does not read the YAML again.

`--mode apply` keeps the plan to that file. The default plan mode is sync. A sync plan also deletes gateway resources that are absent from the file.

When a step shows more than one `kongctl` command, paste and run each one on its own. Pasting the block at once runs them together, and the output does not show which command printed which lines.

## What this lab creates

Step 2 creates the Config Store `sts-lab03-config-store`, the vault `sts-lab03-vault`, and the provider `sts-lab03-openai`. Step 3 creates the auth strategy `sts-lab03-key-auth`. Step 4 creates the model `sts-lab03-chat`, two consumers, and two groups, with an empty policy list and no ACL. Steps 5 through 10 attach one exercise at a time. Step 11 is optional. It deletes the Lab 3 resources, the Lab 3 containers, and this lab's `plans/`, `artifacts/`, and `out/`. The shared `.env` is kept.

`LABS_DIR` is the `labs` directory. Step 1 sets it. This lab is `$LABS_DIR/03-advanced-policies`. The shared `.env` is `$LABS_DIR/.env`.

| Path | Contents |
|---|---|
| `$LABS_DIR/.env` | Shared Konnect, gateway, proxy, and key values. |
| `$LABS_DIR/03-advanced-policies/steps/` | These instructions, in order. |
| `$LABS_DIR/03-advanced-policies/config/` | Declarative YAML. `04-model-baseline.yaml` is the unrestricted model. |
| `$LABS_DIR/03-advanced-policies/plans/` | Local `kongctl` plan output. Not committed. |
| `$LABS_DIR/03-advanced-policies/artifacts/` | Response headers and bodies. Not committed. |
| `$LABS_DIR/03-advanced-policies/cleanup.sh` | Optional step 11. |

## Exercises

Only one exercise is active at a time. Step 4 starts from the baseline. If an exercise is active, use [Return to baseline](#return-to-baseline) before starting another. Steps 2, 3, and 4 do not. A policy object can remain on the gateway after it is detached. A detached policy does not run.

| Step | What is attached | Needs a container |
|---|---|---|
| 5 | `sts-lab03-prompt-guard` on the model | No |
| 6 | `sts-lab03-semantic-guard` on the model | Redis Stack 7.4 |
| 7 | `sts-lab03-pii-sanitizer` on the model | PII service |
| 8 | `sts-lab03-prompt-template` on the model | No |
| 9 | `sts-lab03-semantic-cache` on the model | Redis Stack 7.4 |
| 10 | `access.acls.allow` = `sts-lab03-group-allowed` | No |
| Baseline | Empty policy list, no ACL | No |

No policy in this lab is global. Steps 6 and 9 share one Redis container and logical database 0. Search indexes cannot be created on any other database. The guard and the cache use different index names.

## Return to baseline

Use this only after an exercise, to clear that exercise's policy or ACL before starting another one. Steps 2, 3, and 4 do not use it. API key authentication stays enabled.

**Preview the reset.** The plan should show `sts-lab03-chat` with an empty policy list and no ACL.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/04-model-baseline.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-baseline.apply-plan.json"
```

**Apply the reviewed reset.**

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-baseline.apply-plan.json" \
  --auto-approve \
  --output json
```

**Verify the reset.** `policies` is empty and `acls` is absent. Wait until the Data Plane `sync` is `STATE_IN_SYNC` before the next exercise.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-chat \
  --output json \
  --jq '{name, policies, acls: .access.acls}'
```
