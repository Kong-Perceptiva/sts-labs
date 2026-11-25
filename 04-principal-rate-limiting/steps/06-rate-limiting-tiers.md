# Step 6. Rate limits per principal tier

## Purpose

Replace the single limit of 3 with tier limits of 2, 4, and 6 requests per 60 seconds. A principal stores only its tier name (`t1`, `t2`, or `t3`). The policy stores the limits and maps the tier name to the correct limit. Counters stay separate per principal.

## What will be created or modified

| File | Change |
|---|---|
| `config/08-policy-rate-tiers.yaml` | Creates `sts-lab04-rate-tiers` |
| `config/08-model-attach-rate-tiers.yaml` | Sets `sts-lab04-chat` policies to `sts-lab04-rate-tiers` |

The policy is `rate-limiting-advanced` with a fixed 60-second window and local counters. The CEL expression in `expressions.limit` reads the authenticated principal on every request and maps `principal.metadata.tier` as follows:

- `t1` selects 2 requests.
- `t2` selects 4 requests.
- `t3` selects 6 requests.
- A missing or unrecognized tier selects 2, the most restrictive configured limit.

The static `config.limit` value `[2]` is the fallback if CEL cannot be evaluated. Both the explicit unknown-tier result and the evaluation fallback are therefore no more permissive than T1.

`identifier: principal` answers a different question from the CEL expression. CEL chooses **how large the limit is**. `identifier: principal` chooses **which caller owns the counter**. Two principals with tier `t2` both receive a limit of 4, but each receives an independent counter.

## Why this replaces the Consumer Groups from Lab 2

Lab 2 scenario 2 uses three AI Consumer Groups and three `rate-limiting` policies:

- Membership in `sts-lab02-tier-1`, `sts-lab02-tier-2`, or `sts-lab02-tier-3` selects the policy with limit 2, 4, or 6.
- Each selected policy still has `limit_by: consumer`.
- Consequently, the group selects the limit, but consumers in the same group do not share a counter.

There is no equivalent policy attachment for Kong Identity principals. An Identity group cannot hold an AI Gateway policy, and the basic `rate-limiting` policy does not support `limit_by: principal`. Creating Identity groups would therefore not reproduce the Lab 2 attachment model.

Lab 4 reproduces the observable behavior without creating a group:

- `principal.metadata.tier` replaces Consumer Group membership as the tier selector.
- One CEL expression replaces the three group-attached request policies.
- `identifier: principal` replaces `limit_by: consumer` as the per-caller counter identity.

This is an emulation of the **tier-selection behavior**, not an Identity-group implementation. No group object or shared group counter exists in this scenario. Changing a principal from one tier to another means changing only its `metadata.tier`. Changing the numeric values 2, 4, or 6 means editing only `config/08-policy-rate-tiers.yaml`; the numbers must not be copied into principal metadata.

The model attachment is replaced with `sts-lab04-rate-tiers`, so the scenario 1 policy can remain stored on the gateway without running.

## Required prerequisites

Step 5 is applied. The three principals already have `tier` values `t1`, `t2`, and `t3` from step 3. Do this step before scenario 3. Leaving `sts-lab04-rate-basic` attached together with this policy would apply both request limits. The attachment file lists only `sts-lab04-rate-tiers`.

## Commands to preview changes

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/04-principal-rate-limiting/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/08-policy-rate-tiers.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/rate-tiers.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/04-principal-rate-limiting/config/08-model-attach-rate-tiers.yaml" \
  --output-file "$LABS_DIR/04-principal-rate-limiting/plans/model-rate-tiers.apply-plan.json"
```

Read both previews before applying them. The policy plan creates `sts-lab04-rate-tiers`. The model plan updates `policies` to that one name. It should not create a new model.

If the policy plan rejects `expressions`, stop. That field contains the tier-to-limit expression. Do not replace the policy with an AI Consumer or a `rate-limiting` policy, and do not move 2, 4, or 6 back into principal metadata.

## Commands to apply changes

Apply the policy first, then the model.

```bash
kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/rate-tiers.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/04-principal-rate-limiting/plans/model-rate-tiers.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

The model policy list is `sts-lab04-rate-tiers`. The expression and the fallback limit are on the policy.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-chat \
  --output json \
  --jq '{name, policies}'
```

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab04-rate-tiers \
  --output json \
  --jq '{name, type, identifier: .config.identifier, window_type: .config.window_type, limit: .config.limit, window_size: .config.window_size, expressions}'
```

`type` is `rate-limiting-advanced`. `identifier` is `principal`. `window_type` is `fixed`. `limit` is `[2]`. `window_size` is `[60]`. `expressions.limit` contains the comparisons for `"t3"`, `"t2"`, and `"t1"`, returning 6, 4, and 2. Its final result is also 2.

## Check Data Plane sync

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

`sync` must be `STATE_IN_SYNC`. This policy has different counters from scenario 1, so a previous HTTP 429 does not prove that scenario 2 is active. Read the limit header from a new call after synchronization.

## HTTP test requests

One loop per principal. The loop length is the tier limit plus one, and it stops on HTTP 429. The caps are 3, 5, and 7. One line per request: number, HTTP status, `X-RateLimit-Limit-Minute`, `X-RateLimit-Remaining-Minute`, and `RateLimit-Reset`. Other headers and the body are omitted.

```bash
cd "$LABS_DIR/04-principal-rate-limiting"

bash test-chat.sh \
  --label tier-1 \
  --key-var STS_LAB04_TIER1_KEY \
  --mode requests \
  --expect 2 \
  --max 3

bash test-chat.sh \
  --label tier-2 \
  --key-var STS_LAB04_TIER2_KEY \
  --mode requests \
  --expect 4 \
  --max 5

bash test-chat.sh \
  --label tier-3 \
  --key-var STS_LAB04_TIER3_KEY \
  --mode requests \
  --expect 6 \
  --max 7
```

A single call, if you want the headers before the loop, is the same `curl` as step 5 with `$STS_LAB04_TIER2_KEY` or `$STS_LAB04_TIER3_KEY` in the `apikey` header.

## Expected results

| Principal | `X-RateLimit-Limit-Minute` | From a fresh window |
|---|---:|---|
| `sts-lab04-principal-t1` | 2 | 2 accepted calls, then HTTP 429 |
| `sts-lab04-principal-t2` | 4 | 4 accepted calls, then HTTP 429 |
| `sts-lab04-principal-t3` | 6 | 6 accepted calls, then HTTP 429 |

The 429 body is `{ "message": "API rate limit exceeded" }`. `RateLimit-Remaining` reaches 0 only for the principal being tested. Run the three loops close together when comparing their counters, but read each loop independently. If its first request is already rejected, the script waits for a short reset and repeats that loop.

Principal 2 must report a limit of 4 and principal 3 a limit of 6. If either reports 2, the expression did not match that principal's tier and used the restrictive result. Re-check `metadata.tier` from step 3. Principal 1 also reports 2; that is the configured T1 result. A missing tier would report 2 as well, so principal 1's header alone does not prove which branch ran.

## Explanation of the policy behavior

`principal.metadata.tier` selects the tier, and the policy expression selects the request limit for that tier. `identifier: principal` selects the counter key. Two principals with the same tier therefore receive the same limit but do not spend the same counter. This scenario does not create or use a shared group counter. The three loops below use one principal per tier, so they show both the tier limits and that one principal's traffic does not reduce another principal's remaining count.

`strategy: local` again keeps each counter on this Data Plane node. The response headers show which limit and which remaining count applied to the principal that sent the call.
