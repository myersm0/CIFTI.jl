
module CIFTI

using EzXML
using OrderedCollections

include("cifti_spec.jl")
export BrainStructure, L, R, LR

include("dimord.jl")

include("types.jl")
export CiftiStruct, size, getindex

# load() and save() are defined here, but not exported for namespace reasons
include("io.jl")


end

