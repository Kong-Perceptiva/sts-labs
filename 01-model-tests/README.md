# Lab 1. Model tests

This lab checks that speech and realtime calls go through a Kong AI Gateway Data Plane. The client sends the lab model name to the local proxy. Kong selects the upstream OpenAI model and attaches the credential from the provider `openai-lab`. The client does not call OpenAI directly.

Four checks, after the provider, auth strategy, models, and consumer exist:

1. Text to speech: text in, an MP3 out.
2. Speech to text: that MP3 in, a transcription out.
3. Realtime text over one WebSocket.
4. Realtime audio: PCM in, a WAV out. The same socket then carries a two-turn conversation.

Resources are declared in `config/` and applied with `kongctl plan --mode apply`, then `kongctl apply --plan`. Read the plan before applying it. `--mode apply` limits the change to that file. The default plan mode, sync, also deletes gateway resources that are absent from the file.

## Start

Complete the shared setup in the parent directory: copy `.env.example` to `.env`, fill the values, and export `LABS_DIR`. Then follow the steps in order.

| Step | File | What it does |
|---|---|---|
| 0 | `steps/00-lab-intro.md` | Scope, plan-then-apply, and the directory layout. |
| 1 | `steps/01-prerequisites.md` | Sets `LABS_DIR`. Installs `kongctl` and `jq` when they are missing. |
| 2 | `steps/02-openai-provider.md` | Config Store, vault, and provider `openai-lab`. |
| 3 | `steps/03-auth-strategy-lab.md` | Key-auth strategy `sts-key-auth-lab`. |
| 4 | `steps/04-models-lab.md` | `sts-tts-lab`, `sts-stt-lab`, `sts-voice-lab`, `sts-chat-lab`. |
| 5 | `steps/05-consumer-lab.md` | Consumer, API key, and one chat call. |
| 6 | `steps/06-speech-http.md` | Text to speech and speech to text. |
| 7 | `steps/07-realtime.md` | Realtime text, conversation, and audio. |
| 8 | `steps/08-cleanup.md` | Optional. Deletes the lab resources and the generated local files. `.env` stays. |

Start at `steps/00-lab-intro.md`.
