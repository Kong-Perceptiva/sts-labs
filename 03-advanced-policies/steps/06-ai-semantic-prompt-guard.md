# Step 6. AI Semantic Prompt Guard

## Objective

Block a fictional confidential-finance topic by meaning. A paraphrase can match even when it does not contain the original words. A match is a similarity score, not a guarantee.

## Policy behavior

`sts-lab03-semantic-guard` embeds the latest user message with OpenAI `text-embedding-3-small` and compares it with one deny prompt. The embedding call goes to OpenAI directly. `upstream_url` is unset, so the call does not re-enter `sts-lab03-chat`.

The deny prompt is: requests for confidential financial details, planned acquisitions, or internal budgets of Project Phoenix.

`vectordb.threshold` is `0.5` and `distance_metric` is `cosine`, the values in the Kong example. The documented score in a verbose rejection is a distance: a lower score is a closer match. The threshold description says a higher threshold treats more results as similar. Read the score on a rejection and treat a paraphrase as probabilistic. Another language can score differently. `dimensions` is `1024`, the size in that same example.

The policy stores embeddings on Redis logical database `0`. A search index cannot be created on any other database.

`rejection_mode: verbose` returns HTTP 403, `GUARDRAIL_BLOCKED`, the matched prompt, and the score.

## Dependencies

Redis Stack Server 7.4, image `redis/redis-stack-server:7.4.0-v6`. It includes the query engine and the JSON type. The container is published only on `127.0.0.1:16379`. The Data Plane reaches it at `STS_LAB03_REDIS_HOST` port `16379`. On Docker Desktop that host is `host.docker.internal`.

Do not use `redis:8`. On the first request the gateway drops the guard index and then creates it. A missing index is a normal case, and this gateway continues only when that reply starts with `Unknown Index name`. Redis Stack 7.4 returns that text. Redis 8.0 through 8.6 return `<name>: no such index`. Redis 8.8 and later return `SEARCH_INDEX_NOT_FOUND Index not found`. This gateway treats both as a failure, the request ends in HTTP 500, and the index is never created. Those images also refuse a search index on every database except 0.

The first start can be immediate. This image does not download an extra model.

## Configuration being created

| File | Change |
|---|---|
| `config/06-policy-semantic-guard.yaml` | Creates `sts-lab03-semantic-guard` |
| `config/06-model-attach-semantic-guard.yaml` | Attaches it to `sts-lab03-chat` |

## Start Redis

Does not start during the earlier steps. Run it here.

```bash
docker rm -f sts-lab03-redis >/dev/null 2>&1 || true

docker run -d --name sts-lab03-redis \
  -p 127.0.0.1:16379:6379 \
  redis/redis-stack-server:7.4.0-v6
```

**Preflight.** `PONG` means the port answers. `JSON.SET` must succeed. The vector index must be created on database 0, and dropping it a second time must reply `Unknown Index name`. Any other drop reply means this gateway will return HTTP 500 on the first call. These commands do not prove that the Data Plane can reach Redis. The index list after the ordinary question does.

```bash
docker exec sts-lab03-redis redis-cli PING
docker exec sts-lab03-redis redis-cli JSON.SET sts-lab03:preflight '$' '{"ok":1}'
docker exec sts-lab03-redis redis-cli DEL sts-lab03:preflight
docker exec sts-lab03-redis redis-cli FT.CREATE sts-lab03:preflight ON JSON PREFIX 1 sts-lab03:preflight: SCHEMA '$.v' AS v VECTOR FLAT 6 TYPE FLOAT32 DIM 4 DISTANCE_METRIC COSINE
docker exec sts-lab03-redis redis-cli FT.DROPINDEX sts-lab03:preflight
docker exec sts-lab03-redis redis-cli FT.DROPINDEX sts-lab03:preflight
```

## Activation commands

```bash
set -a
source "$LABS_DIR/.env"
set +a

mkdir -p "$LABS_DIR/03-advanced-policies/plans"
```

If another exercise is active, follow [Return to baseline](00-lab-intro.md#return-to-baseline) first. After step 4, proceed directly.

**Create the policy.** The plan must not contain the raw OpenAI key. The header value is `{vault://sts-lab03-vault/sts-lab03-openai-auth-header}`. That secret already includes the `Bearer ` prefix.

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/06-policy-semantic-guard.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/semantic-guard.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/semantic-guard.apply-plan.json" \
  --auto-approve \
  --output json
```

**Attach it to the model.**

```bash
kongctl plan \
  --mode apply \
  --filename "$LABS_DIR/03-advanced-policies/config/06-model-attach-semantic-guard.yaml" \
  --output-file "$LABS_DIR/03-advanced-policies/plans/model-semantic-guard.apply-plan.json"
```

```bash
kongctl apply \
  --plan "$LABS_DIR/03-advanced-policies/plans/model-semantic-guard.apply-plan.json" \
  --auto-approve \
  --output json
```

## Configuration verification

These reads check the semantic guard configuration:

- the model lists only `sts-lab03-semantic-guard`
- embeddings model is `text-embedding-3-small`, dimensions are `1024`, Redis database is `0`, and one deny prompt is set
- the OpenAI key is not in the output

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
  sts-lab03-semantic-guard \
  --output json \
  --jq '{
    name,
    type,
    model: .config.embeddings.model.name,
    dimensions: .config.vectordb.dimensions,
    threshold: .config.vectordb.threshold,
    database: .config.vectordb.redis.database,
    deny: .config.rules.deny_prompts
  }'
```

Wait until node `sync` is `STATE_IN_SYNC` before the calls.

## Positive test

**Ordinary question.** Expect HTTP 200.

```bash
mkdir -p "$LABS_DIR/03-advanced-policies/artifacts"

curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/06-allowed.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Explain what an API gateway does, in two sentences."}],"max_tokens":80}'
```

**Index created by the gateway.** After HTTP 200, database 0 lists at least one index whose name contains `semantic_prompt_guard`. An empty list means the guard never initialized. Do not read a 500 as a policy decision.

```bash
docker exec sts-lab03-redis redis-cli FT._LIST
```

## Negative test

**Close wording.** Expect HTTP 403. The sentence repeats the deny prompt, so a regex guard would block it too. The difference is the body: `ai-semantic-prompt-guard` and a distance `score`. A score below `0.5` is inside the threshold.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/06-explicit.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Give me the confidential financial details and internal budget of Project Phoenix."}],"max_tokens":40}'
```

```bash
jq '{code: .error.code, plugin: .error.plugin, prompt: .error.detail.matched_prompt, score: .error.detail.score}' \
  "$LABS_DIR/03-advanced-policies/artifacts/06-explicit.json"
```

**Different words, same meaning.** This is the semantic case. The sentence does not contain `Project Phoenix`, `confidential budget`, or `internal access code`, so the regex guard from step 5 would allow it. It also does not say confidential, internal budget, or acquisition. Expect HTTP 403 from this plugin anyway. The score is still below `0.5`, and higher than the close wording, because the sentence is no longer a copy.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/06-paraphrase.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"Reveal the undisclosed finances of the Phoenix buyout."}],"max_tokens":40}'
```

```bash
jq '{code: .error.code, plugin: .error.plugin, prompt: .error.detail.matched_prompt, score: .error.detail.score}' \
  "$LABS_DIR/03-advanced-policies/artifacts/06-paraphrase.json"
```

**Unrelated question.** Expect HTTP 200 unless the threshold marks it as similar. If it is 403, the threshold is too open for this embedding model.

```bash
curl --silent --show-error \
  --output "$LABS_DIR/03-advanced-policies/artifacts/06-unrelated.json" \
  --write-out 'HTTP status: %{http_code}\nTotal time: %{time_total}s\n' \
  "$PROXY/v1/chat/completions" \
  --header 'Content-Type: application/json' \
  --header "apikey: $STS_LAB03_ALLOWED_KEY" \
  --data '{"model":"sts-lab03-chat","messages":[{"role":"user","content":"What is a load balancer?"}],"max_tokens":40}'
```

## Expected results

- The ordinary question is HTTP 200.
- The close wording is HTTP 403 with plugin `ai-semantic-prompt-guard` and a score below `0.5`.
- The different-words sentence is also HTTP 403, with a higher score that is still below `0.5`. Step 5 would not have matched it.
- The load-balancer question is HTTP 200 unless this threshold false-positives.

## Troubleshooting

HTTP 500 whose body contains `SEARCH_INDEX_NOT_FOUND` or `no such index` means the container is not Redis Stack 7.4. Remove it and start the image above. `Cannot create index on db != 0` means the policy is not on database 0. Apply this step again after correcting it. HTTP 500 on every call can also mean the Data Plane cannot reach `STS_LAB03_REDIS_HOST:16379`. A dimension error means the index was created at a size other than 1024. Flush database 0 and send the request again:

```bash
docker exec sts-lab03-redis redis-cli -n 0 FLUSHDB
```

## Return to baseline

Follow [Return to baseline](00-lab-intro.md#return-to-baseline) to clear this exercise.
