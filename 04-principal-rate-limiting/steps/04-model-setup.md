# Step 4. Chat model

## Purpose

Create `sts-lab04-chat` with no rate limit. Confirm that a missing key is rejected and that the tier 1 principal key can complete one chat call. This is the unrestricted baseline. Later scenarios change the policy list on this same model. They do not create a second model.

## What will be created or modified

`config/04-model.yaml` creates the model `sts-lab04-chat`. The client name is `sts-lab04-chat`. The upstream target is `gpt-4o-mini` on `sts-lab04-openai`. The auth strategy is `sts-lab04-key-auth`. `policies` is `[]`.

## Required prerequisites

Steps 2 and 3 are applied. `$LABS_DIR/.env` contains `PROXY`, `AI_GATEWAY_ID`, and `STS_LAB04_TIER1_KEY`.

## Commands to preview changes

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/04-principal-rate-limiting/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/04-model.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/model.apply-plan.json"
```

Read the preview. It should create `sts-lab04-chat` and nothing else. The policy list in the plan is empty.

## Commands to apply changes

```bash
kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/model.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

The row is `sts-lab04-chat`, target `gpt-4o-mini`, provider `sts-lab04-openai`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-chat \
  --output json \
  --jq '{name, target: .targets[0].name, provider: .targets[0].provider, policies, auth: .access.auth_strategies}'
```

`policies` is `[]` or `null`. `auth` includes `sts-lab04-key-auth`.

## Check Data Plane sync

The local Data Plane has to receive the model before the proxy will route it. `sync` must reach `STATE_IN_SYNC`.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

**No key.** Authentication fails before a model policy would run. Expect HTTP 401. The command prints the status and saves the response body in `artifacts/04-missing.json`.

```bash
mkdir -p "$LABS_DIR/04-principal-rate-limiting/artifacts"

curl --silent --show-error --max-time 60 \
  --output "$LABS_DIR/04-principal-rate-limiting/artifacts/04-missing.json" \
  --write-out 'HTTP status: %{http_code}\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --data '{"model":"sts-lab04-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'
```

**Unknown key.** The value is the literal `invalid`; it is not a secret. It matches no principal. Because `error_on_miss` is true, expect HTTP 401. The body is saved in `artifacts/04-invalid.json`.

```bash
curl --silent --show-error --max-time 60 \
  --output "$LABS_DIR/04-principal-rate-limiting/artifacts/04-invalid.json" \
  --write-out 'HTTP status: %{http_code}\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header 'apikey: invalid' \
  --data '{"model":"sts-lab04-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'
```

**Tier 1 key.** The command prints the model, the reply, why generation stopped, and token usage. It does not print the API key.

```bash
curl --silent --show-error --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB04_TIER1_KEY" \
  --data '{"model":"sts-lab04-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}' \
  | jq '{model, reply: .choices[0].message.content, finish_reason: .choices[0].finish_reason, usage}'
```

## Expected results

The first two commands print HTTP 401. Their saved JSON bodies contain the authentication error. The tier 1 call succeeds and returns a short reply; `finish_reason` is `stop` or `length`, and `usage.total_tokens` is a number. No Lab 4 rate-limit header is expected because the model still has an empty policy list.

## Explanation of the policy behavior

An empty `policies` list means this model adds no AI Policy of its own. A successful call is not counted against a Lab 4 limit. Re-applying this same file later clears a model-scoped policy and returns the model to this baseline. The 401 responses come from `sts-lab04-key-auth`, not from a rate policy.
