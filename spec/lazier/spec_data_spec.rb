# frozen_string_literal: true

require 'lazier/spec_data'

# yes, this is a meta spec
# having a good utility to produce inputs
# and most importantly corresponding expected outputs
# is really useful
RSpec.describe Lazier::SpecData do
  let(:described_instance) { described_class.new }

  describe '#inputs' do
    subject { described_instance.inputs }

    context 'defaults' do
      let(:expected) do
        [
          { type: :a },
          { type: :b },
          { type: :c }
        ]
      end

      it { is_expected.to eq(expected) }
      it { is_expected.to all be_a(described_class::Item) }
    end

    context 'setting one type' do
      before { described_instance.types(:new_type) }

      it { is_expected.to eq([{ type: :new_type }]) }

      context 'adding a sub part' do # rubocop:disable RSpec/NestedGroups
        let(:inputs) { subject }

        before { described_instance.sub_parts(:sub_part) }

        it { is_expected.to eq([{ type: :new_type, sub_parts: [{ type: :sub_part }] }]) }

        it 'returns an array of SpecData::Item' do
          inputs.each do |item|
            expect(item.sub_parts).to all be_a(described_class::Item)
          end
        end
      end

      context 'adding repeats' do # rubocop:disable RSpec/NestedGroups
        let(:inputs) { subject }

        before { described_instance.repeats(2) }

        it { is_expected.to eq([{ type: :new_type }, { type: :new_type }]) }

        it 'does not cause the same objects to be reused' do
          object_ids = inputs.map(&:object_id)
          expect(object_ids.uniq.count).to eq(object_ids.count)
        end
      end
    end
  end

  %i[types sub_parts repeats].each do |m|
    describe "##{m} (common behavior)" do
      subject { described_instance.public_send(m, :anything) }

      it { is_expected.to eq(described_instance) }

      context 'calling after inputs have been generated' do
        before { described_instance.inputs }

        it 'raises an error' do
          expect { described_instance.public_send(m, :anything) }.to raise_error('cannot modify after inputs generated')
        end
      end
    end
  end

  describe '#upsert' do
    it 'returns ids and remembers items' do # rubocop:disable RSpec/MultipleExpectations
      expect(described_instance.upsert(:a, %i[fake items])).to eq([1, 2])
      expect(described_instance.upsert(:a, %i[more items])).to eq([3, 4])
      expect(described_instance.upsert(:b, [:item])).to eq([1])
      expect(described_instance.upserted).to eq(a: [%i[fake items], %i[more items]], b: [[:item]])
    end
  end

  describe '#upserted?' do
    subject { described_instance.upserted?(item) }

    let(:item) { described_instance.inputs.first }

    context 'item was upserted' do
      before { described_instance.upsert(:a, [item]) }

      it { is_expected.to be true }

      context 'repeatedly' do # rubocop:disable RSpec/NestedGroups
        before { described_instance.upsert(:a, [item]) }

        it { is_expected.to be true }
      end
    end

    context 'item not upserted' do
      it { is_expected.to be false }
    end
  end

  describe '#upserted_count' do
    subject { described_instance.upserted_count(item) }

    let(:item) { described_instance.inputs.first }

    context 'item was upserted' do
      before { described_instance.upsert(:a, [item]) }

      it { is_expected.to eq(1) }

      context 'repeatedly' do # rubocop:disable RSpec/NestedGroups
        before { described_instance.upsert(:a, [item]) }

        it { is_expected.to eq(2) }
      end
    end

    context 'item not upserted' do
      it { is_expected.to eq(0) }
    end
  end

  describe '#items_not_upserted' do
    subject { described_instance.items_not_upserted }

    let(:items_not_upserted) { subject }

    let(:upserted_items) { described_instance.inputs[0..1] }

    context 'basic items' do
      before { described_instance.upsert(:a, upserted_items) }

      it { is_expected.to eq([{ type: :c }]) }
    end

    context 'with sub parts' do
      before do
        described_instance.sub_parts(:sub_part)
        described_instance.upsert(:a, upserted_items)
      end

      it 'also returns sub parts' do # rubocop:disable RSpec/ExampleLength
        expect(items_not_upserted).to eq(
          [
            { type: :sub_part },
            { type: :sub_part },
            { type: :c, sub_parts: [{ type: :sub_part }] },
            { type: :sub_part }
          ]
        )
      end
    end

    context 'inputs have not been generated' do
      it 'ensures inputs have been generated' do
        expect(items_not_upserted).to eq([{ type: :a }, { type: :b }, { type: :c }])
      end
    end
  end

  describe '#all_items_count' do
    subject { described_instance.all_items_count }

    it { is_expected.to eq(3) }

    context 'with sub parts' do
      before { described_instance.sub_parts(:sub_part) }

      it { is_expected.to eq(6) }
    end
  end

  describe '#new' do
    subject { described_instance.new(some: :data) }

    let(:new_data) { subject }

    it { is_expected.to eq(some: :data) }

    it 'treats the item as not upserted' do # rubocop:disable RSpec/MultipleExpectations
      expect(described_instance.upserted?(new_data)).to be false
      non_inputs = described_instance.items_not_upserted - described_instance.inputs
      expect(non_inputs).to eq([{ some: :data }])
    end
  end
end
