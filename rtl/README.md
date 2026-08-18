# RTL sources / RTL 源文件

Place Verilog, SystemVerilog, or VHDL sources here and maintain their order in `rtl_sources` inside `config.tcl`. When the list is empty, the flow discovers HDL files recursively; when it is populated, compilation follows the configured order exactly.

将 Verilog/SystemVerilog/VHDL 源文件放在这里，并在 `config.tcl` 中维护 `rtl_sources` 顺序。空列表时流程会递归发现 HDL 文件；非空列表时严格按配置顺序编译。
