
# traits to help determine interpretation of matrix dimensions;
# explained in the "Mapping Types" section of CIFTI-2 specs pages 3-4

abstract type IndexType end
struct BRAIN_MODELS <: IndexType end
struct PARCELS <: IndexType end
struct SERIES <: IndexType end
struct SCALARS <: IndexType end
struct TIME_POINTS <: IndexType end

# note that TIME_POINTS is not mentioned in the specification,
# but I've found it exists in XML data from the MSC dataset

abstract type MappingStyle end
struct IsSpatialIndex <: MappingStyle end
struct IsOtherIndex <: MappingStyle end

MappingStyle(::BRAIN_MODELS) = IsSpatialIndex()
MappingStyle(::PARCELS) = IsSpatialIndex()
MappingStyle(::IndexType) = IsOtherIndex()

abstract type TranspositionStyle end
struct DoTranspose <: TranspositionStyle end
struct DontTranspose <: TranspositionStyle end

TranspositionStyle(::MappingStyle, ::MappingStyle) = DontTranspose()
TranspositionStyle(::IsOtherIndex, ::IsSpatialIndex) = DoTranspose()

TranspositionStyle(i1::IndexType, i2::IndexType) = 
	TranspositionStyle(MappingStyle(i1), MappingStyle(i2))

