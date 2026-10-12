# Writing Assistant for Nextpad++ on macOS

Native plugin prototype with automatic code completion, selected-code improvement
and bug fixes, plus the original writing commands.
Automatic suggestions appear beside the caret after a short typing pause and
the local model's response. **Tab accepts; Escape dismisses.** Suggestions are
disabled on a fresh installation; enable them in Local model settings after
choosing your local server. The document
is unchanged until acceptance. Explicit Rewrite and Fix grammar commands still
use a separate review window.

## Build and install

Requires Apple's Command Line Tools. Run `bash scripts/build.sh` to produce a
universal arm64/x86_64 dylib and `build/WritingAssistant.zip`.

In Nextpad++, use the plugin import command with that ZIP, or open the app's
Plugins folder and copy the `WritingAssistant` build folder there. Fully quit
and reopen Nextpad++ to load it. The folder and dylib must have matching names.
Use the host's folder command rather than guessing its configuration directory.

## Use

Choose **Plugins → Writing Assistant → Local model settings…**.

- Ollama: `http://127.0.0.1:11434/v1/chat/completions`
- LM Studio: `http://127.0.0.1:1234/v1/chat/completions`
- Model: the exact name of a model already installed/loaded in your server.

The recommended setup uses two local Qwen2.5-Coder 0.5B profiles:

- **Model name:** `nextpad-coder:0.5b` for selected-code editing.
- **Inline completion model:** `nextpad-complete:0.5b` for filling the gap at the caret.

Code mode is enabled by default; automatic suggestions require opt-in. Inference is configured with
temperature 0.1, top-p 0.9, top-k 20, repetition penalty 1.05 and a 4096-token
context. Inline completion requests one short line with a 96-token ceiling after
a 450 ms typing pause. Both profiles reuse existing model weights; these are
prompt and inference settings, not newly trained weights.

To reproduce the profiles on another machine:

```sh
ollama pull qwen2.5-coder:0.5b
ollama pull qwen2.5-coder:0.5b-base
ollama create nextpad-coder:0.5b -f models/Coder.Modelfile
ollama create nextpad-complete:0.5b -f models/Completion.Modelfile
```

The plugin does not download models or start servers itself.

If no server is installed or running, open **Local model settings** and use
**Ollama setup** or **LM Studio setup** for the official installation guidance.
For LM Studio, download/load a model and start its local server; enter the exact
model name and clear the Ollama-specific inline model field or replace it with
an available model. For Ollama, create the profiles above after installing it.

**Test connection** checks `/v1/models` with a five-second timeout and sends no
document text. It distinguishes an unavailable server from a missing configured
model, including the inline model when code mode is enabled. A successful check
is required before saving automatic suggestions as enabled. The plugin performs
one availability check at startup; connection failures pause automatic requests
until a successful retest. Normal editing continues without a model server.
Availability does not guarantee inference quality or that a backend runs offline.

Type at least eight bytes of text and pause for an automatic continuation.
The status bar shows “thinking locally” while the model runs. There is no global
keyboard hook or Accessibility permission requirement; Tab is intercepted only
inside this app's focused editor when a valid suggestion is visible. Shift-Tab
and Tab without a suggestion retain their normal behavior. Existing completion
menus and calltips take priority. Mouse actions, new typing, caret movement and
tab changes cancel the old suggestion.

Select text for Rewrite/Fix grammar, or place the caret after text for Continue.
For coding tasks, select a function or small block and choose **Improve code
selection** or **Fix code selection**. Review before accepting. In code mode,
the Continue command also requests code rather than prose.
Review the response and click Accept. Dismiss and closing the preview cancel the
request. Undo reverses an accepted change. Existing completion shortcuts are left
available; commands can be assigned shortcuts using the editor's facilities.

Only localhost or loopback IP endpoints are accepted. Redirects and proxies are disabled.
The plugin transmits only the selection (up to 32 KB), or up to 8 KB before and
2 KB after the caret. Language metadata is used for chat-based code prompts;
local Ollama completion uses raw fill-in-the-middle tokens. It does not send
filenames or other files. The selected local
server determines how its model runs; configure it for local inference.

## Guardrails and current limits

Edits are accepted only if the document identity, full contents, selection, view
and revision still match the request. Tab switches, edits and selection changes
invalidate the suggestion. UTF-8 text and a single ordinary selection are required;
documents above 2 MB and read-only files are refused. Requests time out at 120 seconds.
Truncated, malformed, empty and oversized replies are refused. Reasoning blocks
are removed from model output. Automatic previews use a small AppKit overlay
beside the caret, not gray ghost text inserted into the document. The typing
debounce is separate from model latency. Small coding models still make mistakes
and have no project-wide API knowledge; suggestions use only the bounded
current-document context.

Configuration is stored in `WritingAssistant.plist` in the host-provided plugin
configuration directory. No API keys are used. Remove the plugin's folder and
restart to uninstall; optionally delete this settings file too.

## Validation

Run `bash scripts/test.sh`. Tests exercise editor routing, stale snapshots, UTF-8,
undo grouping, endpoint restrictions, and malformed model responses. The test
runner can optionally contact the local model using synthetic text only.

See `VALIDATION.md` for the actual checks performed and outstanding live UI tests.
See `CONTRIBUTING.md` for development and upstream contribution guidance, and
`RELEASE.md` for the remaining checks before publishing a release.

## Dependencies

Vendored ABI headers come from nextpad-plus-plus/nextpad-plus-plus-macos and
mirror/scintilla. See `vendor/PROVENANCE.md` and included upstream licenses.
The plugin source is provided under GPL-3.0-or-later; upstream files retain their
respective licenses. This is an independent prototype, not an official Nextpad++ plugin.
