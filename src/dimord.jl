
# traits to help determine interpretation of matrix dimensions;
# explained in the "Mapping Types" section of CIFTI-2 specs pages 3-4

abstract type IndexType end
struct BrainModels <: IndexType end
struct Parcels <: IndexType end
struct Series <: IndexType end
struct Scalars <: IndexType end

abstract type MappingStyle end
struct IsSpatialIndex <: MappingStyle end
struct IsOtherIndex <: MappingStyle end

MappingStyle(::BrainModel) = IsSpatialIndex()
MappingStyle(::Parcels) = IsSpatialIndex()
MappingStyle(::IndexType) = IsOtherIndex()

abstract type TranspositionStyle end
struct DoTranspose <: TranspositionStyle end
struct DontTranspose <: TranspositionStyle end

TranspositionStyle(::IsSpatialIndex, ::IsOtherIndex) = DontTranspose()
TranspositionStyle(::IsOtherIndex, ::IsSpatialIndex) = DoTranspose()

abstract type DimOrd end
abstract type PosX <: DimOrd end
abstract type PosPos <: DimOrd end

Dimord(::IsSpatialIndex, ::IsSpatialIndex) = PosPos()
Dimord(::IsSpatialIndex, ::IsOtherIndex) = PosX()


