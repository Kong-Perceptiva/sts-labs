#!/usr/bin/env bash
# Sends chat calls through $PROXY for one Lab 04 principal.
# Prints one line per request: label, number, HTTP status, and the rate-limit
# headers for this mode. Does not print the API key, the OpenAI key, or the Konnect token.
#
# The loop stops on HTTP 429 or at --max calls. --max is at most 40.
# If the first call is already 429, the script waits for a reset header of
# 1 to 70 seconds and runs the series once more.
set -euo pipefail

label=""
key_var=""
max_requests=4
mode="requests"
expect_header=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="$2"; shift 2 ;;
    --key-var) key_var="$2"; shift 2 ;;
    --max) max_requests="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    --expect) expect_header="$2"; shift 2 ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$label" || -z "$key_var" || -z "${PROXY:-}" ]]; then
  echo "label, key-var, and PROXY are required" >&2
  exit 2
fi

if [[ "$mode" != "requests" && "$mode" != "tokens" ]]; then
  echo "mode must be requests or tokens" >&2
  exit 2
fi

if ! [[ "$max_requests" =~ ^[0-9]+$ ]] || (( max_requests < 1 || max_requests > 40 )); then
  echo "max must be an integer from 1 to 40" >&2
  exit 2
fi

key="${!key_var-}"
if [[ -z "$key" ]]; then
  echo "$key_var is empty" >&2
  exit 2
fi

mkdir -p artifacts
safe_label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '-')"
body='{"model":"sts-lab04-chat","messages":[{"role":"user","content":"Reply with one word: OK"}],"max_tokens":8}'

header_value() {
  local file="$1"
  local name="$2"
  { grep -i -m1 "^${name}:" "$file" || true; } | awk '{print $2}' | tr -d '\r'
}

reset_seconds() {
  local file="$1"
  local value=""
  local name
  for name in ratelimit-reset retry-after x-ai-ratelimit-reset x-ai-ratelimit-retry-after; do
    value="$(header_value "$file" "$name")"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

one_call() {
  local number="$1"
  local header_file="artifacts/${safe_label}-${number}.headers"
  local body_file="artifacts/${safe_label}-${number}.json"
  local status

  status="$(curl --silent --show-error --max-time 60 \
    --dump-header "$header_file" \
    --output "$body_file" \
    --write-out '%{http_code}' \
    "$PROXY/v1/chat/completions" \
    --header 'Content-Type: application/json' \
    --header "apikey: $key" \
    --data "$body")"

  printf '%s\n' "$status" >"artifacts/${safe_label}-${number}.status"

  local limit remaining reset retry tokens limit_line remaining_line
  if [[ "$mode" == "requests" ]]; then
    limit="$(header_value "$header_file" "x-ratelimit-limit-minute")"
    remaining="$(header_value "$header_file" "x-ratelimit-remaining-minute")"
    reset="$(header_value "$header_file" "ratelimit-reset")"
    retry="$(header_value "$header_file" "retry-after")"
    printf '%s %s/%s  HTTP %s  X-RateLimit-Limit-Minute=%s  X-RateLimit-Remaining-Minute=%s  RateLimit-Reset=%s' \
      "$label" "$number" "$max_requests" "$status" "${limit:-n/a}" "${remaining:-n/a}" "${reset:-n/a}"
    if [[ "$status" == "429" ]]; then
      printf '  Retry-After=%s' "${retry:-n/a}"
    fi
    printf '\n'
  else
    if jq -e . >/dev/null 2>&1 <"$body_file"; then
      tokens="$(jq -r '.usage.total_tokens // "n/a"' "$body_file")"
    else
      tokens="n/a"
    fi
    limit_line="$( { grep -i -m1 '^x-ai-ratelimit-limit-' "$header_file" || true; } | tr -d '\r')"
    remaining_line="$( { grep -i -m1 '^x-ai-ratelimit-remaining-' "$header_file" || true; } | tr -d '\r')"
    printf '%s %s/%s  HTTP %s  total_tokens=%s  %s  %s\n' \
      "$label" "$number" "$max_requests" "$status" "$tokens" \
      "${limit_line:-X-AI-RateLimit-Limit: n/a}" \
      "${remaining_line:-X-AI-RateLimit-Remaining: n/a}"
  fi
}

run_series() {
  local accepted=0
  local rejected=0
  local other=0
  local number=1
  local status
  local limit_seen=""
  local quota_seen=""

  echo "$label"
  echo
  echo "POST $PROXY/v1/chat/completions"
  echo "- text: \"Reply with one word: OK\""
  echo "- max_tokens: 8"
  echo "- calls: up to $max_requests, or until the first HTTP 429"
  echo
  if [[ "$mode" == "requests" ]]; then
    echo "Counting requests for this principal."
    echo "Expected limit: ${expect_header:-unset} per minute."
    echo
    echo "One line per request:"
    echo "- number in this loop"
    echo "- HTTP status"
    echo "- X-RateLimit-Limit-Minute"
    echo "- X-RateLimit-Remaining-Minute"
    echo "- RateLimit-Reset"
    echo
    echo "Other headers and the body are omitted. HTTP 429 also prints Retry-After."
  else
    echo "Counting total tokens from each accepted response."
    echo "Expected quota: ${expect_header:-unset}."
    echo
    echo "One line per request:"
    echo "- number in this loop"
    echo "- HTTP status"
    echo "- total_tokens"
    echo "- the first X-AI-RateLimit-Limit header"
    echo "- the first X-AI-RateLimit-Remaining header"
    echo
    echo "Other headers and the rest of the body are omitted."
  fi
  echo

  while (( number <= max_requests )); do
    one_call "$number"
    status="$(tr -d '\r' <"artifacts/${safe_label}-${number}.status")"

    if [[ "$mode" == "requests" && -z "$limit_seen" ]]; then
      limit_seen="$(header_value "artifacts/${safe_label}-${number}.headers" "x-ratelimit-limit-minute")"
    fi
    if [[ "$mode" == "tokens" && -z "$quota_seen" ]]; then
      quota_seen="$( { grep -i -E '^x-ai-ratelimit-limit-' "artifacts/${safe_label}-${number}.headers" || true; } | tr -d '\r')"
    fi

    if [[ "$status" == "200" ]]; then
      accepted=$((accepted + 1))
    elif [[ "$status" == "429" ]]; then
      rejected=$((rejected + 1))
      break
    else
      other=$((other + 1))
      break
    fi
    number=$((number + 1))
  done

  echo "$label summary: accepted=$accepted rejected=$rejected other=$other  loop cap=$max_requests"
  echo

  if [[ "$mode" == "requests" && -n "$expect_header" ]]; then
    if [[ "$limit_seen" == "$expect_header" ]]; then
      echo "$label: X-RateLimit-Limit-Minute=$limit_seen matches the expected limit of $expect_header."
    else
      echo "$label: X-RateLimit-Limit-Minute=${limit_seen:-missing} does not match the expected limit of $expect_header."
    fi
    if (( rejected < 1 )); then
      echo "$label did not receive HTTP 429 within $max_requests requests. Remaining quota was above the cap, or the window reset during the loop."
    fi
  fi

  if [[ "$mode" == "tokens" && -n "$expect_header" ]]; then
    if printf '%s\n' "$quota_seen" | grep -E -q "(^|[^0-9])${expect_header}([^0-9]|$)"; then
      echo "$label token limit header contains expected quota $expect_header"
    else
      echo "$label token limit headers did not contain expected quota $expect_header"
      printf '%s\n' "$quota_seen"
    fi
    if (( rejected < 1 )); then
      echo "$label did not receive HTTP 429 within $max_requests requests. Token usage stayed inside the quota, or the window reset during the loop."
    fi
  fi

  if (( other > 0 )); then
    return 1
  fi
}

run_series
first_status="$(tr -d '\r' <"artifacts/${safe_label}-1.status")"
if [[ "$first_status" == "429" ]]; then
  echo "$label request 1 was rejected before this series could show an accepted call."
  if seconds="$(reset_seconds "artifacts/${safe_label}-1.headers")" && (( seconds > 0 && seconds <= 70 )); then
    echo "$label waiting ${seconds}s for the window to reset, then running one more series"
    sleep "$seconds"
    run_series
  else
    echo "$label has no reset header of 1-70 seconds. Wait for the window and run the command again."
    exit 1
  fi
fi
