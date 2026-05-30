# Updater trust hardening

## Immediate invariant

The updater must not download metadata or installers over plaintext HTTP, credentials-bearing URLs, or redirects that downgrade from HTTPS to HTTP. Gateway-provided updater base URLs are treated as untrusted input and validated before any metadata request is made. The installer download URL is revalidated before download and again after redirects before any downloaded bytes are written or executed.

The current patch intentionally does not pin a release host. The existing gateway API returns the updater endpoint dynamically and the source tree does not define a stable CDN/host contract. Pinning a guessed host would be brittle and could break releases without actually establishing artifact authenticity.

## Required artifact-authenticity design

Transport security alone is not a complete updater trust boundary. A production-grade updater needs a signed manifest that is verified by keys pinned in the client before an installer is executed.

Recommended manifest fields:

- schema version
- application version
- platform and architecture
- installer URL
- installer size
- installer SHA-256 digest
- signing key id
- monotonic release timestamp or build number for rollback protection

Recommended verification flow:

1. Fetch manifest over HTTPS with downgrade redirects disabled.
2. Verify the manifest signature with an in-app pinned public key before trusting any manifest fields.
3. Validate platform, architecture, version ordering, URL scheme, size, and digest.
4. Download the installer over HTTPS with downgrade redirects disabled.
5. Verify byte length and SHA-256 against the signed manifest.
6. Verify platform-native package signature where available: Authenticode on Windows, notarized/signed package on macOS, and distro/package signature strategy for Linux.
7. Execute only after all checks pass.

## Compatibility rule for future manifest rollout

Once the gateway advertises signed-manifest metadata for an update channel, the client must fail closed if the manifest, signature, digest, or native package signature verification is missing or invalid. Silent fallback from a signed update channel to legacy unsigned installers is not allowed.
