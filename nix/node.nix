{ pkgs, ... }:
let
  nodejs = pkgs.nodejs;
in
{
  home.packages = with pkgs; [
    nodejs
  ];

  home.activation = {
    installWrangler = ''
      npx wrangler --version || npx wrangler@latest
    '';
  };
}