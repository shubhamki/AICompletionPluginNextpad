"""Synthetic local completion checks; never execute generated code."""
import ast
import json
import pathlib
import subprocess
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CASES = [
    ("python-add", "def add(a, b):\n    return a + ", "\n", "python"),
    ("cpp-add", "int add(int a, int b) {\n    return a + ", "\n}\n", "cpp"),
    ("python-identifier", "def double(value):\n    return val", " * 2\n", "python"),
    ("csharp-log", "using UnityEngine;\nclass Game : MonoBehaviour {\n    void StartGame() {\n        Debug.", "\n    }\n}\n", "csharp"),
]
results = []
for name, prefix, suffix, language in CASES:
    body = {
        "model": "qwen2.5-coder:0.5b-base", "raw": True, "stream": False, "keep_alive": "10m",
        "prompt": f"<|fim_prefix|>{prefix}<|fim_suffix|>{suffix}<|fim_middle|>",
        "options": {"temperature": 0.1, "top_p": 0.9, "top_k": 20,
                    "repeat_penalty": 1.05, "num_ctx": 4096, "num_predict": 96,
                    "stop": ["\n", "\r", "<|fim_pad|>", "<|endoftext|>", "<|im_end|>",
                             "<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>"]},
    }
    request = urllib.request.Request("http://127.0.0.1:11434/api/generate",
                                     data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    start = time.monotonic()
    with urllib.request.urlopen(request, timeout=60) as response:
        result = json.load(response)
    seconds = round(time.monotonic() - start, 2)
    code = result["response"]
    assert result["done_reason"] == "stop", (name, result)
    suffix_line = suffix.splitlines()[0] if suffix else ""
    for n in range(min(len(code), len(suffix_line)), 0, -1):
        if code.endswith(suffix_line[:n]):
            code = code[:-n]
            break
    assert code.strip(), (name, result)
    source = prefix + code + suffix
    if language == "python":
        tree = ast.parse(source)
        expression = ast.unparse(tree.body[0].body[0].value)
        assert expression == ("a + b" if name == "python-add" else "value * 2"), source
        validation = "Python syntax and expected return expression passed"
    elif language == "cpp":
        check = subprocess.run(["xcrun", "clang++", "-x", "c++", "-fsyntax-only", "-"],
                               input=source, text=True, capture_output=True)
        assert check.returncode == 0, (source, check.stderr)
        assert "return a + b;" in source, source
        validation = "C++ syntax and expected return expression passed"
    else:
        assert code.startswith("Log(") and code.endswith(");"), source
        validation = "C# completion shape passed; no C# compiler used"
    entry = {"case": name, "seconds": seconds, "completion": code, "validation": validation}
    results.append(entry)
    print(json.dumps(entry), flush=True)
(ROOT / "build/code-model-eval.json").write_text(json.dumps(results, indent=2))
