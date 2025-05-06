{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
        });
  in {
    devShells = forEachSupportedSystem ({pkgs}: {
      default =
        pkgs.mkShell.override {
          # Override stdenv in order to change compiler:
          stdenv = pkgs.llvmPackages_13.stdenv;
        } {
          packages = with pkgs;
            [
              cmake
              ninja
              z3
              gllvm
              zlib
              ncurses
              gcc
            ]
            ++ (with pkgs.llvmPackages_13; [
              llvm
              clang
              lld
            ]);

          # Set LLVM_DIR to point to the LLVM installation
          shellHook = ''
            export LLVM_DIR=${pkgs.llvmPackages_13.llvm.dev}/lib/cmake/llvm
            export LLVM_CONFIG_BINARY=${pkgs.llvmPackages_13.llvm.dev}/bin/llvm-config
            export TTT_DIR=${pkgs.gcc.out}/lib64
            export LD_LIBRARY_PATH=${pkgs.zlib.out}/lib:${pkgs.ncurses.out}/lib:"${pkgs.stdenv.cc.cc.lib}/lib":$LD_LIBRARY_PATH
          '';
        };
    });
  };
}
