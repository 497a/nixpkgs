{
  lib,
  stdenv,
  fetchurl,
  fetchpatch2,
  makeWrapper,
  haskellPackages,
  haskell,
  which,
  swi-prolog,
  rlwrap,
  tk,
  curl,
  git,
  unzip,
  gnutar,
  coreutils,
  sqlite,
}:

let
  pname = "pakcs";
  version = "3.7.2";

  # Don't switch to "Current release" without a reason, because its
  # source updates without version bump. Prefer last from "Older releases" instead.
  src = fetchurl {
    url = "https://www.informatik.uni-kiel.de/~pakcs/download/pakcs-${version}-src.tar.gz";
    hash = "sha256-ZfQUgFqmPPCeDx/T5G/JdvYDq/7XbvsgxPcEX4y9HZ4=";
  };

  curry-frontend =
    (haskellPackages.override {
      overrides = self: super: {
        curry-frontend = lib.pipe (super.callPackage ./curry-frontend.nix { }) [
          haskell.lib.doJailbreak
          (haskell.lib.compose.overrideCabal (drv: {
            inherit src;
            postUnpack = "sourceRoot+=/frontend";
          }))
          (haskell.lib.compose.appendPatch
            # mtl 2.3 compatibility has been fixed upstream but it's not in
            # the release yet
            (
              fetchpatch2 {
                name = "fix-mtl-2.3.patch";
                url = "https://git.ps.informatik.uni-kiel.de/curry/curry-frontend/-/commit/3b26d2826141fee676da07939c2929a049279b70.diff";
                hash = "sha256-R3XjoUzAwTvDoUEAIIjmrSh2r4RHMqe00RMIs+7jFPY=";
              }
            )
          )
        ];
      };
    }).curry-frontend;

in
stdenv.mkDerivation {
  inherit pname version src;

  buildInputs = [ swi-prolog ];
  nativeBuildInputs = [
    which
    makeWrapper
  ];

  makeFlags = [
    "CURRYFRONTEND=${curry-frontend}/bin/curry-frontend"
    "DISTPKGINSTALL=yes"
    # Not needed, just to make script pass
    "CURRYTOOLSDIR=0"
    "CURRYLIBSDIR=0"
  ];

  preConfigure = ''
    for file in examples/test.sh             \
                currytools/optimize/Makefile \
                testsuite/test.sh            \
                scripts/cleancurry.sh        \
                scripts/compile-all-libs.sh; do
        substituteInPlace $file --replace "/bin/rm" "rm"
    done
  '';

  preBuild = ''
    mkdir -p $out/pakcs
    cp -r * $out/pakcs
    cd $out/pakcs
  '';

  installPhase = ''
    runHook preInstall

    ln -s $out/pakcs/bin $out

    mkdir -p $out/share/emacs/site-lisp
    ln -s $out/pakcs/tools/emacs $out/share/emacs/site-lisp/curry-pakcs

    wrapProgram $out/pakcs/bin/pakcs \
      --prefix PATH ":" "${rlwrap}/bin" \
      --prefix PATH ":" "${tk}/bin"

    # List of dependencies from currytools/cpm/src/CPM/Main.curry
    wrapProgram $out/pakcs/bin/cypm \
      --prefix PATH ":" "${
        lib.makeBinPath [
          curl
          git
          unzip
          gnutar
          coreutils
          sqlite
        ]
      }"

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "http://www.informatik.uni-kiel.de/~pakcs/";
    description = "Implementation of the multi-paradigm declarative language Curry";
    license = licenses.bsd3;

    longDescription = ''
      PAKCS is an implementation of the multi-paradigm declarative language
      Curry jointly developed by the Portland State University, the Aachen
      University of Technology, and the University of Kiel. Although this is
      not a highly optimized implementation but based on a high-level
      compilation of Curry programs into Prolog programs, it is not a toy
      implementation but has been used for a variety of applications (e.g.,
      graphical programming environments, an object-oriented front-end for
      Curry, partial evaluators, database applications, HTML programming
      with dynamic web pages, prototyping embedded systems).
    '';

    maintainers = with maintainers; [ t4ccer ];
    platforms = platforms.linux;
  };
}
