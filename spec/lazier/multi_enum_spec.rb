require 'lazier/multi_enum'

RSpec.describe Lazier::MultiEnum do
  let(:described_instance) { Lazier::MultiEnum.new }

  describe '#enums' do
    subject do
      described_instance.enums(3) do |a, b, c|
        raise 'called twice' if @inputs_block_called
        @inputs_block_called = true

        inputs.each do |item|
          case item[:type]
          when :a
            a << item
          when :b
            b << item
          when :c
            c << item
          else
            raise "Did not know how to handle #{item.inspect}"
          end
        end
      end
    end

    let(:base_inputs) do
      [
        { type: :a },
        { type: :b },
        { type: :c }
      ]
    end

    let(:expected) { inputs.map { |item| item.merge(processed: item[:type]) } }
    let(:expected_sorted) { expected.sort_by { |item| item[:type] } }

    it 'returns enumeratorish things' do
      final, a, b, c = subject
      expect(final).to be_an(Enumerator)
      expect(a).to be_an(Lazier::LazierEnum)
      expect(b).to be_an(Lazier::LazierEnum)
      expect(c).to be_an(Lazier::LazierEnum)
    end

    context 'processing a little data' do
      let(:inputs) { base_inputs }

      it 'processes data' do
        final, a, b, c = subject
        a.each_slice(1) { |items| items.each { |item| item[:processed] = :a } }
        b.each_slice(1) { |items| items.each { |item| item[:processed] = :b } }
        c.each_slice(1) { |items| items.each { |item| item[:processed] = :c } }
        expect(final.to_a).to eq(expected)
      end
    end


    context 'enough inputs to need batching' do
      let(:inputs) { base_inputs.cycle(5).to_a.shuffle }

      it 'processes data' do
        final, a, b, c = subject
        a.each_slice(3) { |items| items.each { |item| item[:processed] = :a } }
        b.each_slice(2) { |items| items.each { |item| item[:processed] = :b } }
        c.each_slice(1) { |items| items.each { |item| item[:processed] = :c } }
        final_sorted = final.to_a.sort_by { |item| item[:type] }
        expect(final_sorted).to eq(expected_sorted)
      end

      context 'using a different enumerable method' do
        it 'processes data' do
          final, a, b, c = subject
          a.each { |item| item[:processed] = :a }
          b.each { |item| item[:processed] = :b }
          c.each { |item| item[:processed] = :c }
          final_sorted = final.to_a.sort_by { |item| item[:type] }
          expect(final_sorted).to eq(expected_sorted)
        end
      end
    end
  end
end
