module Cbolt

  # raise if invalid data is provided within new metadata
  class Invalid < StandardError;
  end

  # raise if no image is found
  class NotFound < StandardError;
  end
end
