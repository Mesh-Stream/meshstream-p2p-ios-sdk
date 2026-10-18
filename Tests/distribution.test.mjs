import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import test from "node:test";

const root = fileURLToPath(new URL("../", import.meta.url));
const read = (path) => readFileSync(resolve(root, path), "utf8");
const run = (command, args) => execFileSync(command, args, {
  cwd: root, encoding: "utf8", maxBuffer: 10 * 1024 * 1024,
});

test("SPM resolves a binary product with the published archive and checksum", () => {
  assert.ok(existsSync(resolve(root, "Package.swift")), "Customer Package.swift is missing");
  const release = JSON.parse(read("releases/0.1.0.json"));
  const manifest = JSON.parse(run("swift", ["package", "dump-package"]));
  assert.equal(manifest.name, "MeshStreamKit");
  assert.deepEqual(manifest.products[0].targets, ["MeshStreamKit"]);
  assert.equal(manifest.targets.length, 1);
  assert.equal(manifest.targets[0].type, "binary");
  assert.equal(manifest.targets[0].url, release.url);
  assert.equal(manifest.targets[0].checksum, release.sha256);
  assert.equal(new URL(release.url).origin, "https://sdk.meshstream.net");
});

test("CocoaPods resolves the same archive with a matching SHA-256", () => {
  assert.ok(existsSync(resolve(root, "MeshStreamKit.podspec")), "Customer podspec is missing");
  const release = JSON.parse(read("releases/0.1.0.json"));
  const spec = JSON.parse(run("pod", ["ipc", "spec", "MeshStreamKit.podspec"]));
  assert.equal(spec.name, "MeshStreamKit");
  assert.equal(spec.version, release.version);
  assert.equal(spec.source.http, release.url);
  assert.equal(spec.source.sha256, release.sha256);
  assert.equal(spec.vendored_frameworks, "MeshStreamKit.xcframework");
  assert.equal(spec.platforms.ios, "13.0");
  assert.equal(spec.platforms.osx, "10.14");
});

test("release checksum and platform slices match the actual ZIP", {
  skip: !process.env.MESHSTREAM_SDK_ZIP && "Set MESHSTREAM_SDK_ZIP to validate the binary archive",
}, () => {
  const release = JSON.parse(read("releases/0.1.0.json"));
  const zip = resolve(process.env.MESHSTREAM_SDK_ZIP);
  assert.equal(createHash("sha256").update(readFileSync(zip)).digest("hex"), release.sha256);
  const paths = new Set(run("unzip", ["-Z1", zip]).split("\n"));
  for (const slice of ["ios-arm64", "ios-arm64_x86_64-simulator", "macos-arm64_x86_64"]) {
    assert.ok(paths.has(`MeshStreamKit.xcframework/${slice}/MeshStreamKit.framework/MeshStreamKit`), `Missing ${slice}`);
  }
  assert.ok(paths.has("MeshStreamKit.xcframework/macos-arm64_x86_64/MeshStreamKit.framework/Versions/A/Resources/Info.plist"), "macOS needs a versioned framework bundle for CocoaPods embedding");
});
