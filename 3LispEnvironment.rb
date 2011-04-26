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
      pattern = pattern.down.map(&:up) if pattern.rail_d?
      if args.handle?
        if args.rail_d?
          args = args.down.map(&:up) if args.rail_d?
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
  
public
  # see page 277 of Implementation paper
  # this could be slower than a rail implementation
  def similar?(template)  
    return true if self.equal?(template)
    
    self_keys = local.keys
    template_keys = template.local.keys

    return false if self_keys.length != template_keys.length
    
    self_keys.zip(template_keys).each { |key_pair|
	    return false if key_pair[0] != key_pair[1]
      
      if template.local[key_pair[1]].down != $ppc_t_a # :"''?" # try with a global variable of :"''?" to see whether it's faster
         return false if !(local[key_pair[0]].eq?(template.local[key_pair[1]])) # should be eq?, rather than ==
      end
    }
    
	  return true if tail.empty? && template.tail.empty?
	  tail.similar?(template.tail)
  end
end
