#!/usr/bin/env bash
# Removes this lab's resources from the AI Gateway, then the generated files
# in this directory, then the Lab 03 containers if they are present.
# Kong resources are deleted from the canonical lab YAML only. Attachment
# files repeat the model, so they are not deleted here. Redis cleanup is
# FLUSHDB on logical database 0 only. $LABS_DIR/.env is kept.
# Labs 1 and 2 are not named here.
set -euo pipefail

cd "$LABS_DIR/03-advanced-policies"
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

# The model holds the policy attachment and the ACL. Delete it before the
# policies. Groups before consumers. Auth after the model. The provider file
# is last and takes the vault and the Config Store with it.
delete_file config/04-model-baseline.yaml
delete_file config/05-consumer-groups.yaml
delete_file config/05-policy-prompt-guard.yaml
delete_file config/06-policy-semantic-guard.yaml
delete_file config/07-policy-pii-sanitizer.yaml
delete_file config/08-policy-prompt-template.yaml
delete_file config/05-consumers.yaml
delete_file config/03-auth-strategy.yaml
delete_file config/02-provider-openai.yaml

if command -v docker >/dev/null; then
  if docker inspect sts-lab03-redis >/dev/null 2>&1; then
    docker exec sts-lab03-redis redis-cli -n 0 FLUSHDB
  fi
  docker rm -f sts-lab03-redis sts-lab03-pii >/dev/null 2>&1 || true
fi

rm -rf plans artifacts out
echo "Local generated files removed. Shared .env was kept."
