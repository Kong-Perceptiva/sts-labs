# Step 1. Prerequisites

Set `LABS_DIR` to the `labs` directory. This lab is `$LABS_DIR/01-model-tests`. The shared `.env` is `$LABS_DIR/.env`. On Linux, this installs `kongctl` and `jq` only when each one is missing. Step 2 uses `jq` to filter JSON. Use one block.

> **Replace `/path/to/labs` with the location of the `labs` directory on your machine before you run either block.** Later steps prefix this lab with `$LABS_DIR/01-model-tests`. Both blocks below use the same placeholder.

Debian or Ubuntu:

```bash
export LABS_DIR="/path/to/labs"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v kongctl >/dev/null; then
  if ! command -v unzip >/dev/null && ! command -v bsdtar >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y unzip
  fi
  curl -fsSL https://get.konghq.com/kongctl -o /tmp/kongctl-install.sh
  sh /tmp/kongctl-install.sh --version v1.28.1
  hash -r
fi

kongctl version --full

if ! command -v jq >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y jq
fi

jq --version
```

RHEL:

```bash
export LABS_DIR="/path/to/labs"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v kongctl >/dev/null; then
  if ! command -v unzip >/dev/null && ! command -v bsdtar >/dev/null; then
    sudo dnf install -y unzip
  fi
  curl -fsSL https://get.konghq.com/kongctl -o /tmp/kongctl-install.sh
  sh /tmp/kongctl-install.sh --version v1.28.1
  hash -r
fi

kongctl version --full

if ! command -v jq >/dev/null; then
  sudo dnf install -y jq
fi

jq --version
```

Expected result: `kongctl version --full` prints `1.28.1`, and `jq --version` prints a version.

`kongctl` authenticates with the values loaded in step 2. Do not copy the PAT or the OpenAI key into `~/.config/kongctl/config.yaml` or into a shell command.
