# MES50HP / PGL50H Development Guide / 开发入口

This template targets the MES50HP board, Logos/PGL50H/-6/FBG484, PDS 2022.2-SP6.4, and ModelSim SE-64 10.7. The configured local installations are `E:\APP\PDS\PDS_2022.2-SP6.4` and `E:\APP\ModelSim`.

本模板固定使用 MES50HP 开发板、Logos/PGL50H/-6/FBG484、PDS 2022.2-SP6.4 和 ModelSim SE-64 10.7。PDS 安装在 `E:\APP\PDS\PDS_2022.2-SP6.4`，ModelSim 安装在 `E:\APP\ModelSim`。

## English quick reference

- Use `config.tcl` as the only entry point for device, project, source order, top level, testbench, simulation time, bitstream settings, and active pin group.
- Treat `doc/mes50hp_pinout.csv` as the only board-pin source. Never edit generated FDC files in `prj/generated`.
- Use `check` for configuration and pin validation, `sim` for ModelSim, `build` for the complete PDS build, and `all` for simulation followed by the complete build.
- Timing-related steps pass only when the report says `All Constraints Met`. Testbenches must print `TEST_PASS`; successful PDS steps and launchers must print `SUCCESS:` and `RESULT: status=PASS`.
- Confirm the target board and published `.sbit` or `.bin` before programming. Normal cleanup preserves published bitstreams; `-IncludePublished` removes them as well.

## Fixed boundaries / 固定边界

- `config.tcl` 是器件、项目名、源文件顺序、顶层、testbench、仿真时间、位流参数和启用管脚组的唯一配置入口。
- `doc/mes50hp_pinout.csv` 是唯一板级管脚数据源，PDS 根据它生成 FDC。
- `doc/flash_list_usr_cd.cfl` 定义板载 XT25BF128F（JEDEC `0B4018`），Flash 脚本会将它安装到固定 PDS 目录。
- `rtl/` 存放设计源文件；`sim/` 存放 testbench、模型和仿真数据。
- `prj/run.tcl` 是正式 PDS 流程；`prj/bootstrap/run.tcl` 是 PDS 2022.2 器件引导，二者都要保留。
- `prj/work`、`prj/generated`、`sim/work` 和 `logs/` 是运行时生成目录，可以删除；工具日志只允许出现在 `logs/` 下。
- `build` 和 `all` 成功后，将本次生成的位流复制为 `prj/<project_name>.sbit` 和 `prj/<project_name>.bin`；再次构建会覆盖它们。

## Development commands / 开发命令

```powershell
.\scripts\invoke-pango.cmd check
.\scripts\invoke-pango.cmd sim
.\scripts\invoke-pango.cmd compile
.\scripts\invoke-pango.cmd synth
.\scripts\invoke-pango.cmd pnr
.\scripts\invoke-pango.cmd timing
.\scripts\invoke-pango.cmd build
.\scripts\invoke-pango.cmd all
```

`check` 检查设计源文件并生成、校验当前启用管脚组的 FDC，但不编译 RTL。`build` 只执行完整 PDS 构建，`all` 先运行 ModelSim，再执行完整 PDS 构建。`timing`、`build` 和 `all` 只有在时序报告为 `All Constraints Met` 时才通过。空模板使用 `TOP_MODULE` 和 `TESTBENCH_MODULE` 占位；加入实际源文件后必须同步修改 `config.tcl`。

`rtl_sources` 和 `sim_sources` 非空时严格按列表顺序编译；为空时才递归发现对应目录中的源文件。新增未约束端口必须补充时序约束，只有低速、异步端口才能加入 `allowed_unconstrained_ports`。

## Rules / 规则

1. 顶层端口必须匹配 `doc/mes50hp_pinout.csv` 中已启用管脚组的 `port`。
2. 不编辑 `prj/generated` 中的 FDC。
3. `ddr3_ip`、`sfp_hsst`、`pcie_hsst`、`hsst_ref`、`qspi_config`、`jtag_config` 只能走 PDS IP/配置流程。
4. 按键低有效、LED 高有效；HDMI RX/TX 在 R17 和 W22 存在共享连接。
5. testbench 必须输出 `TEST_PASS`；PDS Tcl 成功时输出 `SUCCESS: PDS step`，启动脚本最终输出 `RESULT: status=PASS`。

## Programming and cleanup / 下载与清理

```powershell
.\scripts\download-jtag.cmd
.\scripts\program-flash.cmd
.\scripts\clean-generated.cmd
.\scripts\clean-generated.cmd -IncludePublished
```

下载脚本默认使用 `config.tcl` 中 `project_name` 对应的 `.sbit` 和 `.bin`。Flash 命令以 1 MHz JTAG 时钟擦除、写入、校验并复位检查 `DONE=1`；该时钟与 `config.tcl` 中的启动配置时钟无关。XT25BF128F 数据库只在烧写期间安装，结束后恢复 PDS 原文件。普通清理保留这两个构建产物，`-IncludePublished` 会同时删除它们。
