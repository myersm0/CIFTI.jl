
const nifti_hdr_size = 540

# from discourse.julialang.org/t/export-enum/5396
macro exported_enum(name, args...)
	esc(quote
		@enum($name, $(args...))
		export $name
		$([:(export $arg) for arg in args]...)
		end)
	end
export exported_enum

@exported_enum(BrainStructure,
	CORTEX_LEFT, CORTEX_RIGHT,
	ACCUMBENS_LEFT, ACCUMBENS_RIGHT,
	AMYGDALA_LEFT, AMYGDALA_RIGHT,
	BRAIN_STEM,
	CAUDATE_LEFT, CAUDATE_RIGHT,
	CEREBELLUM_LEFT, CEREBELLUM_RIGHT,
	DIENCEPHALON_VENTRAL_LEFT, DIENCEPHALON_VENTRAL_RIGHT,
	HIPPOCAMPUS_LEFT, HIPPOCAMPUS_RIGHT,
	PALLIDUM_LEFT, PALLIDUM_RIGHT,
	PUTAMEN_LEFT, PUTAMEN_RIGHT,
	THALAMUS_LEFT, THALAMUS_RIGHT,
	# in my experience, structures in cifti files are limited to the above;
	# but the specification lists the following additional possible values:
	CORTEX,
	CEREBELLUM,
	CEREBELLAR_WHITE_MATTER_LEFT, CEREBELLAR_WHITE_MATTER_RIGHT,
	OTHER_WHITE_MATTER, OTHER_GREY_MATTER,
	ALL_WHITE_MATTER, ALL_GREY_MATTER,
	OTHER
)

# we refer to left and right cortex so often that it's worth having a shorthand
const L = CORTEX_LEFT
const R = CORTEX_RIGHT
const LR = [L, R]

# helper for parsing a string into a BrainStructure enum
const brain_structure_lookup = Dict(
	string(s) => s for s in instances(BrainStructure)
)

# dict to map integer codes representing data type found in the nifti2 header
# (note: not listing certain of those codes that aren't primitive Julia types)
const dtypes = Dict{Int16, DataType}(
	1 => Bool,
	2 => UInt8,
	4 => Int16,
	8 => Int32,
	16 => Float32,
	64 => Float64,
	256 => Int8,
	512 => UInt16,
	768 => UInt32,
	1024 => Int64,
	1280 => UInt64
)

