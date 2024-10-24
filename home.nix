{ pkgs, ... }:

{
  home = rec {
    username = "taka";
    homeDirectory = "/home/${username}";
    stateVersion = "23.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # docker
    # docker-compose
  ];
}