# frozen_string_literal: true

class LazierData
  class Processor
    NOTHING = :_lazier_data_nothing

    attr_reader :upstream, :downstream, :batch_size, :input_path, :output_path_parts, :block

    def initialize(upstream, downstream, batch_size, input_path, output_path_parts, &block)
      @upstream = upstream
      @downstream = downstream
      @batch_size = batch_size
      @input_path = input_path
      @output_path_parts = output_path_parts
      @block = block
    end

    def call
      if batch_size.nil?
        process_each
      else
        process_each_slice
      end
    end

    private

    def dug # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      Enumerator.new do |dug|
        upstream.each do |root_item, item_store|
          output_yielders = build_output_yielders(item_store)

          if input_path.empty?
            log_and_yield(dug, [root_item, root_item, item_store, output_yielders], :root)
          else
            items = item_store.dig(*input_path)
            if items.count.zero?
              log_and_yield(downstream, [root_item, item_store], :no_dug)
            elsif items.count == 1
              log_and_yield(dug, [items.first, root_item, item_store, output_yielders], :only)
            elsif items.count > 1
              items[0..-2].each.with_index(1) do |item, item_number|
                log_and_yield(dug, [item, NOTHING, item_store, output_yielders], :stored, item_number, items.count)
              end

              log_and_yield(dug, [items.last, root_item, item_store, output_yielders], :last, items.count, items.count)
            else
              raise 'wat'
            end
          end
        end
      end
    end

    def process_each
      dug.each do |item, root_item, item_store, output_yielders|
        log_and_call(block, [item, *output_yielders], :item)
        log_and_yield(downstream, [root_item, item_store], :after_item)
      end
    end

    def process_each_slice
      dug.each_slice(batch_size) do |raw_yielded|
        item_slice = raw_yielded.map(&:first)
        log_and_call(block, [item_slice, *raw_yielded.last[3]], :slice)
        raw_yielded.each do |_, root_item, item_store, _|
          next if root_item == NOTHING

          log_and_yield(downstream, [root_item, item_store], :after_slice)
        end
      end
    end

    def build_output_yielders(item_store)
      output_path_parts.map do |output_path_part|
        ::Enumerator::Yielder.new do |item|
          storage_path = input_path + [output_path_part]
          logger.debug { "storing item at #{storage_path}: #{item.inspect}" }
          item_store.dig(*storage_path) << item
        end
      end
    end

    def log_and_yield(yielder, to_yield, msg_type, item_number = nil, found_count = nil)
      logger.debug { build_log_message(msg_type, to_yield, item_number, found_count) }
      yielder << to_yield
    end

    def log_and_call(callee, to_yield, msg_type)
      logger.debug { build_log_message(msg_type, to_yield) }
      callee.call(*to_yield)
    end

    def build_log_message(msg_type, to_yield, item_number = nil, found_count = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      case msg_type
      when :root
        "yielding dug root item: #{to_yield[0..1].inspect}"
      when :no_dug
        "yielding downstream (no dug items from #{input_path.inspect}): #{to_yield[0..0].inspect}"
      when :only
        "yielding dug stored item (1 of 1) from #{input_path.inspect}: #{to_yield[0..1].inspect}"
      when :stored, :last_stored
        "yielding dug stored item (#{item_number} of #{found_count}) " \
        "from #{input_path.inspect}: #{to_yield[0..1].inspect}"
      when :item
        "yielding item to #{block.source_location}: #{to_yield[0..0].inspect}"
      when :after_item
        "yielding downstream (after item): #{to_yield[0..0].inspect}"
      when :slice
        "yielding slice to #{block.source_location}: #{to_yield[0..0].inspect}"
      when :after_slice
        "yielding downstream (after slice): #{to_yield[0..0].inspect}"
      end
    end

    def logger
      LazierData.logger
    end
  end
end
