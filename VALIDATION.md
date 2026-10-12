# Validation

## Current checks

- Universal arm64/x86_64 build and ad-hoc signature verification.
- Core editor, code-completion and response-validation regression checks.
- Seven-command native ABI load and shutdown harness.
- Synthetic loopback transport tests covering errors, redirects, malformed and
  oversized replies, cancellation, truncation and request reuse.
- Vendored header/license SHA-256 checks and Clang native static analysis.
- Public source history privacy checks and dedicated secret scanning.
- Server/model availability parsing and synthetic checks for available and missing
  models and an unavailable loopback server.

The setup update passes 102 core checks, the ABI harness and synthetic HTTP tests.
Live settings checks verified unavailable-server and missing-model messages,
blocking automatic enablement until a successful check, successful testing of
configured models, and saving the tested settings. The updated plugin was installed
and the open editor document was preserved during restart.

The model-discovery update adds a standard instruction-model default, an optional
inline model that reuses the main model when blank, server presets and editable
model dropdowns populated from the local server. It passes 107 core checks and
synthetic model-list transport checks. Public Qwen base-model examples passed
Python expression checks, C++ syntax checks and C# completion-shape checks.
Native FIM routing now applies only to base/completion models; instruction models
use chat. The public instruction model also passed a synthetic completion through
the plugin's real chat client, with no custom profiles required.
The isolated setup harness is available via `bash scripts/setup-ui.sh`.
The latest model picker and the published release installation passed live checks
on 2026-10-12 as described below.

## Downloaded 0.1.0 release: live installation and setup

- Downloaded the published GitHub release ZIP and checked its SHA-256 against
  the published checksum file: `3a6e746242e58d7d587954d2880a4781edaa185746a1b481c031ffb06e22a2a5`.
- Imported that ZIP through Settings → Import → Import Plugin(s), acknowledged
  Restart Required, and restarted after saving the open document with permission.
- The installed dylib's SHA-256 matched the published artifact:
  `3af97b460ddcec9d7cf19c3474771e5f241777c7ddc76f30e568752de8f132c2`.
  Its code signature verified, and all seven commands appeared in the live host.
- Load models populated the dropdown from the running local server. Keyboard
  selection chose the public `qwen2.5-coder:0.5b` model; a blank inline override,
  Test connection and Save succeeded. Reopening settings preserved the choice.
- Ollama and LM Studio presets filled their respective default endpoints.
  An unavailable loopback port showed Server unavailable, and saving automatic
  suggestions without a successful test was blocked. Restoring and testing the
  working endpoint succeeded.
- A temporary clean configuration showed the standard public model as default,
  a blank inline model, coding mode enabled and automatic suggestions disabled.
  The prior settings were restored after this test.
- In a synthetic scratch tab, typing produced the completion `b` for
  `return a + `; Tab accepted it and one Undo restored the input. An earlier
  two-space variant produced a poor duplicate-function suggestion, which was
  dismissed. This confirms interaction behavior, not general model quality.
- The scratch tab was discarded, the original saved document retained, and the
  user's original model profiles and automatic-suggestion preference restored.

The ZIP was downloaded through GitHub CLI and had no quarantine attribute. This
verifies the actual published artifact and host import path, but not browser-added
quarantine/Gatekeeper behavior or notarization. Intel, live LM Studio inference,
full IME and split-view coverage remain unverified.

Prior live checks on Nextpad++ 1.1.2 confirmed completion previews, Tab acceptance,
Escape dismissal, selected-code correction and one-step Undo in synthetic scratch
documents. Local model examples checked Python expressions and C++ syntax.
These samples do not establish general model quality or project API correctness.
Machine-specific investigation records are excluded from public source.

## Remaining verification

Real-editor stale-result scenarios, split views and IME need full live coverage.
Intel execution and a live LM Studio server remain unverified.
See RELEASE.md before declaring release compatibility.

```sh
bash scripts/build.sh
bash scripts/test.sh
python3 tests/http_fixture.py
shasum -a 256 -c vendor/SHA256SUMS
python3 scripts/privacy_check.py
```
