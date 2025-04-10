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
          { type: :c },
        ]
      end

      it { is_expected.to eq(expected) }

      it 'returns an array of SpecData::Item' do
        subject.each do |item|
          expect(item).to be_a(described_class::Item)
        end
      end
    end

    context 'setting one type' do
      before { described_instance.types(:new_type) }
      it { is_expected.to eq([{ type: :new_type }]) }

      context 'adding a sub part' do
        before { described_instance.sub_parts(:sub_part) }
        it { is_expected.to eq([{ type: :new_type, sub_parts: [{ type: :sub_part }] }]) }

        it 'returns an array of SpecData::Item' do
          subject.each do |item|
            item.sub_parts.each do |sub_part|
              expect(sub_part).to be_a(described_class::Item)
            end
          end
        end
      end

      context 'adding repeats' do
        before { described_instance.repeats(2) }
        it { is_expected.to eq([{ type: :new_type }, { type: :new_type }]) }

        it 'does not cause the same objects to be reused' do
          object_ids = subject.map(&:object_id)
          expect(object_ids.uniq.count).to eq(object_ids.count)
        end
      end
    end
  end

  [:types, :sub_parts, :repeats].each do |m|
    describe "##{m} (common behavior)" do
      subject { described_instance.public_send(m, :anything) }

      it 'is chainable (returns self)' do
        expect(subject).to eq(described_instance)
      end

      context 'calling after inputs have been generated' do
        before { described_instance.inputs }

        it 'raises an error' do
          expect { described_instance.public_send(m, :anything) }.to raise_error('cannot modify after inputs generated')
        end
      end
    end
  end

  describe '#record' do
    it 'tracks given data' do
      described_instance.record(:data)
      expect(described_instance.recorded.count).to eq(1)
      recorded = described_instance.recorded.first
      expect(recorded[:data]).to eq(:data)
      caller_data = recorded[:caller]
      expect(caller_data[:label]).to match(/block \(\d levels\) in <top \(required\)>/)
      expect(caller_data[:lineno]).to be_within(500).of(501)
      expect(caller_data[:path]).to match(%r{spec/lazier/spec_data_spec\.rb\z})
    end
  end

  describe '#upsert' do
    it 'returns ids and remembers items' do
      expect(described_instance.upsert(:a, [:fake, :items])).to eq([1, 2])
      expect(described_instance.upsert(:a, [:more, :items])).to eq([3, 4])
      expect(described_instance.upsert(:b, [:item])).to eq([1])
      expect(described_instance.upserted).to eq(a: [[:fake, :items], [:more, :items]], b: [[:item]])
    end
  end

  describe '#upserted?' do
    subject { described_instance.upserted?(item) }
    let(:item) { described_instance.inputs.first }

    context 'item was upserted' do
      before { described_instance.upsert(:a, [item]) }
      it { is_expected.to be true }

      context 'repeatedly' do
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

      context 'repeatedly' do
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
      it 'also returns sub parts' do
        expect(subject).to eq(
          [
            { type: :sub_part },
            { type: :sub_part },
            { type: :c, sub_parts: [{ type: :sub_part }] },
            { type: :sub_part },
          ]
        )
      end
    end

    context 'inputs have not been generated' do
      it 'ensures inputs have been generated' do
        expect(subject).to eq([{ type: :a }, { type: :b }, { type: :c }])
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
    it { is_expected.to eq(some: :data) }

    it 'treats the item as not upserted' do
      expect(described_instance.upserted?(subject)).to be false
      non_inputs = described_instance.items_not_upserted - described_instance.inputs
      expect(non_inputs).to eq([{ some: :data }])
    end
  end

  describe Lazier::SpecData::Item do
    describe '#upserted?' do

    end
  end
end
