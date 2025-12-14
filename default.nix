# This file provides compatibility with non-flake Nix (nix-build, nix-shell).
# It uses flake-compat to evaluate the flake.nix without flakes enabled.
#
# Usage:
#   nix-build                    # Build the default package
#   nix-shell                    # Enter the dev shell (via shell.nix)
#   nix-instantiate --eval -A lib  # Access library functions
#
# This file does NOT require maintenance when adding new modules/options.
# It simply wraps flake.nix, so any flake outputs are automatically available.

(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nodeName = lock.nodes.root.inputs.nixpkgs or "nixpkgs";
  in
  fetchTarball {
    url = "https://github.com/edolstra/flake-compat/archive/35bb57c0c8d8b62bbfd284272c928ceb64ddbde9.tar.gz";
    sha256 = "1prd9b1xx8c0sfwnyzksppluj3yl4yaq95j2zl7l3qpvzi6qa5ri";
  }
) {
  src = ./.;
}).defaultNix
