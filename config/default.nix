{ pkgs ? (import ../src/nix/pinned-nixpkgs.nix {})
, firmware ? import ../src {}
}:

# Builds the three firmware images for the Go60 dongle setup, using the MoErgo
# ZMK distribution checked out at ../src. The custom shields must already be
# copied into ../src/app/boards/shields (the CI workflow does this).
#
#   go60_dongle.uf2          -> flash to the Seeed XIAO nRF52840 dongle
#   go60_lh_peripheral.uf2   -> flash to the LEFT half
#   go60_rh_peripheral.uf2   -> flash to the RIGHT half

let
  config = ./.;

  # Central: XIAO dongle. Keymap lives here in the config dir so it is easy to
  # edit; the go60_dongle.conf is picked up automatically from the shield dir.
  dongle = firmware.zmk.override {
    board = "seeeduino_xiao_ble";
    shield = "go60_dongle";
    keymap = "${config}/go60_dongle.keymap";
  };

  # Left half converted from central to BLE peripheral.
  go60_lh = firmware.zmk.override {
    board = "go60_lh";
    shield = "go60_lh_peripheral";
  };

  # Right half kept as BLE peripheral (wired split disabled).
  go60_rh = firmware.zmk.override {
    board = "go60_rh";
    shield = "go60_rh_peripheral";
  };
in
pkgs.runCommandNoCC "go60-dongle-firmware" { } ''
  mkdir -p $out
  cp ${dongle}/zmk.uf2  $out/go60_dongle.uf2
  cp ${go60_lh}/zmk.uf2 $out/go60_lh_peripheral.uf2
  cp ${go60_rh}/zmk.uf2 $out/go60_rh_peripheral.uf2
''
