
# traits to help determine interpretation of matrix dimensions;
# explained in the "Mapping Types" section of CIFTI-2 specs pages 3-4

abstract type IndexType end
struct BRAIN_MODELS <: IndexType end
struct PARCELS <: IndexType end
struct SERIES <: IndexType end
struct SCALARS <: IndexType end
struct TIME_POINTS <: IndexType end
struct LABELS <: IndexType end
# note that LABELS and TIME_POINTS are not mentioned in the specification,
# but I've found them exists in XML data from various CIFTI files

abstract type MappingStyle end
struct IsSpatialIndex <: MappingStyle end
struct IsOtherIndex <: MappingStyle end

MappingStyle(::BRAIN_MODELS) = IsSpatialIndex()
MappingStyle(::PARCELS) = IsSpatialIndex()
MappingStyle(::IndexType) = IsOtherIndex()

abstract type TranspositionStyle end
struct DoTranspose <: TranspositionStyle end
struct DontTranspose <: TranspositionStyle end

# we only want to transpose in the event that there's a spatial index along the 2nd dim
# because we will conventionally want to have that on the rows instead
TranspositionStyle(::IsOtherIndex, ::IsSpatialIndex) = DoTranspose()
TranspositionStyle(::MappingStyle, ::MappingStyle) = DontTranspose()

TranspositionStyle(i1::IndexType, i2::IndexType) = 
	TranspositionStyle(MappingStyle(i1), MappingStyle(i2))

