# encoding: UTF-8

require './3LispError.rb'

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

    if !result.nil?
      result
    elsif !tail.empty?
      tail.binding(var)
    else
      raise_error(self, "#{var.to_s} is not bound")
    end
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
    new_bindings = bind_pattern_helper({}, pattern, args, 0, 0)
    Environment.new(new_bindings, self)	
  end
protected
  # generate new bindings from nested pattern and args
  # see diss.p.411 & diss.p.559
  def bind_pattern_helper(newbindings, pattern, args, p_quote_level, a_quote_level)
=begin # cleaner but slower by 50% due to ups and downs
    if pattern.atom_d?
      newbindings[pattern.quoted] = args.quoted
    else
      pattern = pattern.quoted.all_up if pattern.rail_d?
      
      if args.handle?
        if args.rail_d?
          args = args.quoted.all_up 
        elsif args.quoted.rail_d?
          args = args.quoted.quoted.all_up_up
        end
      end

      raise_error(self, "sequence is expected for arguments but was given #{args.to_s}") if !args.rail?
      raise_error(self, "sequence is expected as argument pattern but was given #{pattern.to_s}") if !pattern.rail?

      al = args.length; pl = pattern.length
      raise_error(self, "too many arguments") if al > pl
      raise_error(self, "too few arguments") if al < pl

      pc = pattern.list
      ac = args.list
      i = 0
      while i < al do
        bind_pattern_helper(newbindings, pc.car, ac.car)
        pc = pc.cdr; ac = ac.cdr
        i += 1
      end
    end 
=end


#=begin # faster by avoiding ups and downs (esp. ups which creates new structure)
    if pattern.atom?
      raise_error(self, "atom is expected") if p_quote_level != 1
      i = 1 # stripping one level
      while i < a_quote_level
        args = Handle.new(args)
        i += 1
      end
      newbindings[pattern] = args
    elsif pattern.atom_d?
      raise_error(self, "atom is expected") if p_quote_level != 0
      i = 0
      while i < a_quote_level
        args = Handle.new(args)
        i += 1
      end
      newbindings[pattern.quoted] = args.quoted
    else
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
  
      raise_error(self, "Pattern Matching: arguments ill-formed") if !args.rail?
      raise_error(self, "Pattern Matching: pattern ill-formed") if !pattern.rail?

      al = args.length; pl = pattern.length
      raise_error(self, "too many arguments") if al > pl
      raise_error(self, "too few arguments") if al < pl

      pc = pattern.list
      ac = args.list
      i = 0
      while i < al do
        bind_pattern_helper(newbindings, pc.car, ac.car, p_quote_level, a_quote_level)
        pc = pc.cdr; ac = ac.cdr
        i += 1
      end
    end 
#=end

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
    puts "\nEnvironment at level " + current.to_s + ":\n"
    leading_space = "  " * current
    local.each_pair {|var, binding| puts leading_space + "#{var.to_s} => #{binding.to_s} \n" }

    if !tail.empty? && (all_levels || remaining > 0)
      tail.pp_helper(current + 1, remaining - 1, all_levels) 
    elsif !all_levels
      puts "~~ Stopped at level #{current} ~~\n\n"
    end
  end
end
