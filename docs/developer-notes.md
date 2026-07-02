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

Some CPAN requirements are removed for specific image and platform combinations before `cpm install` runs. These removals are also listed in the CPAN build report comment on pull requests.

| Image family | Architecture | Excluded from `core` | Excluded from `3rdparty` |
| --- | --- | --- | --- |
| `*-bookworm`, `*-bullseye` | `linux/amd64` | none | none |
| `*-bullseye` | `linux/386` | `Math::Pari`, `Crypt::Random`, `HiPi` | none |
| `*-bookworm` | `linux/386` | `Math::Pari`, `Crypt::Random`, `HiPi` | `SNMP` |
| `*-bookworm`, `*-bullseye` | `linux/arm/v7` | `Device::Firmata::Constants`, `Math::Pari`, `Crypt::Random`, `HiPi` | `Device::Firmata::Constants`, `SNMP` |
| `*-bookworm` | `linux/arm64` | `Device::Firmata::Constants`, `HiPi` | `Device::Firmata::Constants`, `SNMP` |
| `*-bullseye` | `linux/arm64` | `Device::Firmata::Constants`, `HiPi` | `Device::Firmata::Constants` |

`Device::Firmata::Constants` is only kept on `linux/amd64` and `linux/386`. `Math::Pari` and `Crypt::Random` are removed on `linux/386` and `linux/arm/v7` due runtime instability in `Math::Pari` on those platforms. `HiPi` is only kept on `linux/amd64`, because its dependency chain currently builds reliably only there. `SNMP` is removed where the CPAN module is not usable with the system Net-SNMP library version used by the image.

