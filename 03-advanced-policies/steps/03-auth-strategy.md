# Step 3. Auth strategy

## Purpose

Create the key-auth strategy `sts-lab03-key-auth`. Callers send the header `apikey`. Kong removes that header before the request reaches OpenAI.

## What will be created or modified

`config/03-auth-strategy.yaml` creates that strategy. It does not create consumers or keys.

## Required prerequisites

Step 2 is applied. `$LABS_DIR/.env` is loaded in this shell.

## Commands to preview changes

The plan creates one auth strategy. Konnect is not changed.

`mkdir` creates `plans/` first. `kongctl` does not create that directory.

```bash
mkdir -p "$LABS_DIR/03-advanced-policies/plans"

kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/03-auth-strategy.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/auth-strategy.apply-plan.json"
```

Read the preview. `key_names` is `apikey` and `hide_credentials` is true.

## Commands to apply changes

Performs the saved plan.

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/auth-strategy.apply-plan.json" \
  --auto-approve \
  --output json
```

## Commands to verify configuration

This read checks the strategy the model will require in step 4: header name `apikey`, header location, and hidden credentials.

```bash
kongctl get ai-gateway auth-strategies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-key-auth \
  --output json \
  --jq '{name, type, key_names: .config.key_names, hide_credentials: .config.hide_credentials}'
```

## HTTP test requests

None in this step. There is no model yet.

## Expected results

The name is `sts-lab03-key-auth`, the type is `key-auth`, `key_names` is `["apikey"]`, and `hide_credentials` is true.
