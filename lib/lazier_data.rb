# frozen_string_literal: true

require 'lazier_data/child'
require 'lazier_data/item_store'
require 'lazier_data/processor'
require 'lazier_data/processor/root_each'
require 'lazier_data/processor/root_each_slice'
require 'lazier_data/processor/child_each'
require 'lazier_data/processor/child_each_slice'

class LazierData
  def initialize(inputs)
    @initial_processor_builder = proc { Processor.root(inputs) }
    @processor_builders = []
    @children = {}
  end

  def enum_slice(batch_size, &block)
    output_path_parts = block.parameters[1..].map(&:last)

    output_path_parts.each do |output_path_part|
      @children[output_path_part] = Child.new(self, output_path_part)
    end

    parent.add do |upstream|
      Processor.new(upstream, batch_size, my_path, &block).call
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

  def go
    upstream = @initial_processor_builder.call
    processors = @processor_builders.map do |processor_builder|
      upstream = processor_builder.call(upstream)
    end
    processors.last.each {} # rubocop:disable Lint/EmptyBlock
  end

  def go_stepwise
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

  def parent
    self
  end
end
