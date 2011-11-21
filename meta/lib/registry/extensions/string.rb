# Extending String class
#
class String
  # Convert string to Mongo oid
  def to_oid
    BSON::ObjectId self
  end
end
