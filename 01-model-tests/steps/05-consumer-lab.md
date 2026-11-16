# Step 5. Lab consumer

The load command reads `$LABS_DIR/.env`.

This step creates the gateway identity for the lab client. The client is the program that calls the local proxy. In these steps, that program is `curl`. Kong records the client as the consumer `sts-test-app-lab`. The credential `sts-test-app-lab-key` holds the API key, which the client sends in the `apikey` header. Set the key in `$LABS_DIR/.env` as `STS_TEST_APP_KEY`. It is distinct from the OpenAI provider key and from the Konnect personal access token.

`$LABS_DIR/01-model-tests/config/05-consumer-lab.yaml` creates the consumer and the credential. The file references `STS_TEST_APP_KEY` and does not contain the key. The plan reads the value from the shell.

## Load the API key

Add `STS_TEST_APP_KEY` to `$LABS_DIR/.env` before this command. The name has to be exact. `STS_TEST_API_KEY` is a different variable, and a request that expands the empty one is sent with a blank header.

The command prints the length of the key. It does not print the key.

```bash
set -a
source "$LABS_DIR/.env"
set +a

echo "API key length: ${#STS_TEST_APP_KEY}"
```

## Preview the consumer

`kongctl plan` compares `$LABS_DIR/01-model-tests/config/05-consumer-lab.yaml` with the gateway and writes the difference to `$LABS_DIR/01-model-tests/plans/consumer-lab.apply-plan.json`. Konnect is not changed. The API key is not written into that file. `plans/` is not committed.

`--mode apply` limits the preview to this consumer and its credential. Without it, sync mode also deletes gateway resources that are not in the file.

```bash
mkdir -p "$LABS_DIR/01-model-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/01-model-tests/config/05-consumer-lab.yaml" \
  --output-file "$LABS_DIR/01-model-tests/plans/consumer-lab.apply-plan.json"
```

Read the preview before continuing. It should create `sts-test-app-lab` and `sts-test-app-lab-key`, and nothing else. The credential is listed after the consumer, because it needs the consumer that this same apply creates. The credential has no expiry.

## Apply the preview

`kongctl apply` performs the saved preview. It does not read the YAML again. The preview already includes the API key write, so do not add `--write-secrets`. That flag is rejected together with `--plan`. Konnect does not return the key.

```bash
kongctl apply \
  --plan "$LABS_DIR/01-model-tests/plans/consumer-lab.apply-plan.json" \
  --auto-approve \
  --output json
```

## Check the consumer

This prints the consumer name and type. It does not print the key.

```bash
kongctl get ai-gateway consumers \
  --gateway-id "$AI_GATEWAY_ID" \
  --columns "NAME=.name,TYPE=.type"
```

The row is `sts-test-app-lab` / `api-key`.

## Check Data Plane sync

The local Data Plane has to receive the consumer before the proxy will accept the key. `sync` must reach `STATE_IN_SYNC`. That can take a short interval after apply.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## Call chat through the proxy

`curl` calls `$PROXY/v1/chat/completions`. A completion is the text the model generates from the messages in the request. This call asks `sts-chat-lab` for one word. `jq` prints the model that answered, that text, and why generation stopped.

```bash
curl --silent --show-error --max-time 60 \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_TEST_APP_KEY" \
  --data '{"model":"sts-chat-lab","messages":[{"role":"user","content":"Reply with one word: ok"}],"max_tokens":8}' \
  | jq '{model, reply: .choices[0].message.content, finish_reason: .choices[0].finish_reason}'
```

`reply` is a short affirmation. The wording varies between calls: `ok`, `Okay!`, and `Sure!` are all valid. `finish_reason` is `stop`. `model` is `gpt-4o-mini` or a dated snapshot, such as `gpt-4o-mini-2024-07-18`.
