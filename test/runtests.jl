using CIFTI
using Test
using JLD

data_dir = joinpath(dirname(@__FILE__), "data")

files_to_test = [
	"test.dscalar.nii",
	"test.dtseries.nii",
	"test.pconn.nii",
	"test.ptseries.nii",
	"sub-MSC01_test.dtseries.nii"
]
# the latter file is one I found that has brainordinates along the rows
# so it doesn't need to be transposed

"""
`ground_truth` contains objects generated in MATLAB with the [FieldTrip toolbox]
(https://www.fieldtriptoolbox.org/) from the same cifti files as are contained
here in the `./data/` folder. Files read in via *this* Julia package however
will differ slightly from `ground_truth` because we are reading cifti files in
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
	for filename in files_to_test
		filename = joinpath(data_dir, filename)
		filetype = replace(filename, r".*\.([a-z]+).nii$" => s"\1")
		a = CIFTI.load(filename)
		inds_a = findall(isfinite.(a.data))

		# the MSC01 file is not included in the ground_truth jld object
		if isnothing(match(r"MSC01", filename))
			b = deepcopy(ground_truth["$(filetype)_test"])
			@test test_brainstructure(a, b)
			inds_b = findall(isfinite.(b["data"]))
			@test inds_a == inds_b
			@test maximum(abs.(a.data[inds_a] .- b["data"][inds_b])) < tol
		end

		tempfile = "temp.$filetype.nii"

		CIFTI.save(tempfile, a; template = filename)
		d = CIFTI.load(tempfile)
		@test maximum(abs.(d.data[inds_a] .- a.data[inds_a])) < tol

		mat = deepcopy(a.data)
		CIFTI.save(tempfile, mat; template = filename)
		c = CIFTI.load(tempfile)
		@test maximum(abs.(c.data[inds_a] .- a.data[inds_a])) < tol

		rm(tempfile)

		@test size(a) == size(a.data)
		if filetype in ["dtseries", "dscalar", "dlabel"]
			@test size(a[LR], 1) == size(a[L], 1) + size(a[R], 1) == 59412
		end

		# for convenience in below tests, remove NaNs now
		inds = .!isfinite.(a.data)
		a.data[inds] .= 0

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
		@test a[structs] == a.data[inds, :]
	end
end

