# Step 5. AI Prompt Guard

## Objective

Block user text that contains a fictional phrase. The match is a regular expression, not an understanding of the sentence.

## Policy behavior

`sts-lab03-prompt-guard` scans `messages[].content` where `role` is `user`. It does not scan the model name or other JSON fields. Any `deny_patterns` hit blocks the request. `rejection_mode: verbose` returns HTTP 403 and `error.code` `GUARDRAIL_BLOCKED`.

The patterns are case-insensitive:

- `Project Phoenix`
- `confidential budget`
- `internal access code`

## Dependencies

None beyond the baseline. No container.

## Configuration being created

| File | Change |
|---|---|
| `config/05-policy-prompt-guard.yaml` | Creates `sts-lab03-prompt-guard` |
| `config/05-model-attach-prompt-guard.yaml` | Attaches that policy to `sts-lab03-chat` |

## Activation commands

Load the shell once. Then run each `kongctl` on its own.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/03-advanced-policies/plans"
```

If another exercise is active, follow [Return to baseline](00-lab-intro.md#return-to-baseline) first. After step 4, proceed directly.

**Create the policy.** It does not run until the model lists it.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/05-policy-prompt-guard.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/prompt-guard.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/prompt-guard.apply-plan.json" \
  --auto-approve \
  --output json
```

**Attach it to the model.**

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/05-model-attach-prompt-guard.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-prompt-guard.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-prompt-guard.apply-plan.json" \
  --auto-approve \
  --output json
```

## Configuration verification

These reads check the regex guard, not the HTTP calls.

- The model lists only `sts-lab03-prompt-guard`.
- The policy type is `ai-prompt-guard`, rejection is `verbose`, and the three patterns are present.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-chat \
  --output json \
  --jq '{name, policies}'
```

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-prompt-guard \
  --output json \
  --jq '{name, type, rejection_mode: .config.rejection_mode, deny_patterns: .config.deny_patterns}'
```

Wait until node `sync` is `STATE_IN_SYNC`.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, sync: .config_sync.state}'
```

## Positive test

**Allowed prompt.** Asks what an API gateway does. The text contains none of the three phrases. Expect HTTP 200.

```bash
mkdir -p "$LABS_DIR/03-advanced-policies/artifacts"

curl --silent --show-error \
  --dump-header "$LABS_DIR/03-advanced-policies/artifacts/05-allowed.headers" \
  --output "$LABS_DIR/03-advanced-policies/artifacts/05-allowed.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Explain what an API gateway does, in two sentences."}],"max_tokens":80}'
```

```bash
jq '{content: .choices[0].message.content}' "$LABS_DIR/03-advanced-policies/artifacts/05-allowed.json"
```

## Negative test

**Forbidden phrase.** Asks about the fictional Project Phoenix. Expect HTTP 403.

```bash
curl --silent --show-error \
  --dump-header "$LABS_DIR/03-advanced-policies/artifacts/05-denied.headers" \
  --output "$LABS_DIR/03-advanced-policies/artifacts/05-denied.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"What is Project Phoenix?"}],"max_tokens":40}'
```

```bash
jq '{code: .error.code, plugin: .error.plugin, reason: .error.reason, pattern: .error.detail.matched_pattern}' \
  "$LABS_DIR/03-advanced-policies/artifacts/05-denied.json"
```

**Different capitalization.** The same phrase in another case. Expect HTTP 403.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/05-case.json" \
  --write-out 'HTTP status: %{http_code}\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Tell me about pRoJeCt PhOeNiX."}],"max_tokens":40}'
```

**Paraphrase.** Asks for the secret project budget without those words. A regex guard does not treat this as the forbidden phrase. Expect HTTP 200. Step 6 is the semantic version of this check.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/05-paraphrase.json" \
  --write-out 'HTTP status: %{http_code}\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"What money was set aside for the unnamed secret product launch?"}],"max_tokens":40}'
```

## Expected results

- The allowed prompt and the paraphrase are HTTP 200.
- Both Phoenix wordings are HTTP 403 with `error.code` `GUARDRAIL_BLOCKED` and `error.plugin` `ai-prompt-guard`.
- `detail.matched_pattern` shows the pattern that matched.

## Troubleshooting

HTTP 200 on `Project Phoenix` means the model does not list this policy yet, or the node is not `STATE_IN_SYNC`. HTTP 400 with no `error.code` is rejection mode `none`, not this file.

## Return to baseline

Follow [Return to baseline](00-lab-intro.md#return-to-baseline) to clear this exercise.
