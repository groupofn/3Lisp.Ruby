# encoding: UTF-8

require './3LispError.rb'

### TO DO 
# [ ] pretty print ... Does it belong here?

# Basic extension
class TrueClass
  def to_s
    "$T"
  end
end

class FalseClass
  def to_s
    "$F"
  end
end

class String
  def to_s
    "\"" + self + "\""
  end
end

class Object
  include ThreeLispError
  
  def up
    Handle.new(self)
  end

  def struc_type # case-when doesn't work because === does not work over instances of the class Class
    return :ATOM if self.class == Symbol
    return :NUMERAL if self.class == Fixnum || self.class == Bignum
    return :BOOLEAN if self.class == TrueClass || self.class == FalseClass
    return :CLOSURE if self.class == Closure
    return :HANDLE if self.class == Handle
    return :RAIL if self.class == Rail 
    return :PAIR if self.class == Pair
    return :ENVIRONMENT if self.class == Environment
    return :STRING if self.class == String
    
    p self.class; STDOUT.flush
    raise_error(self, "#{self.inspect} is not a 3Lisp structure")
  end

  def atom?
    self.class == Symbol
  end

  def numeral?
    self.class == Fixnum || self.class == Bignum
  end
  
  def boolean?
    self.class == TrueClass || self.class == FalseClass
  end
  
  def string?
    self.class == String
  end
  
  def closure?
    self.class == Closure
  end

  def handle?
    self.class == Handle
  end

  def rail?
    self.class == Rail
  end

  def pair?
    self.class == Pair
  end
  
  def environment?
    self.class == Environment
  end

  # type of the entity designated
  def ref_type
    return :NUMBER if numeral?
    return :"TRUTH-VALUE" if boolean?
    return :FUNCTION if closure?
    return :SEQUENCE if rail?
    return :BINDINGS if environment?

    raise_error(self, "atom #{self.to_s} has no referential type") if atom?
    raise_error(self, "pair #{self.to_s} has no referential type") if pair?
    
    # must be a handle then    
    raise_error(self, "#{self.to_s} has no referential type") if !handle?    
    return quoted.struc_type # numeral, boolean, closure, atom, pair, handle, string, environment, or rail
  end

  def atom_d? # atom designator?
    handle? && quoted.atom?
  end

  def string_d?
    handle? && quoted.string?
  end
  
  def pair_d? # pair designator?
    handle? && quoted.pair? # ref_type == :PAIR
  end
 
  def sequence_d? # sequence designator?
    rail? # ref_type == :SEQUENCE
  end

  def rail_d? # rail designator?
    handle? && quoted.rail?
  end

  def handle_d? # handle designator?
    handle? && quoted.handle?
  end

  def closure_d? # closure designator?
    handle? && quoted.closure?
  end

  def environment_d? # environment designator?
    handle? && quoted.environment?
  end

  def normal?
    raise_error(self, "#{self.to_s} is not a 3Lisp structure") if !handle?

    return false if atom_d? || pair_d?

  	if rail_d?
	    quoted.each {|item| return false unless item.up.normal? }
	    return true
	  end 

    return true # i.e. [:NUMERAL, :BOOLEAN, :HANDLE, :CLOSURE, :STRING :ENVIRONMENT].include?(ref_type)
  end
 
  
  # true just in case self and other refers to the same entity, 
  # modulo co-reference of different closures and different environments, where
  # structural identicality is also used.
  # Note that Ruby's equal? checks structural identity.
  def eq?(other)
    return false if ref_type != other.ref_type
    
    case struc_type
    # :STRING, like :ATOM & :PAIR, has no referential type and does not belong here
    when :NUMERAL, :BOOLEAN then return eql?(other)  # note that !1.eql?(1.0) whereas 1 == 1.0  
    when :ENVIRONMENT, :CLOSURE then return equal?(other)  # external referent
    when :HANDLE
      return quoted.eq?(other.quoted) if quoted.handle? # recursive call
      return quoted.equal?(other.quoted)
    when :RAIL
	    return false if other.struc_type != :RAIL
      return false if length != other.length
# BEGIN slower version -- using zip & each
#      zip(other).each{|dbl| return false if !dbl.first.eq?(dbl.second) }
# END slower version
# BEGIN faster version -- avoiding zip & each
      s = self; o = other
      while !o.empty?
        return false if !s.element.eq?(o.element);
        s = s.remaining; o = o.remaining 
      end
# END faster version
      return true
    else
      raise_error(self, "equality undefined for #{self.to_s} and #{other.to_s}")
    end
  end  
end
