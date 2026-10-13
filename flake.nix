{
  description = "VectorCraft, HWC fork: the open-source vector editor, tailored for GIS map finishing";

  # Lives on the fork's hwc/main branch only; main tracks storytold/vectorcraft untouched.

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs:
        let
          inherit (pkgs) lib;
          appId = "ai.storyteller.vectorcraft";
          version = (lib.importTOML ./Cargo.toml).workspace.package.version;
          # winit, wgpu and xkb load these with dlopen at run time, so they go on the rpath.
          runtimeLibs = with pkgs; [
            wayland libxkbcommon vulkan-loader libGL
            libx11 libxcursor libxi libxrandr
          ];
          vectorcraft = pkgs.rustPlatform.buildRustPackage {
            pname = "vectorcraft";
            inherit version;
            src = lib.cleanSourceWith {
              src = ./.;
              filter = path: _type: !(builtins.elem (baseNameOf path) [ "target" "dist" "result" ".git" ]);
            };
            cargoHash = "sha256-upQBVAO+mqtqTkixie4tpiAwjTpfG3U8iIoxKodywnc=";
            cargoBuildFlags = [ "-p" "vectorcraft" "-p" "vectorcraft-cli" ];
            # Upstream CI runs the test suite; the package build does not repeat it.
            doCheck = false;
            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs = with pkgs; [ fontconfig freetype openssl wayland libxkbcommon ];
            env.VECTORCRAFT_BUILD_SHA = self.shortRev or self.dirtyShortRev or "unknown";
            postInstall = ''
              install -Dm644 packaging/linux/${appId}.desktop $out/share/applications/${appId}.desktop
              install -Dm644 packaging/linux/${appId}.mime.xml $out/share/mime/packages/${appId}.xml
              mkdir -p $out/share/icons
              cp -R assets/app-icon/hicolor $out/share/icons/
            '';
            postFixup = ''
              patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} $out/bin/vectorcraft
            '';
            meta = {
              description = "Open-source vector graphics editor in the Illustrator mould";
              homepage = "https://github.com/eriqueo/vectorcraft";
              license = with lib.licenses; [ mit asl20 ];
              mainProgram = "vectorcraft";
              platforms = systems;
            };
          };
        in
        { inherit vectorcraft; default = vectorcraft; });
    };
}
