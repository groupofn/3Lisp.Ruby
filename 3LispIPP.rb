# encoding: UTF-8

# [ ] Align prompt_and_read & prompt_and_reply with RPP version & primitives

require './3LispError.rb'
require './3LispReader.rb'
require './3LispClasses.rb'
require './3LispInternaliser.rb'
require './3LispKernel.rb'
require './3LispPrimitives.rb'
require './stopwatch.rb'
      
class ThreeLispIPP
  include ThreeLispKernel

  attr_accessor :reader, :parser, :global_env, :primitives, :reserved_names, :state, :highest_level_reached, :stopwatch

  def initialize(initial_level)
    self.stopwatch = Stopwatch.new
    stopwatch.mute # uncomment this line to turn off time reporting
    stopwatch.start
    
    self.highest_level_reached = initial_level

    # these 4 must be created before initialization of primitives
    # because they are used there by the primitives
    self.reader = ExpReader.new
    self.parser = ThreeLispInternaliser.new    
    self.global_env = Environment.new({}, {})
    self.reserved_names = []
    
    self.primitives = ThreeLispPrimitives.new(reader, parser, global_env, reserved_names)
    
    primitive_bindings, primitive_names = primitives.initialize_primitives
    kernel_bindings, kernel_names = initialize_kernel(global_env, parser)

    global_env.local = primitive_bindings.merge!(kernel_bindings)
    self.reserved_names += primitive_names + kernel_names 

    global_env.rebind_one(:"GLOBAL".up, global_env.up)
    self.reserved_names << :"GLOBAL"

    self.state = [] 
  end

  def shift_down(continuation)
    state.push(continuation)
  end

  def shift_up(&cont_maker)
    if state.empty?
      self.highest_level_reached += 1
      cont_maker.call(highest_level_reached)
    else
      state.pop
    end
  end

  def prompt_and_read(level)
    code = nil
    while code.nil?
  	  print level
      print " > "
      parsed = parser.parse(reader.read)
      raise parser.failure_reason if parsed.nil?
      next if parsed.empty?
      code = parsed.first
    end
    code.up
  end
  
  def prompt_and_reply(result, level)
    if !result.nil?
      print level
      print " = "
      print result.down.to_s + "\n"
    end
  end
  
  def run
    level = highest_level_reached

    stopwatch.lap("Time spent on IPP initialization: ")

    initial_defs = parser.parse(IO.read("init-manual.3lisp"))

    stopwatch.lap("Time spent on parsing initial defenitions: ")
    
    library_just_loaded = false
    $stdout = File.open("/dev/null", "w") # turn off STDOUT during normalization of initial definitions
    
    begin	
    	ipp_proc = :"READ-NORMALISE-PRINT"
    	ipp_args = [] 	  # "arguments" passed among the && procs as an array; none to READ-NORMALISE-PRINT  	  	  
      env = global_env 
      cont = nil
    	
    	until false do
    
      ###### uncomment some or all of the following 5 lines to trace the IPP ##############
      #
      # print "level: "; p level
      # if ipp_proc == :"NORMALISE"
      #   print "ipp_proc: "; p ipp_proc; print "ipp_args: ["; 
      #   ipp_args.each {|e| print "\n            "; print e; }; print "\n          ]\n\n" 
      # end
      #
    
        case ipp_proc
    
        when :"READ-NORMALISE-PRINT"		# state level env
          if !initial_defs.empty?
            ipp_args = [initial_defs.pop.up]
            library_just_loaded = true if initial_defs.length == 0
          else
            if library_just_loaded
              $stdout.close
              $stdout = STDOUT
              library_just_loaded = false
              
              stopwatch.lap("Time spent on normalising initial defenitions: ")
            else
              stopwatch.lap("Time used: ")
            end
    
      	    ipp_args = [prompt_and_read(level)] # initialize here!
          end
          cont = make_reply_continuation(level, env)
          ipp_proc = :"NORMALISE"
          
          stopwatch.start
    		
    	  when :"REPLY-CONTINUATION"			# state result level env
          result = ipp_args[0]
          f = ipp_args[1]
          level = f.extract(:LEVEL.up)
          env = f.extract(:ENV.up)
          prompt_and_reply(result, level)
          ipp_proc = :"READ-NORMALISE-PRINT"
    
    
    	  when :"NORMALISE"               # state exp env cont
          exp = ipp_args[0]
          if exp.normal? then ipp_args = [cont, exp]; ipp_proc = :"CALL"
          elsif exp.atom_d? then ipp_args = [cont, env.binding(exp)]; ipp_proc = :"CALL"
          elsif exp.rail_d? then ipp_proc = :"NORMALISE-RAIL";
          elsif exp.pair_d? then ipp_args = [exp.car, exp.cdr]; ipp_proc = :"REDUCE"
          else raise_error(self, "don't know how to noramlise #{exp}")
          end
    
    	  when :"REDUCE"                  # state proc args env cont
          proc = ipp_args[0]; args = ipp_args[1]
          cont = make_proc_continuation(proc, args, env, cont)
          ipp_args = [proc]
          ipp_proc = :"NORMALISE"
    		
    	  when :"PROC-CONTINUATION"       # state proc! proc args env cont
          proc_bang = ipp_args[0]
          f = ipp_args[1]
          proc = f.extract(:PROC.up); args = f.extract(:ARGS.up)
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
          
          if !proc_bang.closure_d?
            raise_error(self, "function expected but was given #{proc_bang.down.to_s}!")
          elsif proc_bang.down.reflective?
            ipp_args = [proc_bang.down.de_reflect, args, env, cont]
            ipp_proc = :"CALL"
          else
            cont = make_args_continuation(proc_bang, proc, args, env, cont)
            ipp_args = [args]
            ipp_proc = :"NORMALISE"
          end
    		
        when :"ARGS-CONTINUATION"			# state args! proc! proc args env cont
          args_bang = ipp_args[0]
          f = ipp_args[1]
          proc_bang = f.extract(:"PROC!".up); # proc = f.extract(:PROC.up); args = f.extract(:ARGS.up)
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
          if proc_bang.down.primitive?
             ipp_args = [cont, proc_bang.down.ruby_lambda.call(args_bang.down).up]
             ipp_proc = :"CALL"
    		  else
            ipp_args = [proc_bang, args_bang]
            ipp_proc = :"EXPAND-CLOSURE"
          end
    
        when :"EXPAND-CLOSURE"				# state proc! args! cont
          proc_bang = ipp_args[0]; args_bang = ipp_args[1]
          if proc_bang.down.ppp_type == :"NORMALISE" # && plausible_arguments_to_normalise?(args_bang)
            shift_down(cont)
            ipp_args = [args_bang.first.down]
            env = args_bang.second.down
            cont = args_bang.third.down
            ipp_proc = :"NORMALISE"
            next
          end
    		
          ipp_proc = proc_bang.down.ppc_type
          if ipp_proc != :"UNKNOWN" # && plausible_arguments_to_a_continuation?(args_bang)
            shift_down(cont)
            ipp_args = [args_bang.first.down, proc_bang.down]
    		    next
    		  end
    		   
          ipp_args = [proc_bang.down.body.up]
          env = proc_bang.down.environment.bind_pattern(proc_bang.down.pattern.up, args_bang)
          ipp_proc = :"NORMALISE"		
    
    
        when :"NORMALISE-RAIL"				# state rail env cont
          rail = ipp_args[0]
          if rail.empty? then 
            ipp_args = [cont, rail]
            ipp_proc = :"CALL"
          else 
            ipp_args = [rail.first]
            cont = make_first_continuation(rail, env, cont)
            ipp_proc = :"NORMALISE"
          end
    		
        when :"FIRST-CONTINUATION"			# state first! rail env cont
          first_bang = ipp_args[0]
          f = ipp_args[1]
          rail = f.extract(:RAIL.up);
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
    
          cont = make_rest_continuation(first_bang, rail, env, cont)
          ipp_args = [rail.rest]
          ipp_proc = :"NORMALISE-RAIL"
    		
        when :"REST-CONTINUATION"			# state rest! first! rail env cont
          rest_bang = ipp_args[0]
          f = ipp_args[1]
          first_bang = f.extract(:"FIRST!".up)
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
          ipp_args = [cont, rest_bang.prep(first_bang)]
          ipp_proc = :"CALL"  		
    		
        when :"LAMBDA"						# state [kind pattern body] env cont
          kind = ipp_args[0].first; pattern = ipp_args[0].second; body = ipp_args[0].third;
    
          ipp_args = [kind, Rail.new(env.up, pattern, body).up]
          ipp_proc = :"REDUCE"
    
        when :"IF"							# state [premise c1 c2] env cont
          premise = ipp_args[0].first; c1 = ipp_args[0].second; c2 = ipp_args[0].third
          cont = make_if_continuation(premise, c1, c2, env, cont)
          ipp_args = [premise]
          ipp_proc = :"NORMALISE"
    
        when :"IF-CONTINUATION"				# state premise! premise c1 c2 env cont
          premise_bang = ipp_args[0]; 
          f = ipp_args[1]
          c1 = f.extract(:C1.up)
          c2 = f.extract(:C2.up)
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
          
          raise_error(self, "IF expects a truth value but was give #{premise_bang.down}") if !premise_bang.down.boolean?
          ipp_args = [premise_bang.down ? c1 : c2]
          ipp_proc = :"NORMALISE"
    
        when :"BLOCK"						# state clauses env cont
          clauses = ipp_args[0]
          if clauses.length != 1
            cont = make_block_continuation(clauses, env, cont)
          end
          ipp_args = [clauses.first]
          ipp_proc = :"NORMALISE"
    
        when :"BLOCK-CONTINUATION"			# state 1st-clause! clauses env cont
          f = ipp_args[1]
          clauses = f.extract(:CLAUSES.up)
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
          ipp_args = [Pair.pcons(:BLOCK.up, clauses.rest)]
          ipp_proc = :"NORMALISE"
    
        when :"COND"						# state clauses env cont
          clauses = ipp_args[0]
          if clauses.empty?
            raise_error(self, "COND expects at least one clause");
          else
            ipp_args = [clauses.first.first]
            cont = make_cond_continuation(clauses, env, cont)
            ipp_proc = :"NORMALISE"
          end
    
        when :"COND-CONTINUATION"			# state 1st-condition! clauses env cont
          first_condition_bang = ipp_args[0]
          f = ipp_args[1]
          clauses = f.extract(:CLAUSES.up)
          env = f.extract(:ENV.up)
          cont = f.extract(:CONT.up)
          if first_condition_bang.down
            ipp_args = [clauses.first.second]
          else
            ipp_args = [Pair.pcons(:COND.up, clauses.rest)]
          end
          ipp_proc = :"NORMALISE"
    
    		
        when :"CALL"						# state f a
          f = ipp_args[0]
          a = ipp_args[1..-1]
          
          ipp_proc = f.ppc_type  
          if ipp_proc != :"UNKNOWN"
            ipp_args = [a.first, f]
            next
          end
    		
          ipp_proc = f.ppp_type
          if ipp_proc != :"UNKNOWN"
            ipp_args = a
            next
          end
            
          ipp_args = [f.body.up]      
          env = f.environment.bind_pattern(f.pattern.up, Rail.new(*a).up)
          cont = shift_up {|new_level| make_reply_continuation(new_level, global_env)} 
          ipp_proc = :"NORMALISE" 
    		
        else
          raise_error(self, "Implementation error: control has left the IPP");
        end
      end
    
    rescue RuntimeError, ZeroDivisionError => detail
      print "3-Lisp run-time error: " + detail.message + "\n" 
      retry
    rescue Errno::ENOENT, Errno::EACCES => detail
      print "3-Lisp IO error: " + detail.message + "\n"
      retry 
    rescue ThreeLispSyntaxError => detail
      print "3-Lisp syntax error: " + detail.message + "\n" 
      retry
    end
  end
  
end 
