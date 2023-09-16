# CIFTI

This Julia package supplies a basic function `CIFTI.load` for reading files of the CIFTI-2 format (https://www.nitrc.org/projects/cifti) for fMRI data, along with some convenience functions for indexing into the data matrix.

The intended use case is for simple, fast reading of CIFTI data. No attempt has been made to comprehensively support the CIFTI specification. For more complex use cases in Julia, I recommend instead using Julia's cross-language interoperability to take advantage of one of several more comprehensive implementations (see the `cifti` and `ciftiTools` R packages, `nibabel` in Python, etc).

The `CIFTI.load` function supplied here should work for any of the common CIFTI filetypes (dtseries, dscalar, ptseries, dconn, etc). If you have a CIFTI filetype that's not supported, please send me a sample and I'll add support for it.

## Installation
Within Julia,
```
using Pkg
Pkg.add(url = "http://github.com/myersm0/CIFTI.jl")
```

## Usage
The basic usage of `CIFTI.load` is demonstrated below. A `CiftiStruct` struct is returned, containing:
- `hdr`: a rudimentary header containing low-level information
- `data`: a numeric matrix of whatever data type is specified in the cifti file header
- `brainstructure`: an OrderedDict of indices into anatomical structures as parsed from the CIFTI file's internal XML data

```
x = CIFTI.load("my_cifti_file.dtseries.nii")
x.data # access the data matrix
x.brainstructure # access the dictionary of anatomical indices
```

Some convenience functions for indexing into the `data` matrix are also supplied, taking advantage of the BrainStructure enum types that constitute the keys of the CiftiStruct.brainstructure dictionary. Constants `L`, `R`, and `LR` are supplied as a short-hand for `CORTEX_LEFT`, `CORTEX_RIGHT`, and `[CORTEX_LEFT, CORTEX_RIGHT]`, respectively.

```
x[L]   # return a matrix where the rows correspond to CORTEX_LEFT anatomical indices
x[R]   # return a matrix where the rows correspond to CORTEX_RIGHT anatomical indices
x[LR]  # return a matrix where the rows correspond to left or right coritical indices
```

Or you can index into the data using a vector of arbitrary BrainStructure keys:
```
x[[AMYGDALA_LEFT, CORTEX_LEFT, CEREBELLUM_RIGHT]]
x[[CORTEX_LEFT, CEREBELLUM_RIGHT, AMYGDALA_LEFT]]
```
Important note: order matters in the vector that you specify, so the two lines above will return matrix subsets of the same size but differently sorted.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://myersm0.github.io/CIFTI.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://myersm0.github.io/CIFTI.jl/dev/)
[![Build Status](https://github.com/myersm0/CIFTI.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/myersm0/CIFTI.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/myersm0/CIFTI.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/myersm0/CIFTI.jl)
