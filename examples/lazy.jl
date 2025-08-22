
using CIFTI

# Lazy loading of cifti files and/or incremental disk-based access are sometimes
# very useful things, when you have big functional or connectivity data to work with and
# it's too much to fit in RAM. Although these things are not implemented in our package, 
# it's easy to do yourself it by using the under-the-hood function `get_nifti2_hdr`.

# First, supposing `filename` is a string defining the file you want to access,
# open a file descriptor and retrieve some basic info about how it stores its data:
fid = open(filename, "r")
hdr = CIFTI.get_nifti2_hdr(fid)
vox_offset = hdr.vox_offset
m = hdr.nrows
n = hdr.ncols
dtype = hdr.dtype

# This is all you need to know in order to retrieve, say, a single column
# from the file. Let's say you want to get the 5th column:
my_column_index = 5
byte_offset = vox_offset + (my_column_index - 1) * m * sizeof(dtype)
bytes_to_read = sizeof(dtype) * m
seek(fid, byte_offset)
temp = Vector{UInt8}(undef, bytes_to_read)  # allocate a temparary vector of bytes
readbytes!(fid, temp, bytes_to_read)  # read bytes from the file into that vector
my_column_data = reinterpret(dtype, temp)  # convert those bytes to Float32 (or whatever)

close(fid)

# Now for verification, let's try fully loading the cifti file and checking that
# the respective row/column matches the vector that we just manually retrieved.
# Note a little complication regarding transposition, however: if CIFTI.jl had
# to transpose the matrix upon loading, then you need to swap the axis that
# you want to test against:
cifti = CIFTI.load(filename)
test_data = istransposed(cifti) ? cifti[my_index, :] : cifti[:, my_index]
@assert my_column_data == test_data










