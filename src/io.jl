
export CiftiStruct, size, getindex

# the below assumes we'll deal with headers of the NIfTI-2 spec;
# there are many more fields available, but this is sufficient for basic use
struct NiftiHeader
	dtype::DataType
	nrows::Int64
	ncols::Int64
	vox_offset::Int64
end

struct CiftiStruct{T1, T2}
	_hdr::NiftiHeader
	data::Matrix
	brainstructure::OrderedDict{BrainStructure, UnitRange}
end

function CiftiStruct{T1, T2}(
		hdr, data, brainstructure
	) where {T1 <: IndexType, T2 <: IndexType}
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
	CiftiStruct{T1, T2}(hdr, data, brainstructure)
end

CiftiStruct(hdr, data, brainstructure, dimord, ::DontTranspose) =
	CiftiStruct{dimord[1], dimord[2]}(hdr, data, brainstructure)
	
CiftiStruct(hdr, data, brainstructure, dimord, ::DoTranspose) =
	CiftiStruct{dimord[2], dimord[1]}(hdr, transpose(data), brainstructure)

"""
    size(c::CiftiStruct)

Return the dimensions of the data matrix component of a CiftiStruct
"""
function Base.size(x::CiftiStruct)
	size(x.data)
end

"""
    getindex(c::CiftiStruct, s::BrainStructure)

Use BrainStructure s as indices into the data matrix of a CiftiStruct
"""

function Base.getindex(
		c::CiftiStruct{BRAIN_MODELS(), T}, s::BrainStructure
	) where T
	inds = haskey(c.brainstructure, s) ? c.brainstructure[s] : []
	c.data[inds, :]
end

function Base.getindex(
		c::CiftiStruct{BRAIN_MODELS(), BRAIN_MODELS()}, s1::BrainStructure, s2::BrainStructure
	)
	inds1 = haskey(c.brainstructure, s1) ? c1.brainstructure[s] : []
	inds2 = haskey(c.brainstructure, s2) ? c2.brainstructure[s] : []
	c.data[inds, inds]
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

function get_nifti2_hdr(fid::IOStream)::NiftiHeader
	seek(fid, 0)
	bytes = zeros(UInt8, nifti_hdr_size)
	readbytes!(fid, bytes, nifti_hdr_size)
	test = reinterpret(Int16, bytes[1:2])[1]
	@assert(test == nifti_hdr_size, "File doesn't seem to follow the NIfTI-2 specs!")
	dtype = dtypes[reinterpret(Int16, bytes[13:14])[1]]
	dims = reinterpret(Int64, bytes[17:80])
	nrows = dims[6]
	ncols = dims[7]
	vox_offset = reinterpret(Int64, bytes[169:176])[1]
	NiftiHeader(dtype, nrows, ncols, vox_offset)
end

function get_cifti_data(fid::IOStream, hdr::NiftiHeader)
	seek(fid, hdr.vox_offset)
	bytes_to_read = hdr.nrows * hdr.ncols * sizeof(hdr.dtype)
	data = zeros(UInt8, bytes_to_read)
	readbytes!(fid, data, bytes_to_read)
	@chain data begin
		reinterpret(hdr.dtype, _) 
		reshape(_, (hdr.nrows, hdr.ncols)) 
	end
end

function extract_xml(fid::IOStream, hdr::NiftiHeader)::EzXML.Node
	# parse xml from raw bytes that follow the hdr
	seek(fid, nifti_hdr_size)
	bytes = zeros(UInt8, hdr.vox_offset - nifti_hdr_size)
	readbytes!(fid, bytes, hdr.vox_offset - nifti_hdr_size)
	filter!(.!iszero, bytes) # the below will error if we don't remove null bytes
	start_at = 1 + findfirst(bytes .== UInt8('\n')) # xml begins after 1st newline
	@chain begin
		bytes[start_at:end] 
		Char.(_) 
		join 
		parsexml 
		root
	end
end

function get_dimord(docroot::EzXML.Node)::Vector{IndexType}
	index_mappings = findall("//MatrixIndicesMap", docroot)
	@assert length(index_mappings) in (1, 2)
	dimord = Vector{IndexType}(undef, 2)
	for node in index_mappings
		interpretation = 
			@chain node["IndicesMapToDataType"] begin
				replace(_, r"CIFTI_INDEX_TYPE_" => "")
				Meta.parse
				eval
			end
		temp = node["AppliesToMatrixDimension"]
		if temp == "0,1" # if both dimensions are specified at once ...
			dimord[1] = interpretation()
			dimord[2] = interpretation()
			return dimord
		else # otherwise if only one dimension is specified ...
			try
				applies_to = parse(Int, temp) + 1
				dimord[applies_to] = interpretation()
			catch
				error("Unable to parse dimension order")
			end
		end
	end
	return dimord
end

function get_brainstructure(
		docroot::EzXML.Node
	)::OrderedCollections.OrderedDict{BrainStructure, UnitRange}
	brainmodel_nodes = findall("//BrainModel", docroot)
	brainstructure = OrderedDict{BrainStructure, UnitRange}()
	for node in brainmodel_nodes
		struct_name = 
			@chain node["BrainStructure"] begin
				replace(_, r"CIFTI_STRUCTURE_" => "")
				Meta.parse
				eval
			end
		start = parse(Int, node["IndexOffset"]) + 1
		stop = start + parse(Int, node["IndexCount"]) - 1
		brainstructure[struct_name] = start:stop
	end
	brainstructure
end

"""
    load(filename)

Read a CIFTI file. Returns a `CiftiStruct`, composed of the data matrix `data`
and a dictionary of anatomical indices `brainstructure` for indexing into the data
"""
function load(filename::String)::CiftiStruct
	@assert(isfile(filename), "$filename doesn't exist")
	open(filename, "r") do fid
		hdr = get_nifti2_hdr(fid)
		data = get_cifti_data(fid, hdr)
		xml = extract_xml(fid, hdr)
		brainstructure = get_brainstructure(xml)
		dimord = get_dimord(xml)
		CiftiStruct(hdr, data, brainstructure, dimord, TranspositionStyle(dimord...))
	end
end

