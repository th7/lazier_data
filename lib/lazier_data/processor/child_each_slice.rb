# frozen_string_literal: true

class LazierData
  class Processor
    class ChildEachSlice
      NOTHING = :_lazier_data_nothing

      attr_reader :upstream, :downstream, :batch_size, :input_path, :output_path_parts, :block

      def initialize(upstream, downstream, batch_size, input_path, &block)
        @upstream = upstream
        @downstream = downstream
        @batch_size = batch_size
        @input_path = input_path
        @block = block
      end

      def call
        slicer.each_slice(batch_size) do |raw_yielded|
          items = raw_yielded.map(&:first)
          yielders = raw_yielded.last[3]
          @block.call(items, *yielders)
          raw_yielded.each do |_, root_item, item_store, _|
            next if root_item == NOTHING

            downstream << [root_item, item_store]
          end
        end
      end

      private

      def slicer # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        Enumerator.new do |slicer|
          upstream.each do |root_item, item_store|
            output_yielders = build_output_yielders(item_store)
            items = item_store.dig(*input_path)
            if items.count.zero?
              downstream << [root_item, item_store]
            elsif items.count == 1
              slicer << [items.first, root_item, item_store, output_yielders]
            elsif items.count > 1
              items[0..-2].each do |item|
                slicer << [item, NOTHING, item_store, output_yielders]
              end

              slicer << [items.last, root_item, item_store, output_yielders]
            end
          end
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

      def output_path_parts
        @output_path_parts ||= block.parameters[1..].map(&:last)
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
end
