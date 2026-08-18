# MES50HP / PGL50H FPGA Template

English | [中文](README.zh-CN.md)

> A reproducible Pango FPGA development template for MES50HP / PGL50H, with scriptable AI-assisted workflows from RTL, simulation, synthesis, timing analysis, and bitstream generation to JTAG/Flash programming.

## Project Overview

This template targets the MES50HP development board and supports iterative FPGA design from a blank project. Device settings, the top-level module, source-file order, pin groups, simulation, and bitstream parameters are centralized in `config.tcl`; scripts reproduce the PDS and ModelSim workflows.

It is intended as:

- A starting point for new Pango FPGA projects
- An engineering skeleton for human and AI collaboration on RTL and testbenches
- A unified entry point for simulation, synthesis, place-and-route, timing, and programming
- A reference project for learning automation around domestic FPGA toolchains

In this repository, **AI** refers to an AI-assisted engineering workflow. The template does not include neural-network models or AI inference accelerators.

## Fixed Environment

- Development board: MES50HP
- Device: Logos / PGL50H / -6 / FBG484
- PDS: 2022.2-SP6.4
- ModelSim: SE-64 10.7

Before making changes, read [`AGENTS.md`](AGENTS.md). Project boundaries, pin-data sources, generated-artifact rules, and acceptance criteria are defined there.

## Quick Start

```powershell
# Check configuration, sources, and the active pin group
.\scripts\invoke-pango.cmd check

# Run ModelSim simulation
.\scripts\invoke-pango.cmd sim

# Run the PDS flow step by step
.\scripts\invoke-pango.cmd compile
.\scripts\invoke-pango.cmd synth
.\scripts\invoke-pango.cmd pnr
.\scripts\invoke-pango.cmd timing

# Generate a bitstream
.\scripts\invoke-pango.cmd build

# Run the complete flow after simulation passes
.\scripts\invoke-pango.cmd all
```

Put RTL in `rtl/` and testbenches and simulation models in `sim/`. Then configure the top-level module, source-file order, and active pin group in `config.tcl`. The blank template uses `TOP_MODULE` and `TESTBENCH_MODULE` placeholders; update the configuration when real sources are added.

## Project Structure

```text
config.tcl                 # Single configuration entry point
AGENTS.md                  # Human/AI collaboration rules
rtl/                       # RTL design sources
sim/                       # Testbenches, models, and simulation data
doc/mes50hp_pinout.csv     # Single source of board-level pin data
doc/flash_list_usr_cd.cfl  # XT25BF128F Flash configuration
prj/run.tcl                # Production PDS flow
prj/bootstrap/run.tcl      # PDS device bootstrap flow
scripts/                   # Check, build, programming, and cleanup scripts
```

## AI Collaboration Entry Point

For each task, the recommended order is:

1. Read [`AGENTS.md`](AGENTS.md) and `config.tcl`.
2. Modify `rtl/`, `sim/`, or the configuration as required.
3. Run `check` or `sim` before heavier synthesis and place-and-route steps.
4. Find the first real error in the logs instead of editing generated directories directly.
5. Confirm that the testbench prints `TEST_PASS` and that `timing`, `build`, or `all` reaches `All Constraints Met`.

## Programming and Cleanup

```powershell
.\scripts\download-jtag.cmd
.\scripts\program-flash.cmd
.\scripts\clean-generated.cmd
.\scripts\clean-generated.cmd -IncludePublished
```

Generated `prj/work`, `prj/generated`, `sim/work`, and `logs/` content can be cleaned. Tool logs should remain under `logs/`. Do not manually edit FDC files in `prj/generated`; board-level pins must come from `doc/mes50hp_pinout.csv`.

## Current Scope

This is an engineering template and does not guarantee that a blank project implements a specific application. After adding a real design, users must provide the top-level RTL, testbench, pin group, and timing constraints, then validate the design on the actual development board.
