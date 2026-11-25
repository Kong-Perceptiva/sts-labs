# Step 8. Cleanup (optional)

## Purpose

Remove Lab 4 from the AI Gateway, remove the three Lab 4 principals from the Identity directory, and delete the files the earlier steps generated inside `$LABS_DIR/04-principal-rate-limiting`. Skip this step when the Lab 4 resources should stay.

## What will be created or modified

Nothing is created. `cleanup.sh` deletes the resources named in the canonical YAML files, then removes `plans/`, `artifacts/`, and `out/` in this lab.

The YAML under `config/`, the instructions under `steps/`, `test-chat.sh`, and `cleanup.sh` stay. `$LABS_DIR/.env` stays. The gateway, the Control Plane, the Data Plane, and the Identity directory named `default` stay. Lab 1, Lab 2, and Lab 3 names are not in these files.

## Required prerequisites

`LABS_DIR` is set and `$LABS_DIR/.env` has `AI_GATEWAY_ID` and the Konnect token. The script loads that file itself.

## What leaves Konnect

Each file is planned with `--mode delete`. That mode removes the resources named in the file. A plan with nothing to delete is skipped, so a scenario that was never applied does not fail the cleanup. The default plan mode is sync. The script does not use sync.

The model is deleted before the policies because it holds the active policy attachment. The auth strategy is removed after the model. The provider manifest removes the provider and the vault. `kongctl` cannot directly delete `sts-lab04-config-store` because the AI Gateway is external, so that store stays and the plan prints a warning. The script then deletes only the secret `sts-lab04-openai-auth-header` from that store. The principal manifest is processed last: it deletes the three Lab 4 principals and their imported keys, but its `_external` directory entry keeps `default` outside the delete scope.

| File | Removed |
|---|---|
| `config/04-model.yaml` | `sts-lab04-chat` |
| `config/07-policy-rate-basic.yaml` | `sts-lab04-rate-basic` |
| `config/08-policy-rate-tiers.yaml` | `sts-lab04-rate-tiers` |
| `config/09-policy-rate-tokens.yaml` | `sts-lab04-rate-tokens` |
| `config/03-auth-strategy.yaml` | `sts-lab04-key-auth` |
| `config/02-provider.yaml` | `sts-lab04-openai` and `sts-lab04-vault`. `sts-lab04-config-store` stays. |
| Config Store secret API | `sts-lab04-openai-auth-header` |
| `config/05-principals.yaml` | the three principals and their imported keys |

`config/07-model-attach-rate-basic.yaml`, `config/08-model-attach-rate-tiers.yaml`, and `config/09-model-attach-rate-tokens.yaml` name the same model. The script does not delete those files. Deleting them would target the model a second time. The policy each of them references is deleted by the policy file in the table.

The directory entry is external, so a correct principal plan does not delete `default`. After the script, the directory read below must still show that name.

## What leaves the disk

After the deletes, the script removes `plans/`, `artifacts/`, and `out/` inside this lab. `plans/` holds the apply previews. `artifacts/` holds headers and response bodies from the tests. The shared `.env` is outside this lab, and the script does not remove it.

## Commands to preview changes

`cleanup.sh` writes a delete plan per file and prints the change count. A count of `0` means that file's resources are already absent. There is no separate preview step.

## Commands to apply changes

The script performs each non-empty delete plan. It does not apply configuration.

```bash
set -a
source "$LABS_DIR/.env"
set +a

bash "$LABS_DIR/04-principal-rate-limiting/cleanup.sh"
```

## Commands to verify configuration

The model, policy, auth strategy, provider, and principal commands print Lab 4 resources that still exist. Each must return an empty list, `[]`. The directory command verifies that the shared Identity directory still exists. The last command verifies that the OpenAI secret is gone. The Config Store itself remains.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-lab04-chat")]'
```

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(startswith("sts-lab04-"))]'
```

```bash
kongctl get ai-gateway auth-strategies \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-lab04-key-auth")]'
```

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-lab04-openai")]'
```

```bash
kongctl get id principals \
  --output json \
  --jq '[.[] | .display_name | select(startswith("sts-lab04-"))]'
```

```bash
kongctl get id directory \
  --output json \
  --jq 'if type == "array" then [.[].name] else [.name] end'
```

```bash
config_store_id="$(kongctl get ai-gateway config-stores \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | select(.name == "sts-lab04-config-store") | .id][0]' \
  --jq-raw-output)"

kongctl get ai-gateway config-stores "$config_store_id" secrets \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .key | select(. == "sts-lab04-openai-auth-header")]'
```

## HTTP test requests

None. The model is gone, so `$PROXY/v1/chat/completions` with `sts-lab04-chat` no longer matches this lab.

## Expected results

The model, policy, auth strategy, provider, principal, and OpenAI secret queries each print `[]`. The directory query still prints `["default"]`. The Config Store `sts-lab04-config-store` still exists. The script's last line is `Local generated files removed. Shared .env was kept. The default Identity directory was kept. The Config Store was kept. The OpenAI secret was removed.`

## Check the disk

```bash
for path in plans artifacts out; do
  if [[ -e "$LABS_DIR/04-principal-rate-limiting/$path" ]]; then
    echo "still present: $LABS_DIR/04-principal-rate-limiting/$path" >&2
  fi
done

test -f "$LABS_DIR/.env"
echo "shared .env is still present"
```

## Explanation of the policy behavior

Cleanup removes all Lab 4 resources regardless of which scenario was active. It preserves the shared gateway infrastructure, `.env`, and Identity directory. Run it only when the entire Lab 4 setup should be removed.
