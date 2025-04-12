class LazierData
  class Processor
    class RootEachSlice
      def initialize(upstream, downstream, batch_size, &block)
        @upstream = upstream
        @downstream = downstream
        @batch_size = batch_size
        p block.source_location
        @block = block
      end

      def call
        # upstream.each_slice(batch_size) do |batch|
        #   output_yielders = build_output_yielders(item_store)
        #   items = block.call(batch.map(&:first, *output_yielders)
        # end
        slicer.each_slice(batch_size) do |raw_yielded|
          items, item_stores = separate_items_and_item_stores(raw_yielded)
          # log_and_call(block, [item_slice, *raw_yielded.last[3]], :slice)
          root_items.each do |root_item, item_store|
            log_and_yield(downstream, [root_item, item_store], :after_slice)
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
            # items = item_store.dig
            # p items
            # if items.count.zero?
            #   p 'zero'
            #   downstream << [root_item, item_store]
            # elsif items.count == 1
            #   dug << [items.first, root_item, item_store, output_yielders]
            # elsif items.count > 1
            #   items[0..-2].each do |item|
            #     dug << [item, NOTHING, item_store, output_yielders]
            #   end

            #   dug << [items.last, root_item, item_store, output_yielders]
            # else
            #   raise 'wat'
            # end
          end
        end
      end

      def separate_items_and_item_stores(raw_yielded)
        items = []
        item_stores = []
        raw_yielded.each do |item, root_item, item_store, _|
          item_slice << item
          root_items << [root_item, item_store] unless root_item == NOTHING
        end
        [item_slice, root_items]
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
