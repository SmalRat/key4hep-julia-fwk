# Visualization tools

This folder contains tools to visualize results from benchmark experiments. Use `visualization.jl` script.

Example:
```{bash}
julia --project=.. visualization.jl ../benchmark_results/machine-2/results-machine-2-4.json --event-count-exp=plot_filename
```
```{bash}
julia --project=.. visualization.jl ../benchmark_results/machine-2/merged.json --str-scal=plot_filename
```
```{bash}
julia --project=.. visualization.jl ../benchmark_results/machine-2/results-machine-2-1.json --conc-eff=plot_filename
```
```{bash}
julia --project=.. visualization.jl ../benchmark_results/machine-2/coefs-exp-machine-2.json --crunch-exp=plot_filename
```