#!/usr/bin/env bash
# Removes this lab's resources from the AI Gateway, then the generated files
# in this directory. Kong resources are deleted from the canonical lab YAML
# only. Attachment files repeat the model or the groups, so they are not
# deleted here. $LABS_DIR/.env is kept. Lab 1 resources are not named here.
set -euo pipefail

cd "$LABS_DIR/02-policy-tests"
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

# The model and the groups hold the policy attachments. Delete those parents
# before the policies they reference. Consumers follow the groups. The auth
# strategy follows the model. The provider file is last and takes the vault
# and the Config Store with it.
delete_file config/04-model.yaml
delete_file config/06-consumer-groups.yaml
delete_file config/07-policy-rate-basic.yaml
delete_file config/08-policies-rate-tiers.yaml
delete_file config/09-policy-rate-tokens.yaml
delete_file config/05-consumers.yaml
delete_file config/03-auth-strategy.yaml
delete_file config/02-provider.yaml

rm -rf plans artifacts out
echo "Local generated files removed. Shared .env was kept."
