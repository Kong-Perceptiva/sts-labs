# Step 3. Lab auth strategy

The first command loads `$LABS_DIR/.env`.

`$LABS_DIR/01-model-tests/config/03-auth-strategy-lab.yaml` creates `sts-key-auth-lab`. This is the rule for calls that enter the lab models. It is not the OpenAI credential. The OpenAI key stays on the provider and is read from the vault.

The client sends the header `apikey`. `hide_credentials` is true, so the Data Plane removes that header before the request reaches OpenAI. This file does not create the consumer, and it does not create the API key that satisfies the rule. Step 5 does that.

## Preview the auth strategy

`kongctl plan` compares the file with the gateway and writes the difference to `$LABS_DIR/01-model-tests/plans/auth-strategy-lab.apply-plan.json`. Konnect is not changed. `--mode apply` limits the preview to this strategy. Without it, sync mode also deletes gateway resources that are not in the file.

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/01-model-tests/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/01-model-tests/config/03-auth-strategy-lab.yaml" \
  --output-file "$LABS_DIR/01-model-tests/plans/auth-strategy-lab.apply-plan.json"
```

Read the preview before continuing. It should create `sts-key-auth-lab` and nothing else.

## Apply the preview

`kongctl apply` performs the saved preview. Do not add `--write-secrets`. This file has no secret, and that flag is rejected together with `--plan`.

```bash
kongctl apply \
  --plan "$LABS_DIR/01-model-tests/plans/auth-strategy-lab.apply-plan.json" \
  --auto-approve \
  --output json
```

## Check the strategy

The name is `sts-key-auth-lab`, the type is `key-auth`, and the header name is `apikey`.

```bash
kongctl get ai-gateway auth-strategies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-key-auth-lab \
  --output json \
  --jq '{name, type, key_names: .config.key_names, hide_credentials: .config.hide_credentials}'
```
