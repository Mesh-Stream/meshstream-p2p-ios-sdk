# Third-party components

MeshStreamKit includes third-party software subject to its own license terms.
These terms are independent of the commercial MeshStreamKit license. Applicable
license texts and copyright notices are preserved in `Licenses/`:

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
Additional license texts and copyright notices are preserved in
`Licenses/RustThirdPartyNotices.txt`. For questions about corresponding third-party
source, contact meshstreamsupport@gmail.com. Source availability obligations for
covered components remain governed by their respective licenses, including any
applicable modifications; the proprietary SDK license does not restrict those rights.
These notices are not a complete SBOM or a legal audit of every platform-specific
dependency.

This inventory is not a statement that a host application's App Store privacy,
export, or redistribution obligations have been satisfied. Integrators must retain
applicable third-party notices and follow the licenses and their SDK agreement.
