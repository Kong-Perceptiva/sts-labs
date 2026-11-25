# Step 7. Token quotas per tier

## Purpose

Limit each tier by total tokens instead of by request count. The quotas are 100, 200, and 400 total tokens per 60 seconds.

## What will be created or modified

| File | Change |
|---|---|
| `config/09-policy-rate-tokens.yaml` | Creates `sts-lab04-rate-tokens` |
| `config/09-model-attach-rate-tokens.yaml` | Sets `sts-lab04-chat` policies to `sts-lab04-rate-tokens` |

The policy is `ai-rate-limiting-advanced`, attached only to `sts-lab04-chat`. It uses local counters and counts `total_tokens` in fixed 60-second windows. The three sub-policies match `principal.metadata.tier`: `t1` selects 100 tokens, `t2` selects 200, and `t3` selects 400. `principal.metadata.counter_key` is a unique string on each principal and is used as that principal's counter key. The fallback `unknown-principal` is used only if the expression cannot be evaluated. There is no Redis configuration or cost limit.

This policy type does not accept `principal` as its top-level `identifier`, so the file leaves `identifier` unset. Principal match rules select the quota, and `expressions.custom_key` supplies the counter key. The additional `partition_by` match includes that same principal metadata value in the composed counter.

Each fixed window is one independent 60-second bucket. The file sets `fixed` explicitly because the policy otherwise defaults to a sliding window.

`rate-limiting-advanced` and `ai-rate-limiting-advanced` are different policy types. The attachment file lists only `sts-lab04-rate-tokens`, so the scenario 2 request policy stops running.

## Required prerequisites

The principals and their metadata exist from step 3. Step 6 may be the current attachment. This step replaces it.

## Commands to preview changes

Load the shell once. Then run each `kongctl plan` on its own and read that plan before the next command.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/04-principal-rate-limiting/plans"
```

`source` exports `$LABS_DIR/.env`. `mkdir` creates the local `plans/` directory. Neither command changes Konnect.

**Create the token policy.** Adds `sts-lab04-rate-tokens` only. It is not attached yet, so no request is counted by it.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/09-policy-rate-tokens.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/rate-tokens.apply-plan.json"
```

The plan creates one policy. The three limits are 100, 200, and 400, each with `window_size` 60.

If the plan rejects `expressions`, stop. Without that field, this configuration cannot use the principal's metadata as the counter key. Do not replace the principal with an AI Consumer.

**Attach it to the chat model.** `sts-lab04-chat` then lists only `sts-lab04-rate-tokens`.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/09-model-attach-rate-tokens.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/model-rate-tokens.apply-plan.json"
```

The plan updates that model. It does not create a second model.

## Commands to apply changes

Same two plans, in the same order. Each apply performs the file you just read.

**Policy.** `sts-lab04-rate-tokens` now exists.

```bash
kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/rate-tokens.apply-plan.json" \
  --auto-approve \
  --output json
```

**Model.** Calls to `sts-lab04-chat` use the token policy.

```bash
kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/model-rate-tokens.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

These reads check the token-quota configuration, not the HTTP behavior:

- `sts-lab04-chat` has only `sts-lab04-rate-tokens` attached
- `sts-lab04-rate-tokens` is `ai-rate-limiting-advanced`, counted in total tokens, at 100, 200, and 400 per 60 seconds
- the counter expression is `principal.metadata.counter_key`

Run each command on its own.

**Model attachment.** `policies` should be `["sts-lab04-rate-tokens"]`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-chat \
  --output json \
  --jq '{name, policies}'
```

**Policy settings.** Type, token count, and the three quotas.

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-rate-tokens \
  --output json \
  --jq '{
    name,
    type,
    strategy: .config.strategy,
    tokens_count_strategy: .config.tokens_count_strategy,
    custom_key: .config.custom_key,
    expressions,
    tiers: [.config.policies[] | {tier: .match[0].values, limit: .limits[0].limit, window_size: .limits[0].window_size, window_type: .window_type}]
  }'
```

Expect `ai-rate-limiting-advanced`, `strategy` `local`, `tokens_count_strategy` `total_tokens`, and limits 100, 200, and 400 with `window_size` 60. `expressions.custom_key` is `principal.metadata.counter_key`.

## Check Data Plane sync

Confirms the local node has the configuration you just applied. `sync` must be `STATE_IN_SYNC` before the HTTP calls.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

Each call asks for one word and `max_tokens` 8, so an accepted response spends a small token total. The gateway adds that total after the response.

**Optional full-response inspection.** This uses the tier 1 key and prints the status line, headers, and body. Read `usage.total_tokens` and the `X-AI-RateLimit-Limit-` header; the limit should be 100. This call also consumes tokens from tier 1. For a clean loop, skip it or wait for its 60-second window to reset.

```bash
curl --silent --show-error --include --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB04_TIER1_KEY" \
  --data '{"model":"sts-lab04-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'
```

Swap in `$STS_LAB04_TIER2_KEY` or `$STS_LAB04_TIER3_KEY` to see that tier's limit header, 200 or 400.

**One loop per tier.** Each loop stops on the first HTTP 429. One line per request: number, HTTP status, `total_tokens`, and the first `X-AI-RateLimit-Limit` and `X-AI-RateLimit-Remaining` headers. The body is omitted. Run each loop on its own so the summary stays with that tier.

- Tier 1: quota 100, at most 20 requests.
- Tier 2: quota 200, at most 30 requests.
- Tier 3: quota 400, at most 40 requests.

```bash
cd "$LABS_DIR/04-principal-rate-limiting"

bash test-chat.sh \
  --label tokens-tier-1 \
  --key-var STS_LAB04_TIER1_KEY \
  --mode tokens \
  --expect 100 \
  --max 20
```

```bash
bash test-chat.sh \
  --label tokens-tier-2 \
  --key-var STS_LAB04_TIER2_KEY \
  --mode tokens \
  --expect 200 \
  --max 30
```

```bash
bash test-chat.sh \
  --label tokens-tier-3 \
  --key-var STS_LAB04_TIER3_KEY \
  --mode tokens \
  --expect 400 \
  --max 40
```

## Expected results

- HTTP 200 lines show `total_tokens` and a limit header of 100, 200, or 400.
- The loop stops at HTTP 429 or at the cap.
- The call that crosses the quota is still accepted. The next call is the 429.
- No 429 before the cap means the window reset or the calls stayed under the quota. The cap stays at most 40.
- After tier 1 is rejected, tier 2's first accepted call still shows its own limit of 200 and a remaining count near that quota. Tier 1's tokens are not subtracted from it. The same split holds for tier 3 at 400.

The `X-AI-RateLimit-Limit` and `X-AI-RateLimit-Remaining` headers provide the runtime evidence for the selected principal and tier. They are not a durable analytics report. This step does not query a separate Konnect analytics API.

## Explanation of the policy behavior

`total_tokens` is the sum of prompt and completion tokens. The gateway records the usage after the upstream response, so the request that crosses the quota can still succeed; the following request receives HTTP 429. `metadata.tier` selects the quota, while the unique `metadata.counter_key` keeps each principal's usage separate. Counters stay in memory on this Data Plane.

This is not a cost limit. Lab 2 scenario 3 is also a total-token quota, and this step keeps that metric.

## Return to the unrestricted baseline

This leaves the Lab 4 provider, model, principals, and keys in place. It clears the model policy list. The policy objects can remain. They do not run while nothing references them. Run each `kongctl` on its own.

**Preview the model.** Sets `sts-lab04-chat` policies to empty, which detaches `sts-lab04-rate-tokens`.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/04-principal-rate-limiting/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/04-model.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/model-baseline.apply-plan.json"
```

**Apply the plan.**

```bash
kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/model-baseline.apply-plan.json" \
  --auto-approve \
  --output json
```

**Read the model.** `policies` is empty.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-chat \
  --output json \
  --jq '{name, policies}'
```

Wait until node `sync` is `STATE_IN_SYNC` before another exercise. A call with `$STS_LAB04_TIER1_KEY` is then HTTP 200 without a Lab 4 rate-limit header.
