# Step 10. Cleanup

## Purpose

Remove Lab 3 from the gateway and remove the containers this lab started. Optional. The shared `.env` stays. Labs 1 and 2 are not named in the script.

## What will be deleted

The script deletes, in order: the model, the two groups, the four policies, the two consumers, the auth strategy, and the provider file (vault and Config Store included). Attachment files repeat the model, so the script does not pass them to `kongctl delete`.

If `sts-lab03-redis` is running, the script runs `FLUSHDB` on logical database 0 only. It does not run `FLUSHALL`. It then removes `sts-lab03-redis` and `sts-lab03-pii` when those containers exist. Local `plans/`, `artifacts/`, and `out/` are removed.

## Commands

```bash
set -a
source "$LABS_DIR/.env"
set +a

bash "$LABS_DIR/03-advanced-policies/cleanup.sh"
```

Each file prints how many deletes the plan contains. A file whose resources are already gone prints `0` and is skipped.

## Verify

These lists should not contain `sts-lab03-` names.

```bash
kongctl get ai-gateway models --gateway-id "$AI_GATEWAY_ID" --output json --jq '[.[].name | select(startswith("sts-lab03-"))]'
```

```bash
kongctl get ai-gateway consumers --gateway-id "$AI_GATEWAY_ID" --output json --jq '[.[].name | select(startswith("sts-lab03-"))]'
```

```bash
kongctl get ai-gateway consumer-groups --gateway-id "$AI_GATEWAY_ID" --output json --jq '[.[].name | select(startswith("sts-lab03-"))]'
```

```bash
kongctl get ai-gateway policies --gateway-id "$AI_GATEWAY_ID" --output json --jq '[.[].name | select(startswith("sts-lab03-"))]'
```

```bash
kongctl get ai-gateway auth-strategies --gateway-id "$AI_GATEWAY_ID" --output json --jq '[.[].name | select(startswith("sts-lab03-"))]'
```

```bash
kongctl get ai-gateway model-providers --gateway-id "$AI_GATEWAY_ID" --output json --jq '[.[].name | select(startswith("sts-lab03-"))]'
```

`plans/`, `artifacts/`, and `out/` inside this lab are gone. `$LABS_DIR/.env` is still there. `docker ps -a --filter name=sts-lab03-` prints no containers.
