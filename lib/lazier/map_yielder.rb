module Lazier
  class MapYielder
    def initialize(wrapped_yielder, final_yielder)
      @wrapped_yielder = wrapped_yielder
      @final_yielder = final_yielder
    end

    def <<(item)
      @wrapped_yielder << item
      @final_yielder << item
    end
  end
end
