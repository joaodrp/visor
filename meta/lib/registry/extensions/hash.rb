#
# Extending Hash class
#
#   #stringify_keys, #stringify_keys!, #symbolize_keys, #symbolize_keys! and #assert_valid_keys
#   were extracted from Rails ActiveSupport (active_support/core_ext/hash/keys.rb)
#
class Hash

  # Return a new hash with all keys converted to strings.
  #
  def stringify_keys
    inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
  end

  # Destructively convert all keys to strings.
  #
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end

  # Return a new hash with all keys converted to symbols.
  #
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end

  # Destructively convert all keys to symbols.
  #
  def symbolize_keys!
    self.replace(self.symbolize_keys)
  end

  alias_method :to_options, :symbolize_keys
  alias_method :to_options!, :symbolize_keys!

  # Validate all keys in a hash match *valid keys.
  #
  # @param [Array] valid_keys Valid keys.
  #
  # @raise [ArgumentError] On a mismatch.
  #
  def assert_valid_keys(*valid_keys)
    unknown_keys = keys - [valid_keys].flatten
    raise ArgumentError, "Unknown fields: #{unknown_keys.join(", ")}" unless unknown_keys.empty?
  end

  # Validate inclusions of some keys in a hash.
  #
  # @param [Array] inclusion_keys Keys that must be included in the hash.
  #
  # @raise [ArgumentError] If some key is not included.
  #
  def assert_inclusion_keys(*inclusion_keys)
    inc = inclusion_keys.flatten - keys
    raise ArgumentError, "These fields are required: #{inc.join(', ')}" unless inc.empty?
  end

  # Validate non-inclusion of some keys in a hash.
  #
  # @param [Array] exclude_keys Keys that must be not be included in the hash.
  #
  # @raise [ArgumentError] If some key is included.
  #
  def assert_exclusion_keys(*exclude_keys)
    exc = exclude_keys.flatten & keys
    raise ArgumentError, "These fields are read-only: #{exc.join(', ')}" unless exc.empty?
  end

  # Validate value of some key in a hash.
  #
  # @param [Array] valid_values Values to assert against the given key.
  # @param [Array] key The key to assert its value.
  #
  # @raise [ArgumentError] If some key is included.
  #
  def assert_valid_values_for(key, *valid_values)
    unless valid_values.flatten.include?(self[key.to_sym]) || self[key].nil?
      raise ArgumentError, "Invalid #{key.to_s} '#{self[key]}', available options: #{valid_values.join(', ')}"
    end
  end

  # Set some keys in a hash to a given value, possibly ignoring some keys.
  #
  # @param [Array] keys_to_set Keys to set its value.
  # @param [Array] keys_to_ignore Keys to be ignored.
  # @param [Array] to_value Value to set the wanted keys.
  #
  # @raise [ArgumentError] If some key is included.
  #
  def set_blank_keys_value_to(keys_to_set, keys_to_ignore, to_value)
    keys_to_set.each { |k| self.merge!(k => to_value) unless self[k] || keys_to_ignore.include?(k) }
  end
end

