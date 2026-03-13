# Wallet Pass Construction Guide

This folder contains pass source folders and signed `.pkpass` artifacts.

A Wallet pass is a **ZIP package** with a strict structure:
- `pass.json` (required): pass metadata + fields shown in Wallet
- image assets (required/optional by design): `icon.png`, `logo.png`, `strip.png`, plus retina variants like `@2x`, `@3x`
- localization folders (optional): `en.lproj/pass.strings`, `fr.lproj/pass.strings`, etc.
- `manifest.json` (generated at signing): SHA-1 hash of each file in the package (except `signature`)
- `signature` (generated at signing): PKCS #7 detached signature over `manifest.json`

## Minimal Source Layout

```text
passes/my-pass/
  pass.json
  icon.png                # 29x29 px
  icon@2x.png             # 58x58 px
  logo.png                # 160x50 px
  logo@2x.png             # 320x100 px
  strip.png               # 375x123 px (optional by style/content)
  strip@2x.png            # 750x246 px (optional)
  en.lproj/pass.strings   # optional localization
```

In this repo, `bin/sign-pass.sh` copies your folder, generates `manifest.json`, signs it, and outputs `passes/<folder>.pkpass`.

## `pass.json` Basics

Required top-level keys for a usable pass:
- `formatVersion` (usually `1`)
- `passTypeIdentifier`
- `serialNumber`
- `teamIdentifier`
- `organizationName`
- `description`
- one pass style object, e.g. `storeCard`

Common optional keys seen in production examples:
- visual: `backgroundColor`, `foregroundColor`, `labelColor`, `logoText`
- barcode(s): prefer `barcodes` array; include `format`, `message`, `messageEncoding`, and usually `altText`
- update channel: `webServiceURL`, `authenticationToken`
- app/store links: `appLaunchURL`, `associatedStoreIdentifiers`
- relevance: `locations`, `maxDistance`
- app payload: `userInfo`

## Localization and Assets

- Put translatable labels/strings in `*.lproj/pass.strings` and reference keys from `pass.json`.
- Keep asset naming exact (`icon.png`, `logo.png`, etc.).
- Provide retina assets (`@2x`, `@3x`) for crisp rendering.
- Apple’s Wallet HIG (updated January 17, 2025) documents current image guidance and dimensions (for example logo `160x50 pt`, strip `375x123 pt`, thumbnail `90x90 pt`).

## Practical Best Practices

Patterns that appear consistently in successful production passes:
- Keep front content minimal: primary identifier + one or two secondary/auxiliary fields.
- Use `backFields` for long text, contact information, and metadata.
- Use localization even for small label differences (`NameLabel` etc.).
- Prefer `barcodes` array for compatibility and future expansion.
- Provide at least `icon` + `logo` at multiple scales; include `strip` when brand/layout benefits from it.
- If passes need lifecycle updates, include `webServiceURL` + `authenticationToken`.

## Validation Checklist

Before signing:
1. Validate JSON:
   - `jq . passes/<your-pass>/pass.json >/dev/null`
2. Confirm required files exist.
3. Ensure localized string keys used in `pass.json` are present in each `pass.strings`.

After signing:
1. List archive contents:
   - `unzip -l passes/<your-pass>.pkpass`
2. Confirm `manifest.json` and `signature` are included.

## Apple References

Checked on March 13, 2026:
- Wallet Human Interface Guidelines (current): https://developer.apple.com/design/human-interface-guidelines/wallet
- Wallet Developer page (current entry point): https://developer.apple.com/wallet/get-started/
- PassKit Programming Guide (package/signing internals): https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Creating.html
