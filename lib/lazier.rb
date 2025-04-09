# frozen_string_literal: true

require 'lazier/child'
require 'lazier/item_store'

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
        # item, root_item, item_store, output_yielders
        dug = Enumerator.new do |dug|
          upstream.each do |root_item, item_store|
            logger.debug { "processing #{root_item.inspect} in #{my_path.inspect}" }
            output_yielders = output_path_parts.map do |output_path_part|
              ::Enumerator::Yielder.new do |item|
                storage_path = my_path + [output_path_part]
                logger.debug { "storing item at #{storage_path}: #{item.inspect}" }
                item_store.dig(*storage_path) << item
              end
            end

            if my_path.empty?
              to_yield = [root_item, root_item, item_store, output_yielders]
              logger.debug { "yielding dug root item: #{to_yield[0..1].inspect}" }
              dug << to_yield
            else
              items = item_store.dig(*my_path)
              found_count = items.count
              logger.debug { "found #{found_count} items at #{my_path}: #{items.inspect}"}
              if items.count == 0
                to_yield = [root_item, item_store]
                logger.debug { "yielding downstream (no dug items from #{my_path.inspect}): #{to_yield[0..0].inspect}" }
                downstream << to_yield
              elsif items.count == 1
                to_yield = [items.first, root_item, item_store, output_yielders]
                logger.debug { "yielding dug stored item (1 of 1) from #{my_path.inspect}: #{to_yield[0..1].inspect}" }
                dug << to_yield
              elsif items.count > 1
                items[0..-2].each.with_index(1) do |item, item_number|
                  to_yield = [item, NOTHING, item_store, output_yielders]
                  logger.debug { "yielding dug stored item (#{item_number} of #{found_count}) from #{my_path.inspect}: #{to_yield[0..1].inspect}" }
                  dug << to_yield
                end

                to_yield = [items.last, root_item, item_store, output_yielders]
                logger.debug { "yielding dug last stored item (#{found_count} of #{found_count}) from #{my_path.inspect}: #{to_yield[0..1].inspect}" }
                dug << to_yield
              else
                raise 'wat'
              end
            end
          end
        end

        if batch_size.nil?
          dug.each do |item, root_item, item_store, output_yielders|
            to_yield = [item, *output_yielders]
            logger.debug { "yielding item to #{block.source_location}: #{to_yield[0..0].inspect}" }
            block.call(*to_yield)
            to_yield = [root_item, item_store]
            logger.debug { "yielding downstream (after item): #{to_yield[0..0].inspect}" }
            downstream << [root_item, item_store]
          end
        else
          dug.each_slice(batch_size) do |raw_yielded|
            item_slice = raw_yielded.map(&:first)
            to_yield = [item_slice, *raw_yielded.last[3]]
            logger.debug { "yielding slice to #{block.source_location}: #{to_yield[0..0].inspect}" }
            block.call(*to_yield)
            raw_yielded.each do |_, root_item, item_store, _|
              next if root_item == NOTHING

              to_yield = [root_item, item_store]
              logger.debug { "yielding downstream (after slice): #{to_yield[0..0].inspect}" }
              downstream << to_yield
            end
          end
        end
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
