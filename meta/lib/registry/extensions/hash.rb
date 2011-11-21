# Extending Hash class
#
class Hash
  # Dup hash with keys as symbols
  def symbolize_keys
    dup.symbolize_keys!
  end

  # Replace hash with keys as symbols
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  # Dup hash with keys as strings
  def stringify_keys
    dup.stringify_keys!
  end

  # Replace hash with keys as strings
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end
end
