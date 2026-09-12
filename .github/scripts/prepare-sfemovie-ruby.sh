#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
binding="$(cd "${1:?Pass the disposable SFEMovie Ruby checkout}" && pwd)"
litergss="$(cd "${2:?Pass the matching LiteRGSS checkout}" && pwd)"
test -f "$litergss/ext/LiteRGSS/Texture_Bitmap.h"
test -f "$litergss/external/litecgss/src/src/LiteCGSS/Graphics/Texture.h"
# Replace the binding's obsolete copied headers only in its build checkout.
# The links also work from rake-compiler's separate build directory.
rm -rf "$binding/ext/SFEMovie/LiteCGSS"
ln -s "$litergss/external/litecgss/src/src/LiteCGSS" "$binding/ext/SFEMovie/LiteCGSS"
