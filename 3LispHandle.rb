# encoding: UTF-8

class Handle  
  attr_accessor :quoted

  def initialize(struc)
    self.quoted = struc
  end

  def to_s    
     "'" + quoted.to_s
  end

  def eql?(other) # used by hash
    other.is_a?(Handle) && @quoted == other.quoted
  end

  def ==(other) # used by Array.include?
    eql?(other)
  end
  
  def <=>(other) # used by Array.sort
    quoted <=> other.quoted
  end

  def hash # used by hash
    quoted.hash
  end

  def down
    quoted
  end

# BEGIN Pair
  def car
    Handle.new(quoted.car)
  end
  
  def cdr
    Handle.new(quoted.cdr)
  end

  def rplaca(new_car)
    Handle.new(quoted.rplaca(new_car.quoted))
  end

  def rplacd(new_cdr)
    Handle.new(quoted.rplacd(new_cdr.quoted))
  end
# END Pair

# BEGIN Rail  
  def length
    quoted.length
  end
  
  def empty?
    quoted.empty?
  end

  def nth(n)
    Handle.new(quoted.nth(n))
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
    Handle.new(quoted.tail(n))
  end

  def rest
    tail(1)
  end

  def prep(e)
    Handle.new(quoted.prep(e.quoted))
  end  
 
  # side effect: should alter self instead of returning new struct
  def rplacn(n, e)
    quoted.rplacn(n, e.quoted)
    Handle.new(:OK)
  end

  def join!(other)
    quoted.join!(other.quoted)
    self
  end
  
# banned now
#  # side effect: should alter self instead of returning new struct
#  def rplact(n, t)
#    Handle.new(quoted.rplact(n, t.quoted))
#  end

# END Rail
  
# BEGIN Closure
  def rplacc(c)
    Handle.new(quoted.replace(c.quoted)) 
  end
# END Closure

end

