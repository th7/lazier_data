require 'lazier/enumerator'

RSpec.describe Lazier::Enumerator do
  let(:yielded) { [] }
  let(:input) do
    Enumerator.new do |y|
      1.upto(10).each do |n|
        yielded << n
        y << n
      end
    end.to_a
  end

  subject do
    described_class.new do |y|
      input.each do |n|
        y << n
      end
    end
  end

  describe '#go' do
    let(:first) { [] }
    let(:second) { [] }
    let(:third) { [] }

    context 'triple each' do
      let(:expected) { input }

      before do
        subject.each { |n| first << n }
        subject.each { |n| second << n }
        subject.each { |n| third << n }
      end

      it 'iterates the source once and yields all items' do
        expect(yielded).to be_empty
        expect(first).to be_empty
        expect(second).to be_empty
        expect(third).to be_empty
        subject.go
        expect(yielded).to eq(input)
        expect(first).to eq(expected)
        expect(second).to eq(expected)
        expect(third).to eq(expected)
      end
    end

    context 'triple each_slice' do
      let(:all) { [] }

      before do
        subject.each_slice(2) { |ns| first << ns; all << { first: ns } }
        subject.each_slice(3) { |ns| second << ns; all << { second: ns } }
        subject.each_slice(4) { |ns| third << ns; all << { third: ns } }
      end

      it 'iterates the source once and yields the expected slices' do
        expect(yielded).to be_empty
        expect(first).to be_empty
        expect(second).to be_empty
        expect(third).to be_empty
        subject.go
        expect(yielded).to eq(input)
        expect(first).to eq(input.each_slice(2).to_a)
        expect(second).to eq(input.each_slice(3).to_a)
        expect(third).to eq(input.each_slice(4).to_a)
      end

      it 'ensures items are processed by earlier blocks before being yielded to later blocks' do
        expect(yielded).to be_empty
        expect(all).to be_empty
        subject.go
        expect(yielded).to eq(input)
        expect(all).to eq(
          [
            { first: [1, 2] },
            { first: [3, 4] },
            { second: [1, 2, 3] },
            { first: [5, 6] },
            { second: [4, 5, 6] },
            { third: [1, 2, 3, 4] },
            { first: [7, 8] },
            { first: [9, 10] },
            { second: [7, 8, 9] },
            { third: [5, 6, 7, 8] },
            { second: [10] },
            { third: [9, 10] }
          ]
        )
      end
    end
  end
end
