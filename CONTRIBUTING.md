# Contributing

This independent macOS plugin targets the Nextpad++ native plugin ABI. The
minimum build target is macOS 12. Compatibility has been exercised with
Nextpad++ 1.1.2 on Apple Silicon; see VALIDATION.md for coverage limits.

Install Apple's Command Line Tools and Python 3, then run:

```sh
shasum -a 256 -c vendor/SHA256SUMS
bash scripts/build.sh
bash scripts/test.sh
python3 tests/http_fixture.py
```

These checks require no model download. The HTTP fixture binds only to loopback
and uses synthetic text. Optional model quality checks are in
`tests/code_model_eval.py` and require the documented Ollama profiles.

Keep changes and commits focused, explain the behavior and reason in the commit
message, and add regression coverage for editor or transport changes. Include
host/macOS versions, test results, and any unverified behavior in a pull request.
Preserve bounded context, stale-result guards, one-step Undo, IME behavior, and
the priority of existing editor completion menus. Do not include user documents,
settings, model weights, credentials, or compiled artifacts in source commits.

For an upstream contribution, discuss the feature and integration approach with
Nextpad++ maintainers before opening a host change. This project can be proposed
as an external plugin; inclusion or endorsement is their decision. Retain the
GPL-3.0-or-later license and vendored notices, and include corresponding source
with binary distribution. Model downloads remain separate from this plugin.
