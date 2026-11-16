# Step 6. Speech over HTTP

Run the load once. Later commands in this step use the same shell. The chat call in step 5 must have returned `200` before these two calls. In both calls, `curl` is the client. It sends `apikey` to the Data Plane. The Data Plane removes that header and uses the OpenAI credential from the provider.

The name in the request is the lab model. `sts-tts-lab` selects the text-to-speech route, and Kong sends `tts-1` to OpenAI. `sts-stt-lab` selects the transcription route, and Kong sends `whisper-1`. Putting `tts-1` or `whisper-1` in the request does not match these routes.

The second call transcribes the file the first call writes. Run them in this order.

## Install ffprobe when it is missing

`ffprobe` reads the saved file and reports whether it is an MP3. An error body from the proxy is JSON, and this check is what shows that it was not saved under an `.mp3` name by mistake. Use one block.

Debian or Ubuntu:

```bash
if ! command -v ffprobe >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y ffmpeg
fi

ffprobe -version | head -n 1
```

RHEL:

```bash
if ! command -v ffprobe >/dev/null; then
  sudo dnf install -y ffmpeg
fi

ffprobe -version | head -n 1
```

## Load the shell

This reads `$LABS_DIR/.env` and exports every name in it.

```bash
set -a
source "$LABS_DIR/.env"
set +a
```

## Text to speech

This sends one sentence to `sts-tts-lab` and writes the response body to `$LABS_DIR/01-model-tests/artifacts/demo-tts.mp3`. `artifacts/` is not committed. The sentence is synthetic. The command prints the HTTP status. It has to be `200`. On any other status, the saved file is the error body, not an MP3.

```bash
mkdir -p "$LABS_DIR/01-model-tests/artifacts"

curl --silent --show-error --max-time 60 \
  --output "$LABS_DIR/01-model-tests/artifacts/demo-tts.mp3" \
  --write-out 'HTTP status: %{http_code}\n' \
  "$PROXY/v1/audio/speech" \
  --header "apikey: $STS_TEST_APP_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
    "model": "sts-tts-lab",
    "voice": "alloy",
    "input": "Hello Nikhil, this is a synthetic speech test through Kong AI Gateway."
  }'
```

`ffprobe` then reads the MP3. `format_name` includes `mp3`, and `duration` is a few seconds.

```bash
ffprobe -hide_banner -loglevel error \
  -show_entries format=format_name,duration \
  -of default=nw=1 \
  "$LABS_DIR/01-model-tests/artifacts/demo-tts.mp3"
```

## Speech to text

This uploads the MP3 to `sts-stt-lab`. `jq` prints the transcription from the response. The response is not saved, so a later failure cannot be mistaken for an earlier result. The status has to be `200`. The text should be close to the sentence sent above. A word of difference is acceptable.

```bash
curl --silent --show-error --max-time 120 \
  --write-out '%{stderr}HTTP status: %{http_code}\n' \
  "$PROXY/v1/audio/transcriptions" \
  --header "apikey: $STS_TEST_APP_KEY" \
  --form 'model=sts-stt-lab' \
  --form "file=@$LABS_DIR/01-model-tests/artifacts/demo-tts.mp3;type=audio/mpeg" \
  | jq -r '.text'
```
