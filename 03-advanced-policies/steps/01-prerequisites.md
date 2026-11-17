# Step 1. Prerequisites

## Purpose

Set `LABS_DIR` to the `labs` directory and make sure `kongctl` 1.28.1 and `jq` are available. This lab is `$LABS_DIR/03-advanced-policies`. The shared `.env` is `$LABS_DIR/.env`.

## What will be created or modified

Nothing is created in Konnect. The shell gains `LABS_DIR` and, when the tools are missing, `kongctl` and `jq`.

## Required prerequisites

A shell that can run `bash`, `curl`, and `openssl`. Docker is used only in steps 6, 7, 9, and 10. If Lab 1 already installed `kongctl` 1.28.1, the installer does not run again.

> **Replace `/path/to/labs` with the location of the `labs` directory on your machine before you run either block.** Later steps prefix this lab with `$LABS_DIR/03-advanced-policies`.

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

`kongctl version --full` prints `1.28.1`. `jq --version` prints a version. `openssl version` prints a version. `echo "$LABS_DIR"` is the `labs` directory.

## HTTP test requests

None in this step.

## Expected results

The version lines print, and `LABS_DIR` points at the `labs` directory.

## Explanation of the policy behavior

No policy is configured yet.
