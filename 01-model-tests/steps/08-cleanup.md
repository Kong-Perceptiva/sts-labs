# Step 8. Cleanup (optional)

This step is optional. Skip it when the lab resources should stay on the gateway for another lab. Run it when this lab should be removed.

It removes the lab from the AI Gateway and deletes the files the earlier steps generated inside `$LABS_DIR/01-model-tests`. The YAML under `config/`, the instructions under `steps/`, `test-realtime.py`, and `requirements.txt` stay. `$LABS_DIR/.env` stays. The gateway itself stays. Only the resources named in the four lab files are removed.

`cleanup.sh` does the work. It loads the shared `.env` when `AI_GATEWAY_ID` is not already in the environment, plans each file in delete mode, and performs that plan. A plan with nothing to delete is skipped. The local directories are removed only after the four gateway deletes finish. If a delete fails, the script stops and those directories are left in place.

## What leaves the gateway

Each file is planned with `--mode delete`. That mode removes the resources named in the file. The default plan mode is sync. A sync plan also deletes gateway resources that are absent from the file, including resources this lab never created. The script passes `--mode delete` on every plan, so the rest of the gateway is left as it is.

The order follows the references. The models name the auth strategy and the provider, so the models go first. The consumer and its credential go next. The auth strategy goes after every model that names it. The provider file goes last, and it takes the vault and the Config Store with it.

| File | Removed |
|---|---|
| `$LABS_DIR/01-model-tests/config/04-models-lab.yaml` | `sts-tts-lab`, `sts-stt-lab`, `sts-voice-lab`, `sts-chat-lab` |
| `$LABS_DIR/01-model-tests/config/05-consumer-lab.yaml` | consumer `sts-test-app-lab`, credential `sts-test-app-lab-key` |
| `$LABS_DIR/01-model-tests/config/03-auth-strategy-lab.yaml` | `sts-key-auth-lab` |
| `$LABS_DIR/01-model-tests/config/02-provider-openai.yaml` | provider `openai-lab`, vault `openai-vault`, Config Store `openai-config-store`, secret `openai-auth-header` |

The provider file names `openai-lab`. This delete removes that provider even when step 2 found it already present and skipped the create.

## What leaves the disk

After the gateway deletes, the script removes `plans/`, `artifacts/`, `out/`, `.venv`, `.schema`, and any `__pycache__` directory inside this lab. `plans/` holds the apply previews. `artifacts/` holds the MP3, the PCM input, and the WAV from steps 6 and 7. `.venv` is the Python environment from step 7. The shared `.env` is `$LABS_DIR/.env`, outside this lab, and the script does not remove it.

## Run the cleanup

The first command loads `$LABS_DIR/.env`. The script reads that same file again on its own.

For each file the script writes a delete plan, prints how many changes that plan contains, and runs `kongctl delete --plan` when the count is greater than zero. The plan file is temporary and is removed before the next file. The script then prints one line when the local directories are gone.

```bash
set -a
source "$LABS_DIR/.env"
set +a

bash "$LABS_DIR/01-model-tests/cleanup.sh"
```

The four count lines come first. A count of `0` means that file was already absent. The last line is `Local generated files removed. Shared .env was kept.`

## Check the gateway

Each command prints the lab names that are still on the gateway. An empty list, `[]`, means that group is gone.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-tts-lab" or . == "sts-stt-lab" or . == "sts-voice-lab" or . == "sts-chat-lab")]'
```

```bash
kongctl get ai-gateway consumers \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-test-app-lab")]'
```

```bash
kongctl get ai-gateway auth-strategies \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-key-auth-lab")]'
```

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "openai-lab")]'
```

The provider check prints `[]` when `openai-lab` is gone. A provider of another name is outside this lab and stays out of this list.

## Check the disk

This confirms the generated directories are gone from this lab and `$LABS_DIR/.env` is still in place.

```bash
for path in plans artifacts out .venv .schema; do
  if [[ -e "$LABS_DIR/01-model-tests/$path" ]]; then
    echo "still present: $LABS_DIR/01-model-tests/$path" >&2
  fi
done

test -f "$LABS_DIR/.env"
echo "shared .env is still present"
```
