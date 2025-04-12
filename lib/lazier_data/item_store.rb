# frozen_string_literal: true

class LazierData
  class ItemStore
    ITEMS_KEY = :_lazier_data_items

    def initialize
      @store = new_layer
    end

    def dig(*path)
      if path.empty?
        @store[ITEMS_KEY]
      else
        @store.dig(*path)[ITEMS_KEY]
      end
    end

    def [](key)
      @store[key][ITEMS_KEY]
    end

    private

    def new_layer
      it = Hash.new { |hash, key| hash[key] = new_layer }
      it[ITEMS_KEY] = []
      it
    end
  end
end
