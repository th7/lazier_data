# frozen_string_literal: true

class LazierData
  class Processor
    class ChildEach
      NOTHING = :_lazier_data_nothing

      attr_reader :upstream, :downstream, :batch_size, :input_path, :block

      def initialize(upstream, downstream, input_path, &block)
        @upstream = upstream
        @downstream = downstream
        @batch_size = nil
        @input_path = input_path
        @block = block
      end

      def call
        upstream.each do |root_item, item_store|
          output_yielders = build_output_yielders(item_store)
          item_store.dig(*input_path).each do |item|
            block.call(item, *output_yielders)
          end
          downstream << [root_item, item_store]
        end
      end

      private

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
