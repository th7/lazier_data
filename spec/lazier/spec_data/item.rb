# frozen_string_literal: true

class Lazier
  class SpecData
    class Item
      def initialize(created_by, **attrs)
        @created_by = created_by
        @attrs = attrs
      end

      def [](key)
        @attrs[key]
      end

      def []=(key, value)
        @attrs[key] = value
      end

      def ==(other)
        if other.is_a?(Hash)
          @attrs == other
        elsif other.is_a?(self.class)
          object_id == other.object_id
        end
      end

      def inspect
        @attrs.inspect
      end

      protected

      def upserted?; end

      private

      def method_missing(m_name, *args)
        m_name_s = m_name.to_s
        if m_name_s.end_with?('=')
          raise 'Multiple arguments passed to setter' if args.count > 1

          m_base = m_name_s.sub('=', '').to_sym
          @attrs[m_base] = args.first
        else
          @attrs[m_name]
        end
      end

      def respond_to_missing?(*)
        true
      end
    end
  end
end
