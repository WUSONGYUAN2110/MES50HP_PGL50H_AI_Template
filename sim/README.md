# Simulation sources / 仿真源文件

Place testbenches, simulation models, and simulation data here, and maintain their order in `sim_sources` inside `config.tcl`. Every testbench must print `TEST_PASS` so the shared launcher can determine the result consistently.

将 testbench、仿真模型和仿真数据放在这里，并在 `config.tcl` 中维护 `sim_sources` 顺序。testbench 必须输出 `TEST_PASS`，以便统一脚本判定仿真结果。
