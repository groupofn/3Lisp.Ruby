# encoding: UTF-8

# [ ] There is a question about REBIND: maybe I should block rebinding of all kernel stuff, on top of blocking replacing ...?

require './3LispClasses.rb'

module ThreeLispPrimitives

  PRIMITIVES = [
    [:EXIT, :SIMPLE, Rail.new, lambda {|args| Process.exit }],
    [:ERROR, :SIMPLE, Rail.new(:struc), lambda{|args|
      raise_error(self, "3-Lisp run-time error: " + args.first.to_s + "\n") }],
    
    [:SYS, :SIMPLE, Rail.new(:command, :arguments), lambda{|args|
      raise_error(self, "Usage: (system command-string) or (system command-string arg-string ...)") if args.length < 1
      raise_error(self, "SYSTEM expects a command string but was given #{args.first.to_s}") if !args.first.string?

      sh_command = args.first 
      args.rest.each { |a| 
        raise_error(self, "SYSTEM expects a command string but was given #{a.to_s}") if !a.string?
        sh_command += " " + a  
      }
      
      return Handle.new(:OK) if system(sh_command)

      raise_error(self, "System command " + sh_command + " exited with status " + $?.to_i.to_s)
    }],
    
    [:SOURCE, :SIMPLE, Rail.new(:string), lambda{|args|
      raise_error(self, "Usage: (source filename-string)") if args.length != 1    
      raise_error(self, "SOURCE expects a string of file name but was given #{args}.first.to_s") if !args.first.string?
      
      return IO.read(args.first)
    }],
    
    [:PARSE, :SIMPLE, Rail.new(:string), lambda{|args|
      parsed = $parser.parse(args.first)
      raise_error(self, "Failed to internalise string: #{args.first}") if parsed.empty?
      struc = parsed.up
    }],
        
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
      raise_error(self, "DOWN expects a normal-form structure but was given #{args.first.to_s}") if !args.first.normal?
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
        raise_error(self, "Kernel closure cannot be changed") if args.first.quoted.kernel?
        raise_error(self, "Primitive closure cannot be changed") if args.first.quoted.primitive?
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

    [:ACONS, :SIMPLE, :args, lambda{|args|
      begin
        s = "3LispAtom" + Time.now.to_f.to_s + rand(0x3fffffff).to_s 
      end while !$STRINGS_used_by_ACONS[s].nil?
    
      $STRINGS_used_by_ACONS[s] = s.to_sym.up # returned
    }],

    [:SCONS, :SIMPLE, :args, lambda{|args| 
      raise "SCONS expects a sequence but was given #{args.to_s}" if !args.sequence_d?
      Rail.scons(args) }], 
    [:RCONS, :SIMPLE, :args, lambda{|args| 
      Rail.rcons(args) }], 
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
    

    [:PCONS, :SIMPLE, Rail.new([:car, :cdr]), lambda{|args| 
      raise_error(self, "PCONS expects structure but was given #{args.first.to_s}") if !args.first.handle?
      raise_error(self, "PCONS expects structure but was given #{args.second.to_s}") if !args.second.handle?
      Pair.pcons(args.first, args.second) }],
    [:CAR, :SIMPLE, Rail.new(:pair), lambda{|args| 
      raise_error(self, "CAR expects a pair but was given #{args.first.to_s}") if !args.first.pair_d?
      args.first.car }],
    [:CDR, :SIMPLE, Rail.new(:pair), lambda{|args| 
      raise_error(self, "CDR expects a pair but was given #{args.first.to_s}") if !args.first.pair_d?
      args.first.cdr }], 

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
#     raise_error(self, "CCONS expects a procedure type but was given #{args.first.to_s}") if (args.first != :SIMPLE.up) && (args.first != :REFLECT.up)
#     raise_error(self, "CCONS expects an environment but was given #{args.second.to_s}") if !args.second.environment?
#     raise_error(self, "CCONS expects a pattern designator but was given #{args.third.to_s}") if !args.third.rail_d?
#     raise_error(self, "CCONS expects a structure but was given #{args.fourth.to_s}") if !args.fourth.handle?
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
      args.first.down.kind.up }],
  
    [:ECONS, :SIMPLE, Rail.new(:env), lambda{|args| 
      return Environment.new({}, {}) if args.empty? 
      return Environment.new({}, args.first) if args.first.environtment? 
      raise_error(self, "ECONS was given #{args.first} where it expects an environment") }],
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
      if args.third.eq?($global_env) && $reserved_names.include?(args.first.down)  
        raise_error(self, "Kernel or primitive name '#{args.first.down}' cannot be rebound in the global environment")
      end
      args.third.rebind_one(args.first, args.second) }],
    [:BOUND, :SIMPLE, Rail.new(:var, :env), lambda{|args|
      raise_error(self, "BOUND expects an atom but was given #{args.first.to_s}") if !args.first.atom_d?
      raise_error(self, "BOUND expects an environment but was given #{args.second.to_s}") if !args.second.environment?
      args.second.var_is_bound?(args.first) }],
    [:"BOUND-ATOMS", :SIMPLE, Rail.new(:env), lambda{|args|
      raise_error(self, "BOUND expects an environment but was given #{args.first.to_s}") if !args.first.environment?
      args.first.bound_atoms }], # returns a sequence of atom designators
  ]

  PRIMITIVE_RUBY_LAMBDAS = Hash[PRIMITIVES.map {|p| [p[0], p[3]] }]
  
  def ruby_lambda_for_primitive(closure)
    PRIMITIVE_RUBY_LAMBDAS[closure.body]
  end

  PRIMITIVE_BINDINGS = {}
  PRIMITIVES.map { |p| 
    # these are circular closures: quoted atoms used as the body
    PRIMITIVE_BINDINGS[p[0].up] = Closure.new(p[1], nil, p[2], p[0], :Primitive, p[0]).up # defining env is empty
  }

  PRIMITIVE_CLOSURES = PRIMITIVES.map {|p| PRIMITIVE_BINDINGS[p[0].up] }
  PRIMITIVE_PROCS = PRIMITIVE_CLOSURES.map {|c| c.down }

  def primitive?(closure)
    PRIMITIVE_PROCS.include?(closure)
  end  

end
