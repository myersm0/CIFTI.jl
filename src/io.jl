
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
	chars = Char.(bytes) |> join
	start_at = findfirst("<CIFTI Version=", chars)[1]
	chars[start_at:end] |> parsexml |> root
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

function get_brainstructure(docroot::EzXML.Node)::OrderedDict{BrainStructure, UnitRange}
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

"""
    save(dest, c; template)

Save `c::CiftiStruct` to `dest::String` by copying the CIFTI header content from
`template`. `template`'s dimensions and index mappings must match those of the
input data. 

Instead of a `CiftiStruct`, argument `c` may also be a `Vector` or `Matrix`.
"""
function save(dest::String, c::Union{CiftiStruct, AbstractArray}; template::String)
	isfile(template) || error("File $template does not exist")
	fid = open(template, "r")
	seek(fid, 0)
	hdr = get_nifti2_hdr(fid)
	xml = extract_xml(fid, hdr)
	template_dimord = get_dimord(xml)
	outdims = (hdr.nrows, hdr.ncols)
	seek(fid, 0)
	header_content = zeros(UInt8, hdr.vox_offset)
	readbytes!(fid, header_content, hdr.vox_offset)
	close(fid)

	matrix_out = compare_mappings(c, template_dimord, outdims)
	eltype(matrix_out) == hdr.dtype || error("Inconsistent matrix eltypes")

	open(dest, "w") do fid
		write(fid, header_content)
		write(fid, matrix_out)
	end
end

# below are helpers for save(), to determine whether to transpose a matrix before saving

function compare_mappings(
		c::CiftiStruct{E, R, C}, template_dimord::Vector{IndexType}, template_dims::Tuple
	)::Matrix where {E, R, C}
	input_mappings = (MappingStyle(R), MappingStyle(C))
	output_mappings = (MappingStyle(template_dimord[1]), MappingStyle(template_dimord[2]))
	if input_mappings == output_mappings
		matrix_out = c.data
	elseif input_mappings == reverse(output_mappings)
		matrix_out = c.data'
	else
		error("Dimension mappings of outmap are inconsistent with template")
	end
	outdims = size(matrix_out)
	outdims == template_dims || error(DimensionMismatch)
	return matrix_out
end

function compare_mappings(
		c::AbstractArray, template_dimord::Vector{IndexType}, template_dims::Tuple
	)::Matrix
	input_dims = size(c)
	if input_dims == template_dims
		return c
	elseif input_dims == reverse(template_dims)
		return c'
	elseif length(input_dims) == 1 && input_dims[1] == prod(template_dims)
		return reshape(c, (input_dims[1], 1))
	else
		error(DimensionMismatch)
	end
end


