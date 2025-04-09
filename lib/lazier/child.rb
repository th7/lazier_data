class Lazier
  class Child < Lazier
    def initialize(parent, path)
      @parent = parent
      @path = path
      @children = {}
    end

    def my_path
      @parent.my_path + [@path]
    end

    def add(&block)
      @parent.add(&block)
    end
  end
end
