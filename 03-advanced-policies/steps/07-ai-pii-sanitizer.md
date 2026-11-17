# Step 7. AI PII Sanitizer

## Objective

Replace synthetic email, phone, and card text with placeholders before the prompt is sent to OpenAI. The model reply is a demonstration. The PII service response is the check that redaction happened.

## Policy behavior

`sts-lab03-pii-sanitizer` sends the request text to the Kong AI PII service. `sanitization_mode` is `INPUT`. `redact_type` is `placeholder`. `recover_redacted` is false, so the original values are not put back into the model response. `block_if_detected` is false: the call continues after redaction. `anonymize` is `email`, `phone`, and `creditcard`. `skip_logging_sanitized_items` is true.

The service image is `kong/ai-pii-service:v0.3.1-en`. It listens on container port 8080. This lab publishes `127.0.0.1:18080`. The Data Plane uses `STS_LAB03_PII_HOST` port `18080`. `localhost` inside the Data Plane container is the Data Plane itself, not this service.

The image needs about 600 MB of free memory. The first start loads the English model.

## Dependencies

Docker, and the published image above. Do not start it before this step.

## Configuration being created

| File | Change |
|---|---|
| `config/07-policy-pii-sanitizer.yaml` | Creates `sts-lab03-pii-sanitizer` |
| `config/07-model-attach-pii-sanitizer.yaml` | Attaches it to `sts-lab03-chat` |

## Start the PII service

```bash
docker run -d --name sts-lab03-pii \
  -p 127.0.0.1:18080:8080 \
  kong/ai-pii-service:v0.3.1-en
```

**Preflight.** `GET /llm/v1/status` returns `status` `ok` when the model is loaded. Then sanitize the synthetic record directly. The sanitize body puts the redacted string at `.text[0].sanitized_text`, not in `.text` itself. `.text` is an array. The check prints that string, the entity types, and whether the original email or the card digits remain. It does not print a copy of the card number.

```bash
curl --silent --show-error --max-time 30 \
  http://127.0.0.1:18080/llm/v1/status
echo
```

```bash
mkdir -p "$LABS_DIR/03-advanced-policies/artifacts"

curl --silent --show-error --max-time 60 \
  --output "$LABS_DIR/03-advanced-policies/artifacts/07-service.json" \
  http://127.0.0.1:18080/llm/v1/sanitize \
  --header 'Content-Type: application/json' \
  --data '{"text":"Email demo.person@example.com. Phone +1 202 555 0142. Card 4111 1111 1111 1111.","anonymize":["email","phone","creditcard"],"options":{"redact_type":"placeholder"}}'

jq '{
  identified: .identified_pii,
  sanitized: .text[0].sanitized_text,
  email_still_present: (.text[0].sanitized_text | contains("demo.person@example.com")),
  card_still_present: (.text[0].sanitized_text | contains("4111"))
}' "$LABS_DIR/03-advanced-policies/artifacts/07-service.json"
```

`email_still_present` and `card_still_present` are `false`. `sanitized` uses `PLACEHOLDER` tokens. `identified_pii` lists `email`, `phone`, and `creditcard`. It can also list `general`.

## Activation commands

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/03-advanced-policies/plans" "$LABS_DIR/03-advanced-policies/artifacts"
```

If another exercise is active, follow [Return to baseline](00-lab-intro.md#return-to-baseline) first. After step 4, proceed directly.

**Create the policy.**

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/07-policy-pii-sanitizer.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/pii-sanitizer.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/pii-sanitizer.apply-plan.json" \
  --auto-approve \
  --output json
```

**Attach it to the model.**

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/07-model-attach-pii-sanitizer.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-pii.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-pii.apply-plan.json" \
  --auto-approve \
  --output json
```

## Configuration verification

These reads check the sanitizer settings:

- the model lists only `sts-lab03-pii-sanitizer`
- mode is `INPUT`, redact type is `placeholder`, recovery is false, and the three entity types are set

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
  sts-lab03-pii-sanitizer \
  --output json \
  --jq '{
    name,
    type,
    mode: .config.sanitization_mode,
    redact_type: .config.redact_type,
    recover: .config.recover_redacted,
    anonymize: .config.anonymize,
    host: .config.host,
    port: .config.port
  }'
```

Wait until node `sync` is `STATE_IN_SYNC`.

## Positive test

**No PII.** Expect HTTP 200.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/07-plain.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Explain what an API gateway does, in two sentences."}],"max_tokens":80}'
```

## Comparison test

**Email and phone.** Ask the model to repeat only the contact fields. A placeholder in the reply supports the service check above. It is not proof by itself.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/07-contact.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Repeat only the email and phone from this fictional record. Email: demo.person@example.com Phone: +1 202 555 0142"}],"max_tokens":40}'
```

```bash
jq '{content: .choices[0].message.content}' "$LABS_DIR/03-advanced-policies/artifacts/07-contact.json"
```

**Card number.** Same idea for the synthetic test card `4111 1111 1111 1111`.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/07-card.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Repeat only the card number from this fictional record: 4111 1111 1111 1111"}],"max_tokens":40}'
```

```bash
jq '{content: .choices[0].message.content}' "$LABS_DIR/03-advanced-policies/artifacts/07-card.json"
```

To see the same prompt with the sanitizer off, return to the baseline at the bottom of this step and send the card prompt once. Do not use a real card or a real person.

## Expected results

- The direct service check reports the detected types and `false` for the original email and the card digits still being present.
- The plain prompt is HTTP 200.
- The contact and card replies should show placeholders such as `EMAIL` or `PLACEHOLDER`, not the original values. If the model still echoes the original, confirm that the policy is attached and synchronized, then check Data Plane connectivity to port 18080. The direct check covers the service only.

## Troubleshooting

`/llm/v1/status` failing means the container is still loading the model. HTTP 500 from the proxy usually means the Data Plane cannot resolve `STS_LAB03_PII_HOST`. On a Linux engine without `host.docker.internal`, publish the port and set that variable to a host the Data Plane can route to, then re-apply the policy file.

## Return to baseline

Follow [Return to baseline](00-lab-intro.md#return-to-baseline). For the comparison, resend the same synthetic card prompt after the Data Plane synchronizes.
