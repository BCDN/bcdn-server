# This interface here is used to adapt serializer
# that do compression / transformation
exports = module.exports = class Serializable
  serialize: (obj) -> JSON.stringify obj
  deserialize: (data) -> JSON.parse data
