# Step 7. Realtime

Run the load once. Later commands in this step use the same shell. The speech calls in step 6 must have succeeded. This step uses the MP3 from text to speech as the audio input.

`sts-voice-lab` is the Kong object. Its route is a WebSocket on `/v1`, and its upstream model is `gpt-realtime-2.1`. The client does not send `sts-voice-lab`. It connects to `$WSS/v1/realtime?model=gpt-realtime-2.1` and sends the API key in the header `apikey`.

`test-realtime.py` is the STS lab client. It has three modes. `text` and `audio` print each JSON command marked `client`, and each server event on its own line. Text arrives as separate `response.output_text.delta` lines. `chat` keeps one WebSocket open for two turns. `Nikhil >` is cyan. `server >` is green, and each text fragment is appended to that same line. Audio payloads are not printed. In `text` and `audio`, client JSON is cyan, server events are green, audio notices are yellow, and errors are red.

A socket that opens is not a successful call. Each mode has to reach `response.done` with status `completed`.

## Load the shell

This reads `$LABS_DIR/.env` and exports every name in it.

```bash
set -a
source "$LABS_DIR/.env"
set +a
```

## Install the client

This creates a virtual environment in `.venv` and installs `websockets`. `.venv` is not committed. `python3 -m venv` also needs `ensurepip`. Without that package the directory is created and `pip` is missing. This block installs the package and recreates `.venv` when `pip` is absent. Use one block.

Debian or Ubuntu:

```bash
if ! python3 -c 'import ensurepip' >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y python3-venv
fi

if [[ ! -x "$LABS_DIR/01-model-tests/.venv/bin/pip" ]]; then
  rm -rf "$LABS_DIR/01-model-tests/.venv"
  python3 -m venv "$LABS_DIR/01-model-tests/.venv"
fi

"$LABS_DIR/01-model-tests/.venv/bin/python" -m pip install --requirement "$LABS_DIR/01-model-tests/requirements.txt"
```

RHEL:

```bash
if ! python3 -c 'import ensurepip' >/dev/null 2>&1; then
  sudo dnf install -y python3
fi

if [[ ! -x "$LABS_DIR/01-model-tests/.venv/bin/pip" ]]; then
  rm -rf "$LABS_DIR/01-model-tests/.venv"
  python3 -m venv "$LABS_DIR/01-model-tests/.venv"
fi

"$LABS_DIR/01-model-tests/.venv/bin/python" -m pip install --requirement "$LABS_DIR/01-model-tests/requirements.txt"
```

## Text

The client asks for one short sentence for the STS lab. Each fragment of that sentence is a `response.output_text.delta` line. The wording varies between calls.

```bash
"$LABS_DIR/01-model-tests/.venv/bin/python" "$LABS_DIR/01-model-tests/test-realtime.py" text
```

The last line is `completed`. Above it, `reply` is one short sentence.

## Chat

This mode is one realtime session, not two separate calls. The client opens a single WebSocket to `$WSS/v1/realtime?model=gpt-realtime-2.1` and leaves it open. Each turn adds a user message to that session and asks the model to respond. The gateway forwards the socket upstream and keeps that session alive, so the second reply can use what Nikhil said in the first turn.

The reply is not one JSON object delivered at the end. The model streams `response.output_text.delta` events, and the client appends each fragment to the `server >` line. `response.done` ends that turn. The socket stays open for the next one.

`Nikhil >` is cyan and already contains the suggested line. Press Enter to send it. `server >` is green.

1. `My name is Nikhil and I am planning to use Kong AI Gateway.` The server answers briefly.
2. `Who am I and what do I want to do?` The server still knows the name and the plan.

```bash
"$LABS_DIR/01-model-tests/.venv/bin/python" "$LABS_DIR/01-model-tests/test-realtime.py" chat
```

The last line is `completed`.

## Audio

`ffmpeg` converts the MP3 from step 6 into raw PCM: 16-bit, mono, 24 kHz. That is the input format this realtime model accepts. Step 6 installed `ffmpeg`.

```bash
mkdir -p "$LABS_DIR/01-model-tests/artifacts"

ffmpeg -nostdin -loglevel error \
  -i "$LABS_DIR/01-model-tests/artifacts/demo-tts.mp3" \
  -f s16le -acodec pcm_s16le -ac 1 -ar 24000 \
  "$LABS_DIR/01-model-tests/artifacts/demo-realtime-input.pcm"
```

The client sends that PCM, then waits for spoken audio in return. The WAV is written only after `response.done` completes with audio. A failed run does not replace a WAV from an earlier success.

```bash
"$LABS_DIR/01-model-tests/.venv/bin/python" "$LABS_DIR/01-model-tests/test-realtime.py" audio
```

The last line is `completed`. `reply` is the transcript of the spoken answer, and the wording varies. `ffprobe` then reads the WAV. `codec_name` is `pcm_s16le`, `sample_rate` is `24000`, and `channels` is `1`.

```bash
ffprobe -hide_banner -loglevel error \
  -show_entries stream=codec_name,sample_rate,channels \
  -of default=nw=1 \
  "$LABS_DIR/01-model-tests/artifacts/demo-realtime-response.wav"
```
