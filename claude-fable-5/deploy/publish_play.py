#!/usr/bin/env python3
"""Upload a release AAB to Google Play (internal/closed/production track).

Dependency-free: Python stdlib + the `openssl` binary for JWT signing.

Prereqs (one-time, done by a human in the Play Console UI):
  1. Play Console developer account; app created with package name
     `com.morphcook.app`.
  2. Play App Signing enabled (default for new apps).
  3. A Google Cloud service account linked under Play Console → API access,
     granted "Release to testing tracks" / "Manage production releases".
     Download its JSON key.

Usage:
  python3 deploy/publish_play.py \
      --key play-service-account.json \
      --aab app/build/app/outputs/bundle/release/app-release.aab \
      --track internal \
      [--rollout 1.0] [--notes "first release"]
"""
import argparse
import base64
import json
import mimetypes
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

PACKAGE = "com.morphcook.app"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
TOKEN_URL = "https://oauth2.googleapis.com/token"
BASE = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
UPLOAD_BASE = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token(key_file: str) -> str:
    with open(key_file) as f:
        key = json.load(f)
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64url(json.dumps({
        "iss": key["client_email"],
        "scope": SCOPE,
        "aud": TOKEN_URL,
        "iat": now,
        "exp": now + 3600,
    }).encode())
    signing_input = f"{header}.{claims}".encode()

    with tempfile.NamedTemporaryFile("w", suffix=".pem") as pem:
        pem.write(key["private_key"])
        pem.flush()
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", pem.name],
            input=signing_input, capture_output=True, check=True).stdout
    jwt = f"{header}.{claims}.{b64url(signature)}"

    body = (f"grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"
            f"&assertion={jwt}").encode()
    req = urllib.request.Request(TOKEN_URL, data=body, method="POST", headers={
        "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["access_token"]


def api(token: str, method: str, url: str, payload=None, raw=None,
        content_type="application/json"):
    data = raw if raw is not None else (
        json.dumps(payload).encode() if payload is not None else None)
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": content_type,
    })
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read()
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"API error {e.code} on {method} {url}:\n{e.read().decode()}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", required=True, help="service account JSON key")
    p.add_argument("--aab", required=True, help="path to app-release.aab")
    p.add_argument("--track", default="internal",
                   choices=["internal", "alpha", "beta", "production"])
    p.add_argument("--rollout", type=float, default=1.0,
                   help="staged rollout fraction for production (0..1)")
    p.add_argument("--notes", default="", help="release notes (en-US + de-DE)")
    args = p.parse_args()

    token = access_token(args.key)
    print("· authenticated")

    edit = api(token, "POST", f"{BASE}/edits")
    edit_id = edit["id"]
    print(f"· edit {edit_id} opened")

    with open(args.aab, "rb") as f:
        aab = f.read()
    mimetypes.init()
    bundle = api(token, "POST",
                 f"{UPLOAD_BASE}/edits/{edit_id}/bundles?uploadType=media",
                 raw=aab, content_type="application/octet-stream")
    version_code = bundle["versionCode"]
    print(f"· bundle uploaded, versionCode {version_code}")

    release = {
        "versionCodes": [str(version_code)],
        "status": "completed",
    }
    if args.track == "production" and args.rollout < 1.0:
        release["status"] = "inProgress"
        release["userFraction"] = args.rollout
    if args.notes:
        release["releaseNotes"] = [
            {"language": "en-US", "text": args.notes},
            {"language": "de-DE", "text": args.notes},
        ]
    api(token, "PUT", f"{BASE}/edits/{edit_id}/tracks/{args.track}",
        payload={"track": args.track, "releases": [release]})
    print(f"· assigned to track '{args.track}'")

    api(token, "POST", f"{BASE}/edits/{edit_id}:commit")
    print("✓ committed — release is live on the track (pending Play review "
          "where applicable)")


if __name__ == "__main__":
    main()
