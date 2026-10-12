# Security and privacy

## Threat model

The native plugin runs with the editor's privileges. It sends bounded text to a
configured loopback model server and previews generated text. It does not execute
generated code, fetch models, invoke shells, or send other files or filenames.
Automatic transmission is disabled on fresh installations until enabled in
settings; existing explicitly enabled settings remain enabled.

The local server is a trust boundary. A loopback address does not guarantee its
backend is offline or trustworthy. Use a server you control and configure it for
local inference. Model output may be wrong or influenced by document content;
review before accepting. No tool execution is available to the model.

## Audit and fixes — 2026-10-12

- Removed raw local inspection records from public source history, including
  local app paths and system-tool fingerprints. Removed personal author and
  committer emails from reachable history, using the public GitHub noreply identity.
- No credentials or private keys were found in the scans performed. Native source,
  network handling, editor guards, configuration, package scripts and CI were reviewed.
- Hardened malformed settings booleans, NUL-containing documents, language-name
  bounds and invalid UTF-8 suffix handling. Made automatic submission opt-in and
  canonicalized localhost to a loopback IP before transport to avoid DNS/hosts-file routing.
- Pinned CI checkout to a verified upstream commit and disabled persisted Git
  credentials. CI has read-only repository permissions and no publication step.
- Added a reachable-history privacy guard and ignored local records, credentials
  and runtime configuration. Dedicated secret scanning complements this guard.

Gitleaks 8.30.1 found no leaks in reachable branch/tag history or current files.
Checks include the universal build, editor/transport regression tests, real-dylib
ABI load, synthetic HTTP errors/redirects/limits/cancellation, vendored checksums,
and Clang static analysis. These checks establish scoped coverage, not an absence
of every possible vulnerability. No known critical vulnerability was found in
this review. See VALIDATION.md and RELEASE.md for remaining compatibility checks.

The transport accepts localhost and explicit loopback IPs only, disables proxies,
redirects, cookies and credential storage, bounds replies to 1 MB and times out.
The editor verifies document identity, revision, contents and selection before a
single undoable edit. Replies never cause automatic execution.

## Reporting and maintaining security

Report vulnerabilities using GitHub's private vulnerability reporting for this
repository when available. Avoid public issues containing secrets or private text.
Enable GitHub secret scanning and push protection where available. Before pushing,
run `python3 scripts/privacy_check.py` and a dedicated secret scanner such as
Gitleaks against both Git history and the working directory. Keep dependencies and
CI actions reviewed, and do not commit crash dumps or local model/editor settings.

History rewriting cannot retract existing clones, screenshots, caches or old
commit URLs. Collaborators must reclone after the privacy cleanup rather than merge
old history. GitHub Support controls removal of eligible cached sensitive views;
do not claim that a force-push alone erases every previously accessible copy.
