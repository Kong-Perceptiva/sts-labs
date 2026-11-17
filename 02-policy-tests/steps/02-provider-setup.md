# Step 2. OpenAI provider

## Purpose

Create the Lab 2 OpenAI provider. Later files name `sts-lab02-openai`. They do not configure the provider. Lab 1's provider is a different name and is left as it is.

## What will be created or modified

`config/02-provider.yaml` creates the Config Store `sts-lab02-config-store`, the secret `sts-lab02-openai-auth-header`, the vault `sts-lab02-vault`, and the provider `sts-lab02-openai`. The YAML stores the vault reference, not the key.

## Required prerequisites

Complete step 1 in the same shell, so `LABS_DIR` is set.

Copy `$LABS_DIR/.env.example` to `$LABS_DIR/.env` and fill the empty values before the first command, if that file is not already filled. `.env` is not committed.

| Variable | Used for |
|---|---|
| `KONGCTL_DEFAULT_KONNECT_PAT` | Konnect login for `kongctl`. This is not the API key the client sends. |
| `KONGCTL_DEFAULT_KONNECT_REGION` | Konnect region. `kongctl` uses `us` when this is unset. |
| `AI_GATEWAY_ID` | Gateway the YAML looks up. The gateway itself is not recreated. |
| `OPENAI_API_KEY` | Raw OpenAI key. The YAML adds the `Bearer ` prefix when it writes the vault secret. |

## Load `.env`

This reads `$LABS_DIR/.env` and exports every name in it. The command prints the region and the length of the OpenAI key. It does not print the key or the Konnect token.

```bash
set -a
source "$LABS_DIR/.env"
set +a

echo "Konnect region: $KONGCTL_DEFAULT_KONNECT_REGION"
echo "OpenAI key length: ${#OPENAI_API_KEY}"
```

## See if the provider already exists

This asks Konnect for `sts-lab02-openai`. It does not change the provider. If this prints the provider, stop. The blocks below create it.

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-openai \
  --output json \
  --jq '{name, display_name, type, auth_type: .config.auth.type}'
```

## Commands to preview changes

Run this only when the previous command did not find the provider.

`kongctl plan` reads the YAML, compares it with the gateway, and writes `$LABS_DIR/02-policy-tests/plans/provider.apply-plan.json`. Konnect is not changed. The OpenAI key is not written into that file.

`--mode apply` limits the preview to the four resources in the file. Without `--mode apply`, `kongctl` uses sync mode, and the preview also deletes gateway resources that are not in the YAML.

```bash
mkdir -p "$LABS_DIR/02-policy-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/02-policy-tests/config/02-provider.yaml" \
  --output-file "$LABS_DIR/02-policy-tests/plans/provider.apply-plan.json"
```

Read the preview before continuing. It should create those four resources and nothing else.

This warning is expected, and the plan is still valid:

```text
Warning: Reference config.config_store_id=__REF__:sts-lab02-config-store#id will be resolved during execution
```

The vault needs the Config Store id, and that store does not exist yet. Apply creates the Config Store first, then replaces the placeholder with the real id.

## Commands to apply changes

`kongctl apply` performs the file saved above. The preview already includes the OpenAI key write, so do not add `--write-secrets`. That flag is rejected together with `--plan`.

```bash
kongctl apply \
  --plan "$LABS_DIR/02-policy-tests/plans/provider.apply-plan.json" \
  --auto-approve \
  --output json
```

Konnect does not return the secret value.

## Commands to verify configuration

The Authorization value must be exactly `{vault://sts-lab02-vault/sts-lab02-openai-auth-header}`.

```bash
kongctl get ai-gateway model-providers \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab02-openai \
  --output json \
  --jq '{
    name,
    auth_type: .config.auth.type,
    authorization: (.config.auth.headers[] | select(.name == "Authorization") | .value)
  }'
```

The secrets command takes the Config Store id, not its name. The name `sts-lab02-openai-auth-header` must be in the list. The OpenAI key must not be in the output.

```bash
config_store_id="$(kongctl get ai-gateway config-stores \
  --gateway-id "$AI_GATEWAY_ID" \
  --config-store-name sts-lab02-config-store \
  --output json \
  --jq .id \
  --jq-raw-output)"

echo "Config Store id: $config_store_id"

kongctl get ai-gateway config-stores "$config_store_id" secrets \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json
```

## Check Data Plane sync

`sync` must reach `STATE_IN_SYNC`. That can take a short interval after apply.

```bash
kongctl get ai-gateway nodes \
  --gateway-id "$AI_GATEWAY_ID" \
  --output json \
  --jq '.[] | {hostname, version, compatibility: .compatibility_status.state, sync: .config_sync.state}'
```

## HTTP test requests

None in this step. The provider has no route until step 4.

## Expected results

The provider name is `sts-lab02-openai`, the auth type is `basic`, and the Authorization value is the vault reference above. The secret list contains `sts-lab02-openai-auth-header`. Node `sync` is `STATE_IN_SYNC`.

## Explanation of the policy behavior

No rate limit exists yet. The provider credential is the upstream OpenAI key. The client keys created in step 3 are a different credential.
