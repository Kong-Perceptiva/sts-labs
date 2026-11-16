#!/usr/bin/env bash
# Removes this lab's resources from the AI Gateway, then the generated files
# in this directory. Kong resources are deleted from the lab YAML only.
# $LABS_DIR/.env is kept.
set -euo pipefail

cd "$LABS_DIR/01-model-tests"
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

delete_file config/04-models-lab.yaml
delete_file config/05-consumer-lab.yaml
delete_file config/03-auth-strategy-lab.yaml
delete_file config/02-provider-openai.yaml

rm -rf plans artifacts out .venv .schema
find . -type d -name __pycache__ -prune -exec rm -rf {} +
echo "Local generated files removed. Shared .env was kept."
