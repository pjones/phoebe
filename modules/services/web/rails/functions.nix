rec {
  # The default base directory for Rails applications:
  base = "/var/lib/rails";

  # Where a Rails application lives:
  home = name: "${base}/${name}";
}
