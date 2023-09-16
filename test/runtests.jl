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
their native format (Float32) vs the 64-bit double-precision used in MATLAB
"""
ground_truth = load(joinpath(data_dir, "fieldtrip_objects.jld"))
tol = 1e-6

function test_brainstructure(a::CIFTI.CiftiStruct, b::Dict)
	if haskey(b, "brainstructure")
		vals = filter(x -> Int(x) > 0, b["brainstructure"])
		ks = b["brainstructurelabel"][:]
		length(ks) == length(a.brainstructure) || return false
		temp = Dict([ks[i] => findall(vals .== i) for i in 1:length(ks)])
		for k in ks
			rng_a = a.brainstructure[eval(Meta.parse(k))]
			rng_b = temp[k][1]:temp[k][end]
			rng_a == rng_b || return false
		end
	else
		length(a.brainstructure) == 0 || return false
	end
	return true
end

@testset "CIFTI.jl" begin
	for filetype in filetypes
		a = CIFTI.load(joinpath(data_dir, "test.$filetype.nii"))
		b = deepcopy(ground_truth["$(filetype)_test"])
		@test test_brainstructure(a, b)
		inds_a = findall(isfinite.(a.data))
		inds_b = findall(isfinite.(b["data"]))
		@test inds_a == inds_b
		@test maximum(abs.(a.data[inds_a] .- b["data"][inds_b])) < tol

		@test size(a) == size(a.data)

		# for convenience in below tests, remove NaNs now
		a.data[.!isfinite.(a.data)] .= 0
		b["data"][.!isfinite.(a.data)] .= 0

		structs = collect(keys(a.brainstructure))
		for s in structs
			@test a[s] == a.data[a.brainstructure[s], :]
		end

		# pick out a "random" set of structs to verify that vectorized indexing works
		structs = intersect(structs, [CEREBELLUM_RIGHT, L, AMYGDALA_RIGHT])
		if length(structs) == 0
			inds = []
		else
			inds = union([a.brainstructure[s] for s in structs]...) |> sort
		end
		@test a[structs] == a.data[inds, :]
	end
end



