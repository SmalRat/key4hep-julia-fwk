# Performance evaluation of a Julia-based framework for parallel computing of dependent tasks in high-energy physics application

This folder contains demonstrator project ("FrameworkDemo"). For performance evaluation, head to ``benchmark`` folder.

## FrameworkDemo.jl

[![test](https://github.com/key4hep/key4hep-julia-fwk/actions/workflows/test.yml/badge.svg)](https://github.com/key4hep/key4hep-julia-fwk/actions/workflows/test.yml)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Demonstrator project for HEP event-processing application framework in Julia and using [Dagger.jl](https://github.com/JuliaParallel/Dagger.jl)


### Getting started

Set-up the project:

```
git clone <path>
cd key4hep-julia-fwk
julia --project -e "import Pkg; Pkg.instantiate()"
```

### Usage

See options for running with an example data flow graph in `data/`:

```
julia --project bin/schedule.jl --help
```

or use with REPL:

```julia
using FrameworkDemo
```
