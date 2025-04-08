module Lazier
  class MapEnum
    attr_reader :batch_size, :block

    def map_slice(batch_size, &block)
      @batch_size = batch_size
      @block = block
    end

    def map(&block)
      @block = block
    end
  end
end
