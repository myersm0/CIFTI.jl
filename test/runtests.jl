using CIFTI
using Test
using JLD

data_dir = joinpath(dirname(@__FILE__), "data")
filetypes = ["dscalar", "dtseries", "pconn", "ptseries"]

"""
"ground truth" contains objects generated in MATLAB with the FieldTrip toolbox
(https://www.fieldtriptoolbox.org/) from the same cifti files as are contained
here in the `./data/` folder. Files read in via *this* Julia package however
will differ slightly from "ground truth" because we are reading cifti files in
their native format (Float32) vs the 64-bit double-precision floats used in MATLAB
"""
ground_truth = load(joinpath(data_dir, "fieldtrip_objects.jld"))
tol = 1e-6

@testset "CIFTI.jl" begin
    for filetype in filetypes
        a = CIFTI.load(joinpath(data_dir, "test.$filetype.nii"))
        b = ground_truth["$(filetype)_test"]
        inds = findall(isfinite.(b["data"]))
        @test maximum(abs.(a.data[inds] .- b["data"][inds])) < tol
    end
end



