# frozen_string_literal: true

class LazierData
  class Processor
    class RootEach
      def initialize(upstream, downstream, &block)
        @upstream = upstream
        @downstream = downstream
        @block = block
      end

      def call
        upstream.each do |root_item, item_store|
          output_yielders = build_output_yielders(item_store)
          block.call(root_item, *output_yielders)
          downstream << [root_item, item_store]
        end
      end

      private

      attr_reader :upstream, :downstream, :block

      def output_path_parts
        @output_path_parts ||= block.parameters[1..].map(&:last)
      end

      def build_output_yielders(item_store)
        output_path_parts.map do |output_path_part|
          ::Enumerator::Yielder.new do |item|
            item_store[output_path_part] << item
          end
        end
      end
    end
  end
end
