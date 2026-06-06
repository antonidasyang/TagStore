# TagStore Update Service (MinIO)

TagStore self-updates from a **public MinIO bucket** — there is no web page, no
domain, and no server-side code. The app fetches a static `latest.json`,
compares the advertised version to its own, and downloads the platform package
if a newer one exists.

- Public endpoint: `https://oss.d2ssoft.com` (MinIO, S3-compatible, internal `10.6.2.50`)
- Bucket: `tagstore-updates`
- Manifest URL the app polls: `https://oss.d2ssoft.com/tagstore-updates/latest.json`

## Layout in the bucket

```
tagstore-updates/
├── latest.json
└── 1.0.0.5/
    ├── TagStoreSetup_1.0.0.5.exe     (Windows, Inno Setup)
    ├── TagStore-1.0.0.5.dmg          (macOS, optional)
    └── TagStore-1.0.0.5.tar.gz       (Linux, optional)
```

## `latest.json` format

```json
{
  "version": "1.0.0.5",
  "pubDate": "2026-06-06",
  "notes": "What changed in this release.",
  "platforms": {
    "windows": { "url": "https://oss.d2ssoft.com/tagstore-updates/1.0.0.5/TagStoreSetup_1.0.0.5.exe", "sha256": "<hex>" },
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

## One-time setup: a bucket anyone can download from (no account/password)

**Yes — this is exactly what MinIO's "anonymous download" policy is for.** You
create the bucket once with your admin credentials, then attach a public
*download-only* policy. After that, **anyone with the URL can `GET` objects with
no username, password, or signed request** — but nobody can upload, delete, or
even list the bucket without keys. That's precisely what a release feed needs.

Install the MinIO client `mc`, then:

```bash
# 1. Point mc at the MinIO server using your ADMIN access/secret keys.
#    (Only you need these; end users never do.)
mc alias set d2s https://oss.d2ssoft.com <ACCESS_KEY> <SECRET_KEY>

# 2. Create the bucket
mc mb d2s/tagstore-updates

# 3. Make it publicly downloadable — anonymous READ only.
#    "download" = GET objects by URL; it does NOT allow listing or writing.
mc anonymous set download d2s/tagstore-updates
```

Verify it's reachable with no credentials at all:

```bash
curl -I https://oss.d2ssoft.com/tagstore-updates/latest.json   # expect 200 once uploaded
```

Policy options, for reference:

| `mc anonymous set <policy>` | Anonymous GET object | Anonymous list bucket | Anonymous write |
|-----------------------------|:--------------------:|:---------------------:|:---------------:|
| `download`  ← use this      | ✅ (by exact URL)    | ❌                    | ❌              |
| `public`                    | ✅                   | ✅                    | ✅ (unsafe)     |
| `none` (default)            | ❌                   | ❌                    | ❌              |

Use **`download`**. Avoid `public` — it would let anyone overwrite your
installers. Because listing is off, releases are reachable only by their exact
path, which is why the client fetches a known `latest.json` rather than browsing.

> Alternatively you can set the same thing in the MinIO Console UI:
> *Bucket → Anonymous → Add Access Rule → Prefix `/`, Access `readonly`*.

## Where to upload

Everything goes into the `tagstore-updates` bucket (see the layout above):

- The installer/package → `tagstore-updates/<version>/<file>`
- The manifest → `tagstore-updates/latest.json` (overwrite each release)

You don't place these by hand — `publish.sh` does it. On Windows, build the
installer first with `installer\deploy-windows.ps1` (runs `windeployqt6` +
Inno Setup), then run `publish.sh` to upload.

## Publishing a release

Use `publish.sh` — it uploads the package(s), computes SHA-256, generates
`latest.json`, and uploads the manifest with `Cache-Control: no-cache`:

```bash
./publish.sh 1.0.0.5 \
  --win ../installer/TagStoreSetup_1.0.0.5.exe \
  --notes "Improved AI tagging relevance and consolidated near-duplicate tags."
```

Pass any subset of `--win` / `--mac` / `--linux`. Override `MC_ALIAS`,
`BUCKET`, or `BASE_URL` via environment variables if the server moves.

## Release checklist

1. Bump `version.txt` (e.g. `1.0.0.5`) and add a `CHANGELOG.md` entry.
2. On Windows, run `installer\deploy-windows.ps1 -All` — it builds Release,
   runs `windeployqt6 --qmldir ..\qml`, and compiles the Inno Setup installer
   to `installer\TagStoreSetup_<ver>.exe`.
3. Run `publish.sh <ver> --win <setup.exe> --notes "..."` (from WSL or Git Bash)
   to upload the installer + `latest.json`.
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
