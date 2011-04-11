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
    handle? && quoted.atom?
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
    ref_type == :HANDLE
  end

  def closure_d? # closure designator?
    ref_type == :CLOSURE
  end

  def environment_d? # environment designator?
    ref_type == :ENVIRONMENT
  end

  def normal?
    return false if struc_type == :STRING
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
    when :CLOSURE then return equal?(other)
    when :HANDLE
      return quoted.eq?(other.quoted) if quoted.handle? # recursive call
      return quoted.equal?(other.quoted)
    when :RAIL
	    return false if other.struc_type != :RAIL
      return false if length != other.length
      zip(other).each{|dbl| return false if !dbl.first.eq?(dbl.second) }
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
    raise "SCONS expects a sequence; #{args.to_s} is given instead" if !args.sequence_d?
    args.map{|element|       
      element
    }
  end

  def rcons(args)
    args.map{|element| 
      raise "RCONS expects structure but was given #{element.to_s}" if !element.handle?
      
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
      self.zip(other).each {|dbl| return false if !dbl.first.isomorphic(dbl.second)}
      return true
    when :HANDLE
      return self.down.isomorphic(other.down)
    when :CLOSURE
      return self.type == other.type &&
             self.pattern.isomorphic(other.pattern) &&
             self.body.isomorphic(other.body) &&
             self.environment.similar?(other.environment)
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
  
  def replace(type, environment, pattern, body)
    @type, @environment, @pattern, @body = type, environment, pattern, body
  end
 
  def type_d
    @type.up
  end

  def environment_d
    @environment.up
  end
  
  def pattern_d
    @pattern.up
  end
  
  def body_d
    @body.up
  end
           
  def simple?
    @type == :SIMPLE 
  end
  
  def reflective?
    @type == :REFLECT
  end
  
  def de_reflect
    Closure.new(:SIMPLE, @environment, @pattern, @body)
  end
  
  def similar?(template)
    return true if self.equal?(template)
    return pattern.isomorphic(template.pattern) &&
           body.isomorphic(template.body) &&
           type == template.type && 
           environment.similar?(template.environment)
  end
  
  def to_s
    "{Closure: " + @type.to_s + " " + @environment.to_s + " " + @pattern.to_s + " " + @body.to_s + "}"
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
#    p self.object_id
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
    raise_error(self, "#{self} must refer to a rail") if !@quoted.rail?
    quoted.empty?
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

  def fourth
    nth(4)
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
  
  def rplacc(c)
    quoted.replace(c.quoted.type, c.quoted.environment, c.quoted.pattern, c.quoted.body).up 
  end
end
#### END Handle

#### BEGIN Rail & Sequence implementation  
class Rail
  include ThreeLispError

  attr_accessor :element, :remaining

  def initialize(*args)
    if args.size == 0 
      @element = nil
      @remaining = nil
    else
      @element = args[0]
      @remaining = Rail.new(*args[1..-1])
    end
  end
  
  def empty?
    element == nil # && @rest == nil
  end

  def length
    return 0 if element.nil?
    return remaining.length + 1
  end

  def to_s
    "[" + element.to_s + (element.nil? ? "" : remaining.r_to_s) + "]"
  end
  
  def r_to_s
    element.nil? ? "" : " " + element.to_s + remaining.r_to_s
  end

  def self.array2rail(arr)
    r = Rail.new
    t = r
    for i in 0..arr.length
      t.element = arr[i]
      t.remaining = Rail.new
      t = t.remaining
    end
    return r
  end

  def prep(e)
    r = Rail.new(e)
    r.remaining = self
    return r
  end

  def map(&block)
    if element.nil?
      Rail.new
    else
      e = block.call(element)
      remaining.map(&block).prep(e) 
    end
  end
  
  def each(&block)
    if !element.nil?
      block.call(@element)
      remaining.each(&block)
    end
  end
  
  def zip(other_rail)
    if element.nil?
      Rail.new
    else
      e = Rail.new(self.element, other_rail.element)
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

  def nth(n)
    if n < 1 then raise_error(self, "NTH: index is out of bound")
    elsif n == 1
      raise_error(self, "NTH: index is out of bound") if element.nil?
      return element
    else # n > 1
      raise_error(self, "NTH: index is out of bound") if element.nil?
      return remaining.nth(n-1)
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
    if n < 0 then raise_error(self, "TAIL: index is out of bound")
    elsif n == 0 then 
      return self
    else # n > 0 
      raise_error(self, "TAIL: index is out of bound") if element == nil
      return remaining.tail(n-1)
    end
  end
  
  def rest
    tail(1)
  end

  def rplacn(n, e)
    if n < 1 then raise_error(self, "RPLACN: index is out of bound")
    elsif n == 1
       self.element = e
       return Handle.new(:OK)
    else # n > 1
      raise_error(self, "RPLACN: index is out of bound") if element.nil?
      return remaining.rplacn(n-1, e)
    end
  end

  def rplact(n, t)
    if n < 0 || n > length
      raise_error(self, "RPLACT: index is out of bound")
    elsif n == 0
      @element = t.element
      @remaining = t.remaining
      return self
    else
      tail(n-1).remaining = t # returned
    end
  end

  def push(e)
    r = remaining
    old_top = element
    @element = e
    @remaining = Rail.new
    @remaining.element = old_top
    @remaining.remaining = r 
  end
  
  def pop
    raise_error(self, "POP: attempt to pop from empty rail") if empty?
    old_top = element
    @element = remaining.element
    @remaining = remaining.remaining
    return old_top
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
  
  def to_s
    "#<#{self.class.to_s}:#{object_id}>"  
  end

  def empty?
    (local.nil? || local.empty?) && (tail.nil? || tail.empty?)
  end

  def bound_atoms
    return Rail.new if empty?
    return Rail.array2rail(@local.keys) if tail.nil? || tail.empty?
    return Rail.array2rail(@local.keys).join(@tail.bound_atoms)
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
    arg
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

      raise_error(self, "sequence is expected for arguments but was given #{args.to_s}") if !args.sequence_d?
      raise_error(self, "sequence is expected as argument pattern but was given #{pattern.to_s}") if !pattern.sequence_d?
      raise_error(self, "too many arguments") if args.length > pattern.length
      raise_error(self, "too few arguments") if args.length < pattern.length

      pattern.zip(args).each{|dbl| bind_pattern_helper(newbindings, dbl.first, dbl.second) }  
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
  def similar?(template)  # see page 277 of Implementation paper
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
	@tail.similar?(template.tail)
  end
end
# END Environment

# BEGIN primitive procedures
#def primitive_closure?(closure) # this is a hack!
#  PRIMITIVE_PROC_NAMES.include?(closure.body)
#end

def ruby_lambda_for_primitive(closure)
  PRIMITIVES.assoc(closure.body)[3]
end

PRIMITIVES = [
  [:EXIT, :SIMPLE, Rail.new, lambda {|args| Process.exit }],
  [:ERROR, :SIMPLE, Rail.new(:struc), lambda{|args|
    raise_error(self, "3-Lisp run-time error: " + args.first.to_s + "\n") }],
  [:READ, :SIMPLE, :args, lambda{|args|
    raise_error(self, "READ expects a structure but was given #{args.first.to_s}") if !args.first.handle?
    code = nil
    while code.nil?
      print args.first.down.to_s + " " if !args.empty?   # args.first.handle?
      parsed = $parser.parse($reader.read)
      next if parsed.empty?
      code = parsed.first
    end
    code.up }],
  [:PRINT, :SIMPLE, Rail.new(:struc), lambda{|args|
    if args.first.string?
      print args.first
    else
      raise_error(self, "PRINT expects a structure but was given #{args.first.to_s}") if !args.first.handle?    
      print args.first.down.to_s + " "
    end
    Handle.new(:OK)}],
  [:TERPRI, :SIMPLE, Rail.new, lambda{|args| print "\n"; Handle.new(:OK) }],
  [:INTERNALISE, :SIMPLE, Rail.new(:string), lambda{|args|
    parsed = $parser.parse(args.first)
    raise_error(self, "Failed to internalise string: #{args.first}") if parsed.empty?
    struc = parsed.first.up
  }],
  [:EXTERNALISE, :SIMPLE, Rail.new(:struc), lambda{|args|
    raise_error(self, "Externalise expects a handle but was given #{args.first.to_s}") if !args.first.handle?    
    args.first.down.to_s  
  }],
  
  [:TYPE, :SIMPLE, Rail.new(:struc), lambda{|args| args.first.ref_type.up }],
  [:UP, :SIMPLE, Rail.new(:struc), lambda{|args| args.first.up }],
  [:DOWN, :SIMPLE, Rail.new(:struc), lambda{|args|
    raise_error(self, "DOWN expects a structure but was given #{args.first.to_s}") if !args.first.handle?
    result = args.first.down
    return result }],
  [:REPLACE, :SIMPLE, Rail.new(:struc1, :struc2), lambda{|args|
    s1_rt = args.first.ref_type; s2_rt = args.second.ref_type
    raise_error(self, "REPLACE expects structures of the same type") if s1_rt != s2_rt
    raise_error(self, "REPLACE expects rail, pair, or closure but was given #{s1_rt}") if ![:RAIL, :PAIR, :CLOSURE].include?(s1_rt)
    case s1_rt
    when :RAIL
      args.first.rplact(0, args.second.tail(0))
    when :PAIR
      args.first.rplaca(args.second.car)
      args.first.rplacd(args.second.cdr)
    when :CLOSURE
      args.first.rplacc(args.second)
    end
    return Handle.new(:OK) }],
  [:"=", :SIMPLE, :args, lambda{|args|
    raise_error(self, "= expects at least 2 arguments") if args.length < 2
    
    first = args.first; rest = args.rest;
    while !rest.empty?
      second = rest.first
      if first.eq?(second)
        first = second
        rest = rest.rest
      else
        raise_error(self, "= not generally defined over functions") if first.closure? && second.closure?
        return false
      end
    end  
    return true }],

  [:ISOMORPHIC, :SIMPLE, Rail.new(:e1, :e2), lambda{|args|
    raise_error(self, "ISOMORPHIC expects 2 arguments") if args.length != 2
    args.first.isomorphic(args.second) }],

  [:ACONS, :SIMPLE, :args, lambda{|args|
    begin
      s = "3LispAtom" + Time.now.to_f.to_s + rand(0x3fffffff).to_s 
    end while !$STRINGS_used_by_ACONS[s].nil?
    
    $STRINGS_used_by_ACONS[s] = s.to_sym.up # returned
  }],

  [:SCONS, :SIMPLE, :args, lambda{|args| scons(args) }], 
  [:RCONS, :SIMPLE, :args, lambda{|args| rcons(args) }], 
  [:EMPTY, :SIMPLE, Rail.new(:vec), lambda{|args|
    raise_error(self, "EMPTY expects a vector but was given #{args.first.to_s}") if !args.first.rail? && !args.first.rail_d?
    args.first.empty? }],
  [:LENGTH, :SIMPLE, Rail.new(:vec), lambda{|args|
    raise_error(self, "LENGTH expects a vector but was given #{args.first.to_s}") if !args.first.rail? && !args.first.rail_d?
    args.first.length }],
  [:NTH, :SIMPLE, Rail.new(:n, :vec), lambda{|args|
    raise_error(self, "NTH expects a vector but was given #{args.second.to_s}") if !args.second.rail? && !args.second.rail_d?
    raise_error(self, "NTH expects a number but was given #{args.first.to_s}") if !args.first.numeral?
    args.second.nth(args.first) }],
  [:TAIL, :SIMPLE, Rail.new(:n, :vec), lambda{|args| 
    raise_error(self, "TAIL expects a vector but was given #{args.second.to_s}") if !args.second.rail? && !args.second.rail_d?
    raise_error(self, "TAIL expects a number but was given #{args.first.to_s}") if !args.first.numeral?
    args.second.tail(args.first) }],
  [:PREP, :SIMPLE, Rail.new(:struc, :vec), lambda{|args| 
    raise_error(self, "PREP expects a vector but was given #{args.second.to_s}") if !args.second.rail? && !args.second.rail_d?
    raise_error(self, "PREP expects a structure but was given #{args.first.to_s}") if args.second.rail_d? && !args.first.handle?
    args.second.prep(args.first) }], 
    
    # 3-Lisp Manual has "REPLACE"!
  [:RPLACN, :SIMPLE, Rail.new(:n, :vec, :struc), lambda{|args| 
    raise_error(self, "RPLACN expects a vector but was given #{args.second.to_s}") if !args.second.rail? && !args.second.rail_d?
    raise_error(self, "RPLACN expects a structure but was given #{args.third.to_s}") if !args.third.handle?
    raise_error(self, "RPLACN expects a number but was given #{args.first.to_s}") if !args.first.numeral?
    args.second.rplacn(args.first, args.third) }],
  [:RPLACT, :SIMPLE, Rail.new(:n, :vec, :tail), lambda{|args| 
    raise_error(self, "RPLACT expects a vector but was given #{args.second.to_s}") if !args.second.rail? && !args.second.rail_d?
    raise_error(self, "RPLACN expects a vector but was given #{args.third.to_s}") if !args.third.rail? && !args.third.rail_d?
    raise_error(self, "RPLACT expects a number but was given #{args.first.to_s}") if !args.first.numeral?
    args.second.rplact(args.first, args.third) }],

  [:PCONS, :SIMPLE, Rail.new([:car, :cdr]), lambda{|args| 
    raise_error(self, "PCONS expects structure but was given #{args.first.to_s}") if !args.first.handle?
    raise_error(self, "PCONS expects structure but was given #{args.second.to_s}") if !args.second.handle?
    pcons(args.first, args.second) }],
  [:CAR, :SIMPLE, Rail.new(:pair), lambda{|args| 
    raise_error(self, "CAR expects a pair but was given #{args.first.to_s}") if !args.first.pair_d?
    args.first.car }],
  [:CDR, :SIMPLE, Rail.new(:pair), lambda{|args| 
    raise_error(self, "CDR expects a pair but was given #{args.first.to_s}") if !args.first.pair_d?
    args.first.cdr }], 
  [:RPLACA, :SIMPLE, Rail.new(:pair, :new_car), lambda{|args| 
    raise_error(self, "RPLACA expects a pair but was given #{args.first.to_s}") if !args.first.pair_d?
    raise_error(self, "RPLACA expects a structure but was given #{args.second.to_s}") if !args.second.handle?
    args.first.rplaca(args.second) }],
  [:RPLACD, :SIMPLE, Rail.new(:pair, :new_cdr), lambda{|args| 
    raise_error(self, "RPLACD expects a pair but was given #{args.first.to_s}") if !args.first.pair_d?
    raise_error(self, "RPLACD expects a structure but was given #{args.second.to_s}") if !args.second.handle?
    args.first.rplacd(args.second) }],

  [:">", :SIMPLE, :numbers, lambda{|args|
    raise_error(self, "> expects at least two numbers") if args.length < 2
    args.each {|e|
      raise_error(self, "> expects numbers but was given #{e.to_s}") if !e.numeral?
    }    
    previous = args.first
    args.rest.each {|current|
      return false if !(previous > current)
      previous = current
    }    
    true }],
  [:">=", :SIMPLE, :numbers, lambda{|args|
    raise_error(self, ">= expects at least two numbers") if args.length < 2
    args.each {|e|
      raise_error(self, "> expects numbers but was given #{e.to_s}") if !e.numeral?
    }    
    previous = args.first
    args.rest.each {|current|
      return false if !(previous >= current)
      previous = current
    }    
    true }],
  [:"<", :SIMPLE, :numbers, lambda{|args|
    raise_error(self, "< expects at least two numbers") if args.length < 2
    args.each {|e|
      raise_error(self, "> expects numbers but was given #{e.to_s}") if !e.numeral?
    }    
    previous = args.first
    args.rest.each {|current|
      return false if !(previous < current)
      previous = current
    }    
    true }],
  [:"<=", :SIMPLE, :numbers, lambda{|args|
    raise_error(self, "<= expects at least two numbers") if args.length < 2
    args.each {|e|
      raise_error(self, "> expects numbers but was given #{e.to_s}") if !e.numeral?
    }    
    previous = args.first
    args.rest.each {|current|
      return false if !(previous <= current)
      previous = current
    }    
    true }],
  [:"+", :SIMPLE, :numbers, lambda{|args|
    sum = 0;
    args.each {|n|  
      raise_error(self, "+ expects numbers but was given #{n.to_s}") if !n.numeral?
      sum += n
    }
    sum}], 
  [:"-", :SIMPLE, :numbers, lambda{|args|  # this implementation combines subtraction and minus (i.e. sign-flip)
    raise_error(self, "- expects at least one number") if args.empty?
    diff = args.first;
    raise_error(self, "- expects numbers but was given #{diff.to_s}") if !diff.numeral?
    return -diff if args.length == 1

    args.rest.each {|n|  
      raise_error(self, "- expects numbers but was given #{n.to_s}") if !n.numeral?
      diff -= n
    }
    diff}], 
  [:"*", :SIMPLE, :numbers, lambda{|args|
    product = 1;
    args.each {|n|  
      raise_error(self, "* expects numbers but was given #{n.to_s}") if !n.numeral?
      product *= n
    }
    product}], 
  [:"/", :SIMPLE, Rail.new(:"n1", :"n2"), lambda{|args|
    raise_error(self, "/ expects numbers but was given #{args.first.inspect} and #{args.second.to_s}") if !args.first.numeral? || !args.second.numeral?
    args.first / args.second }],
  
  [:EF, :SIMPLE, Rail.new(:premise, :"clause1", :"clause2"), lambda{|args|
    raise_error(self, "EF expects a truth value but was given #{args.first.to_s}") if !args.first.boolean?
    args.first ? args.second : args.third }], 

  [:CCONS, :SIMPLE, Rail.new(:type, :env, :pattern, :body), lambda{|args|
#    raise_error(self, "CCONS expects a procedure type but was given #{args.first.to_s}") if (args.first != :SIMPLE.up) && (args.first != :REFLECT.up)
#    raise_error(self, "CCONS expects an environment but was given #{args.second.to_s}") if !args.second.environment?
#    raise_error(self, "CCONS expects a pattern designator but was given #{args.third.to_s}") if !args.third.rail_d?
#    raise_error(self, "CCONS expects a structure but was given #{args.fourth.to_s}") if !args.fourth.handle?
    Closure.new(args.first.down, args.second.down, args.third.down, args.fourth.down).up }],
  [:BODY, :SIMPLE, Rail.new(:closure), lambda{|args| 
    raise_error(self, "BODY expects a closure.") if !args.first.closure_d?
    args.first.down.body.up }],
  [:"ENVIRONMENT-DESIGNATOR", :SIMPLE, Rail.new(:closure), lambda{|args| 
    raise_error(self, "ENVIRONMENT-DESIGNATOR expects a closure.") if !args.first.closure_d?
    args.first.down.environment.up }],
  [:PATTERN, :SIMPLE, Rail.new(:closure), lambda{|args| 
    raise_error(self, "PATTERN expects a closure.") if !args.first.closure_d?
    args.first.down.pattern.up  }],
  [:"PROCEDURE-TYPE", :SIMPLE, Rail.new(:closure), lambda{|args| 
    raise_error(self, "PROCEDURE-TYPE expects a closure.") if !args.first.closure_d?
    args.first.down.type.up }],
  
  [:ECONS, :SIMPLE, Rail.new(:env), lambda{|args| 
    args.empty? ? Environment.new({}, {}) : Environment.new({}, args.first) }],
  # handles expected for the follwing three, thus no ".up"
  [:BINDING, :SIMPLE, Rail.new(:var, :env), lambda{|args| 
    raise_error(self, "BINDING expects an atom but was given #{args.first.to_s}") if !args.first.atom_d?
    raise_error(self, "BINDING expects an environment but was given #{args.second.to_s}") if !args.second.environment?
    args.second.binding(args.first) }],
  [:BIND, :SIMPLE, Rail.new(:pat, :bindings, :env), lambda{|args|
#    raise_error(self, "BIND expects an pattern designator but was given #{args.first.to_s}") if !args.first.rail_d?
    raise_error(self, "BIND expects bindings to be in normal form but was given #{args.second.to_s}") if !args.second.normal?
    raise_error(self, "BIND expects an environment but was given #{args.third.to_s}") if !args.third.environment?
    args.third.bind_pattern(args.first, args.second) }],
  [:REBIND, :SIMPLE, Rail.new(:var, :binding, :env), lambda{|args|
    raise_error(self, "REBIND expects an atom but was given #{args.first.to_s}") if !args.first.atom_d?
    raise_error(self, "REBIND expects bindings to be in normal form but was given #{args.second.to_s}") if !args.second.normal?
    raise_error(self, "REBIND expects an environment but was given #{args.third.to_s}") if !args.third.environment?
    args.third.bind_one(args.first, args.second) }],
  [:BOUND, :SIMPLE, Rail.new(:var, :env), lambda{|args|
    raise_error(self, "BOUND expects an atom but was given #{args.first.to_s}") if !args.first.atom_d?
    raise_error(self, "BOUND expects an environment but was given #{args.second.to_s}") if !args.second.environment?
    args.second.var_is_bound?(args.first) }],
  [:"BOUND-ATOMS", :SIMPLE, Rail.new(:env), lambda{|args|
    raise_error(self, "BOUND expects an environment but was given #{args.first.to_s}") if !args.first.environment?
    args.first.bound_atoms }], # returns a sequence of atom designators
  [:"SIMILAR-ENVIRONMENT", :SIMPLE, Rail.new(:env1, :env2), lambda{|args|
      args.first.similar?(args.second) }] # this one no longer needs to be a primitive!
]

PRIMITIVE_PROC_NAMES = PRIMITIVES.map { |primitive| primitive[0].up }
# END primitive procedures
