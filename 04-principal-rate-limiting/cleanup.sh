#!/usr/bin/env bash
# Removes this lab's resources from the AI Gateway and from the Identity
# directory, then the generated files in this directory. Kong resources are
# deleted from the canonical lab YAML. The OpenAI Config Store secret is
# deleted through its own API because the external gateway keeps the store.
# Attachment files repeat the model, so they are not deleted here. The
# Identity directory named default is external in config/05-principals.yaml
# and is not a delete target. $LABS_DIR/.env is kept. Labs 1, 2, and 3 are
# not named here.
set -euo pipefail

cd "$LABS_DIR/04-principal-rate-limiting"
export PATH="$HOME/.local/bin:$PATH"

set -a
source "$LABS_DIR/.env"
set +a

delete_file() {
  yaml="$1"
  plan="$(mktemp)"
  kongctl plan \
    --mode delete \
    --filename "$yaml" \
    --output-file "$plan"
  changes="$(jq -r '.summary.total_changes // 0' "$plan")"
  echo "$yaml: $changes to delete"
  if [[ "$changes" != "0" ]]; then
    kongctl delete \
      --plan "$plan" \
      --auto-approve
  fi
  rm -f "$plan"
}

# kongctl cannot delete a Config Store whose AI Gateway is external. The store
# stays. This removes only the OpenAI secret stored in it. A successful delete
# returns an empty body, so the response is discarded.
delete_openai_secret() {
  local store_id present
  store_id="$(kongctl get ai-gateway config-stores \
    --gateway-id "$AI_GATEWAY_ID" \
    --output json \
    --jq '[.[] | select(.name == "sts-lab04-config-store") | .id][0] // ""' \
    --jq-raw-output)"
  if [[ -z "$store_id" || "$store_id" == "null" ]]; then
    echo "sts-lab04-openai-auth-header: config store already absent"
    return 0
  fi
  present="$(kongctl get ai-gateway config-stores "$store_id" secrets \
    --gateway-id "$AI_GATEWAY_ID" \
    --output json \
    --jq '[.[] | select(.key == "sts-lab04-openai-auth-header")] | length')"
  if [[ "$present" == "0" ]]; then
    echo "sts-lab04-openai-auth-header: already absent"
    return 0
  fi
  kongctl api delete \
    "/v1/ai-gateways/${AI_GATEWAY_ID}/config-stores/${store_id}/secrets/sts-lab04-openai-auth-header" \
    >/dev/null
  echo "sts-lab04-openai-auth-header: deleted"
}

# The model holds the policy attachment. Delete it before the policies.
# The auth strategy follows the model. The provider file removes the provider
# and the vault. The Config Store is retained, so the OpenAI secret is deleted
# on its own afterward. The principals are deleted after the gateway, keys
# included. The external directory stays.
delete_file config/04-model.yaml
delete_file config/07-policy-rate-basic.yaml
delete_file config/08-policy-rate-tiers.yaml
delete_file config/09-policy-rate-tokens.yaml
delete_file config/03-auth-strategy.yaml
delete_file config/02-provider.yaml
delete_openai_secret
delete_file config/05-principals.yaml

rm -rf plans artifacts out
echo "Local generated files removed. Shared .env was kept. The default Identity directory was kept. The Config Store was kept. The OpenAI secret was removed."
