using CIFTI
using Test
using JLD
using Pkg.Artifacts

data_dir = artifact"CIFTI_test_files"

files_to_test = [
	"test.dscalar.nii",
	"test.dtseries.nii",
	"test.pconn.nii",
	"test.ptseries.nii",
	"sub-MSC01_test.dtseries.nii"
]

"""
`ground_truth` contains objects generated in MATLAB with the [FieldTrip toolbox]
(https://www.fieldtriptoolbox.org/) from the same cifti files as are contained
here in the `./data/` folder. Files read in via *this* Julia package however
will differ slightly from `ground_truth` because we are reading cifti files in
their native format (Float32) vs the 64-bit double-precision used in MATLAB
"""
ground_truth = load(joinpath(data_dir, "fieldtrip_objects.jld"))
tol = 1e-6

function test_brainstructure(a::CiftiStruct, b::Dict)
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
	for (i, filename) in enumerate(files_to_test)
		filename = joinpath(data_dir, filename)
		filetype = replace(filename, r".*\.([a-z]+).nii$" => s"\1")
		a = CIFTI.load(filename)
		inds_a = findall(isfinite.(a.data))
		@test eltype(a) == Float32
		@test istransposed(a) == (i != 3) # only file #3 needs to be transposed

		# the MSC01 file is not included in the ground_truth jld object
		if isnothing(match(r"MSC01", filename))
			b = deepcopy(ground_truth["$(filetype)_test"])
			@test test_brainstructure(a, b)
			inds_b = findall(isfinite.(b["data"]))
			@test inds_a == inds_b
			@test maximum(abs.(a.data[inds_a] .- b["data"][inds_b])) < tol
		end

		tempfile = "temp.$filetype.nii"

		# test that the data doesn't change if you save it out and read it back in
		CIFTI.save(tempfile, a; template = filename)
		c = CIFTI.load(tempfile)
		@test maximum(abs.(c.data[inds_a] .- a.data[inds_a])) < tol

		# as above, but save just a Matrix instead of a CiftiStruct
		mat = deepcopy(a.data)
		CIFTI.save(tempfile, mat; template = filename)
		c = CIFTI.load(tempfile)
		@test maximum(abs.(c.data[inds_a] .- a.data[inds_a])) < tol

		# as above, but try different matrix eltypes to test conversion (to Float32)
		types_to_test = [Float16, Float32, Float64, BigFloat]
		tolerances = [1e-2, 1e-8, 1e-6, 1e-7]
		for (dtype, tol) in zip(types_to_test, tolerances)
			mat = convert(Matrix{dtype}, a.data)
			CIFTI.save(tempfile, mat; template = filename)
			c = CIFTI.load(tempfile)
			@test maximum(abs.(c.data[inds_a] .- a.data[inds_a])) < tol
		end

		rm(tempfile)

		@test size(a) == size(a.data)
		if filetype in ["dtseries", "dscalar", "dlabel"]
			@test size(a[LR], 1) == size(a[L], 1) + size(a[R], 1) == 59412
		end

		# for convenience in below tests, remove NaNs now
		inds = .!isfinite.(a.data)
		a.data[inds] .= 0

		# test that a[::BrainStructure] indexing is equivalent to the more verbose form
		structs = collect(keys(a.brainstructure))
		for s in structs
			@test a[s] == a.data[a.brainstructure[s], :]
		end

		# pick out a "random" set of structs to verify that vectorized indexing works
		structs = intersect(structs, [CEREBELLUM_RIGHT, L, AMYGDALA_RIGHT])
		if length(structs) == 0
			inds = []
		else
			inds = union([a.brainstructure[s] for s in structs]...)
		end
		if length(structs) > 0
			@test a[structs] == a.data[inds, :]
		end
	end
end

