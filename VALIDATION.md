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
The isolated setup harness is available via `bash scripts/setup-ui.sh`;
live UI verification of this latest model picker is pending because the computer-use
service timed out. The running editor still has the preceding setup version.

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
