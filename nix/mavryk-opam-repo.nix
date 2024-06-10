{runCommand}: let
  revision = builtins.readFile (
    runCommand
    "mavryk-opam-repo-rev"
    {
      src = ../scripts/version.sh;
    }
    ''
      . $src
      echo -n $opam_repository_tag > $out
    ''
  );
in
  fetchTarball "https://gitlab.com/tezos/opam-repository/-/archive/${revision}/opam-repository-${revision}.tar.gz"
