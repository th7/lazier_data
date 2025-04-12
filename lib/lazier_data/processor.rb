# frozen_string_literal: true

require 'lazier_data/item_store'

class LazierData
  class Processor
    NOTHING = :_lazier_data_nothing
    class << self
      def root(inputs)
        Enumerator.new do |y|
          inputs.each do |item|
            y << [item, ItemStore.new]
          end
        end
      end
    end

    def initialize(upstream, batch_size, path, &block)
      @upstream = upstream
      @downstream = downstream
      @batch_size = batch_size
      @path = path
      @block = block
    end

    def call
      Enumerator.new do |downstream|
        if batch_size.nil?
          build_each_processor(downstream)
        else
          build_each_slice_processor(downstream)
        end
      end
    end

    private

    attr_reader :upstream, :downstream, :batch_size, :path, :block

    def build_each_processor(downstream)
      if path.empty?
        Processor::RootEach.new(upstream, downstream, &block).call
      else
        Processor::ChildEach.new(upstream, downstream, path, &block).call
      end
    end

    def build_each_slice_processor(downstream)
      if path.empty?
        Processor::RootEachSlice.new(upstream, downstream, batch_size, &block).call
      else
        Processor::ChildEachSlice.new(upstream, downstream, batch_size, path, &block).call
      end
    end
  end
end
