# frozen_string_literal: true
require 'warning'
Warning.ignore(%r{/lib/semantic_logger/base\.rb:412})
Warning.ignore(%r{/lib/semantic_logger/levels\.rb:1})
require 'semantic_logger'

require 'lazier'

RSpec.describe Lazier do
  subject { Lazier.new(inputs) }

  let(:ids) { {} }
  let(:raw_upserted) { {} }
  let(:sort_by) do
    Proc.new do |type, item|
      case type
      when :a, :b, :c
        type
      when :a_sub_parts
        "#{item.fetch(:a_id)}#{item.fetch(:sub_part_id)}"
      when :b_sub_parts
        "#{item.fetch(:b_id)}#{item.fetch(:sub_part_id)}"
      when :c_sub_parts
        "#{item.fetch(:c_id)}#{item.fetch(:sub_part_id)}"
      else
        item.fetch(:id)
      end
    end
  end
  let(:upserted) do
    raw_upserted.map do |type, items|
      sorted = items.sort_by do |item|
        sort_by.call(type, item)
      end
      [type, sorted]
    end.to_h
  end
  let(:upsert) do
    Proc.new do |type, items|
      raw_upserted[type] ||= []
      raw_upserted[type] = raw_upserted[type] + items
      if type == :sub_parts
        items.map { |item| item[:external_id] }
      else
        ids[type] ||= 0
        items.map { |_| ids[type] += 1 }
      end
    end
  end
  let(:logger) { SemanticLogger['LazierSpec'] }
  let(:log_level) { :warn }
  let(:log_filter) do
    -> log do
      [
        /.*/,
        /upserting/,
        /checking/,
        /unsaved sub part/,
        # /external_id:/,
        # /items at/,
      ].any? { |matcher| log.message =~ matcher }
    end
  end

  before do
    SemanticLogger.add_appender(io: $stderr)
    SemanticLogger.sync!
    Lazier.logger = SemanticLogger['Lazier']
    logger.level = log_level
    Lazier.logger.level = log_level
    logger.filter = log_filter
    Lazier.logger.filter = log_filter


    subject.split do |item, a, b, c|
      logger.debug { "splitting: #{item.inspect}" }
      case item[:type]
      when :a
        a << item
      when :b
        b << item
      when :c
        c << item
      else
        raise "Unrecognized item type: #{item[:type].inspect}"
      end
    end

    subject[:a].each_slice(2) do |a_slice|
      logger.debug { "a_slice: #{a_slice.inspect}" }
      to_upsert = a_slice.map { |a| a.except(:sub_parts) }
      upsert.call(:a, to_upsert).zip(a_slice) do |id, a|
        a[:id] = id
      end
    end

    subject[:b].each_slice(2) do |b_slice|
      logger.debug { "b_slice: #{b_slice.inspect}" }
      to_upsert = b_slice.map { |b| b.except(:sub_parts) }
      upsert.call(:b, to_upsert).zip(b_slice) do |id, b|
        b[:id] = id
      end
    end

    subject[:c].each_slice(2) do |c_slice|
      logger.debug { "c_slice: #{c_slice.inspect}" }
      to_upsert = c_slice.map { |c| c.except(:sub_parts) }
      upsert.call(:c, to_upsert).zip(c_slice) do |id, c|
        c[:id] = id
      end
    end

    subject.enum do |item, sub_parts|
      logger.debug { "getting sub parts #{item.inspect}" }
      item[:sub_parts].each { |sub_part| sub_parts << sub_part }
    end

    already_saved = {}
    subject[:sub_parts].enum do |sub_part, unsaved|
      logger.debug { "checking unsaved sub parts #{sub_part.inspect}" }
      if (id = already_saved[sub_part[:external_id]])
        logger.debug { 'found unsaved sub part id' }
        sub_part[:id] = id
      else
        logger.debug { 'did not find unsaved sub part id' }
        unsaved << sub_part
      end
    end

    subject[:sub_parts][:unsaved].enum_slice(1) do |sub_parts_slice, saved|
      logger.debug { "upserting sub parts: #{sub_parts_slice.inspect}" }
      upsert.call(:sub_parts, sub_parts_slice).zip(sub_parts_slice) do |id, sub_part|
        sub_part[:id] = id
        already_saved[sub_part[:external_id]] = id
        saved << sub_part
      end
    end

    subject[:a].enum do |a, sub_part_joins|
      logger.debug { "adding sub parts to a: #{a.inspect}" }
      a[:sub_parts].each do |sub_part|
        sub_part_joins << { a_id: a[:id], sub_part_id: sub_part[:id] }
      end
    end

    subject[:b].enum do |b, sub_part_joins|
      logger.debug { "adding sub parts to b: #{b.inspect}" }
      b[:sub_parts].each do |sub_part|
        sub_part_joins << { b_id: b[:id], sub_part_id: sub_part[:id] }
      end
    end

    subject[:c].enum do |c, sub_part_joins|
      logger.debug { "adding sub parts to c: #{c.inspect}" }
      c[:sub_parts].each do |sub_part|
        sub_part_joins << { c_id: c[:id], sub_part_id: sub_part[:id] }
      end
    end

    subject[:a][:sub_part_joins].each_slice(1000) do |a_sub_parts_slice|
      logger.debug { "upserting #{a_sub_parts_slice.count} a_sub_parts" }
      upsert.call(:a_sub_parts, a_sub_parts_slice)
    end

    subject[:b][:sub_part_joins].each_slice(1000) do |b_sub_parts_slice|
      logger.debug { "upserting #{b_sub_parts_slice.count} b_sub_parts" }
      upsert.call(:b_sub_parts, b_sub_parts_slice)
    end

    subject[:c][:sub_part_joins].each_slice(1000) do |c_sub_parts_slice|
      logger.debug { "upserting #{c_sub_parts_slice.count} c_sub_parts" }
      upsert.call(:c_sub_parts, c_sub_parts_slice)
    end
  end

  let(:base_inputs) do
    [
      {
        type: :a,
        sub_parts: [
          { external_id: :a_sub},
          { external_id: :ab_sub},
          { external_id: :ac_sub},
          { external_id: :abc_sub},
        ]
      },
      {
        type: :b,
        sub_parts: [
          { external_id: :b_sub},
          { external_id: :ab_sub},
          { external_id: :bc_sub},
          { external_id: :abc_sub},
        ]
      },
      {
        type: :c,
        sub_parts: [
          { external_id: :c_sub},
          { external_id: :ac_sub},
          { external_id: :bc_sub},
          { external_id: :abc_sub},
        ]
      }
    ]
  end

  let(:base_expected_upserts) do
    {
      a: [{ type: :a }],
      a_sub_parts: [
        { sub_part_id: :a_sub },
        { sub_part_id: :ab_sub },
        { sub_part_id: :abc_sub },
        { sub_part_id: :ac_sub },
      ],
      b: [{ type: :b }],
      b_sub_parts: [
        { sub_part_id: :ab_sub },
        { sub_part_id: :abc_sub },
        { sub_part_id: :b_sub },
        { sub_part_id: :bc_sub },
      ],
      c: [{ type: :c }],
      c_sub_parts: [
        { sub_part_id: :abc_sub },
        { sub_part_id: :ac_sub },
        { sub_part_id: :bc_sub },
        { sub_part_id: :c_sub },
      ],
      sub_parts: [
        { external_id: :a_sub, id: :a_sub },
        { external_id: :ab_sub, id: :ab_sub },
        { external_id: :abc_sub, id: :abc_sub },
        { external_id: :ac_sub, id: :ac_sub },
        { external_id: :b_sub, id: :b_sub },
        { external_id: :bc_sub, id: :bc_sub },
        { external_id: :c_sub, id: :c_sub },
      ]
    }
  end

  describe '#go' do
    let(:reps) { 1 }
    let(:inputs) { base_inputs.cycle(reps) }
    let(:expected_upserts) do
      multi_expected_upserts = base_expected_upserts.map do |type, typed_upserts|
        new_expected = case type
        when :a_sub_parts
          typed_upserts.product(1.upto(reps).to_a).map do |expected_upsert, new_id|
            expected_upsert.merge(a_id: new_id)
          end.to_a
        when :b_sub_parts
          typed_upserts.product(1.upto(reps).to_a).map do |expected_upsert, new_id|
            expected_upsert.merge(b_id: new_id)
          end.to_a
        when :c_sub_parts
          typed_upserts.product(1.upto(reps).to_a).map do |expected_upsert, new_id|
            expected_upsert.merge(c_id: new_id)
          end.to_a
        else
          typed_upserts.cycle(reps).to_a
        end
        [type, new_expected]
      end

      multi_expected_upserts.map do |type, items|
        sorted = items.sort_by do |item|
          sort_by.call(type, item)
        end
        [type, sorted]
      end.to_h
    end

    it 'leads to the expected upserts' do
      expect(raw_upserted).to be_empty
      subject.go
      # the shenanigans in the test code
      # which are intended to demonstrate a somewhat complex interaction
      # with normal ruby code outside the framework
      # somewhat reduce this number
      # though not actually all that much
      expect(upserted[:sub_parts].count).to eq(20)
      # we're still just going to check that each expected sub_part upsert
      # happened at least once
      upserted[:sub_parts].uniq!
      expect(upserted).to eq(expected_upserts)
    end
  end
end
