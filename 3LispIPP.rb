# encoding: UTF-8

# [ ] Fix up READ-PROMPT and REPLY-PROMPT
# [ ] Study env, cont etc as member variables ...
# [ ] Update RPP code ...
# [ ] Test all
# [ ] DONE

require './3LispError.rb'
require './3LispReader.rb'
require './3LispClasses.rb'
require './3LispInternaliser.rb'
require './3LispKernel.rb'
require './3LispPrimitives.rb'
require './stopwatch.rb'

INITIAL_READ_PROMPT = " > "
INITIAL_REPLY_PROMPT = " = "

class ThreeLispIPP
  include ThreeLispKernel

  attr_accessor :reader, :parser, :global_env, :primitives, :reserved_names, :state, :level, :read_prompt, :reply_prompt, :stopwatch

  def initialize
    self.stopwatch = Stopwatch.new
    stopwatch.mute # uncomment this line to turn off time reporting
    stopwatch.start
    
    self.reader = ExpReader.new
    self.parser = ThreeLispInternaliser.new    
    self.global_env = Environment.new({}, {})
    self.reserved_names = []
    
    self.primitives = ThreeLispPrimitives.new(self)
    
    primitive_bindings, primitive_names = primitives.initialize_primitives
    kernel_bindings, kernel_names = initialize_kernel(global_env, parser)

    global_env.local = primitive_bindings.merge!(kernel_bindings)
    self.reserved_names += primitive_names + kernel_names 

    global_env.rebind_one(:"GLOBAL".up, global_env.up)
    self.reserved_names << :"GLOBAL"
  end

  def shift_down(continuation)
    self.level -= 1
    state.push(continuation)
  end

  def shift_up()
    self.level += 1
    if state.empty?
      make_reply_continuation(INITIAL_READ_PROMPT, INITIAL_REPLY_PROMPT, global_env)
    else
      state.pop
    end
  end

  def prompt_level
    return "0" if level == 0
    return sprintf("%+d", level)
  end
  
  def prompt_and_read(prompt_text)
    prompt = prompt_level << prompt_text
  
    begin
      parsed = parser.parse(reader.read(prompt)) 
      raise parser.failure_reason if parsed.nil?
    end until !parsed.nil? && !parsed.empty?
    return parsed.first.up if parsed.length == 1
    
    parsed.up
  end
  
  def prompt_and_reply(result, prompt_text)
    prompt = prompt_level << prompt_text
    if !result.nil?
      print prompt << result.down.to_s + "\n"
    end
  end
  
  def run
    self.state = []
    self.level = 0
    self.read_prompt = INITIAL_READ_PROMPT
    self.reply_prompt = INITIAL_REPLY_PROMPT

    stopwatch.lap("Time spent on IPP initialization: ")

    initial_defs = parser.parse(IO.read("init-manual.3lisp"))
#    initial_defs = parser.parse(IO.read("temp.3lisp"))

    stopwatch.lap("Time spent on parsing initial defenitions: ")
    
    library_just_loaded = false
    $stdout = File.open("/dev/null", "w") # turn off STDOUT during normalization of initial definitions

#
# STUDY the status of env and cont, in particular, whether it makese sense for them to become @s.
#

# FIX UP read-prompt and reply-prompt so that they are stored in reply-continuation appropriately ...

    begin	
    	ipp_proc = :"READ-NORMALISE-PRINT"
    	ipp_args = [] 	  # "arguments" passed among the && procs as an array; none to READ-NORMALISE-PRINT
      env = global_env 
      cont = nil
    	
    	until false do
    
      ###### uncomment some or all of the following 5 lines to trace the IPP ##############
      #
      # print "level: "; p level
       #if ipp_proc == :"NORMALISE"
       #  print "ipp_proc: "; p ipp_proc; print "ipp_args: ["; 
       #  ipp_args.each {|e| print "\n            "; print e; }; print "\n          ]\n\n" 
       #end
      #
    
        case ipp_proc
        
        when :"READ-NORMALISE-PRINT"		# state read-prompt reply-prompt env
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
    
      	    ipp_args = [prompt_and_read(read_prompt)] # initialize here!
          end
          cont = make_reply_continuation(read_prompt.clone, reply_prompt.clone, env)
          ipp_proc = :"NORMALISE"
          
          stopwatch.start
    		
    	  when :"REPLY-CONTINUATION"			# state result prompt env
          result = ipp_args[0]
          f = ipp_args[1]
          read_prompt = f.extract(:"READ-PROMPT".up)
          reply_prompt = f.extract(:"REPLY-PROMPT".up)
          env = f.extract(:ENV.up)
          prompt_and_reply(result, reply_prompt)
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
          if proc_bang.down.ppp_type == :"NORMALISE" && plausible_arguments_to_normalise?(args_bang)
            shift_down(cont)
            ipp_args = [args_bang.first.down]
            env = args_bang.second.down
            cont = args_bang.third.down
            ipp_proc = :"NORMALISE"
            next
          end

          if proc_bang.down.ppp_type == :"READ-NORMALISE-PRINT" # && plausible_arguments_to_rnp?(args_bang)
            shift_down(cont)
            self.read_prompt = args_bang.first.down
            self.reply_prompt = args_bang.second.down
            env = args_bang.third.down
            ipp_proc = :"READ-NORMALISE-PRINT"            
            next
    		  end
        
          ipp_proc = proc_bang.down.ppc_type
          if ipp_proc != :"UNKNOWN" && plausible_arguments_to_a_continuation?(args_bang)
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
          cont = shift_up 
          ipp_proc = :"NORMALISE" 
    		
        else
          raise_error(self, "Implementation error: control has left the IPP");
        end
      end
    
   # rescue RuntimeError, ZeroDivisionError => detail
   #   print "3-Lisp run-time error: " + detail.message + "\n" 
     # retry
    rescue Errno::ENOENT, Errno::EACCES => detail
      print "3-Lisp IO error: " + detail.message + "\n"
      retry 
    rescue ThreeLispSyntaxError => detail
      print "3-Lisp syntax error: " + detail.message + "\n" 
      retry
    end
  end
  
end 
