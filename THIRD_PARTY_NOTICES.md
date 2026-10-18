# Third-party components

MeshStreamKit embeds native components and Rust dependencies. Their licenses are
independent of the proprietary SDK license. The following native license texts are
preserved in `Licenses/`:

| Component | Upstream source | License |
| --- | --- | --- |
| libdatachannel 0.24.5 | https://github.com/paullouisageneau/libdatachannel/tree/v0.24.5 | MPL-2.0 |
| Mbed TLS 3.6.4 | https://github.com/Mbed-TLS/mbedtls/tree/v3.6.4 | Apache-2.0 distribution option |
| libjuice | https://github.com/paullouisageneau/libjuice | MPL-2.0 |
| usrsctp | https://github.com/sctplab/usrsctp | BSD-style; see preserved file |
| plog | https://github.com/SergiusTheBest/plog | MIT |
| nlohmann/json | https://github.com/nlohmann/json | MIT |

The submodule revisions for native dependencies are pinned by libdatachannel's
v0.24.5 source tree. Corresponding source is available from the upstream links.
Rust dependency metadata for this build is recorded in `Licenses/rust-dependencies.json`.
The corresponding license texts and copyright notices from the normal iOS dependency
closure are preserved in `Licenses/RustThirdPartyNotices.txt`; upstream repository
links identify where to obtain the original source. This inventory is not a complete
SBOM or a legal audit of every architecture's platform-specific dependencies.

This inventory is not a statement that a host application's App Store privacy,
export, or redistribution obligations have been satisfied. Integrators must retain
applicable third-party notices and follow the licenses and their SDK agreement.
