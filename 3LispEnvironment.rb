# encoding: UTF-8

####################################
#                                  #
#   Ruby Implementation of 3Lisp   #
#                                  #
#          Version 1.00            #
#                                  #
#           2011-05-20             #
#           Group of N             #
#                                  #
####################################

require './3LispError.rb'
require './3LispRubyBasics.rb'

class Environment
  include ThreeLispError
  
  # @local is a hash; @tail is either an environment or an empty hash
  attr_accessor :local, :tail

  def initialize(local = {}, tail = {})
    self.local, self.tail = local, tail
  end
  
  def to_s
    "#<#{self.class.to_s}:#{object_id}>"  
  end

  def empty?
    local.empty? && tail.empty?
  end

  def bound_atoms
    return Rail.new if empty?
    return Rail.new(*local.keys.map(&:up)) if tail.empty?
    return Rail.new(*local.keys.map(&:up)).join!(tail.bound_atoms)
  end
  
  def var_is_bound?(var)
    return true if !(local[var].nil?)
    return tail.var_is_bound?(var) unless tail.empty?
    return false
  end

  def binding(var)
    result = local[var]
    return result if !result.nil?
    raise_error(self, "#{var.to_s} is not bound") if tail.empty?
    return tail.binding(var)
  end
  
  def rebind_one(var, arg)
    local[var] = arg if !rebind_one_helper(var, arg)
    arg
  end
protected
  def rebind_one_helper(var, arg)
    if local.key?(var)
  	  local[var] = arg
	    return true
	  elsif tail.empty?
	    return false
	  else
	    tail.rebind_one_helper(var, arg)
	  end
  end

public
  def bind_pattern(pattern, args)
    if pattern.atom_d?
      raise_error(self, "Pattern Matching: structure expected for the argument") if !args.handle?
      Environment.new({pattern.quoted => args.quoted}, self)	
    else
      new_bindings = bind_pattern_helper({}, pattern, args, 0, 0)
      Environment.new(new_bindings, self)
    end
  end
protected
  # generate new bindings from nested pattern and args
  # see diss.p.411 & diss.p.559
  def bind_pattern_helper(newbindings, pattern, args, p_quote_level, a_quote_level)
    if pattern.rail_d?
      p_quote_level += 1
      pattern = pattern.quoted
    end
  
    if args.rail_d?
      a_quote_level += 1
      args = args.quoted
    elsif args.handle? && args.quoted.rail_d?
      a_quote_level += 2
      args = args.quoted.quoted
    end
  
    raise_error(self, "Pattern Matching: pattern ill-formed") if !pattern.rail? 
    raise_error(self, "Pattern Matching: arguments ill-formed") if !args.rail?

    al = args.length; pl = pattern.length
    raise_error(self, "Pattern Matching: too many arguments") if al > pl
    raise_error(self, "Pattern Matching: too few arguments") if al < pl

    # accessing innards of Rail directly; this breaches modularity for performance
    pc = pattern.list
    ac = args.list
    i = 0
    while i < al do
      p_e = pc.car; a_e = ac.car
      if p_e.atom?
        raise_error(self, "Pattern Matching: atom is expected") if p_quote_level != 1
        k = 1 # strip one level
        while k < a_quote_level
          a_e = Handle.new(a_e)
          k += 1
        end
        newbindings[p_e] = a_e
      else
        bind_pattern_helper(newbindings, p_e, a_e, p_quote_level, a_quote_level)
      end

      pc = pc.cdr; ac = ac.cdr
      i += 1
    end

    newbindings
  end

public
  # pretty print 
  # down to "levels" below, or all levels if no depth is specified
  def pp(*args)
    if args.size == 0
      pp_helper(1, 0, true)
      puts "~~ BOTTOM ~~\n\n"
    else
      pp_helper(1, args[0], false)
    end
  end
protected
  # pretty print 
  # down to "levels" below the current level, which is the 0th
  def pp_helper(current, remaining, all_levels)
    puts "\nEnvironment at level " << current.to_s << ":\n"
    leading_space = "  " * current
    local.each_pair {|var, binding| puts leading_space << "#{var.to_s} => #{binding.to_s} \n" }

    if !tail.empty? && (all_levels || remaining > 0)
      tail.pp_helper(current + 1, remaining - 1, all_levels) 
    elsif !all_levels
      puts "~~ Stopped at level #{current} ~~\n\n"
    end
  end
end
