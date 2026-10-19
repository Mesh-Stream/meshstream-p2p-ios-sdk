# SDK Release Maintenance Contract

This contract applies to the MeshStream Web Demo, Android SDK, Apple SDK, and
Windows SDK repositories. Its purpose is to keep the public SDK version, the
customer-facing example, release metadata, and documentation consistent.

## Release rule

Every public SDK release must update its matching public repository before the
release is announced. A Demo must never advertise a version that is unavailable
to a customer through its documented distribution channel.

The supported Demo tracks the latest stable SDK release. A deliberate exception
for a compatibility branch must state the pinned version and its reason in that
repository's README and changelog.

## Required release sequence

1. Build the SDK release candidate and complete platform validation.
2. Publish the SDK artifact through its documented channel.
3. Update the matching repository's version reference, artifact metadata, and
   customer example.
4. Build and run the customer example against the published artifact, not a
   workspace path, local binary, or unpublished package.
5. Update the changelog and README when a public behavior, supported platform,
   integration step, or distribution location changes.
6. Commit the repository changes with the SDK version in the release record.
7. Publish the repository commit and release assets before announcing the SDK.

## Platform obligations

### Web Demo

- Update `@meshstream/p2p-web` in `package.json` and `package-lock.json` to the
  published stable version.
- Run `npm install` and `npm run build`.
- Ensure the build stages `meshstream-sw.js` from the installed npm package.
- Do not use npm aliases, local paths, workspace links, or manually copied SDK
  bundles in the public Demo.
- Verify the deployed [Online Demo](https://demo.meshstream.net/) after release.

### Android

- Update the Maven coordinate in the Media3 example and README.
- Update `releases/<version>.json` with the artifact URL, SHA-256, package size,
  ABI set, and minimum Android version.
- Build the independent example using Maven resolution rather than a local AAR.

### Apple

- Update `Package.swift`, `MeshStreamKit.podspec`, and
  `releases/<version>.json` with the same version, archive URL, and checksum.
- Validate the iOS and macOS examples against the published XCFramework.
- Preserve all required third-party notices in the release package.

### Windows

- Build the DLL, import library, and public header as one versioned package.
- Update the committed release archive and `releases/<version>.json` checksums.
- Build `Examples/ConsoleDemo` using the packaged SDK, not files from the main
  development repository.

## Compatibility and rollback

- Use semantic versioning. Breaking public API or supported-platform changes
  require a major version increment and migration notes.
- A patch or minor release must not silently change a documented public API.
- Keep the previous stable release artifact available until a published
  deprecation or replacement policy says otherwise.
- If a release is withdrawn, mark it as withdrawn in release metadata and
  changelog; do not replace an existing artifact with different bytes.

## Completion evidence

Each release commit must leave a reviewer able to identify:

- the exact SDK version consumed by the example;
- the public download or package coordinate;
- the artifact checksum where binaries are distributed;
- the completed build or device validation; and
- the corresponding changelog entry.

If any item is missing, the repository is not ready to represent that SDK
release publicly.
