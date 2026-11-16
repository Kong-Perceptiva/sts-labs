# Kong AI Gateway labs

Hands-on labs for a local Kong AI Gateway Data Plane connected to Konnect. The client calls the local proxy. Kong holds the upstream credential. `kongctl` talks to Konnect, not to the Data Plane Admin API.

Each numbered directory is one lab. Values shared by every lab live in this directory.

| Path | Contents |
|---|---|
| `.env.example` | Names to fill in. Copy it to `.env`. Do not commit `.env`. |
| `.env` | Konnect token, gateway id, proxy URLs, and keys. |
| `01-model-tests/` | Lab 1. Speech, transcription, and realtime calls through the gateway. |

## Start

Set `LABS_DIR` to this directory, then open Lab 1.

```bash
export LABS_DIR="/path/to/labs"
```

Read `01-model-tests/README.md`, then follow `01-model-tests/steps/` from `00-lab-intro.md`.
