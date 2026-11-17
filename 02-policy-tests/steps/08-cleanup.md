# Step 8. Cleanup (optional)

## Purpose

Remove Lab 2 from the AI Gateway and delete the files the earlier steps generated inside `$LABS_DIR/02-policy-tests`. Skip this step when the Lab 2 resources should stay.

## What will be created or modified

Nothing is created. `cleanup.sh` deletes the resources named in the canonical YAML files, then removes `plans/`, `artifacts/`, and `out/` in this lab.

The YAML under `config/`, the instructions under `steps/`, `test-chat.sh`, and `cleanup.sh` stay. `$LABS_DIR/.env` stays. The gateway, the Control Plane, and the Data Plane stay. Lab 1 names are not in these files.

## Required prerequisites

`LABS_DIR` is set and `$LABS_DIR/.env` has `AI_GATEWAY_ID` and the Konnect token. The script loads that file itself.

## What leaves the gateway

Each file is planned with `--mode delete`. That mode removes the resources named in the file. A plan with nothing to delete is skipped, so a scenario that was never applied does not fail the cleanup. The default plan mode is sync. The script does not use sync.

The model and the groups are deleted before the policies, because those parents are what attach the policies. Deleting them removes the attachment whichever scenario was last applied. Consumers follow the groups. The auth strategy follows the model. The provider file is last and includes the vault, the Config Store, and the secret.

| File | Removed |
|---|---|
| `config/04-model.yaml` | `sts-lab02-chat` |
| `config/06-consumer-groups.yaml` | `sts-lab02-tier-1`, `sts-lab02-tier-2`, `sts-lab02-tier-3` |
| `config/07-policy-rate-basic.yaml` | `sts-lab02-rate-basic` |
| `config/08-policies-rate-tiers.yaml` | `sts-lab02-rate-tier-1`, `sts-lab02-rate-tier-2`, `sts-lab02-rate-tier-3` |
| `config/09-policy-rate-tokens.yaml` | `sts-lab02-rate-tokens` |
| `config/05-consumers.yaml` | the three consumers and their credentials |
| `config/03-auth-strategy.yaml` | `sts-lab02-key-auth` |
| `config/02-provider.yaml` | `sts-lab02-openai`, `sts-lab02-vault`, `sts-lab02-config-store`, `sts-lab02-openai-auth-header` |

`config/07-model-attach-rate-basic.yaml`, `config/08-groups-attach-rate-tiers.yaml`, and `config/09-model-attach-rate-tokens.yaml` name the same model or the same groups. The script does not delete those files. Deleting them would target the model or the groups a second time. The policy each of them references is deleted by the policy file in the table.

## What leaves the disk

After the gateway deletes, the script removes `plans/`, `artifacts/`, and `out/` inside this lab. `plans/` holds the apply previews. `artifacts/` holds headers and response bodies from the tests. The shared `.env` is outside this lab, and the script does not remove it.

## Commands to preview changes

`cleanup.sh` writes a delete plan per file and prints the change count. A count of `0` means that file's resources are already absent. There is no separate preview step.

## Commands to apply changes

The script performs each non-empty delete plan. It does not apply configuration.

```bash
set -a
source "$LABS_DIR/.env"
set +a

bash "$LABS_DIR/02-policy-tests/cleanup.sh"
```

## Commands to verify configuration

Each command prints Lab 2 names that are still on the gateway. An empty list, `[]`, means that group is gone.

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-lab02-chat")]'
```

```bash
kongctl get ai-gateway consumers \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(startswith("sts-lab02-"))]'
```

```bash
kongctl get ai-gateway consumer-groups \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(startswith("sts-lab02-"))]'
```

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(startswith("sts-lab02-"))]'
```

```bash
kongctl get ai-gateway auth-strategies \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-lab02-key-auth")]'
```

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '[.[] | .name | select(. == "sts-lab02-openai")]'
```

## HTTP test requests

None. The model is gone, so `$PROXY/v1/chat/completions` with `sts-lab02-chat` no longer matches this lab.

## Expected results

The six lists print `[]`. The script's last line is `Local generated files removed. Shared .env was kept.`

## Check the disk

```bash
for path in plans artifacts out; do
  if [[ -e "$LABS_DIR/02-policy-tests/$path" ]]; then
    echo "still present: $LABS_DIR/02-policy-tests/$path" >&2
  fi
done

test -f "$LABS_DIR/.env"
echo "shared .env is still present"
```

## Explanation of the policy behavior

Cleanup removes the policies and the entities that referenced them. It does not change which scenario was active before the delete. Run it only when Lab 2 should be removed.
