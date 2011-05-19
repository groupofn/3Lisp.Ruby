# encoding: UTF-8

require './3LispError.rb'

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
    "\"" << self << "\""
  end
end

class Object
  include ThreeLispError
  
  def up
    Handle.new(self)
  end

  def struc_type # case-when doesn't work because === does not work over instances of the class Class
    return :ATOM if instance_of?(Symbol)
    return :NUMERAL if instance_of?(Fixnum) || instance_of?(Bignum)
    return :BOOLEAN if instance_of?(TrueClass) || instance_of?(FalseClass)
    return :CLOSURE if instance_of?(Closure)
    return :HANDLE if instance_of?(Handle)
    return :RAIL if instance_of?(Rail) 
    return :PAIR if instance_of?(Pair)
    return :ENVIRONMENT if instance_of?(Environment)
    return :STRING if instance_of?(String)
    
    raise_error(self, "#{self.inspect} is not a 3Lisp structure")
  end

  def atom?
    instance_of?(Symbol)
  end

  def numeral?
    instance_of?(Fixnum) || instance_of?(Bignum)
  end
  
  def boolean?
    instance_of?(TrueClass) || instance_of?(FalseClass)
  end
  
  def closure?
    instance_of?(Closure)
  end
  
  def string?
    instance_of?(String)
  end
  
  def handle?
    instance_of?(Handle)
  end

  def rail?
    instance_of?(Rail)
  end

  def pair?
    instance_of?(Pair)
  end
  
  def environment?
    instance_of?(Environment)
  end

  # type of the entity designated
  def ref_type
    # numeral, boolean, closure, atom, pair, handle, string, environment, or rail
    return quoted.struc_type if handle?    
    return :NUMBER if instance_of?(Fixnum) || instance_of?(Bignum)
    return :"TRUTH-VALUE" if instance_of?(TrueClass) || instance_of?(FalseClass)
    return :FUNCTION if instance_of?(Closure)
    return :SEQUENCE if instance_of?(Rail)
    return :BINDINGS if instance_of?(Environment)

    raise_error(self, "atom #{self.to_s} has no referential type") if atom?
    raise_error(self, "pair #{self.to_s} has no referential type") if pair?
    raise_error(self, "ref_type : #{self.to_s} is ill-structured") 
  end

  def atom_d? # atom designator?
    instance_of?(Handle) && quoted.instance_of?(Symbol)
  end

  def string_d? # string designator?
    instance_of?(Handle) && quoted.instance_of?(String)
  end
  
  def pair_d? # pair designator?
    instance_of?(Handle) && quoted.instance_of?(Pair)
  end
 
  def sequence_d? # sequence designator?
    instance_of?(Rail)
  end

  def rail_d? # rail designator?
    instance_of?(Handle) && quoted.instance_of?(Rail)
  end

  def handle_d? # handle designator?
    instance_of?(Handle) && quoted.instance_of?(Handle)
  end

  def closure_d? # closure designator?
    instance_of?(Handle) && quoted.instance_of?(Closure)
  end

  def environment_d? # environment designator?
    instance_of?(Handle) && quoted.instance_of?(Environment)
  end

  def normal?
    raise_error(self, "normal? : 3Lisp structure expected but #{self.to_s} was given") if !handle?

    return false if atom_d? || pair_d?
  	return quoted.all_normal? if rail_d?
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
    when :HANDLE
      return quoted.eq?(other.quoted) if quoted.handle? # recursive call
      return quoted.list.equal?(other.quoted.list) if quoted.rail?
      return quoted.equal?(other.quoted)
    when :RAIL # Rail overrides eq?
      return self == other
    when :CLOSURE
      return true if equal?(other)
      raise_error(self, "= not generally defined over functions")    
    when :ENVIRONMENT
      return true if equal?(other)
      raise_error(self, "= not generally defined over bindings")    
    else
      raise_error(self, "equality undefined for #{self.to_s} and #{other.to_s}")
    end
  end  
end
