
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
	transposed::Bool
end

function CiftiStruct{E, R, C}(
		hdr::NiftiHeader, 
		data::Matrix{E}, 
		brainstructure::OrderedDict{BrainStructure, UnitRange},
		transposed::Bool
	) where {E <: Real, R <: IndexType, C <: IndexType}
	dims = size(data)
	hdr.nrows == dims[2] || error("Expected $(hdr.nrows) rows, found $(dims[2])")
	hdr.ncols == dims[1] || error("Expected $(hdr.ncols) columns, found $(dims[1])")
	if length(brainstructure) > 0
		brainstruct_max = brainstructure[collect(keys(brainstructure))[end]][end]
		brainstruct_max == dims[1] || error("Max index of brainstructure should match data's spatial dimension size")
	end
	CiftiStruct{E, R, C}(hdr, data, brainstructure, transposed)
end

CiftiStruct(hdr, data, brainstructure, dimord, ::DontTranspose) =
	CiftiStruct{hdr.dtype, dimord[1], dimord[2]}(hdr, data, brainstructure, false)
	
CiftiStruct(hdr, data, brainstructure, dimord, ::DoTranspose) =
	CiftiStruct{hdr.dtype, dimord[2], dimord[1]}(hdr, transpose(data), brainstructure, true)

