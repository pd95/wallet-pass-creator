
# Keychain-based Wallet Pass Signing

This repository provides a minimal, reproducible setup for signing Apple Wallet passes
using a project-specific macOS Keychain instead of storing private keys on disk.

## Goals

- Private keys live only in a dedicated project keychain
- CSR generated using Keychain Access so the keypair stays in Keychain
- Apple-issued certificates imported back into the same keychain
- Signing uses a temporary export of the identity and deletes it immediately
- Supports multiple Pass Type IDs

## Repository Structure

```text
wallet-pass-keychain-repo/
├─ bin/                scripts
├─ certs/              keychains + Apple WWDR certificate
├─ passes/             pass source folders
├─ passes/*.pkpass     generated pkpass files (next to pass folder)
└─ tmp/                temporary files
```

## Requirements

- macOS
- openssl
- python3
- zip
- security CLI

Download Apple's WWDR certificate and store it as:
`certs/AppleWWDRCAG4.pem`

> Note: If you have Xcode installed, you can find it in your Keychain by searching
> "Apple Worldwide Developer Relations". One of the four matches will have the organization
> unit "G4".  
> Right-click on it and export it in PEM format.

## Workflow

1. Initialize keychain for pass type

   ```bash
   bin/init-pass-keychain.sh pass.example.store-card.sample password
   ```

   This will create a new keychain DB under `certs/`, set its password and configuration
   and will open Keychain Access app to let you create a new public/private key pair along with the CSR request.
   Use a dedicated password for this project keychain. Do not reuse your macOS login keychain password.

2. Create CSR

   Keychain Access → Certificate Assistant → Request Certificate From a Certificate Authority.

   Enter an email address and a name for the certificate request.
   Make sure a public and private key pair is generated (use RSA and 2048 bit).
   Save the CSR to disk.

3. Login to your Apple Developer account and make sure you have your desired Pass Type ID registered under <https://developer.apple.com/account/resources/identifiers/list/passTypeId>.
   - Select "Pass Type IDs" on the right side to show all your registered pass types.
   - If you need to register a new Pass Type press (+).
     - Verify that "Pass Type IDs" is preselected and press "Continue"
     - Specify a description and give an identifier `pass.example.store-card.sample` (matches the sample passes in `passes/`). Press "Continue".
     - Confirm your selection and press "Register"

4. Select the pass type ID from the list
   - Press "Create Certificate" to add a new certificate.
   - Choose service "Pass Type ID Certificate" and press "Continue".
   - Enter a name for your pass certificate (purely informal to allow you manage the list).
   - Choose a Pass Type ID (you've previously registered)
   - Upload the CSR file to generate your signed certificate and press "Continue".
   - Download your certificate as "pass.cer" in your "Downloads" folder

5. Import Apple certificate

   ```bash
   bin/import-pass-cert.sh pass.example.store-card.sample password ~/Downloads/pass.cer
   ```

   This will import the new certificate to the relevant keychain, to form the full "identity"

6. Sign a pass

   ```bash
   bin/sign-pass.sh pass.example.store-card.sample password passes/example-pass
   ```

   `bin/sign-pass.sh` takes 3 required arguments:
   - `<keychain_name>` (without `.keychain-db`)
   - `<password>`: the password used to unlock the dedicated project keychain created by `bin/init-pass-keychain.sh`
   - `<pass_folder>` (relative or absolute path)

   This password should be specific to the project keychain and different from your login keychain password.

   Optional certificate-derived overrides (applied only in temporary signing copy, source `pass.json` is unchanged):
   - `--override-team`
   - `--override-pass-id`

   Example with overrides:

   ```bash
   bin/sign-pass.sh \
     pass.example.store-card.sample \
     password \
     passes/example-pass \
     --override-team \
     --override-pass-id
   ```

   Output is written next to the pass folder as `<pass_folder_name>.pkpass`.
   Example: `passes/example-pass` -> `passes/example-pass.pkpass`.

   Validation behavior:
   - If `teamIdentifier` is missing in `pass.json`, signing fails unless `--override-team` is provided.
   - If `passTypeIdentifier` is missing in `pass.json`, signing fails unless `--override-pass-id` is provided.
   - The script extracts Team ID from the signing certificate subject (`OU`) and compares it with the effective team ID.
   - The script extracts pass type identifier from the signing certificate subject (`UID` / `CN=Pass Type ID: ...`) and compares it with `pass.json`.
   - If Team ID differs, signing fails unless `--override-team` is provided.
   - If pass type differs, signing fails unless `--override-pass-id` is provided.

## Security Notes

Keys never persist outside Keychain.
Signing exports the identity temporarily, signs, then deletes the key material.

## Example Pass Folder

`passes/example-pass/`
must contain:

- pass.json
- icon.png
- icon@2x.png
- logo.png
- logo@2x.png

The script generates manifest.json and signature automatically.
