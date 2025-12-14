# This file provides nix-shell compatibility for non-flake users.
# It returns the default devShell from the flake.
#
# Usage:
#   nix-shell              # Enter the dev shell
#   nix-shell --pure       # Enter a pure dev shell
#
# This file does NOT require maintenance when adding new modules/options.
# It simply wraps flake.nix's devShell output.

(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  in
  fetchTarball {
    url = "https://github.com/edolstra/flake-compat/archive/35bb57c0c8d8b62bbfd284272c928ceb64ddbde9.tar.gz";
    sha256 = "1prd9b1xx8c0sfwnyzksppluj3yl4yaq95j2zl7l3qpvzi6qa5ri";
  }
) {
  src = ./.;
}).shellNix
