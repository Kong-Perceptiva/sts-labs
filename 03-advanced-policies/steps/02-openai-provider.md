# Step 2. OpenAI provider

## Purpose

Create the Lab 3 OpenAI provider. Later files name `sts-lab03-openai`. They do not configure the provider. Labs 1 and 2 keep their own providers.

## What will be created or modified

`config/02-provider-openai.yaml` creates the Config Store `sts-lab03-config-store`, the secret `sts-lab03-openai-auth-header`, the vault `sts-lab03-vault`, and the provider `sts-lab03-openai`. The YAML stores the vault reference, not the key.

## Required prerequisites

Complete step 1 in the same shell, so `LABS_DIR` is set. Copy `$LABS_DIR/.env.example` to `$LABS_DIR/.env` and fill the empty values before the first command, if that file is not already filled.

| Variable | Used for |
|---|---|
| `KONGCTL_DEFAULT_KONNECT_PAT` | Konnect login for `kongctl`. This is not the API key the client sends. |
| `KONGCTL_DEFAULT_KONNECT_REGION` | Konnect region. `kongctl` uses `us` when this is unset. |
| `AI_GATEWAY_ID` | Gateway the YAML looks up. The gateway itself is not recreated. |
| `OPENAI_API_KEY` | Raw OpenAI key. The YAML adds the `Bearer ` prefix when it writes the vault secret. |

## Load `.env`

This reads `$LABS_DIR/.env` and exports every name in it. It prints the region and the length of the OpenAI key. It does not print the key or the Konnect token.

```bash
set -a
source "$LABS_DIR/.env"
set +a

echo "Konnect region: $KONGCTL_DEFAULT_KONNECT_REGION"
echo "OpenAI key length: ${#OPENAI_API_KEY}"
```

## See if the provider already exists

This asks Konnect for `sts-lab03-openai`. It does not change the provider. If this prints the provider, stop. The blocks below create it.

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-openai \
  --output json \
  --jq '{name, display_name, type, auth_type: .config.auth.type}'
```

## Commands to preview changes

Run this only when the previous command did not find the provider. The plan writes `$LABS_DIR/03-advanced-policies/plans/provider.apply-plan.json`. Konnect is not changed.

`mkdir` creates `plans/` first. `kongctl` does not create that directory.

```bash
mkdir -p "$LABS_DIR/03-advanced-policies/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/02-provider-openai.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/provider.apply-plan.json"
```

Read the preview. It should create the Config Store, the secret, the vault, and the provider. This warning is expected, and the plan is still valid:

```text
Warning: Reference config.config_store_id=__REF__:sts-lab03-config-store#id will be resolved during execution
```

## Commands to apply changes

Performs the saved plan. Do not add `--write-secrets`. That flag is rejected together with `--plan`.

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/provider.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

These reads check the provider credential reference, not a chat call.

- The Authorization header value is the vault reference, not the OpenAI key.
- The Config Store lists the secret name `sts-lab03-openai-auth-header`.

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-openai \
  --output json \
  --jq '{
    name,
    auth_type: .config.auth.type,
    authorization: (.config.auth.headers[] | select(.name == "Authorization") | .value)
  }'
```

```bash
config_store_id="$(kongctl get ai-gateway config-stores \
  --gateway-id "$AI_GATEWAY_ID" \
  --config-store-name sts-lab03-config-store \
  --output json \
  --jq .id \
  --jq-raw-output)"

echo "Config Store id: $config_store_id"

kongctl get ai-gateway config-stores "$config_store_id" secrets \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json
```

## Check Data Plane sync

Confirms the local node has the provider. `sync` must be `STATE_IN_SYNC`.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

None in this step. The provider has no route until step 4.

## Expected results

The provider name is `sts-lab03-openai`, the auth type is `basic`, and the Authorization value is `{vault://sts-lab03-vault/sts-lab03-openai-auth-header}`. The secret list contains `sts-lab03-openai-auth-header`. Node `sync` is `STATE_IN_SYNC`.
