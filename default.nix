with import <nixpkgs> {}; {
  dEnv = stdenv.mkDerivation {
    name = "d";
    buildInputs = [dmd dub libevent openssl];
  };
}