# frozen_string_literal: true

class Lazier
  class Child < Lazier
    def initialize(parent, path) # rubocop:disable Lint/MissingSuper
      @parent = parent
      @path = path
      @children = {}
    end

    def my_path
      @parent.my_path + [@path]
    end

    def add(&)
      @parent.add(&)
    end
  end
end
