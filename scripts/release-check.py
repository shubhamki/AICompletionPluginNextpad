"""Validate generated release assets and write checksums without local metadata."""
import hashlib
import pathlib
import re
import subprocess
import tarfile
import zipfile

root = pathlib.Path(__file__).resolve().parent.parent
build = root / "build"
version = (root / "VERSION").read_text().strip()
private_path = re.compile(rb"/" + rb"(?:Users|home)/[^\s/]+/")
with zipfile.ZipFile(build / "WritingAssistant.zip") as package:
    for entry in package.infolist():
        parts = pathlib.PurePosixPath(entry.filename).parts
        assert parts and parts[0] == "WritingAssistant" and ".." not in parts
        assert not entry.filename.startswith("/") and "__MACOSX" not in parts
        assert ".DS_Store" not in parts
        assert not private_path.search(package.read(entry)), f"Private path in {entry.filename}"
    binary = package.read("WritingAssistant/WritingAssistant.dylib")
    assert binary == (build / "WritingAssistant/WritingAssistant.dylib").read_bytes()
    assert package.read("WritingAssistant/VERSION").decode().strip() == version
    assert "WritingAssistant/licenses/LICENSE" in package.namelist()
subprocess.run(["codesign", "--verify", "--strict", str(build / "WritingAssistant/WritingAssistant.dylib")], check=True)
arches = subprocess.check_output(["lipo", "-archs", str(build / "WritingAssistant/WritingAssistant.dylib")]).decode().split()
assert set(arches) == {"arm64", "x86_64"}
source = build / f"WritingAssistant-{version}-source.tar.gz"
if source.exists():
    with tarfile.open(source) as archive:
        for entry in archive.getmembers():
            assert ".." not in pathlib.PurePosixPath(entry.name).parts and not entry.name.startswith("/")
            if entry.isfile():
                assert not private_path.search(archive.extractfile(entry).read()), f"Private path in {entry.name}"
assets = [build / "WritingAssistant.zip"] + ([source] if source.exists() else [])
(build / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(asset.read_bytes()).hexdigest()}  {asset.name}\n" for asset in assets))
print(f"Release {version}: package layout, version, signature, universal architectures and private-path checks passed.")
