# Lab 1. Model tests

The lab shows that audio and realtime calls work through a Kong AI Gateway Data Plane. The client calls the local proxy. Kong holds the OpenAI credential and sends the request upstream. The calls do not go to OpenAI directly.

Four checks follow, after the OpenAI provider is in place:

1. Text to speech: synthetic text in, an MP3 out.
2. Speech to text: that MP3 in, a transcription out.
3. Realtime over WebSocket: a text response.
4. Realtime over WebSocket: PCM audio in, a WAV file out.

The Data Plane runs locally and takes its configuration from a Konnect AI Gateway. `kongctl` talks to Konnect. It does not use the Admin API inside the Data Plane.

Each YAML under `config/` is applied from a reviewed plan. `kongctl plan --mode apply` compares that file with the gateway and writes the difference under `plans/`. Konnect stays unchanged. The plan lists the creates and updates from that file. Read it before continuing. `kongctl apply --plan` then performs the saved file. It does not read the YAML again, so the change that runs is the one you just reviewed.

`--mode apply` keeps the plan to that file. The default plan mode is sync. A sync plan also deletes gateway resources that are absent from the file. The saved plan is where that shows up, before anything is removed.

When a step shows more than one `kongctl` command, paste and run each one on its own. Pasting the block at once runs them together, and the output does not show which command printed which lines.

Step 1 installs `kongctl`. Step 2 loads the shared `.env` and creates a provider named `openai-lab` only when that name is missing. An existing provider is left as it is. The OpenAI key is written to a Konnect Config Store and read through a vault. The provider YAML stores the vault reference, not the key. Step 3 creates the auth strategy `sts-key-auth-lab`. The client sends the header `apikey`, and the Data Plane removes it before calling OpenAI. Step 4 creates the lab models `sts-tts-lab`, `sts-stt-lab`, `sts-voice-lab`, and `sts-chat-lab`. Each model uses that strategy and the provider `openai-lab`. Step 5 creates the consumer `sts-test-app-lab` and the credential that stores the API key, then checks that key with one chat call. Step 6 calls text to speech and speech to text through the local proxy. Step 7 opens a WebSocket to `sts-voice-lab`, checks a text reply and a spoken reply, then holds that socket open for a two-turn conversation. Step 8 is optional. It deletes the lab resources from the gateway in dependency order, then removes this lab's `plans/`, `artifacts/`, `out/`, and `.venv`. The shared `.env` is kept.

`LABS_DIR` is the `labs` directory. Step 1 sets it. This lab is `$LABS_DIR/01-model-tests`. The shared `.env` is `$LABS_DIR/.env`.

| Path | Contents |
|---|---|
| `$LABS_DIR/.env.example` | Shared names of the values to fill in. Copy it to `$LABS_DIR/.env`. Do not commit `.env`. |
| `$LABS_DIR/.env` | Shared Konnect, gateway, proxy, and key values. Later labs read this file. |
| `$LABS_DIR/01-model-tests/steps/` | These instructions, in order. |
| `$LABS_DIR/01-model-tests/config/` | Declarative YAML for the OpenAI provider, the lab auth strategy, the lab models, and the lab consumer. |
| `$LABS_DIR/01-model-tests/plans/` | Local `kongctl` plan output. Not committed. |
| `$LABS_DIR/01-model-tests/test-realtime.py` | Realtime client used in step 7. |
| `$LABS_DIR/01-model-tests/requirements.txt` | Python package for that client. |
| `$LABS_DIR/01-model-tests/cleanup.sh` | Optional step 8. Deletes the lab resources from the gateway, then the generated files in this lab. The shared `.env` is kept. |
