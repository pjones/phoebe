#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash utillinux gawk gnupg
# shellcheck shell=bash

################################################################################
[ -n "${DEBUG:-}" ] && set -x

set -e
set -u

################################################################################
usage() {
cat <<EOF
Usage: $(basename "$0") command [options]

Commands:

  mount: Mount a directory of decrypted secrets.

  umount: Unmount a previously mounted directory.

Options:

  Use the "-h" option after a command name.

Examples:

  $ $(basename "$0") mount -d production

  $ $(basename "$0") umount -d production

EOF
}

################################################################################
mount_usage() {
cat <<EOF
Usage: $(basename "$0") mount -d DIR [options]

  -d DIR   Directory of secrets to decrypt
  -h       This message
  -m DIR   Mount the decrypted secrets on DIR
  -s FILE  Use a symmetric key in FILE for decryption

EOF
}

################################################################################
umount_usage() {
cat <<EOF
Usage: $(basename "$0") umount {-d DIR|-m DIR} [options]

  -d DIR   Directory of secrets that was previously mounted
  -h       This message
  -m DIR   Mount point to unmount

EOF
}

################################################################################
calculate_mount_point() {
  local directory=$1
  echo "${directory}.mnt"
}

################################################################################
# Figure out how much space we need in the tmpfs.
calculate_fs_size() {
  local directory=$1
  local size

  size=$(tar -cf - "$directory" | wc -c)
  echo $((size * 10 / 1024))k
}

################################################################################
read_symmetric_key_file() {
  local file=$1

  case "$file" in
    -)
      # Read from STDIN:
      cat
      ;;

    *.gpg)
      # Read first line from encrypted file like pass(1):
      gpg --use-agent \
          --quiet \
          --decrypt \
          "$file" | head -n 1
      ;;

    *)
      # Read from file:
      cat "$file"
      ;;
  esac
}

################################################################################
decrypt_file() {
  local file=$1
  local source_dir=$2
  local dest_dir=$3
  local symmetric_key=$4

  # Make a new file name rooted under the destination directory:
  local dest_file=$dest_dir${file##$source_dir}
  dest_file=${dest_file%%.gpg} # remove .gpg extension

  # If the encrypted file hasn't changed, skip this file:
  [ "$dest_file" -nt "$file" ] && return

  mkdir -p "$(dirname "$dest_file")"
  echo "==> $dest_file"

  case "$file" in
    *.gpg) # File is encrypted, use gpg:
      if [ -n "$symmetric_key" ]; then
        gpg --batch \
            --quiet \
            --decrypt \
            --passphrase-fd 0 \
            --pinentry-mode loopback \
            "$file" > "$dest_file" \
            <<<"$symmetric_key"
      else
        gpg --use-agent \
            --quiet \
            --decrypt \
            --quiet \
            "$file" > "$dest_file"
      fi
      ;;

    *) # Just copy the file as-is:
      cp "$file" "$dest_file"
      ;;
  esac
}

################################################################################
mount_via_dev_shm() {
  local mount_point=$1
  local temp_dir

  temp_dir=$(mktemp --directory --tmpdir=/dev/shm secrets.XXXXXXXXXX)
  (cd "$(dirname "$mount_point")" && ln -nfs "$temp_dir" "$(basename "$mount_point")")
}

################################################################################
umount_via_dev_shm() {
  local mount_point=$1
  local temp_dir

  temp_dir=$(realpath "$mount_point")

  if [ -d "$temp_dir" ] && [ "$(dirname "$temp_dir")" = "/dev/shm" ]; then
    rm "$mount_point"
    rm -rf "$temp_dir"
  fi
}

################################################################################
mount_via_tmpfs() {
  local mount_point=$1
  local secrets=$2

  if ! findmnt "$mount_point" > /dev/null 2>&1; then
    mkdir -p "$mount_point"
    echo "==> Enter sudo password to mount tmpfs"
    sudo mount -t tmpfs \
         -o size="$(calculate_fs_size "$secrets")" \
         tmpfs "$mount_point"
  fi
}

################################################################################
umount_via_tmpfs() {
  local mount_point=$1

  echo "==> Enter sudo password for unmounting"
  sudo umount "$mount_point"
  rmdir "$mount_point"
}

################################################################################
mount_secrets() {
  local option_secrets=""
  local option_mount_point=""
  local option_symmetric_key_file=""
  local symmetric_key=""

  while getopts "hd:m:s:" o; do
    case "${o}" in
      h) mount_usage
         exit
         ;;

      d) option_secrets=$OPTARG
         ;;

      m) option_mount_point=$OPTARG
         ;;

      s) option_symmetric_key_file=$OPTARG
         ;;

      *) exit 1
         ;;
    esac
  done

  shift $((OPTIND-1))

  if [ -z "$option_secrets" ]; then
    >&2 echo "ERROR: missing -d option to mount"
    exit 1
  fi

  if [ -z "$option_mount_point" ]; then
    option_mount_point=$(calculate_mount_point "$option_secrets")
  fi

  if [ -n "$option_symmetric_key_file" ]; then
    symmetric_key=$(read_symmetric_key_file "$option_symmetric_key_file")
  fi

  if [ ! -L "$option_mount_point" ] && [ -d /dev/shm ]; then
    mount_via_dev_shm "$option_mount_point"
  else
    mount_via_tmpfs "$option_mount_point" "$option_secrets"
  fi

  while IFS= read -r -d '' file; do
    decrypt_file "$file" "$option_secrets" "$option_mount_point" "$symmetric_key"
  done < <(find "$option_secrets"/ -type f -print0)
}

################################################################################
unmount_secrets() {
  local option_secrets=""
  local option_mount_point=""

  while getopts "hd:m:" o; do
    case "${o}" in
      h) umount_usage
         exit
         ;;

      d) option_secrets=$OPTARG
         ;;

      m) option_mount_point=$OPTARG
         ;;

      *) exit 1
         ;;
    esac
  done

  shift $((OPTIND-1))

  if [ -z "$option_mount_point" ] && [ -n "$option_secrets" ]; then
    option_mount_point=$(calculate_mount_point "$option_secrets")
  elif [ -z "$option_mount_point" ]; then
    >&2 echo "ERROR: give -d or -m"
    exit 1
  fi

  if [ -L "$option_mount_point" ]; then
    umount_via_dev_shm "$option_mount_point"
  else
    umount_via_tmpfs "$option_mount_point"
  fi
}

################################################################################
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

command=$1
shift

case "$command" in
  mount)
    mount_secrets "$@"
    ;;

  unmount|umount)
    unmount_secrets "$@"
    ;;

  *)
    usage
    exit 1
    ;;
esac

# Local Variables:
#   mode: sh
#   sh-shell: bash
# End:
