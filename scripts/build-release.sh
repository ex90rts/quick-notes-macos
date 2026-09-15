#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
info_plist="$project_dir/Info.plist"
scratch_dir="$project_dir/.build/release-arm64"
dist_dir="$project_dir/dist"
resources_dir="$project_dir/Resources"
agent_skill_dir="$project_dir/skills/quick-notes"

bundle_name="QuickNotes.app"
release_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$info_plist")
[[ "$release_version" == <->.<->.<-> ]] || {
    print -u2 "Invalid application version: $release_version"
    exit 2
}

package_basename="QuickNotes-$release_version-macOS-arm64"
archive_name="$package_basename.zip"
disk_image_name="$package_basename.dmg"
output_app="$dist_dir/$bundle_name"
output_archive="$dist_dir/$archive_name"
output_disk_image="$dist_dir/$disk_image_name"
highlight_bundle_name="HighlightSwift_HighlightSwift.bundle"

staging_dir=$(mktemp -d "${TMPDIR%/}/quicknotes-release.XXXXXX")
trap '/bin/rm -rf -- "$staging_dir"' EXIT
staged_app="$staging_dir/$bundle_name"
staged_archive="$staging_dir/$archive_name"
staged_disk_image="$staging_dir/$disk_image_name"

export SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/module-cache"
export CLANG_MODULE_CACHE_PATH="$scratch_dir/module-cache"

cd "$project_dir"
xcrun swift test --arch arm64 --scratch-path "$scratch_dir"
xcrun swift build -c release --arch arm64 --scratch-path "$scratch_dir"
binary_dir=$(xcrun swift build -c release --arch arm64 --scratch-path "$scratch_dir" --show-bin-path)
binary_path="$binary_dir/QuickNotes"
highlight_resource_accessor=$(find "$scratch_dir" \
    -path '*/HighlightSwift.build/Release/*/DerivedSources/resource_bundle_accessor.swift' \
    -type f -print -quit)
highlight_bundle="$binary_dir/$highlight_bundle_name"
highlight_script="$highlight_bundle/Contents/Resources/highlight.min.js"
highlight_source="$highlight_script"
if [[ ! -f "$highlight_source" ]]; then
    highlight_source=$(find "$scratch_dir/checkouts" \
        -path '*/Sources/HighlightSwift/HighlightJS/highlight.min.js' \
        -type f -print -quit)
fi

[[ -x "$binary_path" ]] || { print -u2 "Release executable not found: $binary_path"; exit 3; }
[[ -f "$highlight_resource_accessor" ]] || {
    print -u2 "HighlightSwift generated resource accessor was not found."
    exit 3
}
/usr/bin/grep -Fq 'Bundle.main.resourceURL' "$highlight_resource_accessor" || {
    print -u2 "The selected Swift toolchain generated an app-incompatible HighlightSwift resource lookup."
    exit 3
}
[[ -f "$highlight_source" ]] || {
    print -u2 "HighlightSwift resource is unavailable: $highlight_source"
    exit 3
}
[[ -d "$resources_dir" ]] || { print -u2 "App resources not found: $resources_dir"; exit 4; }
[[ -f "$agent_skill_dir/SKILL.md" ]] || { print -u2 "Quick Notes Agent skill not found: $agent_skill_dir/SKILL.md"; exit 4; }
icon_source="$resources_dir/AppIcon.png"
[[ -f "$icon_source" ]] || { print -u2 "App icon source not found: $icon_source"; exit 5; }
[[ -f "$resources_dir/MenuBarIcon@black.png" ]] || { print -u2 "Black menu bar icon not found"; exit 5; }
[[ -f "$resources_dir/MenuBarIcon@color.png" ]] || { print -u2 "Color menu bar icon not found"; exit 5; }

/bin/mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources" "$dist_dir"
/usr/bin/install -m 755 "$binary_path" "$staged_app/Contents/MacOS/QuickNotes"
/usr/bin/install -m 644 "$info_plist" "$staged_app/Contents/Info.plist"
/usr/bin/ditto "$resources_dir" "$staged_app/Contents/Resources"
/bin/mkdir -p "$staged_app/Contents/Resources/AgentSkills"
/usr/bin/ditto "$agent_skill_dir" \
    "$staged_app/Contents/Resources/AgentSkills/quick-notes"
staged_highlight_bundle="$staged_app/Contents/Resources/$highlight_bundle_name"
if [[ -f "$highlight_script" ]]; then
    /usr/bin/ditto "$highlight_bundle" "$staged_highlight_bundle"
else
    /bin/mkdir -p "$staged_highlight_bundle/Contents/Resources"
    /usr/bin/install -m 644 "$highlight_source" \
        "$staged_highlight_bundle/Contents/Resources/highlight.min.js"
    /usr/bin/plutil -create xml1 "$staged_highlight_bundle/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string highlightswift.HighlightSwift.resources' \
        "$staged_highlight_bundle/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleName string HighlightSwift_HighlightSwift' \
        "$staged_highlight_bundle/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string BNDL' \
        "$staged_highlight_bundle/Contents/Info.plist"
fi
dependency_resource_bundles=("$binary_dir"/*.bundle(N))
for resource_bundle in "${dependency_resource_bundles[@]}"; do
    [[ "${resource_bundle:t}" == "$highlight_bundle_name" ]] && continue
    /usr/bin/ditto "$resource_bundle" \
        "$staged_app/Contents/Resources/${resource_bundle:t}"
done
staged_highlight_script="$staged_highlight_bundle/Contents/Resources/highlight.min.js"
[[ -s "$staged_highlight_script" ]] || {
    print -u2 "HighlightSwift resource was not packaged: $staged_highlight_script"
    exit 8
}
[[ -f "$staged_app/Contents/Resources/AgentSkills/quick-notes/SKILL.md" ]] || {
    print -u2 "Quick Notes Agent skill was not packaged."
    exit 8
}
[[ ! -e "$staged_app/$highlight_bundle_name" ]] || {
    print -u2 "HighlightSwift resource bundle was also packaged at the invalid app-root path."
    exit 8
}

iconset_dir="$staging_dir/AppIcon.iconset"
/bin/mkdir -p "$iconset_dir"
/usr/bin/sips -z 16 16 "$icon_source" --out "$iconset_dir/icon_16x16.png" >/dev/null
/usr/bin/sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
/usr/bin/sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_32x32.png" >/dev/null
/usr/bin/sips -z 64 64 "$icon_source" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
/usr/bin/sips -z 128 128 "$icon_source" --out "$iconset_dir/icon_128x128.png" >/dev/null
/usr/bin/sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
/usr/bin/sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_256x256.png" >/dev/null
/usr/bin/sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
/usr/bin/sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_512x512.png" >/dev/null
/usr/bin/sips -z 1024 1024 "$icon_source" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
/usr/bin/iconutil -c icns "$iconset_dir" -o "$staged_app/Contents/Resources/AppIcon.icns"

architectures=$(/usr/bin/lipo -archs "$staged_app/Contents/MacOS/QuickNotes")
[[ "$architectures" == "arm64" ]] || { print -u2 "Unexpected architectures: $architectures"; exit 6; }

minimum_system=$(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$staged_app/Contents/Info.plist")
[[ "$minimum_system" == "15.0" ]] || { print -u2 "Unexpected minimum macOS version: $minimum_system"; exit 7; }

/usr/bin/codesign --force --sign - --timestamp=none "$staged_app"
/usr/bin/codesign --verify --strict --verbose=2 "$staged_app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$staged_app" "$staged_archive"
/usr/bin/unzip -p "$staged_archive" \
    "$bundle_name/Contents/Resources/$highlight_bundle_name/Contents/Resources/highlight.min.js" \
    >/dev/null
if /usr/bin/unzip -Z1 "$staged_archive" | \
    /usr/bin/grep -Fqx "$bundle_name/$highlight_bundle_name/Contents/Resources/highlight.min.js"; then
    print -u2 "HighlightSwift resource bundle was archived at the invalid app-root path."
    exit 8
fi

dmg_staging_dir="$staging_dir/dmg"
/bin/mkdir -p "$dmg_staging_dir"
/usr/bin/ditto "$staged_app" "$dmg_staging_dir/$bundle_name"
/bin/ln -s /Applications "$dmg_staging_dir/Applications"
/usr/bin/hdiutil create \
    -quiet \
    -volname "Quick Notes $release_version" \
    -srcfolder "$dmg_staging_dir" \
    -ov \
    -format UDZO \
    "$staged_disk_image"
/usr/bin/hdiutil verify "$staged_disk_image" >/dev/null

/bin/rm -rf -- "$output_app"
/bin/rm -f -- "$output_archive" "$output_disk_image"
/usr/bin/ditto "$staged_app" "$output_app"
/usr/bin/install -m 644 "$staged_archive" "$output_archive"
/usr/bin/install -m 644 "$staged_disk_image" "$output_disk_image"

print "Built $output_app"
print "Packaged $output_archive"
print "Packaged $output_disk_image"
