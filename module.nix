{ config, pkgs, lib, ... }:

let
  package = pkgs.callPackage ./default.nix {};
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
      motd: lib.mkOption {
        type = lib.types.str;
        description = "Motd file to modify on tests failure";
        example = "/etc/motd";
      };
    };
    rollback = {
      reboot =  = mkOption {
        type = types.bool;
        default = false;
        description = "Reboot on succesful rollback";
      };
      generation = lib.mkOption {
        type = lib.types.int;
        description = ''
        Generation to rollback to
        if not suplied or invalid the last succesful generation will be used
        '';
      };
    };
    network = {
      enable = lib.mkEnableOption "Enable network test";
      ping_test = {
        enable = lib.mkEnableOption "Enable ping test for network test";
        timeout = lib.mkOption {
          type = lib.types.ints.positive;
          default = 5;
          description = "Timeout in seconds for ping to wait for response";
        };
        ip = lib.mkOption {
          type = lib.types.listOf str;
          default = ("1.1.1.1" "8.8.8.8");
          description = ''
          List of ip addresses for ping test
          Ping test is failed when non of addresses respond
          '';
        };
      };
    };
    dnsresolve = {
      enable = lib.mkEnableOption "Enable dns resolver tests";
      ping_test = {
        enable = lib.mkEnableOption "Enable ping test for dns test";
        timeout = lib.mkOption {
          type = lib.types.ints.positive;
          default = 5;
          description = "Timeout in seconds for ping to wait for response";
        };
        domains = lib.mkOption {
          type = lib.types.listOf str;
          default = ("google.com");
          description = ''
          List of domains for ping test
          Ping test is failed when non of addresses respond
          '';
        };
      };
    };
    services = lib.mkOption {
      tpye = lib.types.listOf str;
      default = ();
      description = "List of essential services";
      example = ("sshd.service")
    };
  };

  config = lib.mkIf config.services.auto-rollback-service.enable {
    # systemd.services.auto-rollback-service = {
    #   description = "Auto Rollback Service";
    #   wantedBy = [ "multi-user.target" ];
    #   after = [ "network.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = true;
    #     User = "root";
    #     ExecStart = "${package}/bin/auto-rollback.sh";
    #     Restart = "always";
    #     RestartSec = 5;
    #   };
    # };
    environment.etc."auto-rollback-service/config.yml".text = lib.generators.toYAML config.services.auto-rollback-service;
  };
}

