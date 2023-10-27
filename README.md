# CIFTI

This Julia package supplies a basic function `CIFTI.load` for reading files of the CIFTI-2 format (https://www.nitrc.org/projects/cifti) for fMRI data, along with some convenience functions for indexing into the data matrix.

The intended use case is for simple, fast reading of CIFTI data. No attempt has been made to comprehensively support the CIFTI specification. For more complex use cases in Julia, I recommend instead using Julia's cross-language interoperability to take advantage of one of several more comprehensive implementations (see the `cifti` and `ciftiTools` R packages, `nibabel` in Python, etc).

The `CIFTI.load` function supplied here should work for any of the common CIFTI filetypes (dtseries, dscalar, ptseries, dconn, etc). If you have a CIFTI filetype that's not supported, please send me a sample (anonymized, of course, and containing only synthetic data) and I'll add support for it.

Version 1.2 introduces an experimental feature, `CIFTI.save`, to save data out (either from a `CiftiStruct` or simply from a `Matrix`) to a copy of an existing CIFTI file on disk. Due to optional matrix transpositions and to conventions of row major versus column major order, it's tricky to ensure that data is written to disk in the right order and orientation in all cases, so please verify that it works as expected in your environment.

## Performance
Due to Julia's column major storage convention, most CIFTI files will need to be transposed in order to store them in the orientation that users will probably expect. If you don't need to transpose, reading is extremely fast, and if you do, performance suffers but it's still quite fast. Here are some benchmarks achieved on my Macbook Pro:
|                                                |    |
|------------------------------------------------|---:|
|Read a dtseries of size 64k x 8k (w/ transpose) |5 s|
|Read a dtseries of size 64k x 8k (no transpose) |2 s|
|Read a dconn of size 59412 x 59412 (no tranpose)|75 s|

## Installation
Within Julia:
```
using Pkg
Pkg.add("CIFTI")
```

## Usage
The basic usage of `CIFTI.load` is demonstrated below. A `CiftiStruct` struct is returned, containing:
- `data`: a numeric matrix of whatever data type is specified in the cifti file header
- `brainstructure`: an OrderedDict of indices into anatomical structures as parsed from the CIFTI file's internal XML data

```
x = CIFTI.load(filename)
x.data                   # access the data Matrix
x.brainstructure         # access the OrderedDict of anatomical indices
```

When reading in a CIFTI file, transposition will occur or not occur according to the following logic: 
- If the file is stored on disk with spatial dimensions (either parcels or "grayordinates") along the columns but scalars or series elements along the rows (such as timepoints), the data matrix will be transposed for the sake of consistent representation.
- If the rows and columns *both* represent spatial elements, such as in connectivity matrices (pconns and dconns), then no transposition will be done, in part to avoid the cost of transposing large data in those cases. It is expected in these cases that you'll have a symmetric connectivity matrix, so transposition will not matter; but if this is not the case for you for some reason, then pay attention to the orientation and make sure to do any transposing yourself if necessary.

In other words: data will be transposed if it's necessary in order to ensure that there's a spatial mapping along the *rows*, so that they can then be indexed into in a consistent manner.

Some convenience functions for indexing into `data` are also supplied, taking advantage of the BrainStructure enum types that constitute the keys of the CiftiStruct.brainstructure dictionary. Constants `L`, `R`, and `LR` are supplied as a short-hand for `CORTEX_LEFT`, `CORTEX_RIGHT`, and `[CORTEX_LEFT, CORTEX_RIGHT]`, respectively.

```
x[L]   # return a Matrix where the rows correspond to CORTEX_LEFT anatomical indices
x[R]   # return a Matrix where the rows correspond to CORTEX_RIGHT anatomical indices
x[LR]  # return a Matrix where the rows correspond to left or right coritical indices
```

Or you can index into the data using a vector of arbitrary BrainStructure keys:
```
x[[AMYGDALA_LEFT, AMYGDALA_RIGHT]]
x[[AMYGDALA_RIGHT, AMYGDALA_LEFT]]
```
Important note: order matters in the vector that you specify, so the two lines above will return matrix subsets of the same size but differently sorted.

As of version 1.2, data from a `CiftiStruct` or `Matrix` can be written to disk by specifying a `template`, i.e. an existing CIFTI file that has the desired output space. A copy of `template` will be created on disk, with its data component replaced with the new data that you supply. See the note in the introduction, however, about this function's experimental status, and be sure to verify that outputs are oriented correctly.
```
output_path = "my_output_filename.dtseries.nii"
template_path = "path_to_an_existing_cifti_file.dtseries.nii" # NIFTI-2 header and XML data from this will be copied
CIFTI.save(output_path, x; template = template_path)

# it also works if you pass a Matrix instead of a CiftiStruct:
my_matrix = x.data
CIFTI.save(output_path, my_matrix; template = template_path)
```

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://myersm0.github.io/CIFTI.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://myersm0.github.io/CIFTI.jl/dev/)
[![Build Status](https://github.com/myersm0/CIFTI.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/myersm0/CIFTI.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/myersm0/CIFTI.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/myersm0/CIFTI.jl)
