# Step 1. Prerequisites

## Purpose

Set `LABS_DIR` to the `labs` directory and make sure `kongctl` 1.28.1 and `jq` are available. This lab is `$LABS_DIR/04-principal-rate-limiting`. The shared `.env` is `$LABS_DIR/.env`.

## What will be created or modified

Nothing is created in Konnect. The shell gains `LABS_DIR` and, when the tools are missing, `kongctl` and `jq`.

## Required prerequisites

A Linux shell that can run `bash`, `curl`, and `openssl`. Use the block for your distribution below. If an earlier lab already installed `kongctl` 1.28.1, the installer does not run again.

The Identity directory named `default` must already exist. Step 3 looks it up. This step does not create a directory.

> **Replace `/path/to/labs` with the location of the `labs` directory on your machine before you run either block.** Later steps prefix this lab with `$LABS_DIR/04-principal-rate-limiting`. Both blocks below use the same placeholder.

## Commands to preview changes

There is no `kongctl` plan in this step.

## Commands to apply changes

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
openssl version
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
openssl version
```

## Commands to verify configuration

`kongctl version --full` prints `1.28.1`. `jq --version` prints a version. `openssl version` prints a version. `openssl` is used in step 3 to generate the three client keys.

## HTTP test requests

None in this step.

## Expected results

The version commands succeed. `echo "$LABS_DIR"` prints the absolute path of the shared `labs` directory.

## Explanation of the policy behavior

No policy is configured yet. Step 2 loads the Konnect PAT and the OpenAI key from the shared `.env`. Do not copy either secret into `~/.config/kongctl/config.yaml` or directly into a command.
