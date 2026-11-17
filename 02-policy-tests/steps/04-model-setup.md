# Step 4. Chat model

## Purpose

Create `sts-lab02-chat` with no rate limit and confirm that a tier 1 key can complete one chat call. This is the unrestricted baseline. Later scenarios change the policy list on this same model. They do not create a second model.

## What will be created or modified

`config/04-model.yaml` creates the model `sts-lab02-chat`. The client name is `sts-lab02-chat`. The upstream target is `gpt-4o-mini` on `sts-lab02-openai`. The auth strategy is `sts-lab02-key-auth`. `policies` is `[]`.

## Required prerequisites

Steps 2 and 3 are applied. `$LABS_DIR/.env` contains `PROXY`, `AI_GATEWAY_ID`, and `STS_LAB02_TIER1_KEY`.

## Commands to preview changes

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/02-policy-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/04-model.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/model.apply-plan.json"
```

Read the preview. It should create `sts-lab02-chat` and nothing else. The policy list in the plan is empty.

## Commands to apply changes

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/model.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

The row is `sts-lab02-chat`, target `gpt-4o-mini`, provider `sts-lab02-openai`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-chat \
  --output json \
  --jq '{name, target: .targets[0].name, provider: .targets[0].provider, policies, auth: .access.auth_strategies}'
```

`policies` is `[]` or `null`. `auth` includes `sts-lab02-key-auth`.

## Check Data Plane sync

The local Data Plane has to receive the model before the proxy will route it. `sync` must reach `STATE_IN_SYNC`.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

One call, as consumer 1. The command prints the model, the reply, why generation stopped, and token usage. It does not print the API key.

```bash
curl --silent --show-error --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB02_TIER1_KEY" \
  --data '{"model":"sts-lab02-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}' \
  | jq '{model, reply: .choices[0].message.content, finish_reason: .choices[0].finish_reason, usage}'
```

## Expected results

The HTTP call returns JSON. `reply` is a short affirmation. The wording varies between calls. `finish_reason` is `stop` or `length`. `model` is `gpt-4o-mini` or a dated snapshot of that model. `usage.total_tokens` is a number. No `RateLimit-*` or `X-AI-RateLimit-*` header is required on this call, because no rate policy is attached.

## Explanation of the policy behavior

An empty `policies` list means this model adds no AI Policy of its own. The three groups also have empty policy lists, so a successful call is not counted against a Lab 2 limit. Re-applying this same file later clears a model-scoped policy and returns the model to this baseline.
