# frozen_string_literal: true

class LazierData
  class Processor
    class ChildEachSlice
      NOTHING = :_lazier_data_nothing

      attr_reader :upstream, :downstream, :batch_size, :input_path, :block

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

      def slicer
        Enumerator.new do |slicer|
          upstream.each do |root_item, item_store|
            yield_items(slicer, root_item, item_store)
          end
        end
      end

      def yield_items(slicer, root_item, item_store)
        output_yielders = build_output_yielders(item_store)
        items = item_store.dig(*input_path)
        if items.count.zero?
          downstream << [root_item, item_store]
        elsif items.count == 1
          slicer << [items.first, root_item, item_store, output_yielders]
        elsif items.count > 1
          yield_multiple(slicer, items, root_item, item_store, output_yielders)
        end
      end

      def yield_multiple(slicer, items, root_item, item_store, output_yielders)
        items[0..-2].each do |item|
          slicer << [item, NOTHING, item_store, output_yielders]
        end

        slicer << [items.last, root_item, item_store, output_yielders]
      end

      def output_path_parts
        @output_path_parts ||= block.parameters[1..].map(&:last)
      end

      def build_output_yielders(item_store)
        output_path_parts.map do |output_path_part|
          ::Enumerator::Yielder.new do |item|
            storage_path = input_path + [output_path_part]
            item_store.dig(*storage_path) << item
          end
        end
      end
    end
  end
end
