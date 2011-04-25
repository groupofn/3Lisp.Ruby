# encoding: UTF-8

class Handle  
  attr_accessor :quoted

  def initialize(struc)
    @quoted = struc
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
    quoted.car.up
  end
  
  def cdr
    quoted.cdr.up
  end

  def rplaca(new_car)
    (quoted.car = new_car.down).up
  end

  def rplacd(new_cdr)
    (quoted.cdr = new_cdr.down).up
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
    quoted.nth(n).up
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
    quoted.tail(n).up
  end

  def rest
    tail(1)
  end

  def prep(e)
    quoted.prep(e.down).up
  end  
 
  # side effect: should alter self instead of returning new struct
  def rplacn(n, e)
    quoted.rplacn(n, e.down).up
  end

  # side effect: should alter self instead of returning new struct
  def rplact(n, t)
    quoted.rplact(n, t.down).up
  end
# END Rail
  
# BEGIN Closure
  def rplacc(c)
    quoted.replace(c.quoted.type, c.quoted.environment, c.quoted.pattern, c.quoted.body).up 
  end
# END Closure

end

