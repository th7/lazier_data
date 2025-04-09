# frozen_string_literal: true

class Lazier
  class Child < Lazier
    def initialize(parent, path)
      @parent = parent
      @path = path
      @children = {}
    end

    def my_path
      @parent.my_path + [@path]
    end

    def add(&block)
      @parent.add(&block)
    end
  end
end

class Lazier
  class ItemStore
    ITEMS_KEY = :_lazier_items

    def initialize
      @store = new_layer
    end

    def dig(*path)
      if path.empty?
        @store[ITEMS_KEY]
      else
        @store.dig(*path)[ITEMS_KEY]
      end
    end

    private

    def new_layer
      it = Hash.new { |hash, key| hash[key] = new_layer }
      it[ITEMS_KEY] = []
      it
    end
  end
end

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

  def root_processor(inputs)
    Enumerator.new do |y|
      inputs.each do |item|
        y << [item, ItemStore.new]
      end
    end
  end

  def logger
    Lazier.logger
  end

  def enum_slice(batch_size, &block)
    output_path_parts = block.parameters[1..-1].map do |_type, name|
      name
    end

    output_path_parts.each do |output_path_part|
      @children[output_path_part] = Child.new(self, output_path_part)
    end

    parent.add do |upstream|
      Enumerator.new do |downstream|
        # root_item, item_store
        passthrough = Enumerator.new do |passthrough|

          # item, root_item, other_items, output_yielders
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
                  logger.debug { "yielding passthrough (no dug items from #{my_path.inspect}): #{to_yield[0..0].inspect}" }
                  passthrough << to_yield
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
              logger.debug { "yielding passthrough (after item): #{to_yield[0..0].inspect}" }
              passthrough << [root_item, item_store]
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
                logger.debug { "yielding passthrough (after slice): #{to_yield[0..0].inspect}" }
                passthrough << to_yield
              end
            end
          end
        end

        passthrough.each do |root_item, item_store|
          to_yield = [root_item, item_store]
          logger.debug { "yielding downstream: #{to_yield[0..0].inspect}" }
          downstream << to_yield
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

  def my_path
    []
  end

  def parent
    self
  end

  def add(&block)
    @processors << block.call(@processors.last)
  end

  def go
    @processors.last.each {}
  end
end

# class Lazier
#   module Enum
#     def split(&block)
#       processor = Processor.new(&block)
#       @processors << processor
#       processor.outputs.each do |output|
#         @children[output.sym] = Child.new(output.sym, self)
#       end
#     end

#     def enum(&block)
#       processor = Processor.new(&block)
#       add_processor(processor)
#       processor.outputs.each do |output|
#         @children[output.sym] = Child.new(output.sym, self)
#       end
#     end

#     def each_slice(batch_size, &block)
#       processor = AccumulatingProcessor.new(batch_size, &block)
#       add_processor(processor)
#       processor.outputs.each do |output|
#         @children[output.sym] = Child.new(output.sym, self)
#       end
#     end

#     def enum_slice(batch_size, &block)
#       processor = AccumulatingProcessor.new(batch_size, &block)
#       add_processor(processor)
#       processor.outputs.each do |output|
#         @children[output.sym] = Child.new(output.sym, self)
#       end
#     end
#   end
# end

# class Lazier
#   include Enum

#   def initialize(inputs)
#     @inputs = inputs
#     @processors = []
#     @children = {}
#   end

#   def [](key)
#     @children[key]
#   end

#   def add_processor(processor)
#     @processors << processor
#   end

#   def go
#     all_index_items = @inputs.to_enum.lazy.with_index.map do |item, index|
#       [index, item]
#     end
#     process_all(0, all_index_items)
#   end

#   def process_all(next_processor_index, index_items)
#     processors = @processors[next_processor_index..-1]
#     index_items.each do |index, item|
#       processors.each.with_index do |processor, processor_index|
#         p [next_processor_index + processor_index, index]
#         result = processor.process(index, item)
#         case result
#         when true
#           # do nothing
#         when false
#           break
#         when Array
#           process_all(next_processor_index + processor_index + 1, result)
#         end
#       end
#     end
#   end
# end

# class Lazier
#   class Child
#     include Enum

#     def initialize(name, parent)
#       @parent = parent
#       @children = {}
#     end

#     def [](key)
#       @children[key]
#     end

#     def add_processor(processor)
#       @parent.add_processor(processor)
#     end
#   end
# end

# class Lazier
#   class Processor
#     def initialize(&block)
#       @block = block
#       @last_index = -1
#     end

#     def outputs
#       @outputs ||= @block.parameters[1..-1].map do |_type, name|
#         Output.new(name)
#       end
#     end

#     def process(index, item)
#       raise "Processing #{index}, expected #{@last_index + 1}" unless index == @last_index + 1

#       @block.call(item, *@outputs)
#       @last_index += 1
#       true
#     end
#   end
# end

# class Lazier
#   class AccumulatingProcessor
#     def initialize(batch_size, &block)
#       @batch_size = batch_size
#       @block = block
#       @accumulated = []
#       @last_index_accumulated = -1
#     end

#     def outputs
#       @outputs ||= @block.parameters[1..-1].map do |_type, name|
#         Output.new(name)
#       end
#     end

#     def process(index, item)
#       raise "Processing #{index}, expected #{@last_index_accumulated + 1}" unless index == @last_index_accumulated + 1

#       @accumulated << [index, item]
#       @last_index_accumulated += 1

#       if @accumulated.count == @batch_size
#         index_items = @accumulated.dup
#         @block.call(index_items.map(&:last), *@outputs)
#         @accumulated.clear
#         index_items
#       else
#         false
#       end
#     end
#   end
# end

# class Lazier
#   class Output
#     attr_reader :sym

#     def initialize(sym)
#       @sym = sym
#       @items
#     end

#     def <<(item)

#     end
#   end
# end

# class Lazier
#   module Utils
#     class << self
#       def enums(count, this_count=1, previous_yielders=[], meta_yielder=nil, &block)
#         if meta_yielder.nil?
#           Enumerator.new do |y|
#             enums(count, this_count, previous_yielders, y, &block)
#           end
#         else
#           if count != this_count
#             meta_yielder << Enumerator.new do |y|
#               enums(count, this_count + 1, previous_yielders << y, meta_yielder, &block)
#             end
#           else
#             meta_yielder << Enumerator.new do |y|
#               block.call(*previous_yielders, y)
#             end
#           end
#         end
#       end
#     end
#   end
# end



















# require_relative 'lazier/version'
# require 'lazier/enum'
# require 'lazier/yielder'
# require 'lazier/map_yielder'

# module Lazier
#   class Error < StandardError; end

#   class << self
#     def multi_each(count, &block)
#       laziers = count.times.map { Lazier::Enum.new }
#       final = Enumerator.new do |final|
#         normies = nest_normal_enums(count, final, &block)
#         normies.zip(laziers) do |normie, lazier|
#           lazier.call_other(normie)
#         end
#       end
#       [final, *laziers]
#     end

#     def multi_map(count, &block)
#       laziers = count.times.map { Lazier::MapEnum.new }
#       final = Enumerator.new do |final|
#         normies = nest_normal_enums_map(count, final, &block)
#         normies.zip(laziers) do |normie, lazier|
#           normie.each_slice(lazier.batch_size) do |items|
#             lazier.block.call(items).each { |item| final << item }
#           end
#         end
#       end
#       [final, *laziers]
#     end

#     private

#     def nest_normal_enums(count, final_yielder, this_count=1, previous_yielders=[], normies_yielder=nil, &block)
#       if normies_yielder.nil?
#         Enumerator.new do |y|
#           nest_normal_enums(count, final_yielder, this_count, previous_yielders, y, &block)
#         end
#       else
#         if count != this_count
#           normies_yielder << Enumerator.new do |y|
#             lazier_yielder = Lazier::Yielder.new(y, final_yielder)
#             nest_normal_enums(count, final_yielder, this_count + 1, previous_yielders << lazier_yielder, normies_yielder, &block)
#           end
#         else
#           normies_yielder << Enumerator.new do |y|
#             lazier_yielder = Lazier::Yielder.new(y, final_yielder)
#             block.call(*previous_yielders, lazier_yielder)
#           end
#         end
#       end
#     end

#     def nest_normal_enums_map(count, final_yielder, this_count=1, previous_yielders=[], normies_yielder=nil, &block)
#       if normies_yielder.nil?
#         Enumerator.new do |y|
#           nest_normal_enums_map(count, final_yielder, this_count, previous_yielders, y, &block)
#         end
#       else
#         if count != this_count
#           normies_yielder << Enumerator.new do |y|
#             lazier_yielder = Lazier::MapYielder.new(y, final_yielder)
#             nest_normal_enums_map(count, final_yielder, this_count + 1, previous_yielders << lazier_yielder, normies_yielder, &block)
#           end
#         else
#           normies_yielder << Enumerator.new do |y|
#             lazier_yielder = Lazier::MapYielder.new(y, final_yielder)
#             block.call(*previous_yielders, lazier_yielder)
#           end
#         end
#       end
#     end
#   end
# end
