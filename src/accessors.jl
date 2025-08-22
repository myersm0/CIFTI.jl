
"""
    size(c::CiftiStruct)

Get the dimensions of the data matrix component of a CiftiStruct `c`.
"""
function Base.size(x::CiftiStruct)
	size(x.data)
end

"""
    getindex(c::CiftiStruct, s::BrainStructure)

Use BrainStructure `s` as indices into the data matrix of a CiftiStruct `c`.
"""
function Base.getindex(
		c::CiftiStruct{E, BRAIN_MODELS(), C}, s::BrainStructure
	) where {E, C}
	haskey(brainstructure(c), s) && return data(c)[brainstructure(c)[s], :]
	available = collect(keys(c.brainstructure))
	isempty(available) && throw(ArgumentError("no brain structures present"))
	throw(KeyError("BrainStructure $s not found. Available: $(join(available, ", "))"))
end

"""
    getindex(c::CiftiStruct, s::Vector{BrainStructure})

Use a vector of BrainStructure `s` as indices into the data matrix of a CiftiStruct `c`.
"""
function Base.getindex(c::CiftiStruct, s::Vector{BrainStructure})
	isempty(s) && throw(ArgumentError("cannot index with empty BrainStructure vector"))
	inds = union([c.brainstructure[x] for x in s]...)
	data(c)[inds, :]
end

function Base.getindex(
		c::CiftiStruct{E, BRAIN_MODELS(), BRAIN_MODELS()}, s1::BrainStructure, s2::BrainStructure
	) where E
	inds1 = haskey(c.brainstructure, s1) ? c.brainstructure[s1] : []
	inds2 = haskey(c.brainstructure, s2) ? c.brainstructure[s2] : []
	data(c)[inds1, inds2]
end


function Base.getindex(c::CiftiStruct, args...)
	getindex(data(c), args...)
end


"""
	 eltype(c::CiftiStruct)

Get the numeric element type of the data matrix belonging to `c`.
"""
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

Access the dictionary in `c` that describes the mapping of spatial indices to CIFTI_BRAINSTRUCTUREs.
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


