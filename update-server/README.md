# TagStore Update Service (MinIO)

TagStore self-updates from a **public MinIO bucket** — there is no web page, no
domain, and no server-side code. The app fetches a static `latest.json`,
compares the advertised version to its own, and downloads the platform package
if a newer one exists.

- Public endpoint: `https://oss.d2ssoft.com` (MinIO, S3-compatible; internal LAN `http://10.6.1.211:9000`)
- Bucket: `downloads` (shared across products) — TagStore lives under `downloads/tagstore/`
- Manifest URL the app polls: `https://oss.d2ssoft.com/downloads/tagstore/latest.json`

> The `downloads` bucket and the `downloads-app` upload account are managed
> centrally; full details are in [`../docs/软件发布上传指南.md`](../docs/软件发布上传指南.md).
> Each product keeps to its own subfolder — only touch `downloads/tagstore/`.

## Layout in the bucket

```
downloads/
└── tagstore/                          ← our product subfolder (don't touch others)
    ├── latest.json
    └── 1.0.0.5/
        ├── TagStoreSetup_1.0.0.5.exe  (Windows, Inno Setup)
        ├── TagStore-1.0.0.5.dmg       (macOS, optional)
        └── TagStore-1.0.0.5.tar.gz    (Linux, optional)
```

## `latest.json` format

```json
{
  "version": "1.0.0.5",
  "pubDate": "2026-06-06",
  "notes": "What changed in this release.",
  "platforms": {
    "windows": { "url": "https://oss.d2ssoft.com/downloads/tagstore/1.0.0.5/TagStoreSetup_1.0.0.5.exe", "sha256": "<hex>" },
    "macos":   { "url": "...", "sha256": "<hex>" },
    "linux":   { "url": "...", "sha256": "<hex>" }
  }
}
```

- `version` — dotted version compared numerically against the app's `APP_VERSION`.
- `platforms.<os>.url` — direct download URL. A platform may be omitted; clients
  on that OS simply report "up to date".
- `sha256` — optional. When present, the client verifies the download and aborts
  on mismatch. Leave `""` to skip.

## The bucket is already set up (centrally)

The shared `downloads` bucket is already created and set to **anonymous
download** — anyone can `GET` an object by URL, but nobody can list or write
without keys — and the `downloads-app` upload account already exists with
read/write on that bucket only. You do **not** run `mc mb` / `mc anonymous`;
that's the storage admin's job, documented in
[`../docs/软件发布上传指南.md`](../docs/软件发布上传指南.md).

All you need is the `downloads-app` secret in your `minio.secret.env` (next
section). Sanity-check that the feed is reachable with no credentials at all:

```bash
curl -I https://oss.d2ssoft.com/downloads/tagstore/latest.json   # expect 200 once uploaded
```

## Where to upload

Everything goes under our product subfolder in the shared bucket (see the
layout above) — **stay inside `downloads/tagstore/`, never touch other
products' folders**:

- The installer/package → `downloads/tagstore/<version>/<file>`
- The manifest → `downloads/tagstore/latest.json` (overwrite each release)

You don't place these by hand — `publish.sh` does it. On Windows, build the
installer first with `installer\deploy-windows.ps1` (runs `windeployqt6` +
Inno Setup), then run `publish.sh` to upload.

## Publishing a release

### Credentials (one-time, never committed)

Both publish scripts read your MinIO keys from a gitignored file so you never
type them on the command line:

```bash
cd update-server
cp minio.secret.env.example minio.secret.env   # (Windows: Copy-Item)
```

Edit `minio.secret.env` and fill in `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY`
(and `MINIO_ENDPOINT` if it differs). On the first run the script calls
`mc alias set` for you from this file. `minio.secret.env` is in `.gitignore` —
only the `.example` template is tracked. Lock it down on shared machines:

```bash
chmod 600 minio.secret.env                      # POSIX
# Windows: icacls minio.secret.env /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

> The first publish runs `mc alias set` for you from `minio.secret.env`, so you
> don't need to configure `mc` by hand beforehand.

### Run it

Both scripts upload the package(s), compute SHA-256, generate `latest.json`,
and upload the manifest with `Cache-Control: no-cache`. Use whichever matches
your shell — **`publish.ps1` on Windows**, `publish.sh` on
Linux/macOS/WSL/Git-Bash.

**Windows (PowerShell)** — needs the MinIO client `mc.exe`. The script finds it
on PATH or sitting next to `publish.ps1` in `update-server\`. If you don't have
it, pass `-InstallMc` once and the script downloads it for you:

```powershell
.\publish.ps1 -Version 1.0.0.5 -Win ..\installer\TagStoreSetup_1.0.0.5.exe -Notes "..." -InstallMc
```

(`mc.exe` is gitignored.) Subsequent runs don't need the flag:

```powershell
.\publish.ps1 -Version 1.0.0.5 `
  -Win ..\installer\TagStoreSetup_1.0.0.5.exe `
  -Notes "Improved AI tagging relevance and consolidated near-duplicate tags."
```

**Linux / macOS / WSL / Git-Bash:**

```bash
./publish.sh 1.0.0.5 \
  --win ../installer/TagStoreSetup_1.0.0.5.exe \
  --notes "Improved AI tagging relevance and consolidated near-duplicate tags."
```

Pass any subset of windows/macos/linux packages. Override the alias, bucket,
product subfolder, or base URL via `-McAlias`/`-Bucket`/`-Product`/`-BaseUrl`
(PowerShell) or the `MC_ALIAS`/`BUCKET`/`PRODUCT`/`BASE_URL` environment
variables (bash).

## Release checklist

1. Bump `version.txt` (e.g. `1.0.0.5`) and add a `CHANGELOG.md` entry.
2. On Windows, run `installer\deploy-windows.ps1 -All` — it builds Release,
   runs `windeployqt6 --qmldir ..\qml`, and compiles the Inno Setup installer
   to `installer\TagStoreSetup_<ver>.exe`.
3. Run `publish.ps1 -Version <ver> -Win <setup.exe> -Notes "..."` (or the bash
   `publish.sh` equivalent) to upload the installer + `latest.json`.
4. Existing installs pick up the update on their next launch (silent check ~4s
   after startup) or via **Settings → General → Check for Updates**.

## How the client behaves

- On launch, ~4s in, the app silently GETs `latest.json`. If a newer version
  exists for the current OS, an "Update Available" dialog pops with the notes.
- **Windows**: downloads `TagStoreSetup_<ver>.exe`, launches it `/SILENT`, and
  quits so the installer can replace the running binary.
- **macOS / Linux**: downloads the package and opens it with the OS handler for
  the user to finish (no in-app bundle-swap pipeline yet).
- A failed silent check is swallowed quietly; manual checks surface errors.
