#pragma once
#include "NppPluginInterfaceMac.h"
#include "Scintilla.h"
#include <algorithm>
#include <string>

namespace wa {
enum class Action { Continue, Rewrite, Grammar, ImproveCode, FixCode };
struct Snapshot {
    NppHandle view = 0;
    intptr_t buffer = 0, document = 0, caret = 0, anchor = 0;
    size_t start = 0, end = 0;
    uint64_t revision = 0;
    std::string text, context, suffix, language;
    int eolMode = SC_EOL_LF;
};
class EditorBridge {
public:
    NppData host{};
    uint64_t revision = 0;
    intptr_t send(NppHandle handle, uint32_t msg, uintptr_t w = 0, intptr_t l = 0) const {
        return host._sendMessage ? host._sendMessage(handle, msg, w, l) : 0;
    }
    NppHandle currentView() const {
        int view = -1;
        send(host._nppHandle, NPPM_GETCURRENTSCINTILLA, 0, (intptr_t)&view);
        return view == 0 ? host._scintillaMainHandle : view == 1 ? host._scintillaSecondHandle : 0;
    }
    std::string read(NppHandle view, size_t count) const {
        std::string result(count + 1, '\0');
        send(view, SCI_GETTEXT, result.size(), (intptr_t)result.data());
        result.resize(count);
        return result;
    }
    bool capture(Action action, Snapshot &s, std::string &error) const {
        s = {};
        s.view = currentView();
        if (!s.view || !host._sendMessage) { error = "Open a document first."; return false; }
        if (send(s.view, SCI_GETREADONLY)) { error = "This document is read-only."; return false; }
        if (send(s.view, SCI_GETSELECTIONS) != 1 || send(s.view, SCI_GETSELECTIONMODE) != SC_SEL_STREAM) {
            error = "Use a single ordinary text selection."; return false;
        }
        if (send(s.view, SCI_GETCODEPAGE) != SC_CP_UTF8) {
            error = "Convert this document to UTF-8 before requesting assistance."; return false;
        }
        auto length = send(s.view, SCI_GETLENGTH);
        if (length < 0 || length > 2 * 1024 * 1024) {
            error = "This prototype supports documents up to 2 MB."; return false;
        }
        s.caret = send(s.view, SCI_GETCURRENTPOS);
        s.anchor = send(s.view, SCI_GETANCHOR);
        if (s.caret < 0 || s.anchor < 0 || s.caret > length || s.anchor > length) {
            error = "Could not read the current selection."; return false;
        }
        s.start = std::min(s.caret, s.anchor); s.end = std::max(s.caret, s.anchor);
        if (action == Action::Continue && s.start != s.end) {
            error = "Place the caret where you want to continue, without selecting text."; return false;
        }
        if (action != Action::Continue && s.start == s.end) {
            error = "Select the text you want to improve first."; return false;
        }
        if (s.end - s.start > 32768) { error = "Select at most 32 KB of text."; return false; }
        s.buffer = send(host._nppHandle, NPPM_GETCURRENTBUFFERID);
        s.document = send(s.view, SCI_GETDOCPOINTER);
        if (!s.buffer || !s.document) { error = "Could not identify the active document."; return false; }
        s.revision = revision;
        s.text = read(s.view, length);
        s.eolMode = static_cast<int>(send(s.view, SCI_GETEOLMODE));
        int language = 0; char languageName[1024]{};
        send(host._nppHandle, NPPM_GETCURRENTLANGTYPE, 0, (intptr_t)&language);
        send(host._nppHandle, NPPM_GETLANGUAGENAME, language, (intptr_t)languageName);
        s.language = languageName;
        if (action == Action::Continue) {
            size_t begin = s.start > 8192 ? s.start - 8192 : 0;
            while (begin < s.start && (static_cast<unsigned char>(s.text[begin]) & 0xc0) == 0x80) ++begin;
            s.context = s.text.substr(begin, s.start - begin);
        } else s.context = s.text.substr(s.start, s.end - s.start);
        size_t after = std::min(s.text.size(), s.end + 2048);
        while (after > s.end && after < s.text.size() && (static_cast<unsigned char>(s.text[after]) & 0xc0) == 0x80) --after;
        s.suffix = s.text.substr(s.end, after - s.end);
        if (s.context.empty()) { error = "Write some text before requesting assistance."; return false; }
        return true;
    }
    bool matches(const Snapshot &s) const {
        return revision == s.revision && currentView() == s.view &&
            send(host._nppHandle, NPPM_GETCURRENTBUFFERID) == s.buffer &&
            send(s.view, SCI_GETDOCPOINTER) == s.document &&
            send(s.view, SCI_GETCURRENTPOS) == s.caret && send(s.view, SCI_GETANCHOR) == s.anchor &&
            send(s.view, SCI_GETSELECTIONS) == 1 && send(s.view, SCI_GETSELECTIONMODE) == SC_SEL_STREAM &&
            !send(s.view, SCI_GETREADONLY) && send(s.view, SCI_GETCODEPAGE) == SC_CP_UTF8 &&
            send(s.view, SCI_GETLENGTH) == static_cast<intptr_t>(s.text.size()) &&
            read(s.view, s.text.size()) == s.text;
    }
    bool apply(const Snapshot &s, const std::string &replacement) {
        if (replacement.empty() || replacement.find('\0') != std::string::npos || !matches(s)) return false;
        send(s.view, SCI_BEGINUNDOACTION);
        send(s.view, SCI_SETTARGETSTART, s.start);
        send(s.view, SCI_SETTARGETEND, s.end);
        send(s.view, SCI_REPLACETARGET, replacement.size(), (intptr_t)replacement.data());
        send(s.view, SCI_SETSEL, s.start + replacement.size(), s.start + replacement.size());
        send(s.view, SCI_ENDUNDOACTION);
        ++revision;
        return true;
    }
};
}
