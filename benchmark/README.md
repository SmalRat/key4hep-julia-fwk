# FrameworkDemo benchmarks

Run benchmarks from the project's main directory

## Usage

Run benchmark script

```
julia --project=. FrameworkDemoBenchmark.jl test.json --samples=1 --pin-threads=true --relaunch-on-error=true --new-experiment-set=experiments_set_4
```


This example launches ``FrameworkDemo`` benchmark with 1 sample per experiment for experiments from experiments set 4 (``experiments_management/experiments_sets.json``). The pipeline will be restarted in case of error and threads are pinned. Results will be saved in `test.json`.

## Results visualization 

Check the `visualization` folder.