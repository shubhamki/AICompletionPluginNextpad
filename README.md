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

For a prebuilt package, download `WritingAssistant.zip` from the
[0.1.0 preview release](https://github.com/shubhamki/AICompletionPluginNextpad/releases/tag/v0.1.0).
Read the release limitations before installing. Registry inclusion is pending;
this preview is not yet available through the official catalog.

Requires Apple's Command Line Tools. Run `bash scripts/build.sh` to produce a
universal arm64/x86_64 dylib and `build/WritingAssistant.zip`.

In Nextpad++, use **Settings → Import → Import Plugin(s)…** with that ZIP, or open the app's
Plugins folder and copy the `WritingAssistant` build folder there. Fully quit
and reopen Nextpad++ to load it. The folder and dylib must have matching names.
Use the host's folder command rather than guessing its configuration directory.

## First-time setup: Ollama

No custom `nextpad-*` model is required. The easiest starting setup uses one
standard coding model for both editing and completion.

1. Install [Ollama for Mac](https://ollama.com/download/mac) and open the app.
2. Open Terminal and download the small starter model:

   ```sh
   ollama pull qwen2.5-coder:0.5b
   ```

3. In Nextpad++, open **Plugins → Writing Assistant → Local model settings…**.
4. Choose **Ollama (default port 11434)**. The plugin fills the endpoint for you.
5. Click **Load models**, then select `qwen2.5-coder:0.5b` from the Model dropdown.
   Leave **Inline model** blank to use the same model for both tasks.
6. Click **Test connection**. After it succeeds, check **Suggest automatically as
   I type** if desired, and click **Save**.

The plugin requests the selected model by name. Ollama loads its installed weights
when a generation request arrives. You do not need to run `ollama run` first.
The plugin does not install models, start the server, or train model weights.
The 0.5B model is a small starter; choose another installed coding/chat model for
better quality if your hardware supports it.

## First-time setup: LM Studio

1. Install [LM Studio](https://lmstudio.ai/docs/app), download a coding/chat model,
   and load it.
2. Open LM Studio's **Developer** tab and click **Start server**. Note its port.
3. Open the plugin's **Local model settings** and choose **LM Studio (default
   port 1234)**. If your server shows a different port, change the endpoint field.
4. Click **Load models** and select your coding/chat model from the dropdown.
   Leave Inline model blank. Model names here come from the server; you do not
   need to guess the filename or use an Ollama model name.
5. Click **Test connection**, optionally enable automatic suggestions, then **Save**.

Choose a text-generation/chat model, rather than an embeddings-only model. LM
Studio's visible model list may include downloaded models when just-in-time
loading is enabled. Listing a model does not guarantee it fits in memory or can
generate successfully. See the [server guide](https://lmstudio.ai/docs/developer/core/server)
and [model-list guide](https://lmstudio.ai/docs/developer/openai-compat/models).
Servers requiring an API token are not supported by this plugin.

## Endpoints and troubleshooting

| Server | Default chat endpoint |
| --- | --- |
| Ollama | `http://127.0.0.1:11434/v1/chat/completions` |
| LM Studio | `http://127.0.0.1:1234/v1/chat/completions` |

The server creates the endpoint; the plugin just connects to it. `127.0.0.1`
means this computer. The number after the colon is its port; the chat path stays
`/v1/chat/completions`. The presets fill standard values but do not change the
server's configuration. Choose Custom local endpoint to keep a customized URL.

Ollama defaults to port 11434. If customized, check `OLLAMA_HOST`. For its Mac app,
`launchctl getenv OLLAMA_HOST` shows the configured override; an empty result
normally means the default. For a manually started server, check the listening
address in its Terminal output. LM Studio shows its port in the Developer server
settings. Keep the plugin endpoint on loopback. See [Ollama's configuration guide](https://docs.ollama.com/faq).

- **Server unavailable:** open Ollama, or start LM Studio's Developer server;
  confirm the port, then Load models or Test connection again.
- **No models available:** download a model with the Ollama command above or in
  LM Studio. Load it in LM Studio if needed, then click Load models again.
- **Model missing:** select a name actually listed by your current server. Existing
  settings are preserved when updating; if they name a missing `nextpad-*` profile,
  choose a standard model and clear the optional Inline model field.
- **Suggestions paused:** fix the server/model problem, Test connection again,
  and Save. Failed requests do not retry on every keystroke.

Load models and Test connection query `/v1/models` with a five-second timeout and
send no document text. A fresh successful test for the current settings is required
before saving automatic suggestions as enabled. The plugin checks once at startup.
Normal editing works without a server. Use a locally running model; an available
loopback server may still have a cloud-backed model configured.

## Optional completion optimization and custom profiles

For native Ollama fill-in-the-middle completion, optionally download the public
base model and select it in the Inline model dropdown:

```sh
ollama pull qwen2.5-coder:0.5b-base
```

Keep `qwen2.5-coder:0.5b` as the main editing model. Native FIM uses a 96-token
ceiling, temperature 0.1 and a 4096-token context. Standard instruction/chat models
use chat completion with temperature 0.1 and a 128-token ceiling. Both produce one
short code line after a 450 ms pause. LM Studio uses the chat path.

Advanced users can create the optional `nextpad-coder:0.5b` and
`nextpad-complete:0.5b` profiles from the supplied Modelfiles, after pulling their
respective standard models:

```sh
ollama create nextpad-coder:0.5b -f models/Coder.Modelfile
ollama create nextpad-complete:0.5b -f models/Completion.Modelfile
```

These are reusable prompt/inference configurations, not fine-tuned weights. They
are optional and are never downloaded or created automatically by the plugin.

## Use

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
