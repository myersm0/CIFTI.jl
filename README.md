# CIFTI

This Julia package supplies a basic function `CIFTI.load` for reading files of the CIFTI-2 format (https://www.nitrc.org/projects/cifti) for fMRI data.

The intended use case is for simple, fast reading of CIFTI data. No attempt has been made to comprehensively support the CIFTI specification. For more complex use cases in Julia, I recommend instead using Julia's cross-language interoperability to take advantage of one of several more robust and comprehensive implementations (see the `cifti` and `ciftiTools` R packages, `nibabel` in Python, etc).

The `CIFTI.load` function supplied here should work for any of the major CIFTI filetypes (dtseries, dscalar, ptseries, dconn, etc).

The basic usage is demonstrated below. A `CiftiStruct` struct is returned, containing a rudimentary header `hdr`, a data component `data` (simply a numeric matrix of whatever data type is specified in the cifti file header), and a `brainstructure` component (an ordered dictionary of indices into anatomical structures as parsed from the CIFTI file's internal XML data).

```
x = CIFTI.load("my_cifti_file.dtseries.nii")
x.data # access the data matrix
x.brainstructure # access the dictionary of anatomical indices
```

Several pacakges are currently under development to complement this one, including one for 3D visualization of cifti objects (with GLMakie), and a collection of high performance algorithms for operating on CIFTI data.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://myersm0.github.io/CIFTI.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://myersm0.github.io/CIFTI.jl/dev/)
[![Build Status](https://github.com/myersm0/CIFTI.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/myersm0/CIFTI.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/myersm0/CIFTI.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/myersm0/CIFTI.jl)
