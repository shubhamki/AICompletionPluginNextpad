"""Scan reachable source history without printing potentially sensitive values.

This is a focused privacy guard, not a substitute for a dedicated secret scanner.
"""
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


rules = {
    "home-directory path": re.compile(rb"/" + rb"(?:Users|home)/[^\s/]+/"),
    "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "GitHub credential": re.compile(rb"(?:gh[pousr]_)[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}"),
    "AWS access key": re.compile(rb"(?:AKIA|ASIA)[A-Z0-9]{16}"),
}
failures = []
objects = git("rev-list", "--objects", "--branches", "--tags").splitlines()
blobs = 0
for entry in objects:
    oid, _, name = entry.partition(b" ")
    if git("cat-file", "-t", oid.decode()).strip() != b"blob":
        continue
    blobs += 1
    data = git("cat-file", "blob", oid.decode())
    for label, pattern in rules.items():
        if pattern.search(data):
            failures.append(f"{label} in blob {oid.decode()[:12]} ({name.decode(errors='replace')})")
for entry in git("log", "--branches", "--tags", "--format=%H %ae %ce").splitlines():
    oid, author, committer = entry.split()
    for email in (author, committer):
        if not (email.endswith(b"@users.noreply.github.com") or email == b"noreply@github.com"):
            failures.append(f"personal commit email in {oid.decode()[:12]}")
if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print(f"Privacy checks passed for {blobs} reachable source blobs and commit identities.")
