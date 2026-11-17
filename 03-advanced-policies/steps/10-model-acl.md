# Step 10. Model ACL

## Objective

Show that a valid API key and permission to call the model are different checks. Both consumers authenticate. Only `sts-lab03-group-allowed` may call `sts-lab03-chat`.

## Policy behavior

This step does not create an AI Policy. It sets `access.acls.allow` on the model to `sts-lab03-group-allowed`. The docs require exactly one of `allow`, `deny`, `allow_when`, or `deny_when`. This file uses the static allow list.

`sts-lab03-consumer-allowed` is in that group. `sts-lab03-consumer-denied` is in `sts-lab03-group-denied` and is not on the allow list. A denied authenticated caller gets HTTP 403. A missing or unknown `apikey` fails in `sts-lab03-key-auth` before the ACL runs. That failure is HTTP 401.

## Dependencies

None. Consumers and groups already exist from step 4.

## Configuration being created

| File | Change |
|---|---|
| `config/10-model-acl.yaml` | Same model, plus `access.acls.allow: [sts-lab03-group-allowed]` |

`policies` stays empty.

## Activation commands

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/03-advanced-policies/plans" "$LABS_DIR/03-advanced-policies/artifacts"
```

If another exercise is active, follow [Return to baseline](00-lab-intro.md#return-to-baseline) first. After step 4, proceed directly.

**Set the allow list.** Read the plan. It updates `sts-lab03-chat`. It does not create a consumer.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/10-model-acl.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-acl.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-acl.apply-plan.json" \
  --auto-approve \
  --output json
```

## Configuration verification

This read checks the model ACL: `allow` is `sts-lab03-group-allowed` and `policies` is empty.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-chat \
  --output json \
  --jq '{name, policies, allow: .access.acls.allow}'
```

Wait until node `sync` is `STATE_IN_SYNC`.

## Positive test

**Allowed key.** Authentication succeeds and the ACL allows the group. Expect HTTP 200. The key is not printed.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/10-allowed.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":16}'
```

## Negative test

**Denied key.** Authentication succeeds. The ACL rejects the group. Expect HTTP 403.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/10-denied.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_DENIED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":16}'
```

**No key.** Authentication fails. Expect HTTP 401.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/10-missing.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":16}'
```

**Unknown key.** The value is the literal `invalid`. Expect HTTP 401.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/10-invalid.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header 'apikey: invalid' \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":16}'
```

## Expected results

- Allowed key: HTTP 200.
- Denied key: HTTP 403.
- Missing key and `apikey: invalid`: HTTP 401.

## Troubleshooting

HTTP 200 for the denied consumer means the ACL is not on the model yet or the node is not in sync. HTTP 403 for the allowed consumer means that consumer is not a member of `sts-lab03-group-allowed`. Re-check the membership command in step 4.

## Return to baseline

Follow [Return to baseline](00-lab-intro.md#return-to-baseline) to clear this exercise.
