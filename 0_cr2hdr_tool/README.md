# Magic Lantern cr2hdr tool - customized

This directory contains files to compile Magic Lantern cr2hdr dual ISO conversion tool on Linux (Arch Linux preferred).

Patches in this directory have some custom features which are not found in the original cr2hdr version. These features include:

- added support for `--dry-run` parameter for cr2hdr

    - When `--dry-run` is enabled, the actual conversion is not done. The tool just checks that conversion is possible

    - This is handy in scripts where we just want to distinguish normal single ISO CR2 files from Dual ISO ones and then perform some custom action

- added support for `baseline` metadata export. Following tags are exported:

    - Baseline Exposure (sample value: 0.25)

    - Baseline Noise (sample value: 0.8)

    - Baseline Sharpness (sample value: 1.2)

    - These values affect RAW image post-processing

    - [More about the meaning of Baseline values](https://www.rawdigger.com/howtouse/deriving-hidden-ble-compensation)

## Custom patches

### 01-patch_tcc_makefile-fix.patch

- A very bad workaround for solving compilation issues (hard-links some required stuff)

### 02_patch_cr2hdr-source_add-dryrun.patch

- Add dry run implementation for cr2hdr

### 03_patch_add_baseline-exif.patch

- Add baseline exif tags for converted dual ISO files (DNG format)

### 04_patch_cr2hdr_disable-strings.patch

- Remove some unnecessary and Windows-specific strings from cr2hdr entries

### 05_patch_modules-makefile_disable-strings.patch

- Disable `module_strings.h` in a cr2hdr modules file

## Working cr2hdr and other software versions - archives

The following versions have been tested:

    - gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2

        - MD5sum: 4869e6a6e1dc11ea0835e8b8213bb194

    - magic-lantern_source_30092017.tar.bz2

        - MD5sum: 1df9f79ad7e549d95f0065d3d00247f4 
