# Step 5. Basic rate limit per principal

## Purpose

Limit `sts-lab04-chat` to 3 requests per 60 seconds for each authenticated principal. Show that principal 2 still has a full counter after principal 1 is rejected.

## What will be created or modified

| File | Change |
|---|---|
| `config/07-policy-rate-basic.yaml` | Creates policy `sts-lab04-rate-basic` |
| `config/07-model-attach-rate-basic.yaml` | Sets `sts-lab04-chat` policies to `sts-lab04-rate-basic` |

The policy type is `rate-limiting-advanced`. `identifier` is `principal`. `strategy` is `local`. `window_type` is `fixed`. `limit` is 3 and `window_size` is 60. The policy is not global. The provider and the principals are not recreated.

Lab 2 scenario 1 uses `rate-limiting` with `minute: 3` and `limit_by: consumer`. That policy cannot use a principal as its counter key. Lab 4 therefore uses `rate-limiting-advanced` with `identifier: principal`. This policy still counts HTTP requests—not tokens or cost. A fixed 60-second window reproduces Lab 2's one-minute bucket.

## Required prerequisites

Step 4 returned a chat completion for `STS_LAB04_TIER1_KEY`. Load `.env` in this shell.

## Commands to preview changes

Preview the policy first, then the model attachment.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/04-principal-rate-limiting/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/07-policy-rate-basic.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/rate-basic.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/07-model-attach-rate-basic.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/model-rate-basic.apply-plan.json"
```

Read both previews. The first creates `sts-lab04-rate-basic` only. The second updates `sts-lab04-chat` so its policy list is that name. It should not create a second model.

## Commands to apply changes

```bash
kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/rate-basic.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/model-rate-basic.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-rate-basic \
  --output json \
  --jq '{name, type, enabled, global, identifier: .config.identifier, strategy: .config.strategy, window_type: .config.window_type, limit: .config.limit, window_size: .config.window_size}'
```

`type` is `rate-limiting-advanced`, `identifier` is `principal`, `strategy` is `local`, `window_type` is `fixed`, `limit` is `[3]`, and `window_size` is `[60]`. `global` is absent or `false`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-chat \
  --output json \
  --jq '{name, policies}'
```

`policies` is `["sts-lab04-rate-basic"]`.

## Check Data Plane sync

Wait until `sync` is `STATE_IN_SYNC` before the calls below.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

Each principal gets 3 requests per 60 seconds on `sts-lab04-chat`. Run the two loops close together so principal 2 is tested immediately after principal 1 reaches HTTP 429.

**Optional header inspection.** This call shows the full response and `X-RateLimit-Limit-Minute: 3`, but it also consumes one of principal 1's three requests. Skip it when you want the following loop to begin with a fresh counter. If you run it, wait for `RateLimit-Reset` before starting the loops.

```bash
curl --silent --show-error --include --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB04_TIER1_KEY" \
  --data '{"model":"sts-lab04-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'
```

From a fresh window, run both loops as one block. Each sends at most 4 requests and stops on the first HTTP 429. One line per request shows the status, limit, remaining count, and reset time. HTTP 429 also shows `Retry-After`.

- Principal 1: three HTTP 200, then HTTP 429. Remaining falls 2, 1, 0.
- Principal 2, same window: the first request is still HTTP 200, remaining 2. Principal 1 did not spend this counter.

If request 1 is already 429, that principal already used this window. The script waits for the reset when it is 1–70 seconds, then runs that loop once more.

```bash
cd "$LABS_DIR/04-principal-rate-limiting"

bash test-chat.sh \
  --label principal-1 \
  --key-var STS_LAB04_TIER1_KEY \
  --mode requests \
  --expect 3 \
  --max 4

bash test-chat.sh \
  --label principal-2 \
  --key-var STS_LAB04_TIER2_KEY \
  --mode requests \
  --expect 3 \
  --max 4
```

## Expected results

Headers on an accepted response include the limit and the remaining count for the minute window:

```text
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 2
RateLimit-Limit: 3
RateLimit-Remaining: 2
RateLimit-Reset: <seconds until the window resets>
```

The remaining value decreases by one on each accepted call from that same principal. After the principal's own remaining count is spent, the next call is HTTP 429. The body is JSON:

```json
{ "message": "API rate limit exceeded" }
```

A 429 response includes `Retry-After`.

From a fresh window, principal 1 shows three accepted calls and a fourth call of HTTP 429. `X-RateLimit-Limit-Minute` is `3` on those calls. Principal 2 then shows its own `X-RateLimit-Limit-Minute: 3` and a remaining count that principal 1's traffic did not consume. Principal 2's first call in this scenario is accepted when that principal has not already used the window.

If the script says request 1 was rejected, that principal's counter was already above the limit from an earlier run. The retry after the reset is the series to read.

The response headers provide the runtime evidence for this exercise: each principal sees its own limit and remaining count. They are not a durable analytics report, and this step does not query a separate Konnect analytics API.

## Explanation of the policy behavior

`identifier: principal` gives each authenticated principal a separate counter. Principal 1's three requests do not reduce principal 2's remaining count. The policy is attached only to `sts-lab04-chat`, so it counts requests that select this model.

`strategy: local` stores the counters in memory on the Data Plane node. That matches this single local node. Counters are not shared across replicas. This scenario does not use Redis.

The counter is whatever is already in the current window. It is not reset by applying the policy again. Read `RateLimit-Remaining` before deciding that a 429 is the fourth call of a fresh window.
