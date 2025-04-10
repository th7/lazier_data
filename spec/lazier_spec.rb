# frozen_string_literal: true

require 'lazier'
require 'lazier/spec_data'

RSpec.describe Lazier do
  subject { described_class.new(lazy_inputs) }

  let(:spec_data) { Lazier::SpecData.new }
  let(:inputs) { spec_data.inputs }
  let(:lazy_inputs) do
    Enumerator.new do |y|
      inputs.each { |item| y << item }
    end
  end

  let(:logger) { SemanticLogger['LazierSpec'] }
  let(:log_level) { :warn }
  let(:log_filter) do
    lambda do |log|
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

  before do
    described_class.logger = SemanticLogger['Lazier']
    logger.level = log_level
    described_class.logger.level = log_level
    logger.filter = log_filter
    described_class.logger.filter = log_filter
  end

  context 'simple data processing' do
    before do
      subject.each_slice(2) do |items|
        spec_data.upsert(:items, items)
      end
    end

    it 'upserts all items' do
      expect(spec_data.items_not_upserted.count).to eq(inputs.count)
      subject.go
      expect(spec_data.items_not_upserted).to eq([])
    end
  end

  context 'processing with sub parts' do
    before do
      spec_data.sub_parts(:sub_part_a, :sub_part_b, :sub_part_c)

      subject.each_slice(2) do |items|
        spec_data.upsert(:items, items)
      end

      subject.enum do |item, sub_parts|
        item.sub_parts.each { |sub_part| sub_parts << sub_part }
      end

      subject[:sub_parts].each_slice(2) do |sub_parts_slice|
        spec_data.upsert(:sub_parts, sub_parts_slice)
      end
    end

    it 'upserts all items' do
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      subject.go
      expect(spec_data.items_not_upserted).to eq([])
    end
  end

  context 'processing with a split' do
    before do
      subject.split do |item, a, b, c|
        case item.type
        when :a
          a << item
        when :b
          b << item
        when :c
          c << item
        end
      end

      subject[:a].each_slice(2) do |a_items|
        spec_data.upsert(:a_items, a_items)
      end

      subject[:b].each_slice(2) do |b_items|
        spec_data.upsert(:b_items, b_items)
      end

      subject[:c].each_slice(2) do |c_items|
        spec_data.upsert(:c_items, c_items)
      end
    end

    it 'upserts all items' do
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      subject.go
      expect(spec_data.items_not_upserted).to eq([])
      expect(spec_data.upserted[:a_items].count).to eq(1)
      expect(spec_data.upserted[:b_items].count).to eq(1)
      expect(spec_data.upserted[:c_items].count).to eq(1)
    end
  end

  context 'treating sub parts as many to many' do
    before do
      spec_data.sub_parts(:sub_part_a, :sub_part_b, :sub_part_c)

      subject.each_slice(2) do |items|
        spec_data.upsert(:items, items).zip(items) do |id, item|
          item.id = id
        end
      end

      subject.enum do |item, sub_parts|
        item.sub_parts.each { |sub_part| sub_parts << sub_part }
      end

      subject[:sub_parts].each_slice(2) do |sub_parts|
        spec_data.upsert(:sub_parts, sub_parts).zip(sub_parts) do |id, sub_part|
          sub_part.id = id
        end
      end

      subject.enum do |item, item_sub_parts|
        item.sub_parts.each do |sub_part|
          item_sub_parts << spec_data.new(item_id: item.id, sub_part_id: sub_part.id)
        end
      end

      subject[:item_sub_parts].each_slice(2) do |item_sub_parts|
        spec_data.upsert(:item_sub_parts, item_sub_parts)
      end
    end

    it 'upserts all items' do
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      subject.go
      expect(spec_data.items_not_upserted).to eq([])
    end
  end

  context 'splitting, treating sub parts as many-to-many, more data, in uneven batch sizes' do
    let(:repeats) { 100 }

    before do
      spec_data.repeats(repeats)
      spec_data.sub_parts(:sub_part_a, :sub_part_b, :sub_part_c)

      subject.split do |item, a_items, b_items, c_items|
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
      subject.enum do |item, sub_parts|
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
        subject[item_type].each_slice(batch_size, &upsert_to(item_type))
      end

      %i[a_items b_items c_items].each do |item_type|
        subject[item_type].enum do |item, item_sub_parts|
          item.sub_parts.each do |sub_part|
            item_sub_parts << spec_data.new(item_id: item.id, sub_part_id: sub_part.id)
          end
        end
      end

      subject[:a_items][:item_sub_parts].each_slice(2, &upsert_to(:a_item_sub_parts))
      subject[:b_items][:item_sub_parts].each_slice(5, &upsert_to(:b_item_sub_parts))
      subject[:c_items][:item_sub_parts].each_slice(9, &upsert_to(:c_item_sub_parts))
    end

    it 'upserts all items' do
      expect(spec_data.items_not_upserted.count).to eq(spec_data.all_items_count)
      subject.go
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
