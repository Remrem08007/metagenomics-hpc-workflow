#!/usr/bin/env bash
set -euo pipefail

ROOT=""
KRAKEN="pluspf"
KAIJU="nr_euk"
KEEP_ARCHIVES=0

usage() {
  cat <<'USAGE'
Usage:
  download_databases.sh --root DIR \
    [--kraken pluspf|pluspfp|none] \
    [--kaiju nr_euk|none] \
    [--keep-archives]

Downloads are pinned to known database releases and inherit HTTPS_PROXY/https_proxy.
No download is performed by the Nextflow analysis itself.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT=$2; shift 2 ;;
    --kraken) KRAKEN=$2; shift 2 ;;
    --kaiju) KAIJU=$2; shift 2 ;;
    --keep-archives) KEEP_ARCHIVES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$ROOT" ]] || { echo "--root is required" >&2; exit 2; }
[[ "$KRAKEN" =~ ^(pluspf|pluspfp|none)$ ]] || { echo "Invalid --kraken: $KRAKEN" >&2; exit 2; }
[[ "$KAIJU" =~ ^(nr_euk|none)$ ]] || { echo "Invalid --kaiju: $KAIJU" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v tar >/dev/null || { echo "tar is required" >&2; exit 1; }

ROOT=$(realpath -m "$ROOT")
mkdir -p "$ROOT/kraken2" "$ROOT/kaiju"

move_tree_contents() {
    local source=$1 dest=$2
    rm -rf "$dest"
    mkdir -p "$dest"
    shopt -s dotglob nullglob
    local entries=("$source"/*)
    ((${#entries[@]} > 0)) || { echo "Nothing to move from $source" >&2; exit 1; }
    mv "${entries[@]}" "$dest"/
    shopt -u dotglob nullglob
}

if [[ "$KRAKEN" != "none" ]]; then
  KRAKEN_RELEASE="20260626"
  case "$KRAKEN" in
    pluspf)  KRAKEN_URL="https://genome-idx.s3.amazonaws.com/kraken/k2_pluspf_${KRAKEN_RELEASE}.tar.gz" ;;
    pluspfp) KRAKEN_URL="https://genome-idx.s3.amazonaws.com/kraken/k2_pluspfp_${KRAKEN_RELEASE}.tar.gz" ;;
  esac

  KRAKEN_ARCHIVE="$ROOT/kraken2/k2_${KRAKEN}_${KRAKEN_RELEASE}.tar.gz"
  KRAKEN_DIR="$ROOT/kraken2/$KRAKEN"

  if [[ ! -f "$KRAKEN_DIR/hash.k2d" || ! -f "$KRAKEN_DIR/opts.k2d" || ! -f "$KRAKEN_DIR/taxo.k2d" ]]; then
    echo "Downloading Kraken2 $KRAKEN ($KRAKEN_RELEASE)..."
    curl -fL --retry 8 --retry-delay 10 --continue-at - -o "$KRAKEN_ARCHIVE" "$KRAKEN_URL"

    tmp="$ROOT/kraken2/.${KRAKEN}.extracting"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    tar -xzf "$KRAKEN_ARCHIVE" -C "$tmp"

    source_dir=$(find "$tmp" -type f -name hash.k2d -printf '%h\n' | head -1)
    [[ -n "$source_dir" ]] || { echo "hash.k2d not found after Kraken2 extraction" >&2; exit 1; }
    for required in hash.k2d opts.k2d taxo.k2d; do
      [[ -f "$source_dir/$required" ]] || { echo "Missing $required after Kraken2 extraction" >&2; exit 1; }
    done

    move_tree_contents "$source_dir" "$KRAKEN_DIR"
    rm -rf "$tmp"
    (( KEEP_ARCHIVES )) || rm -f "$KRAKEN_ARCHIVE"
  else
    echo "Kraken2 database already present: $KRAKEN_DIR"
  fi
fi

if [[ "$KAIJU" != "none" ]]; then
  KAIJU_RELEASE="2023-05-10"
  KAIJU_URL="https://kaiju-idx.s3.eu-central-1.amazonaws.com/2023/kaiju_db_nr_euk_${KAIJU_RELEASE}.tgz"
  KAIJU_ARCHIVE="$ROOT/kaiju/kaiju_db_nr_euk_${KAIJU_RELEASE}.tgz"
  KAIJU_DIR="$ROOT/kaiju/nr_euk"

  if ! find "$KAIJU_DIR" -maxdepth 1 -type f -name '*.fmi' -print -quit 2>/dev/null | grep -q .; then
    echo "Downloading Kaiju nr_euk ($KAIJU_RELEASE)..."
    curl -fL --retry 8 --retry-delay 10 --continue-at - -o "$KAIJU_ARCHIVE" "$KAIJU_URL"

    tmp="$ROOT/kaiju/.nr_euk.extracting"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    tar -xzf "$KAIJU_ARCHIVE" -C "$tmp"

    source_dir=$(find "$tmp" -type f -name '*.fmi' -printf '%h\n' | head -1)
    [[ -n "$source_dir" ]] || { echo "Kaiju .fmi index not found after extraction" >&2; exit 1; }
    for required in nodes.dmp names.dmp; do
      [[ -f "$source_dir/$required" ]] || { echo "Missing $required after Kaiju extraction" >&2; exit 1; }
    done

    move_tree_contents "$source_dir" "$KAIJU_DIR"
    rm -rf "$tmp"
    (( KEEP_ARCHIVES )) || rm -f "$KAIJU_ARCHIVE"
  else
    echo "Kaiju database already present: $KAIJU_DIR"
  fi
fi

echo "Database preparation complete under $ROOT"
