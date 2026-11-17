# Step 5. Basic rate limit per consumer

## Purpose

Limit `sts-lab02-chat` to 3 requests per minute for each authenticated consumer. Show that consumer 2 still has a full counter after consumer 1 is rejected.

## What will be created or modified

| File | Change |
|---|---|
| `config/07-policy-rate-basic.yaml` | Creates policy `sts-lab02-rate-basic` |
| `config/07-model-attach-rate-basic.yaml` | Sets `sts-lab02-chat` policies to `sts-lab02-rate-basic` |

The policy type is `rate-limiting`. `minute` is 3. `limit_by` is `consumer`. `policy` is `local`. The policy is not global. The provider, consumers, and groups are not recreated.

## Required prerequisites

Step 4 returned a chat completion for `STS_LAB02_TIER1_KEY`. Load `.env` in this shell.

## Commands to preview changes

Preview the policy first, then the model attachment.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/02-policy-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/07-policy-rate-basic.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/rate-basic.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/07-model-attach-rate-basic.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/model-rate-basic.apply-plan.json"
```

Read both previews. The first creates `sts-lab02-rate-basic` only. The second updates `sts-lab02-chat` so its policy list is that name. It should not create a second model.

## Commands to apply changes

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/rate-basic.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/model-rate-basic.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-rate-basic \
  --output json \
  --jq '{name, type, enabled, global, minute: .config.minute, limit_by: .config.limit_by, policy: .config.policy}'
```

`type` is `rate-limiting`, `minute` is `3`, `limit_by` is `consumer`, and `policy` is `local`. `global` is absent or `false`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-chat \
  --output json \
  --jq '{name, policies}'
```

`policies` is `["sts-lab02-rate-basic"]`. The three group policy lists stay empty. Step 6 reads them after it attaches the tier policies.

## Check Data Plane sync

Wait until `sync` is `STATE_IN_SYNC` before the calls below.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

Each consumer gets 3 requests per minute on `sts-lab02-chat`. Run the two loops below back to back, in the same minute. A pause between them lets consumer 1's window reset, and the comparison is lost.

One call first, to see the full response once. `X-RateLimit-Limit-Minute` should be 3.

```bash
curl --silent --show-error --include --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB02_TIER1_KEY" \
  --data '{"model":"sts-lab02-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'
```

Then both loops, as one block. Each sends at most 4 requests and stops on the first HTTP 429. One line per request: number, HTTP status, `X-RateLimit-Limit-Minute`, `X-RateLimit-Remaining-Minute`, and `RateLimit-Reset`. HTTP 429 adds `Retry-After`.

- Consumer 1: three HTTP 200, then HTTP 429. Remaining falls 2, 1, 0.
- Consumer 2, same minute: the first request is still HTTP 200, remaining 2. Consumer 1 did not spend this counter.

If request 1 is already 429, that consumer already used this minute. The script waits for the reset when it is 1–70 seconds, then runs that loop once more.

```bash
cd "$LABS_DIR/02-policy-tests"

bash test-chat.sh \
  --label consumer-1 \
  --key-var STS_LAB02_TIER1_KEY \
  --mode requests \
  --expect 3 \
  --max 4

bash test-chat.sh \
  --label consumer-2 \
  --key-var STS_LAB02_TIER2_KEY \
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

The remaining value decreases by one on each accepted call from that same consumer. After the consumer's own remaining count is spent, the next call is HTTP 429. The body is JSON:

```json
{ "message": "API rate limit exceeded" }
```

A 429 response includes `Retry-After`.

From a fresh window, consumer 1 shows three accepted calls and a fourth call of HTTP 429. `X-RateLimit-Limit-Minute` is `3` on those calls. Consumer 2 then shows its own `X-RateLimit-Limit-Minute: 3` and a remaining count that consumer 1's traffic did not consume. Consumer 2's first call in this scenario is accepted when that consumer has not already used the window.

If the script says request 1 was rejected, that consumer's counter was already above the limit from an earlier run. The retry after the reset is the series to read.

## Explanation of the policy behavior

`limit_by: consumer` gives each authenticated consumer a separate counter. Consumer 1's three requests do not reduce consumer 2's remaining count. The policy is attached only to `sts-lab02-chat`, so it counts requests that select this model.

A shared limit for every caller of the model would put those callers on one counter. This policy does not do that. `limit_by` chooses the counter. `consumer` is the authenticated AI Consumer. `consumer-group` would be one counter for the whole group. `credential`, `ip`, `header`, and `path` are the other documented aggregations. This file sets `consumer`.

`policy: local` stores the counters in memory on the Data Plane node. That matches this single local node. Counters are not shared across replicas. `cluster` is not available for Konnect. This scenario does not use Redis.

The counter is whatever is already in the current minute. It is not reset by applying the policy again. Read `RateLimit-Remaining` before deciding that a 429 is the fourth call of a fresh window.
