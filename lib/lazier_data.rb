# frozen_string_literal: true

require 'lazier_data/child'
require 'lazier_data/item_store'
require 'lazier_data/processor'
require 'lazier_data/processor/root_each'
require 'lazier_data/processor/root_each_slice'
require 'lazier_data/processor/child_each'
require 'lazier_data/processor/child_each_slice'

class LazierData
  class << self
    attr_writer :logger

    def logger
      @logger ||= null_logger
    end

    private

    def null_logger
      Class.new do
        class << self
          def method_missing(*, **, &); end

          def respond_to_missing?
            true
          end
        end
      end
    end
  end

  def initialize(inputs)
    @initial_processor_builder = proc { root_processor(inputs) }
    @processor_builders = []
    @children = {}
  end

  def enum_slice(batch_size, &block)
    output_path_parts = block.parameters[1..].map(&:last)

    output_path_parts.each do |output_path_part|
      @children[output_path_part] = Child.new(self, output_path_part)
    end

    parent.add do |upstream|
      build_processor(upstream, batch_size, &block)
    end
  end

  def enum(&)
    enum_slice(nil, &)
  end

  def split(&)
    enum(&)
  end

  def each_slice(batch_size, &)
    enum_slice(batch_size, &)
  end

  def [](path_part)
    @children.fetch(path_part)
  end

  def logger
    LazierData.logger
  end

  def go
    logger.info { 'initiating processing' }
    upstream = @initial_processor_builder.call
    processors = @processor_builders.map do |processor_builder|
      upstream = processor_builder.call(upstream)
    end
    processors.last.each {} # rubocop:disable Lint/EmptyBlock
  end

  def go_stepwise
    logger.info { 'initiating stepwise processing' }
    stepwise_results = []
    results = @initial_processor_builder.call.to_a
    stepwise_results << results
    @processor_builders.each do |processor_builder|
      results = processor_builder.call(results).to_a
      stepwise_results << results
    end
    stepwise_results
  end

  protected

  def my_path
    []
  end

  def add(&block)
    @processor_builders << block
  end

  private

  def root_processor(inputs)
    Enumerator.new do |y|
      inputs.each do |item|
        y << [item, ItemStore.new]
      end
    end
  end

  def build_processor(upstream, batch_size, &)
    Enumerator.new do |downstream|
      if batch_size.nil?
        build_each_processor(upstream, downstream, &)
      else
        build_each_slice_processor(upstream, downstream, batch_size, &)
      end
    end
  end

  def build_each_processor(upstream, downstream, &)
    if my_path.empty?
      Processor::RootEach.new(upstream, downstream, &).call
    else
      Processor::ChildEach.new(upstream, downstream, my_path, &).call
    end
  end

  def build_each_slice_processor(upstream, downstream, batch_size, &)
    if my_path.empty?
      Processor::RootEachSlice.new(upstream, downstream, batch_size, &).call
    else
      Processor::ChildEachSlice.new(upstream, downstream, batch_size, my_path, &).call
    end
  end

  def parent
    self
  end
end
