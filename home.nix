{ pkgs, ... }:
{
  home = rec {
    username = "taka";
    homeDirectory = "/home/${username}";
    stateVersion = "23.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Docker and Docker Compose installation
  programs.docker.enable = true;
  programs.docker-compose.enable = true;

  # Add Docker group to the user
  users.users.${home.username} = {
    isNormalUser = true;
    extraGroups = [ "docker" ];
  };
}