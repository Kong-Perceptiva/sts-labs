# Step 4. Lab models

The first command loads `$LABS_DIR/.env`. The auth strategy `sts-key-auth-lab` must already exist. `$LABS_DIR/01-model-tests/config/04-models-lab.yaml` does not create it. Each model names that strategy.

These are copies of the model specs. The `-lab` suffix keeps them apart from `sts-tts`, `sts-stt`, `sts-voice`, and `sts-chat`. The name in the client request is the lab name. The upstream model stays the one from the spec.

| Lab name | What the client sends | Upstream model |
|---|---|---|
| `sts-tts-lab` | `"model": "sts-tts-lab"` | `tts-1` |
| `sts-stt-lab` | `"model": "sts-stt-lab"` | `whisper-1` |
| `sts-voice-lab` | WebSocket on `/v1` | `gpt-realtime-2.1` |
| `sts-chat-lab` | `"model": "sts-chat-lab"` | `gpt-4o-mini` |

## Preview the lab models

`kongctl plan` compares `$LABS_DIR/01-model-tests/config/04-models-lab.yaml` with the gateway and writes the difference to `$LABS_DIR/01-model-tests/plans/models-lab.apply-plan.json`. Konnect is not changed. `--mode apply` limits the preview to these models. Without it, sync mode also deletes gateway resources that are not in the file.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/01-model-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/01-model-tests/config/04-models-lab.yaml" \
  --output-file "$LABS_DIR/01-model-tests/plans/models-lab.apply-plan.json"
```

Read the preview before continuing. It should create the four models and nothing else.

## Apply the preview

`kongctl apply` performs the saved preview. Do not add `--write-secrets`. This file has no secret, and that flag is rejected together with `--plan`.

```bash
kongctl apply \
  --plan "$LABS_DIR/01-model-tests/plans/models-lab.apply-plan.json" \
  --auto-approve \
  --output json
```

## Check the models

This prints one row per model: the lab name, the upstream OpenAI model, and the provider. The four rows should be `sts-tts-lab` / `tts-1`, `sts-stt-lab` / `whisper-1`, `sts-voice-lab` / `gpt-realtime-2.1`, and `sts-chat-lab` / `gpt-4o-mini`. The provider column is `openai-lab`.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  --columns "NAME=.name,TARGET=.targets[0].name,PROVIDER=.targets[0].provider"
```
