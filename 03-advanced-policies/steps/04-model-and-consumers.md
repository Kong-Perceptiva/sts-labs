# Step 4. Model, consumers, and one chat call

## Purpose

Create `sts-lab03-chat`, two consumers with their own API keys, and two groups. The model has no policy and no ACL. One chat call shows that the route works before any exercise.

## What will be created or modified

| File | Change |
|---|---|
| `config/05-consumers.yaml` | `sts-lab03-consumer-allowed` and `sts-lab03-consumer-denied` |
| `config/05-consumer-groups.yaml` | `sts-lab03-group-allowed` and `sts-lab03-group-denied` |
| `config/04-model-baseline.yaml` | `sts-lab03-chat` with `policies: []` and no ACL |

## Required prerequisites

Step 3 is applied. `$LABS_DIR/.env` is loaded in this shell.

## Generate the two client keys

Run this once. For each name that is missing or empty, it appends a new key to `$LABS_DIR/.env`. A name that already has a value is left as it is. The command prints the lengths, not the keys.

```bash
umask 077
touch "$LABS_DIR/.env"
if [[ -s "$LABS_DIR/.env" && -n "$(tail -c 1 "$LABS_DIR/.env")" ]]; then
  printf '\n' >>"$LABS_DIR/.env"
fi
for name in STS_LAB03_ALLOWED_KEY STS_LAB03_DENIED_KEY; do
  if ! grep -q "^${name}=..*" "$LABS_DIR/.env"; then
    printf '%s=%s\n' "$name" "$(openssl rand -hex 24)" >>"$LABS_DIR/.env"
  fi
done

set -a
source "$LABS_DIR/.env"
set +a

echo "allowed key length: ${#STS_LAB03_ALLOWED_KEY}"
echo "denied key length: ${#STS_LAB03_DENIED_KEY}"
```

A length of 0 means that name is empty. A key written by this block is 48 characters. A key that was already in `.env` keeps its own length.

## Commands to preview changes

Three plans. Konnect is not changed. The API keys are not written into the plan files.

**Consumers.** Creates the two consumers and their credentials.

`mkdir` creates `plans/` first. `kongctl` does not create that directory.

```bash
mkdir -p "$LABS_DIR/03-advanced-policies/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/05-consumers.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/consumers.apply-plan.json"
```

**Groups.** Puts one consumer in each group. Group policy lists stay empty.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/05-consumer-groups.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/consumer-groups.apply-plan.json"
```

**Model.** Creates `sts-lab03-chat` with an empty policy list.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/04-model-baseline.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-baseline.apply-plan.json"
```

## Commands to apply changes

Same three plans, in the same order.

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/consumers.apply-plan.json" \
  --auto-approve \
  --output json
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/consumer-groups.apply-plan.json" \
  --auto-approve \
  --output json
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-baseline.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

These reads check the unrestricted baseline:

- the model policy list is empty and `access` has no `acls`
- each group lists one consumer name and an empty policy list

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-chat \
  --output json \
  --jq '{name, policies, acls: .access.acls}'
```

```bash
for group in sts-lab03-group-allowed sts-lab03-group-denied; do
  group_id="$(kongctl get ai-gateway consumer-groups \
    --gateway-id "$AI_GATEWAY_ID" \
    "$group" \
    --output json \
    --jq .id \
    --jq-raw-output)"
  echo "$group members:"
  kongctl api get "/v1/ai-gateways/${AI_GATEWAY_ID}/consumer-groups/${group_id}/consumers" \
    --output json \
    --jq '[.data[].name]'
done
```

## Check Data Plane sync

`sync` must be `STATE_IN_SYNC` before the chat call.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

One chat call from the allowed consumer. It sends the text `Reply with one word: OK` to `sts-lab03-chat` and prints the status line, the headers, and the body.

```bash
curl --silent --show-error --include --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":16}'
```

## Expected results

The model policies list is `[]` and `acls` is null or absent. `sts-lab03-group-allowed` contains `sts-lab03-consumer-allowed`. `sts-lab03-group-denied` contains `sts-lab03-consumer-denied`. The chat call is HTTP 200, `finish_reason` is `stop` or `length`, and `usage.total_tokens` is a number.
