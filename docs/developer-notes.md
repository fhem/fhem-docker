# Developer Notes

This page collects build and CI details that are mainly relevant for maintainers and contributors.

### CPAN inventory

The generated `cpanfile` artifacts describe the expected CPAN dependencies before the image build starts. To document what actually ended up in an image, the build now exports an inventory of installed Perl modules after the CPAN installation stage finished.

For every platform built in GitHub Actions, the `cpan_build` job builds a dedicated export stage and uploads an artifact named like `cpan-inventory-bookworm-arm64`. It contains:

* `core/core-modules.tsv|json` for the modules installed from the FHEM `cpanfile`
* `3rdparty/3rdparty-modules.tsv|json` for the modules installed from the `3rdParty/cpanfile`
* `all/all-modules.tsv|json` for the combined installed module set
* `verify/core|3rdparty|all/*` for the requirement verification reports
* `logs/core-install.log` and `logs/3rdparty-install.log` for the captured `cpm install` output

The inventory is generated directly in `build-cpan` after the `cpm install` steps and exported through a separate `cpan-inventory` stage. This keeps the inventory out of the regular runtime images and still makes it possible to compare the dynamic `cpanfile` input with the actually installed module set even when the CPAN build layer was restored from cache.

For verification, `build-cpan` now reads the generated `cpanfile`s directly inside the container, validates them with `require` against the real Perl environment, and correlates unresolved modules with the captured install logs. The workflow host only evaluates the exported verification reports. The `cpan_build` job only fails for actionable verification results such as probable install failures or real version mismatches.

Some CPAN requirements are removed for specific image and platform combinations before `cpm install` runs. These removals are also listed in the per platform CPAN build report in the job summary.

| Image family | Architecture | Excluded from `core` | Excluded from `3rdparty` |
| --- | --- | --- | --- |
| `*-bookworm`, `*-bullseye` | `linux/amd64` | none | none |
| `*-bullseye` | `linux/386` | `Math::Pari`, `Crypt::Random`, `HiPi` | none |
| `*-bookworm` | `linux/386` | `Math::Pari`, `Crypt::Random`, `HiPi` | `SNMP` |
| `*-bookworm`, `*-bullseye` | `linux/arm/v7` | `Device::Firmata::Constants`, `Math::Pari`, `Crypt::Random`, `HiPi` | `Device::Firmata::Constants`, `SNMP` |
| `*-bookworm` | `linux/arm64` | `Device::Firmata::Constants`, `HiPi` | `Device::Firmata::Constants`, `SNMP` |
| `*-trixie` | `linux/amd64` | none | none |
| `*-trixie` | `linux/arm/v7` | `Device::Firmata::Constants`, `Math::Pari`, `Crypt::Random`, `HiPi` | `Device::Firmata::Constants`, `SNMP` |
| `*-trixie` | `linux/arm64` | `Device::Firmata::Constants`, `HiPi` | `Device::Firmata::Constants`, `SNMP` |
| `*-bullseye` | `linux/arm64` | `Device::Firmata::Constants`, `HiPi` | `Device::Firmata::Constants` |

`Device::Firmata::Constants` is only kept on `linux/amd64` and `linux/386`. `Math::Pari` and `Crypt::Random` are removed on `linux/386` and `linux/arm/v7` due runtime instability in `Math::Pari` on those platforms. `HiPi` is only kept on `linux/amd64`, because its dependency chain currently builds reliably only there. `SNMP` is removed where the CPAN module is not usable with the system Net-SNMP library version used by the image. The trixie images keep the bookworm exclusions until `SNMP` has been verified against trixie's Net-SNMP library. `*-trixie` is not built for `linux/386`, because the official Perl trixie images are not published for that platform.

### CPAN build report on pull requests

Every leg of the `cpan_build` matrix writes its detailed report into its own job summary and additionally uploads a small status file as an artifact named like `cpan-status-bookworm-arm64`. The separate `cpan_report` job collects those status files and maintains a single pull request comment that only states whether all image and platform combinations verified successfully. Per platform details stay in the job summaries and in the `cpan-inventory-*` artifacts, so a pull request no longer collects one comment per matrix leg.

The comment is identified by the marker `<!-- cpan-build-report:summary -->` and is updated in place on later runs. Comments that older runs of the workflow left behind for individual matrix legs are removed by the same job.

### Release series and image variants

The `variants` job decides which Dockerfiles a workflow run builds; every other job takes its matrix from that job's outputs.

| Event | Built variants | Example image tags |
| --- | --- | --- |
| Release `v5.x` (below `TRIXIE_MIN_MAJOR`) | `-bookworm`, `-threaded-bookworm` | `5.5.2-bookworm`, `5-bookworm` |
| Release `v6.x` and later | `-trixie`, `-threaded-trixie` | `6.0.0-trixie`, `6-trixie` |
| Push, pull request, manual run | all four | `dev-bookworm`, `dev-trixie`, `pr-123-trixie` |

`TRIXIE_MIN_MAJOR` is set in the `variants` job. Bookworm fixes are released as `v5.x`, trixie releases as `v6.x`. A release tag that does not start with a major version fails the run.
