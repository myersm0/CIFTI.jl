
# the below assumes we'll deal with headers of the NIfTI-2 spec;
# there are many more fields available, but this is sufficient for basic use
struct NiftiHeader
    dtype::DataType
    nrows::Int64
    ncols::Int64
    vox_offset::Int64
end

struct CiftiStruct
    hdr::NiftiHeader
    data::Matrix
    brainstructure::OrderedDict{BrainStructure, UnitRange}
    function CiftiStruct(hdr, data, brainstructure)
        dims = size(data)
        @assert(hdr.nrows == dims[2], "Expected $(hdr.nrows) rows, found $(dims[2])")
        @assert(hdr.ncols == dims[1], "Expected $(hdr.ncols) columns, found $(dims[1])")
        if length(brainstructure) > 0
            brainstruct_max = brainstructure[collect(keys(brainstructure))[end]][end]
            @assert(
                brainstruct_max in dims,
                "Max index of brainstructure should match data's spatial dimension size"
            )
        end
        new(hdr, data, brainstructure)
    end
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
        transpose
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

function parse_brainmodel(
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

get_brainstructure(fid::IOStream, hdr::NiftiHeader) = 
    extract_xml(fid, hdr) |> parse_brainmodel

"""
    load(filename)

Read a CIFTI file. Returns a CiftiStruct, a struct composed of the data matrix `data`,
a rudimentary header `hdr`, and a dictionary of anatomical indices `brainstructure`
for indexing into the data
"""
function load(filename::String)::CiftiStruct
    @assert(isfile(filename), "$filename doesn't exist")
    open(filename, "r") do fid
        hdr = get_nifti2_hdr(fid)
        data = get_cifti_data(fid, hdr)
        brainstructure = get_brainstructure(fid, hdr)
        CiftiStruct(hdr, data, brainstructure)
    end
end

