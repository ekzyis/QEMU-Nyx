let
  # QEMU-Nyx version for afl++ v4.35c
  version = "ff1c897321";
in
{
  stdenv,
  lib,
  fetchFromGitHub,
  python3,
  pkg-config,
  flex,
  bison,
  glib,
  pixman,
  qemuNyxSrc ? fetchFromGitHub {
    owner = "nyx-fuzz";
    repo = "QEMU-Nyx";
    rev = version;
    hash = "sha256-3HMgI1tEQ3Epi0Q3OmFNgC9fDStlNXSaI5bSXj1SLmQ=";
    fetchSubmodules = true;
  },
}:

# this derivation assumes x86_64-linux
assert stdenv.targetPlatform.system == "x86_64-linux";

stdenv.mkDerivation {
  pname = "QEMU-Nyx";
  inherit version;

  src =
    if builtins.typeOf qemuNyxSrc == "path" then
      lib.cleanSource qemuNyxSrc
    else
      qemuNyxSrc;

  # same flags for ./configure as ./compile_qemu_nyx.sh static would set
  configureFlags = [
    "--target-list=x86_64-softmmu"
    "--disable-docs"
    "--disable-gtk"
    "--disable-werror"
    "--disable-capstone"
    "--disable-libssh"
    "--disable-tools"
    "--enable-nyx"
    "--enable-nyx-static"
  ];

  nativeBuildInputs = [
    python3
    pkg-config
    flex
    bison
  ];

  buildInputs = [
    glib
    pixman
  ];

  enableParallelBuilding = true;

  preConfigure = ''
    CAPSTONE_ROOT=$PWD/capstone_v4
    LIBXDC_ROOT=$PWD/libxdc

    make -C $CAPSTONE_ROOT -j$(nproc)
    make -C $LIBXDC_ROOT -j$(nproc) clean

    # For some reason the Makefile of libxdc clears LDFLAGS; we remove that line
    # so ld can find libcapstone.so.4
    sed -i '3d' $LIBXDC_ROOT/Makefile

    NO_LTO=1 LDFLAGS="-L$CAPSTONE_ROOT -L$LIBXDC_ROOT" CFLAGS="-I$CAPSTONE_ROOT/include/" make -C $LIBXDC_ROOT -j$(nproc)

    export LIBS="-L$CAPSTONE_ROOT -L$LIBXDC_ROOT/"
    export QEMU_CFLAGS="-I$CAPSTONE_ROOT/include/ -I$LIBXDC_ROOT/ $QEMU_CFLAGS"
  '';
}
