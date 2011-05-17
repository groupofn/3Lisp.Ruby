# encoding: UTF-8

# This version allows shared tail, but forbids mutation of tail.

require './3LispError.rb'
require './3LispPair.rb'
require './3LispHandle.rb'

class Rail
  include ThreeLispError

  attr_accessor :list, :length, :last

  def initialize(*args)
    self.list = Pair.new(nil, nil)
    self.length = args.size
    current = list
    i = 0
    while i < length
      current.car = args[i]
      current.cdr = Pair.new(nil, nil)
      current = current.cdr
      i += 1
    end
    self.last = current
  end
  
  def empty?
    length == 0
  end

  def eq?(other)
    return false if other.struc_type != :RAIL
    return false if length != other.length
    
    s = list; o = other.list
    i = 0
    while i < length
      return false if !s.car.eq?(o.car);
      s = s.cdr; o = o.cdr
      i += 1 
    end
    return true
  end

  def to_s
    s = "["
    current = list
    i = 0
    while i < length
      s << current.car.to_s << " "
      current = current.cdr
      i += 1
    end
    s.chop! if (length > 0) 
    s << "]"
  end
  
  def self.scons(args)
    args.map{|element|       
      element
    }
  end

  def self.rcons(args)
    Handle.new(args.map{|element| 
      raise_error(self, "RCONS expects structure but was given #{element.to_s}") if !element.handle?     
      element.quoted
    })
  end

  def prep(e)
    new_rail = Rail.new
    new_rail.list = Pair.new(e, list)
    new_rail.length = length + 1
    new_rail.last = last
    return new_rail
  end

  def map(&block)
    new_rail = Rail.new

    current = list
    nr_current = new_rail.list
    i = 0
    while i < length do
      nr_current.car = block.call(current.car)
      nr_current.cdr = Pair.new(nil, nil) 
      current = current.cdr
      nr_current = nr_current.cdr
      i += 1
    end
    new_rail.last = nr_current
    new_rail.length = length
    new_rail
  end
  
  def each(&block)
    current = list
    i = 0 
    while i < length do
      block.call(current.car)
      current = current.cdr
      i += 1
    end
  end

  def down
    map { |e| 
      raise_error(self, 
        "structure expected; #{self.to_s} given") if !e.handle?
      e.quoted
    } 
  end
  
  def all_up
    new_rail = Rail.new

    current = list
    nr_current = new_rail.list
    i = 0
    while i < length
      nr_current.car = Handle.new(current.car)
      nr_current.cdr = Pair.new(nil, nil) 
      current = current.cdr
      nr_current = nr_current.cdr
      i += 1
    end
    new_rail.last = nr_current
    new_rail.length = length
    new_rail
  end
  
  def all_up_up
    new_rail = Rail.new

    current = list
    nr_current = new_rail.list
    i = 0
    while i < length 
      nr_current.car = Handle.new(Handle.new(current.car))
      nr_current.cdr = Pair.new(nil, nil) 
      current = current.cdr
      nr_current = nr_current.cdr
      i += 1
    end
    new_rail.last = nr_current
    new_rail.length = length
    new_rail
  end
  
  def all_normal?
    current = list
    i = 0
    while i < length
      return false unless Handle.new(current.car).normal?
      current = current.cdr
      i += 1
    end
    
    return true
  end

  def nth(n)
    raise_error(self, "NTH: index is out of bound") if n > length || n < 1
    
    current = list
    i = 1
    while i < n
      current = current.cdr
      i += 1
    end
    current.car
  end
 
  def first
    nth(1)
  end
  
  def second
    nth(2)
  end
  
  def third
    nth(3)
  end
  
  def fourth
    nth(4)
  end
  
  def tail(n)
    if n > 0 && n <= length 
      new_rail = Rail.new
      current = list
      i = 0
      while i < n do
        current = current.cdr
        i += 1
      end
      new_rail.list = current
      new_rail.length = length - n
      new_rail.last = last
      return new_rail
    elsif n == 0  
      return self
    else
      raise_error(self, "TAIL: index is out of bound")
    end
  end
  
  def rest
    tail(1)
  end

  def rplacn(n, e)
    raise_error(self, "RPLACN: index is out of bound") if n < 1 || n > length

    current = list
    i = 1
    while i < n
      current = current.cdr
      i += 1
    end
    current.car = e
    
    return Handle.new(:OK)
  end

=begin # rplact is banded after all!
  def rplact(n, t)
    raise_error(self, "RPLACT: index is out of bound") if n < 0 || n > length
    
    current = list
    i = 0
    while i < n 
      current = current.cdr
      i += 1
    end
    current.car = t.list.car
    current.cdr = t.list.cdr
    self.last = t.last
    self.length = n + t.length
    
    return Handle.new(:OK)
  end
=end

  def append!(e)
    last.car = e
    last.cdr = Pair.new(nil, nil)
    self.last = last.cdr
    self.length += 1
    return self
  end
  
  def join!(r)
    raise_error(self, "Rail.join!: joining is permitted only on a terminating rail") if !last.car.nil?
    last.car = r.list.car
    last.cdr = r.list.cdr
    self.last = r.last
    self.length += r.length  
    self
  end

  def push(e)
    self.list = Pair.new(e, list)
    self.length += 1
    return self
  end
  
  def pop
    raise_error(self, "POP: attempt to pop from empty rail") if empty?
    old_top = list.car
    self.list = list.cdr
    self.length -= 1
    return old_top
  end
end


