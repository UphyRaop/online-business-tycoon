#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
godot="${GODOT_BIN:-godot}"
version=$("$godot" --version)
if [[ "$version" != 4.7.2.stable.* ]]; then
    printf 'Expected Godot 4.7.2 stable, found %s\n' "$version" >&2
    exit 1
fi

"$godot" --headless --path . --editor --import

profile_root=$(mktemp -d)
trap 'rm -rf -- "$profile_root"' EXIT
suites=(
    phase1_test phase2_test final_test corrective_test phase3_test phase33_test ceo_profile_test
    phase1_ui_test phase2_ui_test final_ui_test phase3_ui_test phase33_ui_test phase4_ui_test phase4_finance_test phase4_inventory_ads_test
    phase4_products_campaign_save_test product_management_test phase4_campaign_lifecycle_test company_sale_test company_sale_ui_test
    game_store_test game_ui_test control_style_test dashboard_inventory_test chart_legend_test
    supplier_credit_test supplier_workflow_ui_test web_shell_test
)
for suite in "${suites[@]}"; do
    profile="$profile_root/$suite"
    mkdir -p "$profile/data" "$profile/config" "$profile/cache"
    printf '\nRunning %s\n' "$suite"
    XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" \
        XDG_CACHE_HOME="$profile/cache" OBT_ISOLATED_TEST_PROFILE=1 \
        timeout 60 "$godot" --headless --path . --script "res://$suite.gd"
done

mkdir -p web-build
"$godot" --headless --path . --export-release Web web-build/index.html
for file in index.html index.js index.wasm index.pck; do
    test -s "web-build/$file"
done
