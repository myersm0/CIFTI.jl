
export CiftiStruct, size, getindex

# the below assumes we'll deal with headers of the NIfTI-2 spec;
# there are many more fields available, but this is sufficient for basic use
struct NiftiHeader
	dtype::DataType
	nrows::Int64
	ncols::Int64
	vox_offset::Int64
end

# type parameters E, R, C stand for: matrix eltype, row and column interpretations
struct CiftiStruct{E, R, C}
	_hdr::NiftiHeader
	data::Matrix{E}
	brainstructure::OrderedDict{BrainStructure, UnitRange}
end

function CiftiStruct{E, R, C}(
		hdr::NiftiHeader, 
		data::Matrix{E}, 
		brainstructure::OrderedDict{BrainStructure, UnitRange}
	) where {E <: Real, R <: IndexType, C <: IndexType}
	dims = size(data)
	@assert(hdr.nrows == dims[2], "Expected $(hdr.nrows) rows, found $(dims[2])")
	@assert(hdr.ncols == dims[1], "Expected $(hdr.ncols) columns, found $(dims[1])")
	if length(brainstructure) > 0
		brainstruct_max = brainstructure[collect(keys(brainstructure))[end]][end]
		@assert(
			brainstruct_max == dims[1],
			"Max index of brainstructure should match data's spatial dimension size"
		)
	end
	CiftiStruct{E, R, C}(hdr, data, brainstructure)
end

CiftiStruct(hdr, data, brainstructure, dimord, ::DontTranspose) =
	CiftiStruct{hdr.dtype, dimord[1], dimord[2]}(hdr, data, brainstructure)
	
CiftiStruct(hdr, data, brainstructure, dimord, ::DoTranspose) =
	CiftiStruct{hdr.dtype, dimord[2], dimord[1]}(hdr, transpose(data), brainstructure)

"""
    size(c::CiftiStruct)

Get the dimensions of the data matrix component of a `CiftiStruct`
"""
function Base.size(x::CiftiStruct)
	size(x.data)
end

"""
    getindex(c::CiftiStruct, s::BrainStructure)

Use `BrainStructure` `s` as indices into the data matrix of a `CiftiStruct`
"""
function Base.getindex(
		c::CiftiStruct{E, BRAIN_MODELS(), C}, s::BrainStructure
	) where {E, C}
	inds = haskey(c.brainstructure, s) ? c.brainstructure[s] : []
	c.data[inds, :]
end

function Base.getindex(
		c::CiftiStruct{E, BRAIN_MODELS(), BRAIN_MODELS()}, s1::BrainStructure, s2::BrainStructure
	) where E
	inds1 = haskey(c.brainstructure, s1) ? c.brainstructure[s1] : []
	inds2 = haskey(c.brainstructure, s2) ? c.brainstructure[s2] : []
	c.data[inds1, inds2]
end

"""
    getindex(c::CiftiStruct, s::Vector{BrainStructure})

Use a vector of BrainStructure s as indices into the data matrix of a CiftiStruct
"""
function Base.getindex(c::CiftiStruct, s::Vector{BrainStructure})
	structs = intersect(keys(c.brainstructure), s)
	inds = length(structs) == 0 ? [] : union([c.brainstructure[x] for x in s]...)
	c.data[inds, :]
end

function Base.show(io::IO, ::MIME"text/plain", cifti::CiftiStruct)
	display(cifti.data)
end

