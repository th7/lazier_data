# frozen_string_literal: true

require 'lazier'
require 'lazier/spec_data'

RSpec.describe Lazier do
  let(:lazier) do
    lazy_inputs = Enumerator.new do |y|
      spec_data.inputs.each { |item| y << item }
    end
    described_class.new(lazy_inputs)
  end

  let(:spec_data) { Lazier::SpecData.new }

  before do
    described_class.logger = SemanticLogger['Lazier']
    described_class.logger.level = :warn
    described_class.logger.filter = lambda do |log|
      [
        /.*/,
        /upserting/,
        /checking/,
        /unsaved sub part/
        # /external_id:/,
        # /items at/,
      ].any? { |matcher| log.message =~ matcher }
    end
  end

  context 'simple data processing' do
    before do
      lazier.each_slice(2) do |items|
        spec_data.upsert(:items, items)
      end
    end

    it 'upserts all items' do # rubocop:disable RSpec/MultipleExpectations
      expect(spec_data.items_not_upserted.count).to eq(spec_data.inputs.count)
      lazier.go
      expect(spec_data.items_not_upserted).to eq([])
    end
  end

  context 'processing with sub parts' do
    before do
      spec_data.sub_parts(:sub_part_a, :sub_part_b, :sub_part_c)

      lazier.each_slice(2) do |items|
        spec_data.upsert(:items, items)
      end

      lazier.enum do |item, sub_parts|
        item.sub_parts.each { |sub_part| sub_parts << sub_part }
      end

      lazier[:sub_parts].each_slice(2) do |sub_parts_slice|
        spec_data.upsert(:sub_parts, sub_parts_slice)
      end
    end

    it 'upserts all items' do # rubocop:disable RSpec/MultipleExpectations
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      lazier.go
      expect(spec_data.items_not_upserted).to eq([])
    end
  end

  context 'processing with a split' do
    before do
      lazier.split do |item, a, b, c|
        case item.type
        when :a
          a << item
        when :b
          b << item
        when :c
          c << item
        end
      end

      lazier[:a].each_slice(2) do |a_items|
        spec_data.upsert(:a_items, a_items)
      end

      lazier[:b].each_slice(2) do |b_items|
        spec_data.upsert(:b_items, b_items)
      end

      lazier[:c].each_slice(2) do |c_items|
        spec_data.upsert(:c_items, c_items)
      end
    end

    it 'upserts all items' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      lazier.go
      expect(spec_data.items_not_upserted).to eq([])
      expect(spec_data.upserted[:a_items].count).to eq(1)
      expect(spec_data.upserted[:b_items].count).to eq(1)
      expect(spec_data.upserted[:c_items].count).to eq(1)
    end
  end

  context 'treating sub parts as many to many' do
    before do
      spec_data.sub_parts(:sub_part_a, :sub_part_b, :sub_part_c)

      lazier.each_slice(2) do |items|
        spec_data.upsert(:items, items).zip(items) do |id, item|
          item.id = id
        end
      end

      lazier.enum do |item, sub_parts|
        item.sub_parts.each { |sub_part| sub_parts << sub_part }
      end

      lazier[:sub_parts].each_slice(2) do |sub_parts|
        spec_data.upsert(:sub_parts, sub_parts).zip(sub_parts) do |id, sub_part|
          sub_part.id = id
        end
      end

      lazier.enum do |item, item_sub_parts|
        item.sub_parts.each do |sub_part|
          item_sub_parts << spec_data.new(item_id: item.id, sub_part_id: sub_part.id)
        end
      end

      lazier[:item_sub_parts].each_slice(2) do |item_sub_parts|
        spec_data.upsert(:item_sub_parts, item_sub_parts)
      end
    end

    it 'upserts all items' do # rubocop:disable RSpec/MultipleExpectations
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      lazier.go
      expect(spec_data.items_not_upserted).to eq([])
    end
  end

  context 'splitting, treating sub parts as many-to-many, more data, in uneven batch sizes' do
    let(:repeats) { 100 }

    before do
      spec_data.repeats(repeats)
      spec_data.sub_parts(:sub_part_a, :sub_part_b, :sub_part_c)

      lazier.split do |item, a_items, b_items, c_items|
        case item.type
        when :a
          a_items << item
        when :b
          b_items << item
        when :c
          c_items << item
        end
      end

      @count = 0
      lazier.enum do |item, sub_parts|
        @count += 1
        item.sub_parts.each { |sub_part| sub_parts << sub_part }
      end

      def upsert_to(target)
        lambda do |items|
          spec_data.upsert(target, items).zip(items) do |id, item|
            item.id = id
          end
        end
      end

      %i[a_items b_items c_items sub_parts].each.with_index(2) do |item_type, batch_size|
        lazier[item_type].each_slice(batch_size, &upsert_to(item_type))
      end

      %i[a_items b_items c_items].each do |item_type|
        lazier[item_type].enum do |item, item_sub_parts|
          item.sub_parts.each do |sub_part|
            item_sub_parts << spec_data.new(item_id: item.id, sub_part_id: sub_part.id)
          end
        end
      end

      lazier[:a_items][:item_sub_parts].each_slice(2, &upsert_to(:a_item_sub_parts))
      lazier[:b_items][:item_sub_parts].each_slice(5, &upsert_to(:b_item_sub_parts))
      lazier[:c_items][:item_sub_parts].each_slice(9, &upsert_to(:c_item_sub_parts))
    end

    it 'upserts all items' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      lazier.go
      expect(spec_data.items_not_upserted).to eq([])
      expect(spec_data.upserted[:a_items].flatten.count).to eq(repeats)
      expect(spec_data.upserted[:b_items].flatten.count).to eq(repeats)
      expect(spec_data.upserted[:c_items].flatten.count).to eq(repeats)
      expect(spec_data.upserted[:sub_parts].flatten.count).to eq(repeats * 3 * 3)
      expect(spec_data.upserted[:a_item_sub_parts].flatten.count).to eq(repeats * 3)
      expect(spec_data.upserted[:b_item_sub_parts].flatten.count).to eq(repeats * 3)
      expect(spec_data.upserted[:c_item_sub_parts].flatten.count).to eq(repeats * 3)
      expect(spec_data.upserted[:a_item_sub_parts].first.first).to eq(id: 1, item_id: 1, sub_part_id: 1)
      expect(spec_data.upserted[:a_item_sub_parts].last.last).to eq(id: 300, item_id: 100, sub_part_id: 885)
    end
  end
end
