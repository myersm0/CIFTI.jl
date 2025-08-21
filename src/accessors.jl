
Base.eltype(c::CiftiStruct{E, R, C}) where {E, R, C} = E

"""
    index_types(c::CiftiStruct)

Get a length-2 Tuple of `CIFTI_INDEX_TYPE`s corresponding to rows and columns, respectively, in `c`.

Note: The ordering will reflect the way data is stored in the CiftiStruct `c` itself, not 
necessarily the way it was stored on disk (assuming you read the data from a file to begin with)!
Specifically, the data might have been transposed during `CIFTI.load()`. Use `istransposed(c)` to 
check if this is the case.
"""
index_types(c::CiftiStruct{E, R, C}) where {E, R, C} = (typeof(R), typeof(C))

"""
    istransposed(c::CiftiStruct)

Get a `Bool` that indicates whether a matrix transposition occurred during `CIFTI.load()`.
"""
istransposed(c::CiftiStruct) = c.transposed

"""
    data(c::CiftiStruct)

Access the data matrix of CiftiStruct `c`.
"""
data(c::CiftiStruct) = c.data

"""
    brainstructure(c::CiftiStruct)

Access the dictionary in `c` that describes the mapping of spatial indices to `CIFTI_BRAINSTRUCTURE`s.
"""
brainstructure(c::CiftiStruct) = c.brainstructure

function Base.show(io::IO, ::MIME"text/plain", cifti::CiftiStruct)
	r, c = index_types(cifti)
	e = eltype(cifti)
	println(io, "CiftiStruct{$e}")
	println(io,    "  size:             $(size(cifti))")
	println(io,    "  dimension order:  ($r, $c)")
	if !isempty(brainstructure(cifti))
		println(io, "  structures:       $(join(keys(brainstructure(cifti)), ", "))")
	end
end

