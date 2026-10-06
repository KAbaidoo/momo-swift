"""Type-check every SDK module at each declared Apple deployment floor."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
platforms = [
    ("watchsimulator", "arm64-apple-watchos8.0-simulator"),
    ("appletvsimulator", "arm64-apple-tvos15.0-simulator"),
    ("iphonesimulator", "arm64-apple-ios16.0-simulator"),
    ("macosx", "arm64-apple-macosx13.0"),
]
for sdk, target in platforms:
    sdkpath = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="momo-" + sdk + "-") as directory:
        out = Path(directory)
        for module in ["MoMoCore", "MoMoCollections", "MoMoDisbursements", "MoMoRemittance", "MoMoSDK"]:
            sources = sorted((repo / "MoMoSDK" / "Sources" / module).rglob("*.swift"))
            command = [
                "xcrun", "swiftc", "-emit-module", "-module-name", module,
                "-swift-version", "6", "-target", target, "-sdk", sdkpath,
                "-I", str(out), "-emit-module-path", str(out / (module + ".swiftmodule")),
                "-module-cache-path", str(out / "cache"),
            ] + list(map(str, sources))
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode:
                print(sdk, module, "FAILED", result.stderr, flush=True)
                raise SystemExit(result.returncode)
            print(sdk, module, "PASS", flush=True)
