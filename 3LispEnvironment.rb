# encoding: UTF-8

require './3LispError.rb'

class Environment
  include ThreeLispError
  
  # @local is a hash; @tail is either an environment or an empty hash
  attr_accessor :local, :tail

  def initialize(local, tail)
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
    return Rail.array2rail(local.keys) if tail.empty?
    return Rail.array2rail(local.keys).join(tail.bound_atoms)
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
=begin slower version -- using map 
      pattern = pattern.down.map(&:up) if pattern.rail_d?
      if args.handle?
        if args.rail_d?
          args = args.down.map(&:up) 
        elsif args.down.rail_d?
          args = args.down.down.map{|element| element.up.up}
        end
      end
      raise_error(self, "sequence is expected for arguments but was given #{args.to_s}") if !args.sequence_d?
      raise_error(self, "sequence is expected as argument pattern but was given #{pattern.to_s}") if !pattern.sequence_d?

      al = args.length; pl = pattern.length
      raise_error(self, "too many arguments") if al > pl
      raise_error(self, "too few arguments") if al < pl

      for i in 1..al
        bind_pattern_helper(newbindings, pattern.nth(i), args.nth(i))
      end
=end

# BEGIN faster version -- avoiding map 
      if pattern.rail_d?
        pattern = pattern.down
        root = nr = Rail.new
        while !pattern.empty?
          nr.element = pattern.element.up
          nr.remaining = Rail.new
          nr = nr.remaining
          pattern = pattern.remaining
        end
        pattern = root
      end

      if args.handle?
        if args.rail_d?
          args = args.down
          root = nr = Rail.new
          while !args.empty?
            nr.element = args.element.up
            nr.remaining = Rail.new 
            nr = nr.remaining
            args = args.remaining
          end
          args = root
        elsif args.down.rail_d?
          args = args.down.down
          root = nr = Rail.new
          while !args.empty?
            nr.element = args.element.up.up
            nr.remaining = Rail.new 
            nr = nr.remaining
            args = args.remaining
          end
          args = root
        end
      end

      raise_error(self, "sequence is expected for arguments but was given #{args.to_s}") if !args.sequence_d?
      raise_error(self, "sequence is expected as argument pattern but was given #{pattern.to_s}") if !pattern.sequence_d?

      al = args.length; pl = pattern.length
      raise_error(self, "too many arguments") if al > pl
      raise_error(self, "too few arguments") if al < pl

      while !args.empty?
        bind_pattern_helper(newbindings, pattern.element, args.element)
        args = args.remaining; pattern = pattern.remaining
      end
    end 
# END faster version

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
