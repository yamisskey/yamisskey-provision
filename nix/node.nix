{ pkgs, ... }:
let
  nodejs = pkgs.nodejs;
  npx = pkgs.nodePackages.npx;
in
{
  home.packages = with pkgs; [
    nodejs
    npx
  ];

  home.activation = {
    installWrangler = {
      text = ''
        npx wrangler --version || npx wrangler@latest
      '';
    };
  };
}