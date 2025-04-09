# frozen_string_literal: true

require 'lazier/child'
require 'lazier/item_store'
require 'lazier/processor'

class Lazier
  NOTHING = :_lazier_nothing

  class << self
    attr_writer :logger

    def logger
      @logger ||= init_logger
    end

    private

    def init_logger
      OpenStruct.new
    end
  end

  def initialize(inputs)
    @processors = [root_processor(inputs)]
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
        Processor.new(upstream, downstream, batch_size, output_path_parts, my_path, &block).call
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
    @processors.last.each {}
  end

  protected

  def my_path
    []
  end

  def add(&block)
    @processors << block.call(@processors.last)
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
