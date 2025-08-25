
function get_nifti2_hdr(fid::IOStream)::NiftiHeader
	seek(fid, 0)
	bytes = zeros(UInt8, nifti_hdr_size)
	bytes_read = readbytes!(fid, bytes, nifti_hdr_size)
	bytes_read == nifti_hdr_size || throw(EOFError("file too small to contain NIfTI-2 header"))
	test = reinterpret(Int16, bytes[1:2])[1]
	test == nifti_hdr_size || throw(CiftiFormatError("invalid NIfTI-2 header: expected magic number $nifti_hdr_size, got $test"))
	dtype_code = reinterpret(Int16, bytes[13:14])[1]
	haskey(dtypes, dtype_code) || throw(CiftiFormatError("unsupported data type code: $dtype_code"))
	dtype = dtypes[dtype_code]
	dims = reinterpret(Int64, bytes[17:80])
	nrows = dims[6]
	ncols = dims[7]
	vox_offset = reinterpret(Int64, bytes[169:176])[1]
	vox_offset >= nifti_hdr_size || throw(CiftiFormatError("invalid vox_offset: $vox_offset (must be >= $nifti_hdr_size)"))
	NiftiHeader(dtype, nrows, ncols, vox_offset)
end

function get_cifti_data(fid::IOStream, hdr::NiftiHeader)
	seek(fid, hdr.vox_offset)
	read!(fid, Matrix{hdr.dtype}(undef, hdr.nrows, hdr.ncols))
end

function extract_xml(fid::IOStream, hdr::NiftiHeader)::EzXML.Node
	# parse xml from raw bytes that follow the hdr
	seek(fid, nifti_hdr_size)
	bytes = zeros(UInt8, hdr.vox_offset - nifti_hdr_size)
	readbytes!(fid, bytes, hdr.vox_offset - nifti_hdr_size)
	filter!(!iszero, bytes) # the below will error if we don't remove null bytes
	chars = String(bytes)
	start_at = findfirst("<CIFTI Version=", chars)[1]
	chars[start_at:end] |> parsexml |> root
end

function get_dimord(docroot::EzXML.Node)::Vector{IndexType}
	index_mappings = findall("//MatrixIndicesMap", docroot)
	n_mappings = length(index_mappings)
	n_mappings in (1, 2) || error("expected 1 or 2 index mappings, not $n_mappings")
	dimord = Vector{IndexType}(undef, 2)
	for node in index_mappings
		temp = replace(node["IndicesMapToDataType"], r"CIFTI_INDEX_TYPE_" => "")
		haskey(index_type_lookup, temp) || throw(CiftiFormatError("Unrecognized IndexType $temp"))
		interpretation = index_type_lookup[temp]
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
				throw(CiftiFormatError("unable to parse dimension order"))
			end
		end
	end
	return dimord
end

function get_brainstructure(docroot::EzXML.Node)::OrderedDict{BrainStructure, UnitRange}
	brainmodel_nodes = findall("//BrainModel", docroot)
	brainstructure = OrderedDict{BrainStructure, UnitRange}()
	for node in brainmodel_nodes
		if !haskey(node, "BrainStructure")
			@warn "BrainModel node missing BrainStructure attribute, skipping"
			continue
		end
		temp = replace(node["BrainStructure"], r"CIFTI_STRUCTURE_" => "")
		haskey(brain_structure_lookup, temp) || throw(CiftiFormatError("unknown structure $temp"))
		struct_name = brain_structure_lookup[temp]
		# validate numeric parsing
		try
			start = parse(Int, node["IndexOffset"]) + 1
			count = parse(Int, node["IndexCount"])
			count > 0 || throw(ArgumentError("IndexCount must be positive"))
			stop = start + count - 1
			brainstructure[struct_name] = start:stop
		catch e
			if e isa ArgumentError
				throw(CiftiFormatError("invalid index values in BrainModel node: $(e.msg)"))
			else
				rethrow()
			end
		end
	end
	brainstructure
end

"""
    load(filename)

Read a CIFTI file from disk.

Returns a `CiftiStruct`, composed of the data matrix `data` and a dictionary of 
anatomical indices `brainstructure` for indexing into the data
"""
function load(filename::String)::CiftiStruct
	isfile(filename) || throw(ArgumentError("File does not exist: $filename"))
	local out
	open(filename, "r") do fid
		try
			hdr = get_nifti2_hdr(fid)
			data = get_cifti_data(fid, hdr)
			xml = extract_xml(fid, hdr)
			brainstructure = get_brainstructure(xml)
			dimord = get_dimord(xml)
			out = CiftiStruct(hdr, data, brainstructure, dimord, TranspositionStyle(dimord...))
		catch e
			if e isa CiftiFormatError
				throw(CiftiFormatError("error reading $filename: $(e.msg)"))
			else
				rethrow()
			end
		end
	end
	return out
end



"""
    save(dest, c; template)

Save `c::CiftiStruct` to `dest::String` by copying the CIFTI header content from
`template`. `template`'s dimensions and index mappings must match those of the
input data. 

Instead of a `CiftiStruct`, argument `c` may also be a `Vector` or `Matrix`.
"""
function save(dest::String, c::Union{CiftiStruct, AbstractArray}; template::String)
	isfile(template) || throw(ArgumentError("template file does not exist: $template"))
	dest_dir = dirname(dest)
	if !isempty(dest_dir) && !isdir(dest_dir)
		throw(ArgumentError("output directory does not exist: $dest_dir"))
	end
	
	local hdr, xml, template_dimord, header_content
	open(template, "r") do fid
		try
			hdr = get_nifti2_hdr(fid)
			xml = extract_xml(fid, hdr)
			template_dimord = get_dimord(xml)
			seek(fid, 0)
			header_content = read(fid, hdr.vox_offset)
		catch e
			if e isa CiftiFormatError
				throw(CiftiFormatError("invalid template file $template: $(e.msg)"))
			else
				rethrow()
			end
		end
	end
	
	outdims = (hdr.nrows, hdr.ncols)
	matrix_out = compare_mappings(c, template_dimord, outdims)
	
	if eltype(matrix_out) != hdr.dtype
		try
			matrix_out = convert(Matrix{hdr.dtype}, matrix_out)
		catch e
			throw(ArgumentError(
				"cannot convert data from $(eltype(matrix_out)) to $(hdr.dtype): $(e)"
			))
		end
	end
	
	try
		open(dest, "w") do fid
			write(fid, header_content)
			write(fid, matrix_out)
		end
	catch e
		# try to clean up partial file
		isfile(dest) && rm(dest, force=true)
		throw(e)
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
		throw(DimensionMismatch("dimension mappings of outmap are inconsistent with template"))
	end
	outdims = size(matrix_out)
	if outdims == template_dims
		return matrix_out
	else
		throw(DimensionMismatch("cannot write matrix of size $outdims to a $template_dims template"))
	end
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
		throw(DimensionMismatch("could not conform input dimensions $input_dims to $template_dims"))
	end
end


