# frozen_string_literal: true

require 'lazier/child'
require 'lazier/item_store'
require 'lazier/processor'

class Lazier
  class << self
    attr_writer :logger

    def logger
      @logger ||= null_logger
    end

    private

    def null_logger
      Class.new do
        class << self
          def method_missing(m, *args, **kwargs, &block)
          end
        end
      end
    end
  end

  def initialize(inputs)
    @initial_processor_builder = Proc.new { root_processor(inputs) }
    @processor_builders = []
    @children = {}
  end

  def enum_slice(batch_size, &block)
    output_path_parts = block.parameters[1..-1].map do |_type, name|
      name
    end

    full_output_paths = output_path_parts.map do |path_part|
      my_path + [path_part]
    end
    logger.debug { "setting up processor with batch_size: #{batch_size.inspect}, outputs: #{full_output_paths} for #{block.source_location}"}

    output_path_parts.each do |output_path_part|
      @children[output_path_part] = Child.new(self, output_path_part)
    end

    parent.add do |upstream|
      Enumerator.new do |downstream|
        Processor.new(upstream, downstream, batch_size, my_path, output_path_parts, &block).call
      end
    end
  end

  def enum(&block)
    enum_slice(nil, &block)
  end

  def split(&block)
    enum(&block)
  end

  def each_slice(batch_size, &block)
    enum_slice(batch_size, &block)
  end

  def [](path_part)
    @children.fetch(path_part)
  end

  def logger
    Lazier.logger
  end

  def go
    logger.info { 'initiating processing' }
    upstream = @initial_processor_builder.call
    processors = @processor_builders.map do |processor_builder|
      upstream = processor_builder.call(upstream)
    end
    processors.last.each {}
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

  def parent
    self
  end
end
