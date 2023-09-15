let
  opam-nix-integration = import (
    fetchTarball {
      url = "https://github.com/vapourismo/opam-nix-integration/archive/ea79c9787ef571724b49157c003b832b83a133a5.tar.gz";
      sha256 = "1m2fsb3np0a0mwh8gbpazf4mxcsqc64hiaxx2f9njcksx1hjvsyh";
    }
  );

  rust-overlay = import (
    fetchTarball {
      url = "https://github.com/oxalica/rust-overlay/archive/b91706f9d5a68fecf97b63753da8e9670dff782b.tar.gz";
      sha256 = "1c34aihrnwv15l8hyggz92rk347z05wwh00h33iw5yyjxkvb8mqc";
    }
  );

  pkgsSrc = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/973d6ebcbf54f7030e10ef10bc0c5e7729cfc973.tar.gz";
    sha256 = "1lz090ghfhn280jx8m9zffy2pdy1cwj1fdyci9sfwir8ax8qm5h5";
  };

  pkgs = import pkgsSrc {overlays = [opam-nix-integration.overlay rust-overlay];};

  riscv64Pkgs = import pkgsSrc {
    crossSystem = pkgs.lib.systems.examples.riscv64;
  };
in {
  inherit opam-nix-integration rust-overlay pkgs riscv64Pkgs;
}
