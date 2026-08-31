#!/bin/bash
# Bionic's version endpoint is small, but its installer currently publishes only
# SHA-512. Download a newly released AppImage once to verify that checksum and
# calculate the SHA-256 expected by Omarchy's upstream synchronization.
set -euo pipefail

VERSION_URL="https://versions-prod.lmstudio.ai/update/bionic/linux/x86/stable/latest"
INSTALLER_BASE_URL="https://bionic-installers.lmstudio.ai/linux/x64"

release=$(curl -fsSL "${VERSION_URL}")
version=$(jq -r '.version // empty' <<<"${release}")
build=$(jq -r '.build // empty' <<<"${release}")
os=$(jq -r '.os // empty' <<<"${release}")
arch=$(jq -r '.arch // empty' <<<"${release}")

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  [[ ! "${build}" =~ ^[0-9]+$ ]] || [[ "${os}" != linux ]] || [[ "${arch}" != x86 ]]; then
  echo "Upstream returned an invalid Linux x86 release: ${release}" >&2
  exit 1
fi

pkgver="${version}+${build}"
current=$(awk -F= '/^pkgver=/ { print $2; exit }' PKGBUILD)
if [[ -n "${current}" ]] && [[ "$(vercmp "${pkgver}" "${current}")" -le 0 ]]; then
  echo '{}'
  exit 0
fi

release_path="${version}-${build}"
asset="Bionic-${release_path}-x64.AppImage"
url="${INSTALLER_BASE_URL}/${release_path}/${asset}"
expected_sha512=$(curl -fsSL "${url}.sha512" | tr -d '[:space:]')
if [[ ! "${expected_sha512}" =~ ^[0-9a-f]{128}$ ]]; then
  echo "Upstream returned an invalid SHA-512 for ${asset}" >&2
  exit 1
fi

work_dir=$(mktemp -d)
trap 'rm -rf -- "${work_dir}"' EXIT
curl -fL --retry 3 --output "${work_dir}/${asset}" "${url}"
actual_sha512=$(sha512sum "${work_dir}/${asset}" | cut -d' ' -f1)
if [[ "${actual_sha512}" != "${expected_sha512}" ]]; then
  echo "SHA-512 mismatch for ${asset}" >&2
  exit 1
fi

sha256=$(sha256sum "${work_dir}/${asset}" | cut -d' ' -f1)
jq -n --arg pkgver "${pkgver}" --arg sha256 "${sha256}" \
  '{pkgver: $pkgver, sha256sums: {x86_64: [$sha256]}}'
