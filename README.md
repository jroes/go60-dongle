# Go60 dongle

Adds a **ZMK dongle** to a MoErgo Go60: a Seeed XIAO nRF52840 that plugs into
your computer over USB and acts as the split **central**, while both Go60 halves
become BLE **peripherals** that talk to the dongle. Because the radio talking to
the host is now a dongle sitting right next to it (instead of a keyboard half
across the desk), Bluetooth signal and reliability improve.

This is the same idea as a Corne dongle, adapted to the Go60's quirks: MoErgo's
own ZMK fork, its Nix/Docker build, and — the hard part — **both trackpads**.

> **Status: working on real hardware.** Both halves' keys and both trackpads
> (left = scroll, right = cursor) run through the dongle, with a full custom
> keymap (homerow mods, layers, mouse layer) living on the central. The part I
> wasn't sure would survive a dongle — the Cirque trackpads — works, because the
> Go60 already forwards the right pad over the split via `zmk,input-split`; the
> left pad just needed the same treatment, routed by a distinct `reg`.

### Gotchas worth knowing (for other MoErgo folks)

- **Bonds survive flashing.** Old Corne/stock bonds blocked pairing — each board
  needed a `settings_reset` pass before the dongle and halves would bond.
- **The Cirque is SPI, but MoErgo only enables `CONFIG_SPI` via RGB underglow.**
  Disabling underglow on the peripherals silently killed the trackpad until SPI
  was enabled explicitly.
- **RGB status indicators only link on the central**, so underglow is off on the
  halves for now (plain lighting can be restored by dropping the indicators node).
- **The keymap lives on the dongle (central)** — keymap edits only require
  reflashing the XIAO; the halves never move.

## How it works

```
        [ LEFT half ]  --BLE-->\
         peripheral             \
         fwd left trackpad       [ XIAO dongle ] --USB--> computer
         (reg 1)                /   central
        [ RIGHT half ] --BLE-->/    both trackpads + all keys
         peripheral
         fwd right trackpad
         (reg 0)
```

- **Keys.** Each Go60 half already transforms its own matrix into the *combined*
  14-column layout locally (the left half uses columns 0–6, the right half sets
  `col-offset = 7` for columns 7–13). So both halves emit combined-space key
  positions and the dongle just needs the same matrix transform + the keymap.
- **Trackpads.** Both pads are Cirque Pinnacle sensors. ZMK forwards pointer
  input from a peripheral to the central with `zmk,input-split`. The stock Go60
  already does this for the *right* pad (to the left/central half). Here, *both*
  halves forward their pad to the dongle. The central routes incoming pointer
  events **by `reg` value only**, so the halves must use distinct regs:
  **right = reg 0, left = reg 1**, and the dongle has one proxy + listener per reg.

## Repo layout

```
config/
  default.nix            # builds all three .uf2s against ../src (MoErgo ZMK)
  go60_dongle.keymap     # the dongle (central) keymap — edit your layout here
shields/
  go60_dongle/           # central shield for the XIAO: mock kscan, transform,
                         # two trackpad proxies + listeners, central role
  go60_lh_peripheral/    # left half: central -> peripheral, forward left pad @reg 1
  go60_rh_peripheral/    # right half: stays peripheral, wired split disabled
.github/workflows/build.yml
```

## Building

Firmware builds in GitHub Actions (no local Nix needed). The workflow checks out
`moergo-sc/zmk`, copies the shields in, and runs the MoErgo Nix build to produce
three artifacts:

- `go60_dongle.uf2`
- `go60_lh_peripheral.uf2`
- `go60_rh_peripheral.uf2`

Push, open the **Actions** tab, and download the `go60-dongle-firmware` artifact.

To build locally (needs Nix + Docker like the stock Go60 config):

```bash
git clone https://github.com/moergo-sc/zmk src
cp -r shields/* src/app/boards/shields/
nix-build config -o result
ls result/*.uf2
```

## Flashing

Each device enters its UF2 bootloader as a USB drive; copy the matching `.uf2`
onto it.

1. **Dongle (XIAO):** double-tap reset to mount `XIAO-BOOT`, copy
   `go60_dongle.uf2`. (Reuse the XIAO from the Corne dongle — it already has the
   Adafruit nRF52 bootloader.)
2. **Left half:** enter the bootloader (Magic layer has `&bootloader`, or
   double-tap reset) and copy `go60_lh_peripheral.uf2`.
3. **Right half:** same with `go60_rh_peripheral.uf2`.
4. Plug the dongle into USB. The halves should connect to it automatically. If
   they were previously paired to each other, you may need to clear bonds
   (`&bt BT_CLR` / settings reset) on the halves and dongle once.

> Reverting to a normal Go60 is just reflashing the stock `go60.uf2` to both
> halves from the official Go60 config.

## Notes / troubleshooting

Confirmed working on hardware (keys + both trackpads + a full custom keymap). If
you're adapting this and something's off:

1. **Pairing.** Both halves should connect to the dongle over BLE. If a half
   won't pair, flash `settings_reset` to it (and the dongle) to wipe stale bonds,
   then reflash the real firmware. As a fallback, try re-enabling the wired split
   (remove the `&{/split_config}` block in that half's shield).
2. **Trackpads.** Both pads should work (left = scroll, right = cursor). If one
   is dead or both drive the same listener, it's a `reg` mismatch (left = reg 1,
   right = reg 0).
3. **Key positions.** If keys are wrong or mirrored, it's the matrix transform /
   column offset.
4. **Entering the bootloader.** The XIAO dongle: double-tap reset. The Go60
   halves have no reset button — power off, hold `Ctrl`+`D` (left) or `Alt`+`K`
   (right), and switch power on; a slow-pulsing red LED by the power switch means
   it's ready (fast flash = bootloader up but no host USB, usually a charge-only
   cable).
5. **RGB underglow is disabled on the halves** in this first cut. The Go60's
   underglow status indicators (layer/battery/BLE) only link when the board is
   the central, which the halves no longer are. Plain RGB *lighting* can be
   restored later by re-enabling `CONFIG_ZMK_RGB_UNDERGLOW` on the halves and
   deleting the `underglow_indicators` node (see the note in
   `go60_lh_peripheral.conf`); full status indication would need split RGB
   forwarding from the dongle.

Derived from the stock MoErgo `go60-zmk-config` and `moergo-sc/zmk`.
