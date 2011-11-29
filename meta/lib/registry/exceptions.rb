module Cbolt

  # raise if invalid data is provided within new metadata
  class Invalid < ArgumentError;
  end

  # raise if no image is found
  class NotFound < StandardError;
  end
end
