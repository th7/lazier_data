# frozen_string_literal: true

require_relative 'lazier/version'
require 'lazier/enum'
require 'lazier/yielder'
require 'lazier/map_yielder'

module Lazier
  class Error < StandardError; end

  class << self
    def multi_each(count, &block)
      laziers = count.times.map { Lazier::Enum.new }
      final = Enumerator.new do |final|
        normies = nest_normal_enums(count, final, &block)
        normies.zip(laziers) do |normie, lazier|
          lazier.call_other(normie)
        end
      end
      [final, *laziers]
    end

    def multi_map(count, &block)
      laziers = count.times.map { Lazier::MapEnum.new }
      final = Enumerator.new do |final|
        normies = nest_normal_enums_map(count, final, &block)
        normies.zip(laziers) do |normie, lazier|
          normie.each_slice(lazier.batch_size) do |items|
            lazier.block.call(items).each { |item| final << item }
          end
        end
      end
      [final, *laziers]
    end

    private

    def nest_normal_enums(count, final_yielder, this_count=1, previous_yielders=[], normies_yielder=nil, &block)
      if normies_yielder.nil?
        Enumerator.new do |y|
          nest_normal_enums(count, final_yielder, this_count, previous_yielders, y, &block)
        end
      else
        if count != this_count
          normies_yielder << Enumerator.new do |y|
            lazier_yielder = Lazier::Yielder.new(y, final_yielder)
            nest_normal_enums(count, final_yielder, this_count + 1, previous_yielders << lazier_yielder, normies_yielder, &block)
          end
        else
          normies_yielder << Enumerator.new do |y|
            lazier_yielder = Lazier::Yielder.new(y, final_yielder)
            block.call(*previous_yielders, lazier_yielder)
          end
        end
      end
    end

    def nest_normal_enums_map(count, final_yielder, this_count=1, previous_yielders=[], normies_yielder=nil, &block)
      if normies_yielder.nil?
        Enumerator.new do |y|
          nest_normal_enums_map(count, final_yielder, this_count, previous_yielders, y, &block)
        end
      else
        if count != this_count
          normies_yielder << Enumerator.new do |y|
            lazier_yielder = Lazier::MapYielder.new(y, final_yielder)
            nest_normal_enums_map(count, final_yielder, this_count + 1, previous_yielders << lazier_yielder, normies_yielder, &block)
          end
        else
          normies_yielder << Enumerator.new do |y|
            lazier_yielder = Lazier::MapYielder.new(y, final_yielder)
            block.call(*previous_yielders, lazier_yielder)
          end
        end
      end
    end
  end
end
