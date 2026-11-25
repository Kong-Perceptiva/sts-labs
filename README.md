# Kong AI Gateway labs

Hands-on labs for a local Kong AI Gateway Data Plane connected to Konnect. The client calls the local proxy. Kong holds the upstream credential. `kongctl` talks to Konnect, not to the Data Plane Admin API.

Each numbered directory is one lab. Values shared by every lab live in this directory.

| Path | Contents |
|---|---|
| `.env.example` | Names to fill in. Copy it to `.env`. Do not commit `.env`. |
| `.env` | Konnect token, gateway id, proxy URLs, and keys. |
| `01-model-tests/` | Lab 1. Speech, transcription, and realtime calls through the gateway. |
| `02-policy-tests/` | Lab 2. Request and token rate limits on one chat model. |
| `03-advanced-policies/` | Lab 3. Five governance policies on one chat model. |
| `04-principal-rate-limiting/` | Lab 4. The Lab 2 rate limits, counted by Kong Identity principals. |

## Start

Set `LABS_DIR` to this directory, then open Lab 1.

```bash
export LABS_DIR="/path/to/labs"
```

Read `01-model-tests/README.md`, then follow `01-model-tests/steps/` from `00-lab-intro.md`.

Lab 2 uses the same gateway, Data Plane, and `.env`. It does not use Lab 1's named resources. Read `02-policy-tests/README.md`, then follow `02-policy-tests/steps/` from `00-lab-intro.md`.

Lab 3 uses the same gateway, Data Plane, and `.env`. It does not use Lab 1 or Lab 2 named resources. Read `03-advanced-policies/README.md`, then follow `03-advanced-policies/steps/` from `00-lab-intro.md`.

Lab 4 uses the same gateway, Data Plane, and `.env`. It does not use Lab 1, Lab 2, or Lab 3 named resources. It does add principals to the existing Identity directory named `default`. Read `04-principal-rate-limiting/README.md`, then follow `04-principal-rate-limiting/steps/` from `00-lab-intro.md`.
