# MES50HP / PGL50H FPGA 模板

[English](README.md) | 中文

> 面向 MES50HP / PGL50H 的可复现 Pango FPGA 开发模板，支持 AI 辅助下从 RTL、仿真、综合、时序到位流和 JTAG/Flash 的脚本化全流程。

## 项目定位

本模板固定面向 MES50HP 开发板，适用于从空白工程开始迭代 FPGA 设计。项目把器件、顶层、源文件顺序、管脚组、仿真和位流参数集中到 `config.tcl`，并用脚本复现 PDS 与 ModelSim 流程。

它更适合作为：

- Pango FPGA 新项目的起始模板
- 人与 AI 协作开发 RTL 和 testbench 的工程骨架
- 仿真、综合、布局布线、时序和下载流程的统一入口
- 学习国产 FPGA 工具链自动化的参考工程

本仓库中的 AI 主要指 **AI 辅助工程开发流程**，模板本身不预置神经网络模型或 AI 推理加速器。

## 固定环境

- 开发板：MES50HP
- 器件：Logos / PGL50H / -6 / FBG484
- PDS：2022.2-SP6.4
- ModelSim：SE-64 10.7

开始修改前，请先阅读 [`AGENTS.md`](AGENTS.md)。工程边界、管脚来源、生成物规则和验收标准均以该文件为准。

## 快速开始

```powershell
# 检查配置、源文件和当前启用管脚组
.\scripts\invoke-pango.cmd check

# 运行 ModelSim 仿真
.\scripts\invoke-pango.cmd sim

# 逐步执行 PDS 流程
.\scripts\invoke-pango.cmd compile
.\scripts\invoke-pango.cmd synth
.\scripts\invoke-pango.cmd pnr
.\scripts\invoke-pango.cmd timing

# 生成位流
.\scripts\invoke-pango.cmd build

# 仿真通过后执行完整流程
.\scripts\invoke-pango.cmd all
```

将 RTL 放入 `rtl/`，将 testbench 和仿真模型放入 `sim/`，然后在 `config.tcl` 中配置顶层模块、源文件顺序和启用管脚组。空模板使用 `TOP_MODULE` 和 `TESTBENCH_MODULE` 占位，加入实际源文件后必须同步修改配置。

## 项目结构

```text
config.tcl                 # 唯一配置入口
AGENTS.md                  # 人与 AI 协作规则
rtl/                       # RTL 设计源文件
sim/                       # testbench、模型和仿真数据
doc/mes50hp_pinout.csv     # 唯一板级管脚数据源
doc/flash_list_usr_cd.cfl  # XT25BF128F Flash 配置
prj/run.tcl                # 正式 PDS 流程
prj/bootstrap/run.tcl      # PDS 器件引导流程
scripts/                   # 检查、构建、下载和清理脚本
```

## AI 协作入口

建议每次任务按以下顺序进行：

1. 先阅读 [`AGENTS.md`](AGENTS.md) 和 `config.tcl`。
2. 根据任务修改 `rtl/`、`sim/` 或配置文件。
3. 先运行 `check` 或 `sim`，再执行更重的综合和布局布线流程。
4. 根据日志中的第一个真实错误定位问题，不直接修改生成目录。
5. 最终确认 testbench 输出 `TEST_PASS`，并且 `timing`、`build` 或 `all` 达到 `All Constraints Met`。

## 下载与清理

```powershell
.\scripts\download-jtag.cmd
.\scripts\program-flash.cmd
.\scripts\clean-generated.cmd
.\scripts\clean-generated.cmd -IncludePublished
```

运行时生成的 `prj/work`、`prj/generated`、`sim/work` 和 `logs/` 可以清理，工具日志只应放在 `logs/` 下。不要手动编辑 `prj/generated` 中的 FDC；板级管脚必须来自 `doc/mes50hp_pinout.csv`。

## 当前边界

这是一个工程模板，不保证空模板直接实现具体业务功能。加入实际设计后，需要由使用者补充顶层 RTL、testbench、管脚组和时序约束，并完成真实开发板验证。
