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
calculate_fs_size() {
  local directory=$1
  local size

  size=$(du --bytes --summarize "$directory" | awk '{print $1}')
  echo $((size * 2))
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

  if ! findmnt "$option_mount_point" > /dev/null 2>&1; then
    mkdir -p "$option_mount_point"
    echo "==> Enter sudo password to mount tmpfs"
    sudo mount -t tmpfs \
         -o size="$(calculate_fs_size "$option_secrets")" \
         tmpfs "$option_mount_point"
  fi

  while IFS= read -r -d '' file; do
    decrypt_file "$file" "$option_secrets" "$option_mount_point" "$symmetric_key"
  done < <(find "$option_secrets" -type f -print0)
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

  echo "==> Enter sudo password for unmounting"
  sudo umount "$option_mount_point"
  rmdir "$option_mount_point"
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
