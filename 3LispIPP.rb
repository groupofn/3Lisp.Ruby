# encoding: UTF-8

# [ ] Further optimization is possible through 
#     (1) less construction of IPP_ARGS, 
#     (2) simplification of continuation construction, and

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

  attr_accessor :reader, :parser, :global_env, :primitives, :reserved_names  # infrastructure of the IPP; note that part of the RPP state is in global_env
  attr_accessor :cont_stack, :level, :cont, :env, :ipp_args, :ipp_proc, :read_prompt, :reply_prompt # state of the IPP
  attr_accessor :stopwatch # utility

  def initialize
    self.stopwatch = Stopwatch.new
    stopwatch.mute # comment this line out to turn on time reporting
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

    global_env.rebind_one(:"GLOBAL", global_env)
    self.reserved_names << :"GLOBAL"
  end

  def shift_down(continuation)
    self.level -= 1
    cont_stack.push(continuation) # cont_stack is roughly what's called "state" in the implementation paper
  end

  def shift_up()
    self.level += 1
    if cont_stack.empty?
      make_reply_continuation(INITIAL_READ_PROMPT, INITIAL_REPLY_PROMPT, global_env)
    else
      cont_stack.pop
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
    self.cont_stack = []
    self.level = 0
    self.read_prompt = INITIAL_READ_PROMPT
    self.reply_prompt = INITIAL_REPLY_PROMPT

    stopwatch.lap("Time spent on IPP initialization: ")

    initial_defs = parser.parse(IO.read("init.3lisp"))

    stopwatch.lap("Time spent on parsing initial defenitions: ")
    
    library_just_loaded = false
    $stdout = File.open("/dev/null", "w") # turn off STDOUT during normalization of initial definitions

    begin	
    	self.ipp_proc = :"READ-NORMALISE-PRINT"
    	self.ipp_args = [] 	  # "arguments" passed among the && procs as an array; none to READ-NORMALISE-PRINT
      self.env = global_env 
      self.cont = nil
    	
    	until false do
    
      ###### uncomment some or all of the following 5 lines to trace the IPP ##############
      #
      # print "level: "; p level
      # if ipp_proc == :"NORMALISE"
      #   print "ipp_proc: "; p ipp_proc; 
      #   print "ipp_args: ["; ipp_args.each {|e| print "\n            "; print e; }; print "\n          ]\n\n" 
      # end
      #

    
        case ipp_proc
        # while there are thousands of trips through these when clauses,
        # a reordering of them according to frequency reduces execution time
        # by only a small fraction, around 3%.

        when :"CALL"						# f a
          f = ipp_args[0]
          a = ipp_args[1..-1]
          
          self.ipp_proc = f.ppc_type  
          if ipp_proc != :"UNKNOWN"
            self.ipp_args = [a.first, f]
            next
          end
    		
          self.ipp_proc = f.ppp_type
          if ipp_proc != :"UNKNOWN"
            self.ipp_args = a
            next
          end
          
# This is unnecessary because primitive closures can now be expanded.
#
#          if f.primitive?       # primitive as continuation
#            self.cont = shift_up
#            self.ipp_args = [cont, f.ruby_lambda.call(Rail.new(*a)).up]
#            self.ipp_proc = :"CALL"
#            next
#          end
          
          if f.reflective?      # reflective as continuation
            c = shift_up
            e = c.extract(:ENV)
            self.ipp_args = [f.body.up]
            self.env = f.environment.bind_pattern(f.pattern.up, Rail.new(Rail.new(*a), e, c).up)
            self.cont = shift_up
            self.ipp_proc = :"NORMALISE"
            next
          end
          
          self.ipp_args = [f.body.up]
          self.env = f.environment.bind_pattern(f.pattern.up, Rail.new(*a).up)
          self.cont = shift_up 
          self.ipp_proc = :"NORMALISE"
         
    	  when :"NORMALISE"               # exp
          exp = ipp_args[0]
          if exp.normal? then self.ipp_args = [cont, exp]; self.ipp_proc = :"CALL"
          elsif exp.atom_d? then self.ipp_args = [cont, env.binding(exp.down).up]; self.ipp_proc = :"CALL"
          elsif exp.rail_d? then self.ipp_proc = :"NORMALISE-RAIL";
          elsif exp.pair_d? then self.ipp_args = [exp.car, exp.cdr]; self.ipp_proc = :"REDUCE"
          else raise_error(self, "don't know how to noramlise #{exp}")
          end

        when :"NORMALISE-RAIL"				# rail
          rail = ipp_args[0]
          if rail.empty? then 
            self.ipp_args = [cont, rail]
            self.ipp_proc = :"CALL"
          else 
            self.ipp_args = [rail.first]
            self.cont = make_first_continuation(rail, env, cont)
            self.ipp_proc = :"NORMALISE"
          end
    
        when :"FIRST-CONTINUATION"			# first! rail
          first_bang = ipp_args[0]
          f = ipp_args[1]
          rail = f.extract(:RAIL);
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
    
          self.cont = make_rest_continuation(first_bang, rail, env, cont)
          self.ipp_args = [rail.rest]
          self.ipp_proc = :"NORMALISE-RAIL"
    		
        when :"REST-CONTINUATION"			# rest! first! rail
          rest_bang = ipp_args[0]
          f = ipp_args[1]
          first_bang = f.extract(:"FIRST!")
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
          self.ipp_args = [cont, rest_bang.prep(first_bang)]
          self.ipp_proc = :"CALL"  		
    		    
    	  when :"PROC-CONTINUATION"       # proc! proc args
          proc_bang = ipp_args[0]
          f = ipp_args[1]
          proc = f.extract(:PROC); args = f.extract(:ARGS)
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
          
          if !proc_bang.closure_d?
            raise_error(self, "function expected but was given #{proc_bang.down.to_s}!")
          elsif proc_bang.down.reflective?
            self.ipp_args = [proc_bang.down.de_reflect, args, env, cont]
            self.ipp_proc = :"CALL"
          else
            self.cont = make_args_continuation(proc_bang, proc, args, env, cont)
            self.ipp_args = [args]
            self.ipp_proc = :"NORMALISE"
          end
    
    	  when :"REDUCE"                  # proc args
          proc = ipp_args[0]; args = ipp_args[1]
          self.cont = make_proc_continuation(proc, args, env, cont)
          self.ipp_args = [proc]
          self.ipp_proc = :"NORMALISE"
    		
        when :"ARGS-CONTINUATION"			# args! proc! proc args
          args_bang = ipp_args[0]
          f = ipp_args[1]
          proc_bang = f.extract(:"PROC!")
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
          if proc_bang.down.primitive?
             self.ipp_args = [cont, proc_bang.down.ruby_lambda.call(args_bang.down).up]
             self.ipp_proc = :"CALL"
    		  else
            self.ipp_args = [proc_bang, args_bang]
            self.ipp_proc = :"EXPAND-CLOSURE"
          end
    
        when :"EXPAND-CLOSURE"				# proc! args!
          proc_bang = ipp_args[0]; args_bang = ipp_args[1]
          
          if proc_bang.down.ppp_type == :"NORMALISE" && plausible_arguments_to_normalise?(args_bang)
            shift_down(cont)
            self.ipp_args = [args_bang.first.down]
            self.env = args_bang.second.down
            self.cont = args_bang.third.down
            self.ipp_proc = :"NORMALISE"
            next
          end

          if proc_bang.down.ppp_type == :"READ-NORMALISE-PRINT" && plausible_arguments_to_rnp?(args_bang)
            shift_down(cont)
            self.read_prompt = args_bang.first.down
            self.reply_prompt = args_bang.second.down
            self.env = args_bang.third.down
            self.ipp_proc = :"READ-NORMALISE-PRINT"            
            next
    		  end
        
          self.ipp_proc = proc_bang.down.ppc_type
          if ipp_proc != :"UNKNOWN" && plausible_arguments_to_a_continuation?(args_bang)
            shift_down(cont)
            self.ipp_args = [args_bang.first.down, proc_bang.down]
    		    next
    		  end
    		   
          self.ipp_args = [proc_bang.down.body.up]
          self.env = proc_bang.down.environment.bind_pattern(proc_bang.down.pattern.up, args_bang)
          self.ipp_proc = :"NORMALISE"    
    		    
        when :"COND"						# clauses
          clauses = ipp_args[0]
          if clauses.empty?
            raise_error(self, "COND expects at least one clause");
          else
            self.ipp_args = [clauses.first.first]
            self.cont = make_cond_continuation(clauses, env, cont)
            self.ipp_proc = :"NORMALISE"
          end
    
        when :"COND-CONTINUATION"			# 1st-condition! clauses
          first_condition_bang = ipp_args[0]
          f = ipp_args[1]
          clauses = f.extract(:CLAUSES)
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
          if first_condition_bang.down
            self.ipp_args = [clauses.first.second]
          else
            self.ipp_args = [Pair.pcons(:COND.up, clauses.rest)]
          end
          self.ipp_proc = :"NORMALISE"
    
        when :"IF"							# [premise c1 c2]
          premise = ipp_args[0].first; c1 = ipp_args[0].second; c2 = ipp_args[0].third
          self.cont = make_if_continuation(premise, c1, c2, env, cont)
          self.ipp_args = [premise]
          self.ipp_proc = :"NORMALISE"
    
        when :"IF-CONTINUATION"				# premise! premise c1 c2
          premise_bang = ipp_args[0]; 
          f = ipp_args[1]
          c1 = f.extract(:C1)
          c2 = f.extract(:C2)
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
          
          raise_error(self, "IF expects a truth value but was give #{premise_bang.down}") if !premise_bang.down.boolean?
          self.ipp_args = [premise_bang.down ? c1 : c2]
          self.ipp_proc = :"NORMALISE"
    
        when :"BLOCK"						# clauses
          clauses = ipp_args[0]
          if clauses.length != 1
            self.cont = make_block_continuation(clauses, env, cont)
          end
          self.ipp_args = [clauses.first]
          self.ipp_proc = :"NORMALISE"
    
        when :"BLOCK-CONTINUATION"			# 1st-clause! clauses
          f = ipp_args[1]
          clauses = f.extract(:CLAUSES)
          self.env = f.extract(:ENV)
          self.cont = f.extract(:CONT)
          self.ipp_args = [Pair.pcons(:BLOCK.up, clauses.rest)]
          self.ipp_proc = :"NORMALISE"

        when :"LAMBDA"						# [kind pattern body]
          kind = ipp_args[0].first; pattern = ipp_args[0].second; body = ipp_args[0].third;
    
          self.ipp_args = [kind, Rail.new(env.up, pattern, body).up]
          self.ipp_proc = :"REDUCE"

        when :"READ-NORMALISE-PRINT"		# read-prompt reply-prompt
          if !initial_defs.empty?
            self.ipp_args = [initial_defs.pop.up]
            library_just_loaded = true if initial_defs.length == 0
          else
            if library_just_loaded
              $stdout.close
              $stdout = STDOUT
              library_just_loaded = false
              
              stopwatch.lap("Time spent on normalising initial definitions: ")
            else
              stopwatch.lap("Time used: ")
            end
    
      	    self.ipp_args = [prompt_and_read(read_prompt)]
          end
          self.cont = make_reply_continuation(String.new(read_prompt), String.new(reply_prompt), env)
          self.ipp_proc = :"NORMALISE"
          
          stopwatch.start
    		
    	  when :"REPLY-CONTINUATION"			# result prompt
          result = ipp_args[0]
          f = ipp_args[1]
          self.read_prompt = f.extract(:"READ-PROMPT")
          self.reply_prompt = f.extract(:"REPLY-PROMPT")
          self.env = f.extract(:ENV)
          prompt_and_reply(result, reply_prompt)
          self.ipp_proc = :"READ-NORMALISE-PRINT"
        		
        else
          raise_error(self, "Implementation error: control has left the IPP");
        end
      end
    
#    rescue RuntimeError, ZeroDivisionError => detail
#      print "3-Lisp run-time error: " + detail.message + "\n" 
#      retry
    rescue Errno::ENOENT, Errno::EACCES => detail
      print "3-Lisp IO error: " + detail.message + "\n"
      retry 
    rescue ThreeLispSyntaxError => detail
      print "3-Lisp syntax error: " + detail.message + "\n" 
      retry
    rescue Interrupt => e  # Control-C during processing of a 3Lisp expression
      print "\n"
      retry
    end
  end
  
end


# Stats from normalising (map + [1 2 3 4 5 6 7 8 9] [1 2 3 4 5 6 7 8 9])
# 6,574	CALL
# 5,345	NORMALISE
# 2,987	NORMALISE-RAIL
# 1,785	FIRST-CONTINUATION
# 1,785	REST-CONTINUATION
# 1,414	PROC-CONTINUATION
# 1,414	REDUCE
# 1,239	ARGS-CONTINUATION
#  556	EXPAND-CLOSURE
#  156	COND
#  156	COND-CONTINUATION
#   19	IF
#   19	IF-CONTINUATION
#    1	READ-NORMALISE-PRINT
#    1	REPLY-CONTINUATION
#    0	BLOCK-CONTINUATION
#    0	LAMBDA


 
