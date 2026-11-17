# Step 9. AI Semantic Cache

## Objective

Show a cache miss, an exact repeat, a similar question, and an unrelated question. Use `X-Cache-Status` for the result. A fast call is not a hit by itself.

## Policy behavior

`sts-lab03-semantic-cache` stores embeddings in Redis logical database `0`, the same database as step 6. The cache index name is not the guard index name. `exact_caching` is true, so an identical prompt is checked before the similarity search. `cache_ttl` is 300 seconds. `threshold` is `0.5` with cosine distance and `text-embedding-3-small` at 1024 dimensions, the same embedding settings as step 6.

The schema has no per-consumer cache partition. The cache is on this model, so callers of `sts-lab03-chat` share it. This step uses the allowed consumer and synthetic prompts only.

Documented response headers, when the proxy sends them:

- `X-Cache-Status` is `Hit`, `Miss`, `Bypass`, or `Refresh`
- `X-Cache-Key`
- `X-Cache-Ttl`
- `Age`

A similar prompt can miss. The threshold decides.

## Dependencies

The `sts-lab03-redis` container from step 6. Start it here if it is not running. If it was created from `redis:8`, remove it and start the Redis Stack image from step 6. Do not start a second Redis.

```bash
docker start sts-lab03-redis 2>/dev/null || docker run -d --name sts-lab03-redis \
  -p 127.0.0.1:16379:6379 \
  redis/redis-stack-server:7.4.0-v6

docker exec sts-lab03-redis redis-cli PING
```

## Configuration being created

| File | Change |
|---|---|
| `config/09-policy-semantic-cache.yaml` | Creates `sts-lab03-semantic-cache` |
| `config/09-model-attach-semantic-cache.yaml` | Attaches it to `sts-lab03-chat` |

## Activation commands

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/03-advanced-policies/plans" "$LABS_DIR/03-advanced-policies/artifacts"
```

If another exercise is active, follow [Return to baseline](00-lab-intro.md#return-to-baseline) first. After step 4, proceed directly.

**Create the policy.** The plan must not contain the raw OpenAI key. The header value is `{vault://sts-lab03-vault/sts-lab03-openai-auth-header}`. That secret already includes the `Bearer ` prefix.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/09-policy-semantic-cache.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/semantic-cache.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/semantic-cache.apply-plan.json" \
  --auto-approve \
  --output json
```

**Attach it to the model.**

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/09-model-attach-semantic-cache.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-cache.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-cache.apply-plan.json" \
  --auto-approve \
  --output json
```

## Configuration verification

These reads check the cache configuration:

- the model lists only `sts-lab03-semantic-cache`
- TTL is 300, exact caching is true, and Redis database is 0

```bash
kongctl get ai-gateway models \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-chat \
  --output json \
  --jq '{name, policies}'
```

```bash
kongctl get ai-gateway policies \
  --gateway-id "$AI_GATEWAY_ID" \
  sts-lab03-semantic-cache \
  --output json \
  --jq '{
    name,
    type,
    cache_ttl: .config.cache_ttl,
    exact_caching: .config.exact_caching,
    database: .config.vectordb.redis.database,
    threshold: .config.vectordb.threshold
  }'
```

Wait until node `sync` is `STATE_IN_SYNC`.

## Positive test

Each call prints status, time, and the cache headers. The body is saved under `artifacts/` and is not printed in full.

**Miss.** First time this prompt is cached.

```bash
curl --silent --show-error \
  --dump-header "$LABS_DIR/03-advanced-policies/artifacts/09-miss.headers" \
  --output "$LABS_DIR/03-advanced-policies/artifacts/09-miss.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Explain the main benefits of using an API Gateway in a microservices architecture."}],"max_tokens":80}'

grep -i -E '^(HTTP/|X-Cache-Status:|X-Cache-Key:|X-Cache-Ttl:|Age:)' \
  "$LABS_DIR/03-advanced-policies/artifacts/09-miss.headers"
```

**Exact repeat.** Same body. Expect `X-Cache-Status: Hit`.

```bash
curl --silent --show-error \
  --dump-header "$LABS_DIR/03-advanced-policies/artifacts/09-exact.headers" \
  --output "$LABS_DIR/03-advanced-policies/artifacts/09-exact.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Explain the main benefits of using an API Gateway in a microservices architecture."}],"max_tokens":80}'

grep -i -E '^(HTTP/|X-Cache-Status:|X-Cache-Key:|X-Cache-Ttl:|Age:)' \
  "$LABS_DIR/03-advanced-policies/artifacts/09-exact.headers"
```

## Comparison test

**Similar wording.** May be `Hit` or `Miss`. Record `X-Cache-Status`.

```bash
curl --silent --show-error \
  --dump-header "$LABS_DIR/03-advanced-policies/artifacts/09-similar.headers" \
  --output "$LABS_DIR/03-advanced-policies/artifacts/09-similar.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Why is an API Gateway useful when building applications with many microservices?"}],"max_tokens":80}'

grep -i -E '^(HTTP/|X-Cache-Status:|X-Cache-Ttl:|Age:)' \
  "$LABS_DIR/03-advanced-policies/artifacts/09-similar.headers"
```

**Different topic.** Expect `Miss`.

```bash
curl --silent --show-error \
  --dump-header "$LABS_DIR/03-advanced-policies/artifacts/09-other.headers" \
  --output "$LABS_DIR/03-advanced-policies/artifacts/09-other.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"What is the difference between TCP and UDP?"}],"max_tokens":80}'

grep -i -E '^(HTTP/|X-Cache-Status:|X-Cache-Ttl:|Age:)' \
  "$LABS_DIR/03-advanced-policies/artifacts/09-other.headers"
```

## Expected results

- The first benefits prompt is `Miss` and HTTP 200.
- The identical prompt is `Hit` and HTTP 200. `Age` or `X-Cache-Ttl` may be present.
- The similar prompt is `Hit` only when the score passes the threshold.
- The TCP question is `Miss`.

## Troubleshooting

Every call `Miss` on the exact repeat means the node is not in sync, Redis database 0 is unreachable, or the first call failed before it was stored. Flush database 0 to retry this step. This also clears the semantic guard index:

```bash
docker exec sts-lab03-redis redis-cli -n 0 FLUSHDB
```

Do not run `FLUSHALL`.

## Return to baseline

Follow [Return to baseline](00-lab-intro.md#return-to-baseline) to clear this exercise.
