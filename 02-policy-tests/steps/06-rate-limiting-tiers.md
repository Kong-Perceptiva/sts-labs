# Step 6. Rate limits per consumer group

## Purpose

Replace the single model limit with three group limits: 2, 4, and 6 requests per minute. Each consumer receives the limit of the group it belongs to.

## What will be created or modified

| File | Change |
|---|---|
| `config/04-model.yaml` | Sets `sts-lab02-chat` policies back to empty. This detaches `sts-lab02-rate-basic`. |
| `config/08-policies-rate-tiers.yaml` | Creates `sts-lab02-rate-tier-1`, `sts-lab02-rate-tier-2`, and `sts-lab02-rate-tier-3` |
| `config/08-groups-attach-rate-tiers.yaml` | Attaches those policies to `sts-lab02-tier-1`, `sts-lab02-tier-2`, and `sts-lab02-tier-3` |

Each policy is `rate-limiting`, `limit_by: consumer`, and `policy: local`. The minute values are 2, 4, and 6. Membership stays one consumer per group. The model, provider, and credentials are not recreated. `sts-lab02-rate-basic` can remain on the gateway. After the model update it is not attached, so it does not run.

## Required prerequisites

Step 5 is applied. Do this step before scenario 3. The two `rate-limiting` attachments are the same policy type. This step clears the model attachment instead of leaving both in place.

## Commands to preview changes

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/02-policy-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/04-model.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/model-baseline.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/08-policies-rate-tiers.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/rate-tiers.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/08-groups-attach-rate-tiers.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/groups-rate-tiers.apply-plan.json"
```

Read the three previews before applying them. The model plan updates `policies` to empty. The policy plan creates the three tier policies. The group plan updates each group's `policies` list and keeps the existing member. It should not create new consumers.

## Commands to apply changes

Apply in this order. The model detach runs before the group policies are attached.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/model-baseline.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/rate-tiers.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/groups-rate-tiers.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

The model policy list is empty. The groups list the tier policies.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-chat \
  --output json \
  --jq '{name, policies}'

for group in sts-lab02-tier-1 sts-lab02-tier-2 sts-lab02-tier-3; do
  kongctl get ai-gateway consumer-groups \
    --gateway-id "$AI_GATEWAY_ID" \
    "$group" \
    --output json \
    --jq '{name, policies}'
done
```

Expected group policies: `sts-lab02-rate-tier-1`, `sts-lab02-rate-tier-2`, `sts-lab02-rate-tier-3`.

```bash
for policy in sts-lab02-rate-tier-1 sts-lab02-rate-tier-2 sts-lab02-rate-tier-3; do
  kongctl get ai-gateway policies \
    --gateway-id "$AI_GATEWAY_ID" \
    "$policy" \
    --output json \
    --jq '{name, type, minute: .config.minute, limit_by: .config.limit_by, policy: .config.policy}'
done
```

The minute values are 2, 4, and 6. `limit_by` is `consumer` on all three.

## Check Data Plane sync

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

`sync` must be `STATE_IN_SYNC`. If scenario 1 just filled a counter, wait until that minute window ends or let `test-chat.sh` honor the reset header. The new policies have their own counters. An old 429 from scenario 1 is not the result to read after sync completes.

## HTTP test requests

One loop per tier. The loop length is the tier limit plus one, and it stops on HTTP 429. The caps are 3, 5, and 7. One line per request: number, HTTP status, `X-RateLimit-Limit-Minute`, `X-RateLimit-Remaining-Minute`, and `RateLimit-Reset`. Other headers and the body are omitted.

```bash
cd "$LABS_DIR/02-policy-tests"

bash test-chat.sh \
  --label tier-1 \
  --key-var STS_LAB02_TIER1_KEY \
  --mode requests \
  --expect 2 \
  --max 3

bash test-chat.sh \
  --label tier-2 \
  --key-var STS_LAB02_TIER2_KEY \
  --mode requests \
  --expect 4 \
  --max 5

bash test-chat.sh \
  --label tier-3 \
  --key-var STS_LAB02_TIER3_KEY \
  --mode requests \
  --expect 6 \
  --max 7
```

A single call, if you want the headers before the loop, is the same `curl` as step 5 with `$STS_LAB02_TIER2_KEY` or `$STS_LAB02_TIER3_KEY` in the `apikey` header.

## Expected results

| Consumer | `X-RateLimit-Limit-Minute` | From a fresh window |
|---|---:|---|
| `sts-lab02-consumer-t1` | 2 | 2 accepted calls, then HTTP 429 |
| `sts-lab02-consumer-t2` | 4 | 4 accepted calls, then HTTP 429 |
| `sts-lab02-consumer-t3` | 6 | 6 accepted calls, then HTTP 429 |

The 429 body is `{ "message": "API rate limit exceeded" }`. `RateLimit-Remaining` on that consumer reaches 0. Another tier's remaining count stays at that tier's own limit when that tier has not called yet. Run the three commands in one minute so a reset does not start a new window in the middle of a series. If the script waits on request 1, the counter from an earlier attempt was already spent. Read the series after that wait.

## Explanation of the policy behavior

The group attachment selects which policy runs for a member. `limit_by: consumer` still counts per consumer. The three consumers do not share a counter inside a tier, and they do not share a counter across tiers. `limit_by: consumer-group` would be one counter for every member of the group. These three policies do not set that value. With one member in each group, the limit you observe is the tier limit, and it is that member's counter.

A group-scoped policy runs for that consumer on the requests the gateway authenticates as that consumer. These three consumers are the Lab 2 keys. The model policy from scenario 1 is cleared first so the only `rate-limiting` policies in effect are the three group policies.

`policy: local` again keeps each counter on this Data Plane node.
