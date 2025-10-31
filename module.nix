{ config, pkgs, lib, ... }:

let
  package = pkgs.callPackage ./default.nix { inherit pkgs; };
in {
  options.services.auto-rollback-service = {
    enable = lib.mkEnableOption "Enable the Auto Rollback Service";
    verbose = lib.mkEnableOption "Verbose mode";
    timeout = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 300;
      description = "Timeout before tests start in seconds";
    };
    notify = {
      motd = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Motd file to modify on tests failure";
        example = "/etc/motd";
      };
    };
    rollback = {
      reboot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Reboot on succesful rollback";
      };
      generation = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = ''
        Generation to rollback to
        if not suplied or invalid the last succesful generation will be used
        '';
      };
    };
    network = lib.mkEnableOption "Enable network test";
    resolve = lib.mkEnableOption "Enable resolver test";
    ping_test = {
      timeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Timeout in seconds for ping to wait for response";
      };
      addrs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        example = ["1.1.1.1" "8.8.8.8"];
        default = [];
        description = ''
        List of ip addresses for ping test
        Ping test is failed when non of addresses respond
        '';
      };
      domains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        example = ["google.com" "example.com"];
        default = [];
        description = ''
        List of ip addresses for ping test
        Ping test is failed when non of addresses respond
        '';
      };
    };
    sshd = lib.mkEnableOption "Enable sshd service tests";
    echo_test = {
      timeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Timeout in seconds for script to wait for connection";
      };
      ip_service = lib.mkOption {
        type = lib.types.str;
        default = "https://api.ipify.org";
        description = "Service to get machine's external ip";
      };
      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [];
        example = [ 22 ];
        description = "Ports to test";
      };
    };
    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of essential services";
      default = [];
    };
  };

  config = lib.mkIf config.services.auto-rollback-service.enable {
    systemd.services.auto-rollback-service = {
      description = "Auto Rollback Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${package}/bin/auto-rollback.sh";
        Environment = [
          "CONFIG_FILE=/etc/auto-rollback-service/config.json"
          "DATA_DIR=/var/lib/auto-rollback-service"
        ];
        WorkingDirectory = "/var/lib/auto-rollback-service";
      };
    };
   systemd.tmpfiles.settings = {
      "auto-rollback-service" = {
        "/var/lib/auto-rollback-service".d = {
          group = "root";
          user = "root";
          mode = "0744";
        };
      };
    };
    environment.etc."auto-rollback-service/config.json".text = lib.strings.toJSON config.services.auto-rollback-service;
  };
}
