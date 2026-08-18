# RTL 源文件

将 Verilog/SystemVerilog/VHDL 源文件放在这里，并在 `config.tcl` 中维护 `rtl_sources` 顺序。空列表时流程会递归发现 HDL 文件；非空列表时严格按配置顺序编译。