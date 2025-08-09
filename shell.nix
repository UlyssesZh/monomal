{ pkgs ? import <nixpkgs> { } }: with pkgs; mkShell {
	packages = [ ruby_3_4 librsvg jetbrains-mono ];
}
