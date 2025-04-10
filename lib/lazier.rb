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
      Enumerator.new do |downstream|
        Processor.new(upstream, downstream, batch_size, my_path, output_path_parts, &block).call
      end
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
    Lazier.logger
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

  def parent
    self
  end
end
