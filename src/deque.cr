# A Deque ("[double-ended queue](https://en.wikipedia.org/wiki/Double-ended_queue)") is a collection of objects of type
# T that behaves much like an Array.
#
# Deque has a subset of Array's API. It performs better than an Array when there are frequent insertions or deletions
# of items near the beginning or the end.
#
# The most typical use case of a Deque is a queue: use `push` to add items to the end of the queue and `shift` to get
# and remove the item at the beginning of the queue.
#
# This Deque is implemented with a [dynamic array](http://en.wikipedia.org/wiki/Dynamic_array) used as a
# [circular buffer](https://en.wikipedia.org/wiki/Circular_buffer).
class Deque(T)
  include Enumerable(T)
  include Iterable
  include Comparable(Deque)

  # This Deque is based on a circular buffer. It works like a normal array, but when an item is removed from the left
  # side, instead of shifting all the items, only the start position is shifted. This can lead to configurations like:
  # [234---01] @start = 6, length = 5, @capacity = 8
  # (this Deque has 5 items, each equal to their index)

  MINIMAL_CAPACITY = 4

  @start = 0

  # Creates a new empty Deque backed by a buffer that is initially `initial_capacity` big.
  #
  # The `initial_capacity` is useful to avoid unnecesary reallocations of the internal buffer in case of growth. If you
  # have an estimate of the maxinum number of elements a deque will hold, you should initialize it with that capacity
  # for improved execution performance.
  #
  # ```
  # deq = Deque(Int32).new(5)
  # deq.length #=> 0
  # ```
  def initialize(initial_capacity = MINIMAL_CAPACITY : Int)
    if initial_capacity < 0
      raise ArgumentError.new("negative deque capacity: #{initial_capacity}")
    end
    @length = 0
    @capacity = Math.max(initial_capacity.to_i, MINIMAL_CAPACITY)
    @buffer = Pointer(T).malloc(@capacity)
  end

  # Creates a new Deque of the given size filled with the same value in each position.
  #
  # ```
  # Deque.new(3, 'a') #=> Deque{'a', 'a', 'a'}
  # ```
  def initialize(size : Int, value : T)
    if size < 0
      raise ArgumentError.new("negative deque size: #{size}")
    end
    @length = size.to_i
    if @length < MINIMAL_CAPACITY
      @capacity = MINIMAL_CAPACITY
      @buffer = Pointer(T).malloc(@capacity)

      (0...@length).each do |i|
        @buffer[i] = value
      end
    else
      @capacity = @length
      @buffer = Pointer(T).malloc(@capacity, value)
    end
  end

  # Creates a new Deque of the given size and invokes the block once for each index of the deque, assigning the block's
  # value in that index.
  #
  # ```
  # Deque.new(3) { |i| (i + 1) ** 2 } #=> Deque{1, 4, 9}
  # ```
  def initialize(size : Int, &block : Int32 -> T)
    if size < 0
      raise ArgumentError.new("negative deque size: #{size}")
    end
    @length = size.to_i
    @capacity = Math.max(@length, MINIMAL_CAPACITY)
    @buffer = Pointer(T).malloc(@capacity)

    (0...@length).each do |i|
      @buffer[i] = yield i
    end
  end

  # Creates a new Deque that copies its items from an Array.
  #
  # ```
  # Deque.new([1, 2, 3]) #=> Deque{1, 2, 3}
  # ```
  def self.new(array : Array(T))
    Deque(T).new(array.length) { |i| array[i] }
  end

  # Equality. Returns true if it is passed a Deque and `equals?` returns true for both deques, the caller and the
  # argument.
  #
  # ```
  # deq = Deque{2, 3}
  # deq.unshift 1
  # deq == Deque{1, 2, 3} # => true
  # deq == Deque{2, 3}    # => false
  # ```
  def ==(other : Deque)
    equals?(other) { |x, y| x == y }
  end

  # :nodoc:
  def ==(other)
    false
  end

  # Concatenation. Returns a new Deque built by concatenating two deques together to create a third. The type of the new
  # deque is the union of the types of both the other deques.
  def +(other : Deque(U))
    Deque(T | U).new.concat(self).concat(other)
  end

  # :nodoc:
  def +(other : Deque(T))
    dup.concat other
  end

  # Alias for `push`.
  def <<(value : T)
    push(value)
  end

  # Returns the element at the given `index`.
  #
  # Negative indices can be used to start counting from the end of the deque.
  # Raises `IndexError` if trying to access an element outside the deque's range.
  def [](index : Int)
    at(index)
  end

  # Returns the element at the given index.
  #
  # Negative indices can be used to start counting from the end of the deque.
  # Returns `nil` if trying to access an element outside the deque's range.
  def []?(index : Int)
    at(index) { nil }
  end

  # Sets the given value at the given index.
  #
  # Raises `IndexError` if the deque had no previous value at the given index.
  def []=(index : Int, value : T)
    index += @length if index < 0
    unless 0 <= index < @length
      raise IndexError.new
    end
    index += @start
    index -= @capacity if index >= @capacity
    @buffer[index] = value
  end

  # Returns the element at the given index, if in bounds, otherwise raises `IndexError`.
  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  # Returns the element at the given index, if in bounds, otherwise executes the given block and returns its value.
  def at(index : Int)
    index += @length if index < 0
    unless 0 <= index < @length
      yield
    else
      index += @start
      index -= @capacity if index >= @capacity
      @buffer[index]
    end
  end

  # Removes all elements from self.
  def clear
    halfs do |r|
      (@buffer + r.begin).clear(r.end - r.begin)
    end
    @length = 0
    @start = 0
    self
  end

  # Returns a new Deque that has this deque's elements cloned.
  # That is, it returns a deep copy of this deque.
  #
  # Use `#dup` if you want a shallow copy.
  def clone
    Deque(T).new(length) { |i| self[i].clone as T }
  end

  # Appends the elements of *other* to `self`, and returns `self`.
  def concat(other : Enumerable(T))
    other.each do |x|
      push x
    end
    self
  end

  # Same as `length`.
  def count
    @length
  end

  # Delete the item that is present at the `index`. Items to the right of this one will have their indices decremented.
  # Raises `IndexError` if trying to delete an element outside the deque's range.
  #
  # ```
  # a = Deque{1, 2, 3}
  # a.delete_at(1) # => Deque{1, 3}
  # ```
  def delete_at(index : Int)
    if index < 0
      index += @length
    end
    unless 0 <= index < @length
      raise IndexError.new
    end
    return shift if index == 0
    return pop if index == @length - 1

    rindex = @start + index
    rindex -= @capacity if rindex >= @capacity
    value = @buffer[rindex]

    if index > @length / 2
      # Move following items to the left, starting with the first one
      # [56-01234] -> [6x-01235]
      dst = rindex
      finish = (@start + @length - 1) % @capacity
      loop do
        src = dst + 1
        src -= @capacity if src >= @capacity
        @buffer[dst] = @buffer[src]
        break if src == finish
        dst = src
      end
      (@buffer + finish).clear
    else
      # Move preceding items to the right, starting with the last one
      # [012345--] -> [x01345--]
      dst = rindex
      finish = @start
      @start += 1
      @start -= @capacity if @start >= @capacity
      loop do
        src = dst - 1
        src += @capacity if src < 0
        @buffer[dst] = @buffer[src]
        break if src == finish
        dst = src
      end
      (@buffer + finish).clear
    end

    @length -= 1
    value
  end

  # Returns a new Deque that has exactly this deque's elements.
  # That is, it returns a shallow copy of this deque.
  def dup
    Deque(T).new(length) { |i| self[i] as T }
  end

  # Yields each item in this deque, from first to last.
  #
  # Do not modify the deque while using this variant of `each`!
  def each
    halfs do |r|
      r.each do |i|
        yield @buffer[i]
      end
    end
  end

  # Gives an iterator over each item in this deque, from first to last.
  def each
    ItemIterator.new(self)
  end

  # Yields indices of each item in this deque, from first (`0`) to last (`length - 1`).
  def each_index
    (0...@length).each do |i|
      yield i
    end
    self
  end

  # Gives an iterator over the indices of each item in this deque, from first (`0`) to last (`length - 1`).
  def each_index
    IndexIterator.new(self)
  end

  # Returns true if this deque has 0 items.
  def empty?
    @length == 0
  end

  # Zips two deques and gives each pair to the passed block. Returns `true` if the block returns `true` every time.
  def equals?(other : Deque)
    return false if @length != other.length
    each_with_index do |x, i|
      return false unless yield(x, other[i])
    end
    true
  end

  # Returns the leftmost item in the deque (index `0`). Raises `IndexError` if empty.
  def first
    first { raise IndexError.new }
  end

  # Returns the leftmost item in the deque (index `0`), if not empty, otherwise executes the given block and returns its
  # value.
  def first
    @length == 0 ? yield : @buffer[@start]
  end

  # Returns the leftmost item in the deque (index `0`), if not empty, otherwise `nil`.
  def first?
    first { nil }
  end

  def hash
    inject(31 * @length) do |memo, elem|
      31 * memo + elem.hash
    end
  end

  # Insert a new item before the item at `index`. Items to the right of this one will have their indices incremented.
  #
  # ```
  # a = Deque{0, 1, 2}
  # a.insert_at(1, 7) # => Deque{0, 7, 1, 2}
  # ```
  def insert(index : Int, value : T)
    if index < 0
      index += @length + 1
    end
    unless 0 <= index <= @length
      raise IndexError.new
    end
    return unshift(value) if index == 0
    return push(value) if index == @length

    increase_capacity if @length >= @capacity
    rindex = @start + index
    rindex -= @capacity if rindex >= @capacity

    if index > @length / 2
      # Move following items to the right, starting with the last one
      # [56-01234] -> [4560123^]
      dst = @start + @length
      dst -= @capacity if dst >= @capacity
      loop do
        src = dst - 1
        src += @capacity if src < 0
        @buffer[dst] = @buffer[src]
        break if src == rindex
        dst = src
      end
    else
      # Move preceding items to the left, starting with the first one
      # [01234---] -> [1^234--0]
      @start -= 1
      @start += @capacity if @start < 0
      rindex -= 1
      rindex += @capacity if rindex < 0
      dst = @start
      loop do
        src = dst + 1
        src -= @capacity if src >= @capacity
        @buffer[dst] = @buffer[src]
        break if src == rindex
        dst = src
      end
    end

    @length += 1
    @buffer[rindex] = value
    self
  end

  def inspect(io : IO)
    executed = exec_recursive(:inspect) do
      io << "Deque{"
      join ", ", io, &.inspect(io)
      io << "}"
    end
    io << "Deque{...}" unless executed
  end

  # Returns the rightmost item in the deque (index `length - 1`). Raises `IndexError` if empty.
  def last
    last { raise IndexError.new }
  end

  # Returns the rightmost item in the deque (index `length - 1`), if not empty, otherwise executes the given block and
  # returns its value.
  def last
    @length == 0 ? yield : self[@length - 1]
  end

  # Returns the rightmost item in the deque (index `length - 1`), if not empty, otherwise `nil`.
  def last?
    last { nil }
  end

  # Returns the number of elements in the deque.
  #
  # ```
  # Deque{:foo, :bar}.length #=> 2
  # ```
  def length
    @length
  end

  # Removes and returns the last item. Raises `IndexError` if empty.
  #
  # ```
  # a = Deque{1, 2, 3}
  # a.pop # => 3
  # # a == Deque{1, 2}
  # ```
  def pop
    pop { raise IndexError.new }
  end

  # Removes and returns the last item, if not empty, otherwise executes the given block and returns its value.
  def pop
    if @length == 0
      yield
    else
      @length -= 1
      index = @start + @length
      index -= @capacity if index >= @capacity
      value = @buffer[index]
      (@buffer + index).clear
      value
    end
  end

  # Removes and returns the last item, if not empty, otherwise `nil`.
  def pop?
    pop { nil }
  end

  # Removes the last `n` (at most) items in the deque.
  def pop(n : Int)
    if n < 0
      raise ArgumentError.new("can't pop negative count")
    end
    n = Math.min(n, @length)
    n.times { pop }
    nil
  end

  # Adds an item to the end of the deque.
  #
  # ```
  # a = Deque{1, 2}
  # a.push 3 # => Deque{1, 2, 3}
  # ```
  def push(value : T)
    increase_capacity if @length >= @capacity
    index = @start + @length
    index -= @capacity if index >= @capacity
    @buffer[index] = value
    @length += 1
    self
  end

  # Yields each item in this deque, from last to first.
  #
  # Do not modify the deque while using `reverse_each`!
  def reverse_each
    (length - 1).downto(0) do |i|
      yield self[i]
    end
    self
  end

  # Rotates this deque in place so that the element at `n` becomes first.
  #
  # For positive `n`, equivalent to `n.times { push(shift) }`.
  # For negative `n`, equivalent to `(-n).times { unshift(pop) }`.
  def rotate!(n = 1 : Int)
    if @length == @capacity
      @start = (@start + n) % @capacity
    else
      # Turn `n` into an equivalent index in range -length/2 .. length/2
      half = @length / 2
      if n.abs >= half
        n = (n + half) % @length - half
      end
      while n > 0
        push(shift)
        n -= 1
      end
      while n < 0
        n += 1
        unshift(pop)
      end
    end
  end

  # Removes and returns the first item. Raises `IndexError` if empty.
  #
  # ```
  # a = Deque{1, 2, 3}
  # a.shift # => 1
  # # a == Deque{2, 3}
  # ```
  def shift
    shift { raise IndexError.new }
  end

  # Removes and returns the first item, if not empty, otherwise executes the given block and returns its value.
  def shift
    if @length == 0
      yield
    else
      value = @buffer[@start]
      (@buffer + @start).clear
      @length -= 1
      @start += 1
      @start -= @capacity if @start >= @capacity
      value
    end
  end

  # Removes and returns the first item, if not empty, otherwise `nil`.
  def shift?
    shift { nil }
  end

  # Removes the first `n` (at most) items in the deque.
  def shift(n : Int)
    if n < 0
      raise ArgumentError.new("can't shift negative count")
    end
    n = Math.min(n, @length)
    n.times { shift }
    nil
  end

  # Same as `length`.
  def size
    @length
  end

  # Swaps the items at the indices `i` and `j`.
  def swap(i, j)
    self[i], self[j] = self[j], self[i]
    self
  end

  # Returns an Array (shallow copy) that contains all the items of this deque.
  def to_a
    arr = Array(T).new(@length)
    each do |x|
      arr << x
    end
    arr
  end

  def to_s(io : IO)
    inspect(io)
  end

  # Adds an item to the beginning of the deque.
  #
  # ```
  # a = Deque{1, 2}
  # a.unshift 0 # => Deque{0, 1, 2}
  # ```
  def unshift(value : T)
    increase_capacity if @length >= @capacity
    @start -= 1
    @start += @capacity if @start < 0
    @buffer[@start] = value
    @length += 1
    self
  end

  private def halfs
    # For [----] yields nothing
    # For contiguous [-012] yields 1...4
    # For separated [234---01] yields 6...8, 0...3

    return if empty?
    a = @start
    b = @start + length
    b -= @capacity if b > @capacity
    if a < b
      yield a...b
    else
      yield a...@capacity
      yield 0...b
    end
  end

  private def increase_capacity
    old_capacity = @capacity
    @capacity *= 2
    @buffer = @buffer.realloc(@capacity)

    finish = @start + @length
    if finish > old_capacity
      # If the deque is separated into two parts, we get something like [2301----] after resize, so additional action is
      # needed, to turn it into [23----01] or [--0123--].
      # To do the moving we can use `copy_from` because the old and new locations will never overlap (assuming we're
      # multiplying the capacity by 2 or more). Due to the same assumption, we can clear all of the old locations.
      finish -= old_capacity
      if old_capacity - @start >= @start
        # [3012----] -> [-0123---]
        (@buffer + old_capacity).copy_from(@buffer, finish)
        @buffer.clear(finish)
      else
        # [1230----] -> [123----0]
        to_move = old_capacity - @start
        new_start = @capacity - to_move
        (@buffer + new_start).copy_from(@buffer + @start, to_move)
        (@buffer + @start).clear(to_move)
        @start = new_start
      end
    end
  end

  # :nodoc:
  class ItemIterator(T)
    include Iterator(T)

    def initialize(@deque : Deque(T), @index = 0)
    end

    def next
      value = @deque.at(@index) { stop }
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end

  # :nodoc:
  class IndexIterator(T)
    include Iterator(Int32)

    def initialize(@deque : Deque(T), @index = 0)
    end

    def next
      return stop if @index >= @deque.length

      value = @index
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end

end
