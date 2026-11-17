# Step 3. Auth strategy, consumers, and groups

## Purpose

Create the client identity for Lab 2. Three consumers each have their own API key. Three consumer groups each have one of those consumers. Group policies stay empty until step 6.

## What will be created or modified

| File | Resources |
|---|---|
| `config/03-auth-strategy.yaml` | Auth strategy `sts-lab02-key-auth` |
| `config/05-consumers.yaml` | `sts-lab02-consumer-t1`, `sts-lab02-consumer-t2`, `sts-lab02-consumer-t3`, and one API key credential on each |
| `config/06-consumer-groups.yaml` | `sts-lab02-tier-1`, `sts-lab02-tier-2`, `sts-lab02-tier-3`, with one member each and `policies: []` |

The auth strategy expects the header `apikey` and sets `hide_credentials` to true. It does not create the consumers. The consumer file does not contain the keys. The plan reads `STS_LAB02_TIER1_KEY`, `STS_LAB02_TIER2_KEY`, and `STS_LAB02_TIER3_KEY` from the shell.

## Required prerequisites

Step 2 is complete in this shell, or you load `$LABS_DIR/.env` again below. The provider check in step 2 printed `sts-lab02-openai`.

## Generate the three client keys

Run this once. For each name that is missing or empty, it appends a new key to `$LABS_DIR/.env`. A name that already has a value is left as it is. The command prints the lengths, not the keys.

```bash
umask 077
touch "$LABS_DIR/.env"
if [[ -s "$LABS_DIR/.env" && -n "$(tail -c 1 "$LABS_DIR/.env")" ]]; then
  printf '\n' >>"$LABS_DIR/.env"
fi
for name in STS_LAB02_TIER1_KEY STS_LAB02_TIER2_KEY STS_LAB02_TIER3_KEY; do
  if ! grep -q "^${name}=..*" "$LABS_DIR/.env"; then
    printf '%s=%s\n' "$name" "$(openssl rand -hex 24)" >>"$LABS_DIR/.env"
  fi
done

set -a
source "$LABS_DIR/.env"
set +a

echo "tier 1 key length: ${#STS_LAB02_TIER1_KEY}"
echo "tier 2 key length: ${#STS_LAB02_TIER2_KEY}"
echo "tier 3 key length: ${#STS_LAB02_TIER3_KEY}"
```

A length of 0 means that name is empty. A key written by this block is 48 characters: `openssl rand -hex 24` writes 24 bytes as hexadecimal. A key that was already in `.env` keeps its own length. The names have to be exact.

## Commands to preview changes

Preview the auth strategy, then the consumers, then the groups. Konnect is not changed. The API keys are not written into the plan files.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/02-policy-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/03-auth-strategy.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/auth-strategy.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/05-consumers.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/consumers.apply-plan.json"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/06-consumer-groups.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/consumer-groups.apply-plan.json"
```

Read the three previews. The first creates `sts-lab02-key-auth`. The second creates the three consumers and the credentials `sts-lab02-consumer-t1-key`, `sts-lab02-consumer-t2-key`, and `sts-lab02-consumer-t3-key`. The third creates the three groups. Each group plan lists one consumer name. The group policy lists are empty.

`--mode apply` limits each preview to that file. Without it, sync mode also deletes gateway resources that are not in the file.

## Commands to apply changes

Apply the saved previews in this order. The groups name consumers that the second apply creates. Do not add `--write-secrets`.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/auth-strategy.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/consumers.apply-plan.json" \
  --auto-approve \
  --output json

kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/consumer-groups.apply-plan.json" \
  --auto-approve \
  --output json
```

Konnect does not return the API keys.

## Commands to verify configuration

The strategy name is `sts-lab02-key-auth`, the type is `key-auth`, and the header name is `apikey`.

```bash
kongctl get ai-gateway auth-strategies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-key-auth \
  --output json \
  --jq '{name, type, key_names: .config.key_names, hide_credentials: .config.hide_credentials}'
```

The consumer rows include the three Lab 2 names. The command does not print the keys.

```bash
kongctl get ai-gateway consumers \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(startswith("sts-lab02-"))]'
```

The group body has no member list. Membership is a separate API. `kongctl` 1.28.1 accepts `consumers` on the group YAML as a list of consumer names, removes that list from the group body, and writes it with `POST /v1/ai-gateways/{aiGatewayId}/consumer-groups/{consumerGroupId}/consumers` and `{"consumer":"<name>"}`. This read uses that same sub-resource. It prints member names only.

```bash
for group in sts-lab02-tier-1 sts-lab02-tier-2 sts-lab02-tier-3; do
  group_id="$(kongctl get ai-gateway consumer-groups \
    --gateway-id "$AI_GATEWAY_ID" \
    "$group" \
    --output json \
    --jq .id \
    --jq-raw-output)"

  echo "group $group"
  kongctl api get "/v1/ai-gateways/${AI_GATEWAY_ID}/consumer-groups/${group_id}/consumers" \
    --output json \
    --jq '[.data[].name]'
done
```

The three results are `["sts-lab02-consumer-t1"]`, `["sts-lab02-consumer-t2"]`, and `["sts-lab02-consumer-t3"]`. Each group `policies` list is empty:

```bash
for group in sts-lab02-tier-1 sts-lab02-tier-2 sts-lab02-tier-3; do
  kongctl get ai-gateway consumer-groups \
    --gateway-id "$AI_GATEWAY_ID" \
    "$group" \
    --output json \
    --jq '{name, policies}'
done
```

## HTTP test requests

None in this step. The model does not exist until step 4, so the proxy has no Lab 2 route yet.

## Expected results

`hide_credentials` is `true`. The consumer list contains the three `sts-lab02-consumer-t*` names. Each group has the one matching consumer and an empty `policies` list.

## Explanation of the policy behavior

A consumer group does not, by itself, set a rate. Step 6 puts a `rate-limiting` policy on each group. Until then, membership only records which consumer is in which tier. One consumer belongs to one group, so later match rules select one tier.
