class LazierData
  class Processor
    class RootEachSlice
      def initialize(upstream, downstream, batch_size, &block)
        @upstream = upstream
        @downstream = downstream
        @batch_size = batch_size
        @block = block
      end

      def call
        slicer.each_slice(batch_size) do |raw_yielded|
          root_items = raw_yielded.map(&:first)
          yielders = raw_yielded.last[2]
          @block.call(root_items, *yielders)
          raw_yielded.each do |root_item, item_store, _|
            downstream << [root_item, item_store]
          end
        end
      end

      private

      attr_reader :upstream, :downstream, :batch_size, :block

      def slicer # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        Enumerator.new do |slicer|
          upstream.each do |root_item, item_store|
            output_yielders = build_output_yielders(item_store)
            slicer << [root_item, item_store, output_yielders]
          end
        end
      end

      # probably go in module
      def output_path_parts
        @output_path_parts ||= block.parameters[1..].map(&:last)
      end

      def build_output_yielders(item_store)
        output_path_parts.map do |output_path_part|
          ::Enumerator::Yielder.new do |item|
            logger.debug { "storing item at #{storage_path}: #{item.inspect}" }
            item_store.dig(output_path_part) << item
          end
        end
      end

      def logger
        LazierData.logger
      end
    end
  end
end
