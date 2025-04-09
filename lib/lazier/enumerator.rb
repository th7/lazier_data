class Lazier
  class Enumerator
    class Each
      def initialize(&block)
        @block = block
        @next_index = 0
      end

      def call(accumulated)
        @block.call(accumulated.fetch(@next_index))
        @next_index += 1
      end

      def finish(_, _)
        # do nothing
      end

      def max_processed
        @next_index - 1
      end

      def unused_batch_keys
        [max_processed]
      end

      def next_batch_ends_at
        @next_index
      end
    end
  end
end

class Lazier
  class Enumerator
    class EachSlice
      attr_reader :next_batch_ends_at

      def initialize(batch_size, &block)
        @batch_size = batch_size
        @block = block
        @next_batch_starts_at = 0
        @next_batch_ends_at = batch_size - 1
      end

      def call(accumulated)
        next_batch_keys = (@next_batch_starts_at..@next_batch_ends_at).to_a
        @block.call(accumulated.values_at(*next_batch_keys))
        @next_batch_starts_at = next_batch_keys.last + 1
        @next_batch_ends_at = next_batch_keys.last + @batch_size
      end

      def finish(accumulated, max_index)
        next_batch_keys = (@next_batch_starts_at..max_index).to_a
        values = accumulated.values_at(*next_batch_keys)
        return if values.empty?

        @block.call(values)
        @next_batch_starts_at = next_batch_keys.last + 1
        @next_batch_ends_at = next_batch_keys.last + @batch_size
      end

      def max_processed
        @next_batch_starts_at - 1
      end

      def unused_batch_keys
        ((max_processed - @batch_size)..max_processed).to_a
      end
    end
  end
end

class Lazier
  class Enumerator
    def initialize(&block)
      @block = block
      @processors = []
      @accumulated = {}
      @current_index = -1
      @yielder = ::Enumerator::Yielder.new do |item|
        @current_index += 1
        @accumulated[@current_index] = item

        process(item, @processors)
      end
    end

    def each(&block)
      @processors << Each.new(&block)
    end

    def each_slice(batch_size, &block)
      @processors << EachSlice.new(batch_size, &block)
    end

    def go
      @block.call(@yielder)
      @processors.each { |p| p.finish(@accumulated, @current_index) }
    end

    private

    def process(item, processors, min_processed = Float::INFINITY)
      this_processor = processors.first
      min_ok = min_processed >= this_processor.next_batch_ends_at
      index_ok = @current_index >= this_processor.next_batch_ends_at
      if min_ok && index_ok
        this_processor.call(@accumulated)
        next_min_processed = [this_processor.max_processed, min_processed].min
        next_processors = processors[1..-1]
        if next_processors&.any?
          process(item, next_processors, next_min_processed)
        else
          @accumulated = @accumulated.except(*this_processor.unused_batch_keys)
        end
      end
    end
  end
end
