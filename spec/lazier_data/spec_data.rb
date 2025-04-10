# frozen_string_literal: true

require 'lazier_data/spec_data/item'

class LazierData
  class SpecData
    def initialize
      @upserted_counts = Hash.new { |hash, key| hash[key] = 0 }
      @upserted_counts.compare_by_identity
      @all_items = []
    end

    def types(*type_list)
      assert_not_generated!
      @type_list = type_list
      self
    end

    def sub_parts(*sub_parts_list)
      assert_not_generated!
      @sub_parts_list = sub_parts_list
      self
    end

    def repeats(count)
      assert_not_generated!
      @repeats_count = count
      self
    end

    def inputs
      @inputs ||= generate_inputs
    end

    def upsert(label, items)
      upserted[label] << items
      items.map do |item|
        @upserted_counts[item] += 1
        next_id(label)
      end
    end

    def upserted
      @upserted ||= Hash.new { |hash, key| hash[key] = [] }
    end

    def upserted?(item)
      @upserted_counts.include?(item)
    end

    def upserted_count(item)
      @upserted_counts[item]
    end

    def items_not_upserted
      inputs # ensure generated
      @all_items.reject { |item| upserted?(item) }
    end

    def all_items_count
      inputs # ensure generated
      @all_items.count
    end

    def new(**attrs)
      item = Item.new(self, **attrs)
      @all_items << item
      item
    end

    private

    def add(&block)
      @processor_blocks << block
    end

    def type_list
      @type_list ||= %i[a b c]
    end

    def sub_parts_list
      @sub_parts_list ||= []
    end

    def repeats_count
      @repeats_count ||= 1
    end

    def generate_inputs
      inputs = []
      repeats_count.times do
        inputs += type_list.map(&generate_item)
      end
      inputs
    end

    def generate_item
      lambda do |type|
        item = new(type:)
        item[:sub_parts] = sub_parts_list.map(&generate_sub_part) unless sub_parts_list.empty?
        item
      end
    end

    def generate_sub_part
      ->(type) { new(type:) }
    end

    def assert_not_generated!
      raise 'cannot modify after inputs generated' if @inputs
    end

    def results
      @results ||= []
    end

    def next_id(label)
      @ids ||= {}
      @ids[label] ||= 0
      @ids[label] += 1
    end
  end
end
