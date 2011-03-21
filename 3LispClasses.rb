# encoding: UTF-8

# error reporting
module ThreeLispError
  def raise_error(obj, msg)
    caller[0]=~/`(.*?)'/  # note the first quote is a backquote: ` not a normal '
#    raise "from " + obj.class.name + "." + $1 + ": " + msg
    raise msg
  end
end

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
    "\""+self+"\""
  end
end

class Object
  include ThreeLispError
  
  def up
    Handle.new(self)
  end

  def struc_type # somehow case-when doesn't work ...
    return :ATOM if self.class == Symbol
    return :NUMERAL if self.class == Fixnum || self.class == Bignum
    return :BOOLEAN if self.class == TrueClass || self.class == FalseClass
    return :CLOSURE if self.class == Closure
    return :HANDLE if self.class == Handle
    return :RAIL if self.class == Rail 
    return :PAIR if self.class == Pair
    return :ENVIRONMENT if self.class == Environment
    return :STRING if self.class == String
    
    p self.class
    raise_error(self, "#{self.inspect} is not a 3Lisp structure")
  end

  def atom?
    self.class == Symbol
  end

  def numeral?
    self.class == Fixnum || self.class == Bignum
  end
  
  def boolean?
    struc_type == :BOOLEAN
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
    self.class == Rail # || self.class == Array # TAI!
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
#    return :TEXT if string?
    return :FUNCTION if closure?
    return :SEQUENCE if rail?
    return :BINDINGS if environment?

    raise_error(self, "atom #{self.to_s} has no referential type") if atom?
    raise_error(self, "pair #{self.to_s} has no referential type") if pair?
    
    # must be a handle then    
    raise_error(self, "#{self.to_s} has no referential type") if !handle?    
    return quoted.struc_type # numeral, boolean, closure, atom, pair, handle, or rail
  end

  def atom_d? # atom designator?
    ref_type == :ATOM
  end

  def pair_d? # pair designator?
    ref_type == :PAIR
  end
 
  def sequence_d? # sequence designator?
    ref_type == :SEQUENCE
  end

  def rail_d? # rail designator?
    ref_type == :RAIL
  end

  def string_d? # string designator?
    ref_type == :TEXT
  end
 
  def handle_d? # handle designator?
    ref_type == :HANDLE
  end

  def closure_d? # closure designator?
    ref_type == :CLOSURE
  end

  def environment_d? # environment designator?
    ref_type == :ENVIRONMENT
  end

  def normal?
    t = ref_type
    return false if [:ATOM, :PAIR].include?(t)
  	if (t == :RAIL)
	    quoted.each {|item| return false unless item.up.normal? }
	    return true
	  end 
    return true # i.e. [:NUMERAL, :BOOLEAN, :HANDLE, :CLOSURE, :ENVIRONMENT].include?(ref_type)
  end
 
  def struc_normal?
    return false if atom?
    return true if [:NUMERAL, :BOOLEAN, :STRING, :CLOSURE, :ENVIRONMENT].include?(struc_type)
    return true if handle?

    if rail?
      each {|item| return false unless item.struc_normal? }
      return true
    end

    return false
  end
  
  # true just in case self and other refers to the same entity, 
  # ? modulo co-reference of different closures and different environments, where
  # structural identicality is also used.
  # Note that Ruby's equal? checks structural identity.
  def eq?(other)
    return false if ref_type != other.ref_type
    
    case struc_type
    when :NUMERAL, :BOOLEAN, :ENVIRONMENT then return equal?(other)  # external referent
    when :STRING then return equl?(other)
    when :CLOSURE 
#      if equal?(other) then return true
#      else
        raise_error(self, "equality undefined for closures #{self.to_s} and #{other.to_s}")
#      end
    when :HANDLE
      return quoted.eq?(other.quoted) if quoted.handle? # recursive call
      return quoted.equal?(other.quoted)
    when :RAIL
	  return false if other.struc_type != :RAIL
      return false if length != other.length
      zip(other).each{|s,o| return false if !s.equal?(o) }
      return true
    else
      raise_error(self, "equality undefined for #{self.to_s} and #{other.to_s}")
    end
  end  

  ## BEGIN constructors
  def pcons(h, t)
    raise "#{h.to_s} must be a handle" if !h.handle?
    raise "#{t.to_s} must be a handle" if !t.handle?

    Handle.new(Pair.new(h.down, t.down))
  end

  def scons(args)
    Rail.new(args) # should work, just copy the whole Ruby array
  end

  def rcons(args)
    args.map{|element| 
      raise "RCONS expects structure; #{element.to_s} is given instead" if !element.handle?
      
      element.down
    }.up
  end
  ## End constructors

  def isomorphic(other)
    return false if struc_type != other.struc_type
    return true if self.equal?(other)
    
    case struc_type
    when :PAIR
      return self.car.isomorphic(other.car) && self.cdr.isomorphic(other.cdr)
    when :RAIL
      return false if length != other.length
      self.zip(other).each {|s, o| return false if !s.isomorphic(o)}
      return true
    when :HANDLE
      return self.down.isomorphic(other.down)
    when :CLOSURE
      return self.type == other.type &&
             self.pattern.isomorphic(other.pattern) &&
             self.body.isomorphic(other.body) &&
             self.environment.similar(other.environment)
    end    
    return false
  end
  
end

# BEGIN Closure
class Closure  
  include ThreeLispError
  
  attr_reader :type, :environment, :pattern, :body

  def initialize(type, environment, pattern, body)
    @type, @environment, @pattern, @body = type, environment, pattern, body
  end
  
  def simple?
    @type == :SIMPLE.up 
  end
  
  def reflective?
    @type == :REFLECT.up
  end
  
  def de_reflect
    Closure.new(:SIMPLE.up, @environment, @pattern, @body)
  end
  
  def similar?(template)
    return true if self.equal?(template)
    return @pattern.isomorphic(template.pattern) &&
           @body.isomorphic(template.body) &&
           reflective? == template.reflective? && 
           @environment.similar(template.environment)
  end
  
  def to_s
    "{Closure: " + type.to_s + " " + environment.to_s + " " + pattern.to_s + " " + body.to_s + "}"
  end
end
# END Closure

#### Pair implementation
class Pair
  include ThreeLispError
  
  attr_accessor :car, :cdr

  def initialize(car, cdr)
    @car, @cdr = car, cdr
  end

  def to_s
    case @car
    when :UP then "↑" + (@cdr.rail? ? @cdr.to_s[1..-2] : @cdr.to_s)   # strip brackets when  
    when :DOWN then "↓" + (@cdr.rail? ? @cdr.to_s[1..-2] : @cdr.to_s) # cdr is rail
    else
      "(" + car.to_s + 
        (@cdr.rail? ? (@cdr.empty? ? "" : " " + @cdr.to_s[1..-2]) : " . " + @cdr.to_s) +
      ")"
    end
  end
end

#### Handle implementation
class Handle
  include ThreeLispError
  
  attr_accessor :quoted

  def initialize(struc)
    @quoted = struc
  end

  def to_s
    "'" + @quoted.to_s
  end

  # maybe both of the following should be defined in terms of eq?  
  def eql?(other) # used by hash
    other.is_a?(Handle) && @quoted == other.quoted
  end

  def ==(other) # used by Array.include?
    eql?(other)
  end
  
  def <=>(other) # used by Array.sort
    @quoted <=> other.quoted
  end

  def hash # used by hash
    @quoted.hash
  end

  def down
    @quoted
  end

  def car
    raise_error(self, "#{self} must refer to a pair") if !@quoted.pair?
    @quoted.car.up
  end
  
  def cdr
    raise_error(self, "#{self} must refer to a pair") if !@quoted.pair?
    @quoted.cdr.up
  end

  def rplaca(new_car)
    raise_error(self, "#{self} must refer to a pair") if !@quoted.pair?
    @quoted.car = new_car.down
    @quoted.car.up
  end

  def rplacd(new_cdr)
    raise_error(self, "#{self} must refer to a pair") if !@quoted.pair?
    @quoted.cdr = new_cdr.down
    @quoted.cdr.up
  end
  
  def length
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail?
    quoted.length
  end
  
  def empty?
    length == 0
  end

  def nth(n)
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail?
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
  
  def tail(n)
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail?
    quoted.tail(n).up
  end

  def rest
    tail(1)
  end

  def prep(e)
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail? 
    raise_error(self, "#{e} must be a handle") if !e.handle?
    quoted.prep(e.down).up
  end  
 
  # side effect: should alter self instead of returning new struct
  def rplacn(n, e)
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail?
    raise_error(self, "#{e} must be a handle") if !e.handle?
    quoted.rplacn(n, e.down).up
  end

  # side effect: should alter self instead of returning new struct
  def rplact(n, t)
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail?
    raise_error(self, "#{t} must be a handle") if !t.handle?
    quoted.rplact(n, t.down).up
  end  
end
#### END Handle

#### BEGIN Rail & Sequence implementation  
class Rail < Array
  include ThreeLispError

  def map(*args)
    Rail.new(super(*args))
  end
  
  def to_s
    return "[]" if empty?

    # "join" can't handle recursion appropriately
    inject("[") do |str, element|
        str + element.to_s + " "
    end.chop << "]"
  end
  
  def down
    map { |element| 
      raise_error(self, 
        "#{self.inspect} must be sequence of S-expression") if !element.handle?
      element.down 
    } 
  end

  # length and empty? are inherited from Array
  # cannot rely on Ruby for checking bounds
  # because a[a.length] => nil, which is an object in Rub!
  def nth(n)
    raise_error(self, "#{n} is out of bound") if n > length
    self[n-1]
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
  
  def tail(n)
    raise_error(self, "#{n} is out of bound") if n > length
    self[n..-1]
  end
  
  def rest
    tail(1)
  end

  def prep(e)
    Rail.new([e] + self)
  end  
 
  def rplacn(n, e)
    self[n-1] = e
  end

  def rplact(n, t)
    slice!(n..-1)
    concat(t)
    tail(n) # returned
  end
end
#### END Rail
### END 2-Lisp categories

# BEGIN Environment
class Environment
  include ThreeLispError
  
  # @local is a hash; @tail is an environment
  attr_reader :local, :tail

  def initialize(local, tail)
    @local, @tail = local, tail
  end
  
;  def to_s
;    "#<#{self.class.to_s}:#{object_id}>"  
;  end

  def empty?
    (local.nil? || local.empty?) && (tail.nil? || tail.empty?)
  end

  def bound_atoms
    return scons if empty?
    return scons(@local.keys) if tail.nil? || tail.empty?
    return scons(@local.keys) + @tail.bound_atoms
  end
  
  def var_is_bound?(var)
    raise_error(self, "atom expected; #{var.inspect} found") unless var.atom_d?

    return true if !(@local[var].nil?)
    return tail.var_is_bound?(var) unless tail.nil? || tail.empty?
    return false
  end

  def binding(var)
    raise_error(self, "atom expected; #{var.inspect} found") unless var.atom_d?

    result = @local[var] # var refers to an ATOM
    return result unless result.nil?
    return tail.binding(var) unless tail.nil? || tail.empty?
#pp
#sleep(1)
    raise_error(self, "#{var.to_s} is not bound")
  end
  
  # note that this side-effects the environment 
  def bind_one_local(var, arg)
    raise_error(self, "atom expected; #{var.inspect} found") unless var.atom_d?
    @local[var] = arg
  end

  # note that this side-effects the environment 
  def bind_one(var, arg)
    raise_error(self, "atom expected; #{var.inspect} found") unless var.atom_d?
    @local[var] = arg if !bind_one_helper(var, arg)
  end

  protected
  def bind_one_helper(var, arg)
    if @local.key?(var)
	  @local[var] = arg
	  return true
	elsif @tail.nil? || @tail.empty?
	  return false
	else
	  @tail.bind_one_helper(var, arg)
	end
  end

  public
  # note that this returns an extended environment 
  def bind_pattern(pattern, args)
    new_bindings = bind_pattern_helper({}, pattern, args)
    raise_error(self, "#{pattern} and #{args} must match") if new_bindings.nil?
	
    Environment.new(new_bindings, self)	
  end

  protected
  # generate new bindings from nested pattern and args
  # see diss.p.411 & diss.p.559
  def bind_pattern_helper(newbindings, pattern, args)
    if pattern.atom_d?
      newbindings[pattern] = args
    else
      pattern = pattern.down.map{|element| element.up} if pattern.rail_d?
      if args.handle?
        if args.rail_d?
          args = args.down.map{|element| element.up} if args.rail_d?
        elsif args.down.rail_d?
          args = args.down.down.map{|element| element.up.up} if args.down.rail_d?
        end
      end

      if !pattern.sequence_d? || !args.sequence_d? || pattern.length != args.length
        return nil
      end
      
      pattern.zip(args).each{|pat, arg| bind_pattern_helper(newbindings, pat, arg) }  
    end 

    newbindings
  end

  public
  # pretty print 
  # down to "levels" below the current level, which is the 0th
  def pp(levels = 0)
    pp_helper(0, levels)
  end

  protected
  # pretty print 
  # down to "levels" below the current level, which is the 0th
  def pp_helper(current, remaining)
    puts "\nEnvironment at level " + current.to_s + ":\n"
    leading_space = "  " * current
    @local.each_pair {|var, binding| puts leading_space + "#{var.to_s} => #{binding.to_s} \n" }

    @tail.pp_helper(current + 1, remaining - 1) if !@tail.empty? && remaining > 0

    puts "~~BOTTOM~~\n\n" if @tail.nil?
  end
  
  public
  def similar(template)  # see page 277 of Implementation paper
    return true if self.equal?(template)
    self_keys = @local.keys
    template_keys = template.local.keys

    return false if self_keys.length != template_keys.length
    self_keys.sort.zip(template_keys.sort).each { |key_pair|
	  return false if !(key_pair[0] == key_pair[1])
      if !(template.local[key_pair[1]].to_s == "''?")
        return false if !(@local[key_pair[0]] == template.local[key_pair[1]])
      end
    }
	return true if @tail.empty? && template.tail.empty?
	@tail.similar(template.tail)
  end
end
# END Environment

# BEGIN primitive procedures
#def primitive_closure?(closure) # this is a hack!
#  PRIMITIVE_PROC_NAMES.include?(closure.body)
#end

def ruby_lambda_for_primitive(closure)
  PRIMITIVES.assoc(closure.body.down)[3]
end

PRIMITIVES = [
  [:EXIT, :SIMPLE, Rail.new([]), lambda {|args| Process.exit }],
  [:ERROR, :SIMPLE, Rail.new([:struc]), lambda{|args|
    raise_error(self, "3-Lisp run-time error: " + args[0].to_s + "\n") }],
  [:READ, :SIMPLE, :args, lambda{|args|
    raise_error(self, "READ expects a handle but was given #{args[0].to_s}") if !args[0].handle?
    code = nil
    while code.nil?
      print args[0].down.to_s + " " if !args.empty?   # args[0].handle?
      code = $parser.parse($reader.read)[0]
    end
    code.up }],
  [:PRINT, :SIMPLE, Rail.new([:struc]), lambda{|args|
    raise_error(self, "PRINT expects a handle but was given #{args[0].to_s}") if !args[0].handle?    
    print args[0].down.to_s + " " }],
  [:TERPRI, :SIMPLE, Rail.new([]), lambda{|args| print "\n" }],
  
  [:TYPE, :SIMPLE, Rail.new([:struc]), lambda{|args| args[0].ref_type.up }],
  [:UP, :SIMPLE, :args, lambda{|args| args[0].up }],
  [:DOWN, :SIMPLE, :args, lambda{|args|
    raise_error(self, "DOWN expects a handle but was given #{args[0].to_s}") if !args[0].handle?
    result = args[0].down
    raise_error(self, "DOWN expects a normal form designator but was given #{args[0].to_s}") if !result.normal? 
    return result }],
  [:"=", :SIMPLE, Rail.new([:struc1, :struc2]), lambda{|args| args[0].eq?(args[1]) }],

  [:SCONS, :SIMPLE, :args, lambda{|args| scons(args) }], 
  [:RCONS, :SIMPLE, :args, lambda{|args| rcons(args) }], 
  [:LENGTH, :SIMPLE, Rail.new([:vec]), lambda{|args|
    raise_error(self, "LENGTH expects a rail or rail designator but was given #{args[0].to_s}") if !args[0].rail? && !args[0].rail_d?
    args[0].length }],
  [:NTH, :SIMPLE, Rail.new([:n, :vec]), lambda{|args|
    raise_error(self, "NTH expects a rail or rail designator but was given #{args[1].to_s}") if !args[1].rail? && !args[1].rail_d?
    raise_error(self, "NTH expects a numeral but was given #{args[0].to_s}") if !args[0].numeral?
    args[1].nth(args[0]) }],
  [:TAIL, :SIMPLE, Rail.new([:n, :vec]), lambda{|args| 
    raise_error(self, "TAIL expects a rail or rail designator but was given #{args[1].to_s}") if !args[1].rail? && !args[1].rail_d?
    raise_error(self, "TAIL expects a numeral but was given #{args[0].to_s}") if !args[0].numeral?
    args[1].tail(args[0]) }],
  [:PREP, :SIMPLE, Rail.new([:struc, :vec]), lambda{|args| 
    raise_error(self, "PREP expects a rail or rail designator but was given #{args[1].to_s}") if !args[1].rail? && !args[1].rail_d?
    args[1].prep(args[0]) }], 
    
    # 3-Lisp Manual has "REPLACE"!
  [:RPLACN, :SIMPLE, Rail.new([:n, :vec, :struc]), lambda{|args| 
    raise_error(self, "RPLACN expects rail or rail designator but was given #{args[1].to_s}") if !args[1].rail? && !args[1].rail_d?
    raise_error(self, "RPLACN expects rail or rail designator but was given #{args[2].to_s}") if !args[2].rail? && !args[2].rail_d?
    raise_error(self, "RPLACN expects a numeral but was given #{args[0].to_s}") if !args[0].numeral?
    args[1].rplacn(args[0], args[2]) }],
  [:RPLACT, :SIMPLE, Rail.new([:n, :vec, :tail]), lambda{|args| 
    raise_error(self, "RPLACT expects rail or rail designator but was given #{args[1].to_s}") if !args[1].rail? && !args[1].rail_d?
    raise_error(self, "RPLACN expects rail or rail designator but was given #{args[2].to_s}") if !args[2].rail? && !args[2].rail_d?
    raise_error(self, "RPLACT expects a numeral but was given #{args[0].to_s}") if !args[0].numeral?
    args[1].rplact(args[0], args[2]) }],

  [:PCONS, :SIMPLE, Rail.new([:car, :cdr]), lambda{|args| pcons(args[0], args[1]) }],
    
  [:CAR, :SIMPLE, Rail.new([:pair]), lambda{|args| 
    raise_error(self, "CAR expects a pair designator but was given #{args[0].to_s}") if !args[0].pair_d?
    args[0].car }],
  [:CDR, :SIMPLE, Rail.new([:pair]), lambda{|args| 
    raise_error(self, "CDR expects a pair designator but was given #{args[0].to_s}") if !args[0].pair_d?
    args[0].cdr }], 
  [:RPLACA, :SIMPLE, Rail.new([:pair, :new_car]), lambda{|args| 
    raise_error(self, "RPLACA expects a pair designator but was given #{args[0].to_s}") if !args[0].pair_d?
    raise_error(self, "RPLACA expects a handle but was given #{args[1].to_s}") if !args[1].pair_d?
    args[0].rplaca(args[1]) }],
  [:RPLACD, :SIMPLE, Rail.new([:pair, :new_cdr]), lambda{|args| 
    raise_error(self, "RPLACD expects a pair designator but was given #{args[0].to_s}") if !args[0].pair_d?
    raise_error(self, "RPLACD expects a handle but was given #{args[1].to_s}") if !args[1].pair_d?
    args[0].rplacd(args[1]) }],

  [:">", :SIMPLE, Rail.new([:"n1", :"n2"]), lambda{|args| 
    raise_error(self, "> expects numerals but was given #{args[0].inspect} and #{args[1].to_s}") if !args[0].numeral? || !args[1].numeral?
    args[0] > args[1] }], 
  [:"<", :SIMPLE, Rail.new([:"n1", :"n2"]), lambda{|args|
    raise_error(self, "< expects numerals but was given #{args[0].inspect} and #{args[1].to_s}") if !args[0].numeral? || !args[1].numeral?
    args[0] < args[1] }], 
  [:"+", :SIMPLE, Rail.new([:"n1", :"n2"]), lambda{|args|
    raise_error(self, "+ expects numerals but was given #{args[0].inspect} and #{args[1].to_s}") if !args[0].numeral? || !args[1].numeral?
    args[0] + args[1] }], 
  [:"-", :SIMPLE, Rail.new([:"n1", :"n2"]), lambda{|args|
    raise_error(self, "- expects numerals but was given #{args[0].inspect} and #{args[1].to_s}") if !args[0].numeral? || !args[1].numeral?
    args[0] - args[1] }], 
  [:"*", :SIMPLE, Rail.new([:"n1", :"n2"]), lambda{|args|
    raise_error(self, "* expects numerals but was given #{args[0].inspect} and #{args[1].to_s}") if !args[0].numeral? || !args[1].numeral?
    args[0] * args[1] }], 
  [:"/", :SIMPLE, Rail.new([:"n1", :"n2"]), lambda{|args|
    raise_error(self, "/ expects numerals but was given #{args[0].inspect} and #{args[1].to_s}") if !args[0].numeral? || !args[1].numeral?
    args[0] / args[1] }],
  
  [:EF, :SIMPLE, Rail.new([:premise, :"clause1", :"clause2"]), lambda{|args|
    raise_error(self, "EF expects a boolean but was given #{args[0].to_s}") if !args[0].boolean?
    args[0] ? args[1] : args[2] }], 

  [:CCONS, :SIMPLE, Rail.new([:type, :env, :pattern, :body]).up, lambda{|args| 
    raise_error(self, "CCONS expects a procedure type designator but was given #{args[0].to_s}") if (args[0] != :SIMPLE.up) && (args[0] != :REFLECT.up)
    raise_error(self, "CCONS expects an environment but was given #{args[1].to_s}") if !args[1].environment?
#    raise_error(self, "CCONS expects a pattern designator but was given #{args[2].to_s}") if !args[2].rail_d?
    raise_error(self, "CCONS expects expression designator but was given #{args[3].to_s}") if !args[3].handle?
    Closure.new(args[0], args[1], args[2], args[3]).up }],
  [:BODY, :SIMPLE, Rail.new([:closure]), lambda{|args| args[0].down.body }],
  [:ENVIRONMENT, :SIMPLE, Rail.new([:closure]), lambda{|args| args[0].down.environment }],
  [:PATTERN, :SIMPLE, Rail.new([:closure]), lambda{|args| args[0].down.pattern  }],
  [:"PROCEDURE-TYPE", :SIMPLE, Rail.new([:closure]), lambda{|args| args[0].down.type }],
  
  [:ECONS, :SIMPLE, Rail.new([:env]), lambda{|args| 
    args.empty? ? Environment.new({}, {}) : Environment.new({}, args[0]) }],
  # handles expected for the follwing three, thus no ".up"
  [:BINDING, :SIMPLE, Rail.new([:var, :env]), lambda{|args| 
    raise_error(self, "BINDING expects an atom designator but was given #{args[0].to_s}") if !args[0].atom_d?
    raise_error(self, "BINDING expects an environment but was given #{args[1].to_s}") if !args[1].environment?
    args[1].binding(args[0]) }],
  [:BIND, :SIMPLE, Rail.new([:pat, :bindings, :env]), lambda{|args|
#    raise_error(self, "BIND expects an pattern designator but was given #{args[0].to_s}") if !args[0].rail_d?
    raise_error(self, "BIND expects bindings to be in normal form but was given #{args[1].to_s}") if !args[1].normal?
    raise_error(self, "BIND expects an environment but was given #{args[2].to_s}") if !args[2].environment?
    args[2].bind_pattern(args[0], args[1]) }],
  [:REBIND, :SIMPLE, Rail.new([:var, :binding, :env]), lambda{|args|
    raise_error(self, "REBIND expects an atom designator but was given #{args[0].to_s}") if !args[0].atom_d?
    raise_error(self, "REBIND expects bindings to be in normal form but was given #{args[1].to_s}") if !args[1].normal?
    raise_error(self, "REBIND expects an environment but was given #{args[2].to_s}") if !args[2].environment?
    args[2].bind_one(args[0], args[1]) }],
  [:BOUND, :SIMPLE, Rail.new([:var, :env]), lambda{|args|
    raise_error(self, "BOUND expects an atom designator but was given #{args[0].to_s}") if !args[0].atom_d?
    raise_error(self, "BOUND expects an environment but was given #{args[1].to_s}") if !args[1].environment?
    args[1].var_is_bound?(args[0]) }],
  [:"BOUND-ATOMS", :SIMPLE, Rail.new([:env]), lambda{|args|
    raise_error(self, "BOUND expects an environment but was given #{args[0].to_s}") if !args[0].environment?
    args[0].bound_atoms }], # returns a sequence of atom designators
  [:"SIMILAR-ENVIRONMENT", :SIMPLE, Rail.new([:env1, :env2]), lambda{|args|
      args[0].similar(args[1]) }] # this one no longer needs to be a primitive!
]

PRIMITIVE_PROC_NAMES = PRIMITIVES.map { |primitive| primitive[0].up }
# END primitive procedures
