# AGENTS.md

## Purpose

This repository is a minimal macOS workflow for creating and signing Apple Wallet passes (`.pkpass`) using project-specific keychains under `certs/`.

Primary goals:
- Keep private keys in Keychain (not committed files)
- Generate pass `manifest.json` and `signature`
- Produce signed `.pkpass` archives from folders in `passes/`

## Repository Layout

- `bin/init-pass-keychain.sh`: creates/unlocks a dedicated keychain and opens Keychain Access to create CSR/keypair.
- `bin/import-pass-cert.sh`: imports the Apple-issued pass certificate into that keychain.
- `bin/sign-pass.sh`: exports identity temporarily, signs pass, zips `.pkpass`, deletes `tmp/`.
- `certs/`: keychain DB files and Apple WWDR cert (sensitive area).
- `passes/`: pass source folders and sample passes.
- `tmp/`: temporary export/signing workspace (removed by signing script).

## Environment Assumptions

- macOS only (uses `security` and Keychain Access).
- Required CLIs: `security`, `openssl`, `python3`, `zip`.
- Apple WWDR cert must exist at `certs/AppleWWDRCAG4.pem`.
- Codex agent runtime is Linux in this workspace, so scripts cannot be executed here; provide commands/instructions for a macOS host instead of attempting local execution.

## Canonical Workflow

1. Initialize pass keychain:
   - `bin/init-pass-keychain.sh <keychain_name> <password>`
2. Create CSR in Keychain Access for that keychain.
3. In Apple Developer, create/download pass cert (`pass.cer`).
4. Import cert:
   - `bin/import-pass-cert.sh <keychain_name> <password> <path_to_pass.cer>`
5. Sign pass folder:
   - `bin/sign-pass.sh <keychain_name> <password> <pass_folder>`
   - Output is written next to folder: `<pass_folder_basename>.pkpass`.

Example:
- `bin/sign-pass.sh pass.example.offer mypass passes/my-pass`
- Produces `passes/my-pass.pkpass`.

## Important Script Notes

- All scripts expect `<keychain_name>` without `.keychain-db`; scripts append it internally.
- `bin/sign-pass.sh` currently ignores custom output path/password arguments from `README.md`; it uses:
  - fixed export password `dummy123`
  - output path derived from input pass directory
- Signing script removes the entire repo `tmp/` directory at the end.

## Agent Guardrails

- Never commit secrets, private keys, exported `.p12`, or temporary key material.
- Treat `certs/*.keychain-db` as sensitive; avoid modifying/deleting unless explicitly requested.
- Do not run destructive cleanup in `certs/` or `passes/tmp_*` unless user asks.
- Prefer editing scripts over adding new tooling unless needed.
- If testing signing, use sample passes first (`passes/example-pass` and `passes/example-pass-multilang`).

## Quick Validation

- Script lint/syntax:
  - `bash -n bin/init-pass-keychain.sh bin/import-pass-cert.sh bin/sign-pass.sh`
- Sanity-check generated pass:
  - Ensure `manifest.json` and `signature` exist in signed archive.
  - `unzip -l passes/<name>.pkpass`
