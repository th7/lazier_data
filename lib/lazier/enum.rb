module Lazier
  class Enum
    def call_other(other)
      other.public_send(m, *args, **kwargs, &block)
    end

    private

    attr_reader :m, :args, :kwargs, :block

    def method_missing(m, *args, **kwargs, &block)
      @m = m
      @args = args
      @kwargs = kwargs
      @block = block
    end
  end
end
