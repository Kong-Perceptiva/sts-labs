# Lab 3. Advanced AI Gateway policies

This lab demonstrates five governance controls on one chat model. The client calls the local proxy with the model name `sts-lab03-chat`. Kong selects `gpt-4o-mini` and attaches the OpenAI credential from the provider `sts-lab03-openai`. The client does not call OpenAI directly.

Run one exercise at a time. After setup in step 4, start any exercise. If one is already active, use [Return to baseline](steps/00-lab-intro.md#return-to-baseline) before switching.

1. Prompt Guard: block literal phrases with regular expressions.
2. Semantic Prompt Guard: block a fictional confidential topic by meaning.
3. PII Sanitizer: replace synthetic email, phone, and card text before OpenAI sees it.
4. Prompt Template: allow only two named templates.
5. Model ACL: allow one consumer group and reject the other. This is `access.acls` on the model, not an AI Policy.

Resources are declared in `config/` and applied with `kongctl plan --mode apply`, then `kongctl apply --plan`. Read the plan before applying it. `--mode apply` limits the change to that file. The default plan mode, sync, also deletes gateway resources that are absent from the file.

Lab 3 uses the gateway, Data Plane, and `$LABS_DIR/.env` from the parent directory. Every new Kong name starts with `sts-lab03-`. The lab does not read or change Lab 1 or Lab 2 resources.

Step 6 needs Redis Stack Server 7.4. Step 7 needs the Kong PII service. Start those containers only in the step that uses them.

## Start

Complete the shared setup in the parent directory: copy `.env.example` to `.env`, fill the values, and export `LABS_DIR`. Add the two Lab 3 keys. Then follow the steps in order.

| Step | File | What it does |
|---|---|---|
| 0 | `steps/00-lab-intro.md` | Scope, plan-then-apply, and how exercises are switched. |
| 1 | `steps/01-prerequisites.md` | Sets `LABS_DIR`. Installs `kongctl` and `jq` when they are missing. |
| 2 | `steps/02-openai-provider.md` | Config Store, vault, and provider `sts-lab03-openai`. |
| 3 | `steps/03-auth-strategy.md` | Key-auth strategy `sts-lab03-key-auth`. |
| 4 | `steps/04-model-and-consumers.md` | Model, two consumers, two groups, and one chat call. |
| 5 | `steps/05-ai-prompt-guard.md` | Regex deny list. |
| 6 | `steps/06-ai-semantic-prompt-guard.md` | Semantic deny list. Needs Redis. |
| 7 | `steps/07-ai-pii-sanitizer.md` | PII placeholders. Needs the PII service. |
| 8 | `steps/08-ai-prompt-template.md` | Two templates. Untemplated calls are rejected. |
| 9 | `steps/09-model-acl.md` | Allow one group on the model. |
| 10 | `steps/10-cleanup.md` | Optional. Deletes Lab 3 resources and its containers. `.env` stays. |

Start at `steps/00-lab-intro.md`.
