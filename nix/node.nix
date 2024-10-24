{ pkgs, ... }:
let
  nodejs = pkgs.nodejs;
in
{
  home.packages = with pkgs; [
    nodejs
  ];
}