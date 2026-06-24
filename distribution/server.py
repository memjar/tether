"""
Beam — OTA distribution engine for Tether.
Signs IPAs, generates manifests, serves to devices over HTTPS.
Runs standalone or embedded in Tether as a self-hosted distribution node.
"""
import os
import hmac
import hashlib
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

DIST_DIR = Path(os.getenv("BEAM_DIST", "/var/lib/tether-beam"))
SIGNING_IDENTITY = os.getenv("BEAM_IDENTITY", "Apple Distribution: Robert Lewis (237Q6KHJY6)")
PROVISIONING_PROFILE = os.getenv("BEAM_PROFILE", "")
BASE_URL = os.getenv("BEAM_URL", "https://tether.diy")
API_KEY = os.getenv("BEAM_KEY", "")
BUNDLE_ID = "ca.axetechnologies.tether"

app = FastAPI(title="Beam", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["https://tether.diy"], allow_methods=["GET"], allow_headers=["*"])


class BuildInfo(BaseModel):
    version: str
    build: str
    size_bytes: int
    sha256: str
    signed_at: float
    ghost_mode: bool


def _require_key(authorization: Optional[str]) -> None:
    if not API_KEY:
        return
    if not authorization or not hmac.compare_digest(authorization, f"Bearer {API_KEY}"):
        raise HTTPException(401, "unauthorized")


def _manifest_plist(version: str, build: str, ipa_url: str, title: str = "Tether") -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key><string>software-package</string>
                    <key>url</key><string>{ipa_url}</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key><string>{BUNDLE_ID}</string>
                <key>bundle-version</key><string>{version}</string>
                <key>kind</key><string>software</string>
                <key>title</key><string>{title} {version} ({build})</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>"""


def _hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _extract_info_plist(ipa_path: Path) -> dict:
    import plistlib
    with zipfile.ZipFile(ipa_path, "r") as zf:
        for name in zf.namelist():
            if name.endswith(".app/Info.plist") and name.count("/") == 2:
                with zf.open(name) as f:
                    return plistlib.load(f)
    return {}


def _sign_ipa(ipa_path: Path, output_path: Path, ghost: bool = False) -> Path:
    work = Path(tempfile.mkdtemp(prefix="tether-sign-"))
    try:
        with zipfile.ZipFile(ipa_path, "r") as zf:
            zf.extractall(work)

        payload = work / "Payload"
        apps = list(payload.glob("*.app"))
        if not apps:
            raise HTTPException(400, "no .app bundle found in IPA")
        app_bundle = apps[0]

        if PROVISIONING_PROFILE and Path(PROVISIONING_PROFILE).exists():
            shutil.copy2(PROVISIONING_PROFILE, app_bundle / "embedded.mobileprovision")

        entitlements = app_bundle / "entitlements.plist"
        if not entitlements.exists():
            _write_entitlements(entitlements, ghost)

        cmd = [
            "codesign", "--force", "--sign", SIGNING_IDENTITY,
            "--entitlements", str(entitlements),
            "--timestamp", "--generate-entitlement-der",
            str(app_bundle)
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise HTTPException(500, f"codesign failed: {result.stderr.strip()}")

        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, _, files in os.walk(work):
                for fn in files:
                    full = Path(root) / fn
                    zf.write(full, full.relative_to(work))

        return output_path
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _write_entitlements(path: Path, ghost: bool) -> None:
    import plistlib
    ents = {
        "application-identifier": f"237Q6KHJY6.{BUNDLE_ID}",
        "com.apple.developer.team-identifier": "237Q6KHJY6",
        "com.apple.developer.networking.HotspotConfiguration": True,
        "com.apple.developer.networking.multicast": True,
        "com.apple.developer.networking.wifi-info": True,
    }
    if ghost:
        ents["com.apple.private.security.no-sandbox"] = True
        ents["platform-application"] = True
        ents["com.apple.private.mobileinstall.allowedSPI"] = ["Lookup", "Install", "Browse"]
    with open(path, "wb") as f:
        plistlib.dump(ents, f)


@app.get("/health")
def health():
    latest = _latest_build()
    return {
        "status": "ok",
        "service": "beam",
        "latest": latest.version if latest else None,
        "dist_dir": str(DIST_DIR),
    }


@app.post("/upload")
async def upload_ipa(
    file: UploadFile = File(...),
    ghost: bool = False,
    authorization: Optional[str] = Header(None),
):
    _require_key(authorization)
    if not file.filename or not file.filename.endswith(".ipa"):
        raise HTTPException(400, "file must be .ipa")

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    raw = DIST_DIR / "incoming.ipa"
    with open(raw, "wb") as f:
        shutil.copyfileobj(file.file, f)

    info = _extract_info_plist(raw)
    version = info.get("CFBundleShortVersionString", "0.0.0")
    build = info.get("CFBundleVersion", "1")
    tag = "ghost" if ghost else "release"
    out_name = f"tether-{version}-{build}-{tag}.ipa"
    out_path = DIST_DIR / out_name

    _sign_ipa(raw, out_path, ghost=ghost)
    raw.unlink(missing_ok=True)

    sha = _hash_file(out_path)
    size = out_path.stat().st_size

    build_info = BuildInfo(
        version=version, build=build,
        size_bytes=size, sha256=sha,
        signed_at=time.time(), ghost_mode=ghost,
    )
    meta_path = DIST_DIR / f"{out_name}.json"
    meta_path.write_text(build_info.model_dump_json(indent=2))

    ipa_url = f"{BASE_URL}/ipa/{out_name}"
    manifest = _manifest_plist(version, build, ipa_url, "Tether Ghost" if ghost else "Tether")
    manifest_name = f"tether-{version}-{build}-{tag}.plist"
    (DIST_DIR / manifest_name).write_text(manifest)

    return {
        "ok": True,
        "ipa": out_name,
        "manifest": manifest_name,
        "install_url": f"itms-services://?action=download-manifest&url={BASE_URL}/manifest/{manifest_name}",
        "sha256": sha,
        "size": size,
    }


@app.get("/manifest/{name}")
def get_manifest(name: str):
    path = DIST_DIR / name
    if not path.exists() or not name.endswith(".plist"):
        raise HTTPException(404)
    return Response(content=path.read_text(), media_type="application/xml")


@app.get("/ipa/{name}")
def get_ipa(name: str):
    path = DIST_DIR / name
    if not path.exists() or not name.endswith(".ipa"):
        raise HTTPException(404)
    return FileResponse(path, media_type="application/octet-stream", filename=name)


@app.get("/latest")
def latest():
    build = _latest_build()
    if not build:
        raise HTTPException(404, "no builds available")
    return build.model_dump()


@app.get("/latest/install")
def latest_install(ghost: bool = False):
    tag = "ghost" if ghost else "release"
    manifests = sorted(DIST_DIR.glob(f"tether-*-{tag}.plist"), reverse=True)
    if not manifests:
        raise HTTPException(404, "no builds available")
    name = manifests[0].name
    url = f"itms-services://?action=download-manifest&url={BASE_URL}/manifest/{name}"
    return {"install_url": url, "manifest": name}


def _latest_build() -> Optional[BuildInfo]:
    metas = sorted(DIST_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True) if DIST_DIR.exists() else []
    if not metas:
        return None
    import json
    data = json.loads(metas[0].read_text())
    return BuildInfo(**data)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8902)
