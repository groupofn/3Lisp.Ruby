# encoding: UTF-8

require '3LispError.rb'

class Rail
  include ThreeLispError

  attr_accessor :element, :remaining

  def initialize(*args)
    if args.size == 0 
      self.element = nil
      self.remaining = nil
    else
      self.element = args[0]
      self.remaining = Rail.new(*args[1..-1])
    end
  end
  
  def empty?
    element == nil
  end

  def to_s
    "[" + (empty? ? "" : (element.to_s + remaining.r_to_s)) + "]"
  end
protected  
  def r_to_s
    empty? ? "" : (" " + element.to_s + remaining.r_to_s)
  end
  
public
  def self.scons(args)
    args.map{|element|       
      element
    }
  end

  def self.rcons(args)
    args.map{|element| 
      raise "RCONS expects structure but was given #{element.to_s}" if !element.handle?     
      element.down
    }.up
  end

  def self.array2rail(arr)
    r = Rail.new
    t = r
    for i in 0..arr.length-1
      t.element = arr[i]
      t.remaining = Rail.new
      t = t.remaining
    end
    return r
  end

  def prep(e)
    r = Rail.new
    r.element = e
    r.remaining = self
    return r
  end

  def map(&block)
    if empty?
      Rail.new
    else
      e = block.call(element)
      remaining.map(&block).prep(e) 
    end
  end
  
  def each(&block)
    if !empty?
      block.call(element)
      remaining.each(&block)
    end
  end
  
  def zip(other_rail)
    if empty?
      Rail.new
    else
      e = Rail.new(element, other_rail.element)
      remaining.zip(other_rail.remaining).prep(e)
    end
  end
  
  def down
    map { |e| 
      raise_error(self, 
        "structure expected; #{self.to_s} given") if !e.handle?
      e.down
    } 
  end

  def length
    return 0 if empty?
    return remaining.length + 1
  end

  def nth(n)
    raise_error(self, "NTH: index is out of bound") if empty?
    
    if n == 1
      element
    elsif n > 1
      remaining.nth(n-1)
    else # n < 0
      raise_error(self, "NTH: index is out of bound")
    end
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
    if n == 0  
      return self
    elsif n > 0 
      raise_error(self, "TAIL: index is out of bound") if empty?
      return remaining.tail(n-1)
    else # n < 0
      raise_error(self, "TAIL: index is out of bound")
    end
  end
  
  def rest
    tail(1)
  end

  def rplacn(n, e)
    raise_error(self, "RPLACN: index is out of bound") if empty?

    if n == 1
      self.element = e
      return Handle.new(:OK)
    elsif n > 1
      remaining.rplacn(n-1, e)
    else  # n < 1
      raise_error(self, "RPLACN: index is out of bound")
    end
  end

  def rplact(n, t)
    raise_error(self, "RPLACT: index is out of bound") if n < 0 || n > length
    
    if n == 0
      self.element = t.element
      self.remaining = t.remaining
      return self
    else
      tail(n-1).remaining = t # returned
    end
  end

  def append!(e)
    t = tail(length)
    t.element = e
    t.remaining = Rail.new
    return self
  end
  
  def join(r)
    t = tail(length-1)
    t.remaining = r
    self
  end

  def push(e)
    r = remaining
    old_top = element
    self.element = e
    self.remaining = Rail.new
    self.remaining.element = old_top
    self.remaining.remaining = r
    return self
  end
  
  def pop
    raise_error(self, "POP: attempt to pop from empty rail") if empty?
    old_top = element
    self.element = remaining.element
    self.remaining = remaining.remaining
    return old_top
  end
end


