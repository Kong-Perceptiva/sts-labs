# Step 7. Token quotas per tier

## Purpose

Limit each tier by total tokens instead of by request count. The quotas are 100, 200, and 400 total tokens per 60 seconds.

## What will be created or modified

| File | Change |
|---|---|
| `config/06-consumer-groups.yaml` | Sets every group policy list to empty. Membership stays the same. This detaches the three scenario 2 policies. |
| `config/09-policy-rate-tokens.yaml` | Creates `sts-lab02-rate-tokens` |
| `config/09-model-attach-rate-tokens.yaml` | Sets `sts-lab02-chat` policies to `sts-lab02-rate-tokens` |

The policy type is `ai-rate-limiting-advanced`. It is attached only to `sts-lab02-chat`. It is not global. `strategy` is `local`. `identifier` is `consumer`. `tokens_count_strategy` is `total_tokens`. Three sub-policies match `sts-lab02-tier-1`, `sts-lab02-tier-2`, and `sts-lab02-tier-3` by group name. Each sub-policy also matches the consumer with `partition_by: true`, so the consumer is part of the counter key. `window_type` is `fixed` and `window_size` is 60. There is no Redis configuration and no monthly cost limit.

The fixed window is a single 60-second bucket. The policy default is a sliding window, which weighs the previous bucket into the current rate. The fixed window is the bucket these quotas describe.

## Required prerequisites

The groups and their members exist from step 3. Step 6 may be the current attachment. This step detaches it before the token policy is attached. `rate-limiting` and `ai-rate-limiting-advanced` are different policy types, so leaving the scenario 2 policies attached would apply both. This step removes the scenario 2 attachments first.

## Commands to preview changes

Load the shell once. Then run each `kongctl plan` on its own and read that plan before the next command.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/02-policy-tests/plans"
```

`source` exports `$LABS_DIR/.env`. `mkdir` creates the local `plans/` directory. Neither command changes Konnect.

**Detach scenario 2.** Clears the policy list on the three groups. Each group keeps its one member. The tier request policies stay on the gateway, but they stop running.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/06-consumer-groups.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/groups-baseline.apply-plan.json"
```

The plan updates the three groups. `policies` becomes empty.

**Create the token policy.** Adds `sts-lab02-rate-tokens` only. It is not attached yet, so no request is counted by it.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/09-policy-rate-tokens.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/rate-tokens.apply-plan.json"
```

The plan creates one policy. The three limits are 100, 200, and 400, each with `window_size` 60.

**Attach it to the chat model.** `sts-lab02-chat` then lists only `sts-lab02-rate-tokens`.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/09-model-attach-rate-tokens.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/model-rate-tokens.apply-plan.json"
```

The plan updates that model. It does not create a second model.

## Commands to apply changes

Same three plans, in the same order. Each apply performs the file you just read.

**Groups.** Scenario 2 stops applying.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/groups-baseline.apply-plan.json" \
  --auto-approve \
  --output json
```

**Policy.** `sts-lab02-rate-tokens` now exists.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/rate-tokens.apply-plan.json" \
  --auto-approve \
  --output json
```

**Model.** Calls to `sts-lab02-chat` use the token policy.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/model-rate-tokens.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

These reads check the token-quota configuration, not the HTTP behavior:

- `sts-lab02-chat` has only `sts-lab02-rate-tokens` attached
- the three groups have no policy attached, so the scenario 2 request limits are off
- `sts-lab02-rate-tokens` is `ai-rate-limiting-advanced`, counted per consumer, in total tokens, at 100, 200, and 400 per 60 seconds

Run each command on its own.

**Model attachment.** `policies` should be `["sts-lab02-rate-tokens"]`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-chat \
  --output json \
  --jq '{name, policies}'
```

**Group attachments.** Each `policies` list should be empty. Members are not in this output.

```bash
for group in sts-lab02-tier-1 sts-lab02-tier-2 sts-lab02-tier-3; do
  kongctl get ai-gateway consumer-groups \
    --gateway-id "$AI_GATEWAY_ID" \
    "$group" \
    --output json \
    --jq '{name, policies}'
done
```

**Policy settings.** Type, counter scope, token count, and the three quotas.

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-rate-tokens \
  --output json \
  --jq '{
    name,
    type,
    strategy: .config.strategy,
    identifier: .config.identifier,
    tokens_count_strategy: .config.tokens_count_strategy,
    tiers: [.config.policies[] | {groups: .match[0].values, limit: .limits[0].limit, window_size: .limits[0].window_size, window_type: .window_type}]
  }'
```

Expect `ai-rate-limiting-advanced`, `strategy` `local`, `identifier` `consumer`, `tokens_count_strategy` `total_tokens`, and limits 100, 200, and 400 with `window_size` 60.

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

**One full response.** Uses the tier 1 key and prints the status line, the headers, and the body. Read `usage.total_tokens` and the `X-AI-RateLimit-Limit-` header. The limit should be 100.

```bash
curl --silent --show-error --include --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB02_TIER1_KEY" \
  --data '{"model":"sts-lab02-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'
```

Swap in `$STS_LAB02_TIER2_KEY` or `$STS_LAB02_TIER3_KEY` to see that tier's limit header, 200 or 400.

**One loop per tier.** Each loop stops on the first HTTP 429. One line per request: number, HTTP status, `total_tokens`, and the first `X-AI-RateLimit-Limit` and `X-AI-RateLimit-Remaining` headers. The body is omitted. Run each loop on its own so the summary stays with that tier.

- Tier 1: quota 100, at most 20 requests.
- Tier 2: quota 200, at most 30 requests.
- Tier 3: quota 400, at most 40 requests.

```bash
cd "$LABS_DIR/02-policy-tests"

bash test-chat.sh \
  --label tokens-tier-1 \
  --key-var STS_LAB02_TIER1_KEY \
  --mode tokens \
  --expect 100 \
  --max 20
```

```bash
bash test-chat.sh \
  --label tokens-tier-2 \
  --key-var STS_LAB02_TIER2_KEY \
  --mode tokens \
  --expect 200 \
  --max 30
```

```bash
bash test-chat.sh \
  --label tokens-tier-3 \
  --key-var STS_LAB02_TIER3_KEY \
  --mode tokens \
  --expect 400 \
  --max 40
```

## Expected results

- HTTP 200 lines show `total_tokens` and a limit header of 100, 200, or 400.
- The loop stops at HTTP 429 or at the cap.
- The call that crosses the quota is still accepted. The next call is the 429.
- No 429 before the cap means the window reset or the calls stayed under the quota. The cap stays at most 40.
- After tier 1 is rejected, tier 2 and tier 3 still accept calls. Their limits are 200 and 400.

## Explanation of the policy behavior

- `total_tokens` is prompt plus completion. The gateway adds it after the response.
- The group selects the quota: 100, 200, or 400 per 60 seconds. The counter is per consumer.
- Counters stay in memory on this Data Plane.

## Return to the unrestricted baseline

This leaves the Lab 2 provider, model, consumers, groups, and keys in place. It clears both policy lists. Policy objects can remain. They do not run while nothing references them. Run each `kongctl` on its own.

**Preview the model.** Sets `sts-lab02-chat` policies to empty, which detaches `sts-lab02-rate-tokens`.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/02-policy-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/04-model.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/model-baseline.apply-plan.json"
```

**Preview the groups.** Sets each group's policies to empty and keeps the same member.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/06-consumer-groups.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/groups-baseline.apply-plan.json"
```

**Apply both plans**, model first.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/model-baseline.apply-plan.json" \
  --auto-approve \
  --output json
```

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/groups-baseline.apply-plan.json" \
  --auto-approve \
  --output json
```

**Read the result.** The model policy list and the three group policy lists are empty.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-chat \
  --output json \
  --jq '{name, policies}'
```

```bash
for group in sts-lab02-tier-1 sts-lab02-tier-2 sts-lab02-tier-3; do
  kongctl get ai-gateway consumer-groups \
    --gateway-id "$AI_GATEWAY_ID" \
    "$group" \
    --output json \
    --jq '{name, policies}'
done
```

To activate a scenario again, apply that scenario's policy file and then its attachment file, as listed in the introduction. Step 8 removes the Lab 2 resources entirely.
