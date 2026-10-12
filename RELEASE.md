# Release preparation

Current status: preview candidate. The existing live tests establish basic
completion, code editing, acceptance and Undo; they do not establish compatibility
with every host version, architecture or input method.

Before tagging a release:

- Run the contribution checks from a fresh checkout and record the commit,
  macOS/Xcode versions and supported Nextpad++ version.
- Exercise stale replies after edits, caret movement, tab switches and split
  views in the real editor, plus IME composition, app deactivation, shutdown,
  read-only documents, existing completion menus, Escape, Tab and Undo.
- Test the supported LM Studio chat path with a loaded model and execute the
  dylib on Intel if claiming Intel support. Cross-compilation alone is insufficient.
- Install the ZIP in a fresh plugin configuration and verify setup, all seven
  commands, uninstall and reinstall. Models and servers must be installed separately.
- Update VALIDATION.md and release notes with results and unresolved limitations.
  Choose a version tag only after these checks; no production tag is created here.

`bash scripts/build.sh` produces a universal dylib with an ad-hoc signature and
`build/WritingAssistant.zip`. Ad-hoc signing is not Developer ID signing or
notarization. Validate the distribution against the host's actual loading policy;
arrange Developer ID signing/notarization if required by that distribution channel.
Do not claim notarization for the current artifact.

Publish the ZIP, its SHA-256 checksum, release notes and corresponding source
archive for the exact tag. Preserve all included license notices and provide the
GPL corresponding source. Document the bounded local data flow from README.md.
Raw local investigation records are excluded from the public repository and ZIP.

CI builds and runs deterministic core, ABI and synthetic HTTP checks. It does
not perform live editor, Intel hardware, LM Studio or model-quality validation.
