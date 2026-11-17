# Step 8. AI Prompt Template

## Objective

Call two managed templates, reuse one of them with a different variable, and show that a free-form chat message is rejected.

## Policy behavior

`sts-lab03-prompt-template` replaces `messages` when the client sends `{template://<name>}` plus `properties`. `allow_untemplated_requests` is false, so a normal `messages` array returns HTTP 400.

| Template | Variables | Prompt it builds |
|---|---|---|
| `sts-lab03-api-explainer` | `technology`, `audience` | Explain that technology for that audience. |
| `sts-lab03-api-review` | `api_description`, `review_focus` | A short review of that description. |

The model field stays `sts-lab03-chat`. The template reference replaces `messages`, not the model name.

## Dependencies

None. No container.

## Configuration being created

| File | Change |
|---|---|
| `config/08-policy-prompt-template.yaml` | Creates the policy, with both templates inside it |
| `config/08-model-attach-prompt-template.yaml` | Attaches that policy to `sts-lab03-chat` |

## Activation commands

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/03-advanced-policies/plans" "$LABS_DIR/03-advanced-policies/artifacts"
```

If another exercise is active, follow [Return to baseline](00-lab-intro.md#return-to-baseline) first. After step 4, proceed directly.

**Create the policy, including the templates.** This apply creates `sts-lab03-prompt-template`. The two templates are entries in that policy's `config.templates`, not separate resources. `sts-lab03-api-explainer` and `sts-lab03-api-review` exist when this apply finishes. No later command creates them. The plan shows one policy create and both template names.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/08-policy-prompt-template.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/prompt-template.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/prompt-template.apply-plan.json" \
  --auto-approve \
  --output json
```

**Attach the policy to the model.** The templates are already stored. This apply only sets the policy list of `sts-lab03-chat` to `sts-lab03-prompt-template`. Until it finishes, a call to the model does not use them.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/08-model-attach-prompt-template.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-template.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-template.apply-plan.json" \
  --auto-approve \
  --output json
```

## Configuration verification

These reads check the template policy:

- the model lists only `sts-lab03-prompt-template`
- untemplated requests are disabled
- the template names are `sts-lab03-api-explainer` and `sts-lab03-api-review`

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
  sts-lab03-prompt-template \
  --output json \
  --jq '{name, type, allow_untemplated_requests: .config.allow_untemplated_requests, templates: [.config.templates[].name]}'
```

Wait until node `sync` is `STATE_IN_SYNC`. The `templates` list from the read above is the proof that both templates exist before any call.

## Positive test

These calls do not create a template. `messages` is a string such as `{template://sts-lab03-api-explainer}`. The gateway finds that name in the policy, replaces `{{technology}}` and `{{audience}}` with the `properties` in the request, and sends the resulting messages upstream. Another `properties` object reuses the same stored template.

**Template A.** Explains Kong AI Gateway for junior developers. Expect HTTP 200. The reply is the model's wording of the stored sentence, filled with these two properties.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/08-explainer.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":"{template://sts-lab03-api-explainer}","properties":{"technology":"Kong AI Gateway","audience":"junior developers"},"max_tokens":80}'
```

```bash
jq '{content: .choices[0].message.content}' "$LABS_DIR/03-advanced-policies/artifacts/08-explainer.json"
```

**Template B.** Reviews a one-line fictional API.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/08-review.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":"{template://sts-lab03-api-review}","properties":{"api_description":"POST /parcels creates one parcel order and returns a tracking number.","review_focus":"idempotency"},"max_tokens":80}'
```

**Same template, other value.** Template A again, for a different audience. This shows reuse, not a second policy.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/08-explainer-again.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":"{template://sts-lab03-api-explainer}","properties":{"technology":"a load balancer","audience":"finance managers"},"max_tokens":80}'
```

## Negative test

**No template.** A normal user message. Expect HTTP 400.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/08-free.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":16}'
```

## Expected results

- Both explainer calls and the review call are HTTP 200. The wording is the model's, so do not match it exactly.
- The free-form call is HTTP 400.

## Troubleshooting

HTTP 200 on the free-form call means `allow_untemplated_requests` is still true or the policy is not attached. HTTP 400 on a template call usually means the template name or a property name does not match the policy.

## Return to baseline

Follow [Return to baseline](00-lab-intro.md#return-to-baseline) to clear this exercise.
