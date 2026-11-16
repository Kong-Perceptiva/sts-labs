# Step 2. OpenAI provider

Complete step 1 in the same shell, so `LABS_DIR` is set.

This step makes sure the gateway has a provider named `openai-lab`. Later models use that name. They do not configure the provider. If the provider is already there, stop after the check. Do not run the preview, the apply, or the final reads.

Copy `$LABS_DIR/.env.example` to `$LABS_DIR/.env` and fill the empty values before the first command. That file is shared with later labs. `.env` is not committed.

| Variable | Used for |
|---|---|
| `KONGCTL_DEFAULT_KONNECT_PAT` | Konnect login for `kongctl`. This is not the API key the client sends. |
| `KONGCTL_DEFAULT_KONNECT_REGION` | Konnect region. `kongctl` uses `us` when this is unset. |
| `AI_GATEWAY_ID` | Gateway the YAML looks up. The gateway itself is not recreated. |
| `OPENAI_API_KEY` | Raw OpenAI key. The YAML adds the `Bearer ` prefix when it writes the vault secret. |

## Load `.env`

This reads `$LABS_DIR/.env` and exports every name in it. A quoted value keeps its spaces. The command prints the region and the length of the OpenAI key. It does not print the key or the Konnect token.

```bash
set -a
source "$LABS_DIR/.env"
set +a

echo "Konnect region: $KONGCTL_DEFAULT_KONNECT_REGION"
echo "OpenAI key length: ${#OPENAI_API_KEY}"
```

## See if the provider already exists

This asks Konnect for the provider `openai-lab` and prints its name, display name, type, and auth type. It does not change the provider.

If this prints the provider, stop. The blocks below create it, and they must not run when it already exists.

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  openai-lab \
  --output json \
  --jq '{name, display_name, type, auth_type: .config.auth.type}'
```

## Preview the create

Run this only when the previous command did not find the provider.

`kongctl plan` reads `$LABS_DIR/01-model-tests/config/02-provider-openai.yaml`, compares it with the gateway, and writes the difference to `$LABS_DIR/01-model-tests/plans/openai-provider.apply-plan.json`. Konnect is not changed. The OpenAI key is not written into that file. `plans/` is not committed.

`--mode apply` limits the preview to what this YAML adds: the Config Store `openai-config-store`, the secret `openai-auth-header`, the vault `openai-vault`, and the provider `openai-lab`. The Authorization value in the preview is `{vault://openai-vault/openai-auth-header}`. Without `--mode apply`, `kongctl` uses sync mode, and the preview also deletes gateway resources that are not in the YAML.

```bash
mkdir -p "$LABS_DIR/01-model-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/01-model-tests/config/02-provider-openai.yaml" \
  --output-file "$LABS_DIR/01-model-tests/plans/openai-provider.apply-plan.json"
```

Read the preview before continuing. It should create those four resources and nothing else.

This warning is expected, and the plan is still valid:

```text
Warning: Reference config.config_store_id=__REF__:openai-config-store#id will be resolved during execution
```

The vault needs the Config Store id, and that store does not exist yet. The preview keeps the placeholder `__REF__:openai-config-store#id`. Apply creates the Config Store first, then replaces the placeholder with the real id.

## Apply the preview

`kongctl apply` performs the file saved above. It does not read the YAML again. The preview already includes the OpenAI key write, so do not add `--write-secrets` here. That flag is rejected together with `--plan`. `--auto-approve` skips the confirmation prompt.

```bash
kongctl apply \
  --plan "$LABS_DIR/01-model-tests/plans/openai-provider.apply-plan.json" \
  --auto-approve \
  --output json
```

Konnect does not return the secret value.

## Check the provider

This reads the provider `openai-lab` and prints its name, auth type, and the Authorization value. The apply output showed that value as `[REDACTED]`. This command shows the real value. It must be exactly `{vault://openai-vault/openai-auth-header}`.

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  openai-lab \
  --output json \
  --jq '{
    name,
    auth_type: .config.auth.type,
    authorization: (.config.auth.headers[] | select(.name == "Authorization") | .value)
  }'
```

## Check the secret

The secrets command takes the Config Store id, not its name. Passing `openai-config-store` in that position returns `configStoreId: invalid ID format`. The first command prints the id. `--jq .id` selects the id, and `--jq-raw-output` prints it without quotes. Those are two flags. `.id` is not a value of `--jq-raw-output`. The second command lists the secrets. The name `openai-auth-header` must be there. The OpenAI key must not be in the output.

```bash
config_store_id="$(kongctl get ai-gateway config-stores \
  --gateway-id "$AI_GATEWAY_ID" \
  --config-store-name openai-config-store \
  --output json \
  --jq .id \
  --jq-raw-output)"

echo "Config Store id: $config_store_id"

kongctl get ai-gateway config-stores "$config_store_id" secrets \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json
```

## Check Data Plane sync

This shows whether the local Data Plane has the new configuration. `sync` must reach `STATE_IN_SYNC`. That can take a short interval after apply.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```
