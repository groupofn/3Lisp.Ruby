# encoding: UTF-8

module ThreeLispIPP

def prompt_and_read(level)
  code = nil
  while code.nil?
	  print level
    print " > "
    parsed = $parser.parse($reader.read)
    raise $parser.failure_reason if parsed.nil?
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

#####

def three_lisp
  # global to threeLisp: state, level, env, cont
  initial_level_at_prompt = 0                         # rather than 1 as in Implementation paper
  state = IPPState.new(initial_level_at_prompt)   # rather than initial_tower(2) as in Implementation paper
  level = initial_level_at_prompt                    
  initial_defs = $parser.parse(IO.read("init-manual.3lisp"))
 
  library_just_loaded = false

  $stdout = File.open("/dev/null", "w")
  
  oldtime = Time.now
  
  begin	
  	ipp_proc = :"READ-NORMALISE-PRINT"
  	ipp_args = [] 	  # "arguments" passed among the && procs as an array; none to READ-NORMALISE-PRINT  	  	  
    env = $global_env 
    cont = nil
  	
  	until false do
  
    # print "level: "; p level
    # if ipp_proc == :"NORMALISE"
#        print "ipp_proc: "; p ipp_proc; print "ipp_args: ["; 
#        ipp_args.each {|e| print "\n            "; print e; }; print "\n          ]\n\n" 
    #end	  
  
      case ipp_proc
  
      when :"READ-NORMALISE-PRINT"		# state level env
        if initial_defs.length > 0
          ipp_args = [initial_defs.pop.up]
          library_just_loaded = true if initial_defs.length == 0
        else
          if library_just_loaded
            $stdout.close
            $stdout = STDOUT
            library_just_loaded = false
          end
  
          elapsed = Time.now - oldtime
  
          # uncomment the following line to get time for each interaction
          # p elapsed
                  
    	    ipp_args = [prompt_and_read(level)] # initialize here!
        end
        cont = make_reply_continuation(level, env)
        ipp_proc = :"NORMALISE"
        oldtime = Time.now
  		
  	  when :"REPLY-CONTINUATION"			# state result level env
        result = ipp_args[0]
        f = ipp_args[1]
        level = ex(:LEVEL.up, f)
        env = ex(:ENV.up, f)
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
        proc = ex(:PROC.up, f); args = ex(:ARGS.up, f)
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
        
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
        proc_bang = ex(:"PROC!".up, f); # proc = ex(:PROC.up, f); args = ex(:ARGS.up, f)
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
        if primitive?(proc_bang.down)
          ipp_args = [cont, ruby_lambda_for_primitive(proc_bang.down).call(args_bang.down).up]
          ipp_proc = :"CALL"
  		  else
          ipp_args = [proc_bang, args_bang]
          ipp_proc = :"EXPAND-CLOSURE"
        end
  
      when :"EXPAND-CLOSURE"				# state proc! args! cont
        proc_bang = ipp_args[0]; args_bang = ipp_args[1]
        if ppp_type(proc_bang.down) == :"NORMALISE" # && plausible_arguments_to_normalise?(args_bang)
          state.shift_down(cont)
          ipp_args = [args_bang.first.down]
          env = args_bang.second.down
          cont = args_bang.third.down
          ipp_proc = :"NORMALISE"
          next
        end
  		
        ipp_proc = ppc_type(proc_bang.down)
        if ipp_proc != :"UNKNOWN" # && plausible_arguments_to_a_continuation?(args_bang)
          state.shift_down(cont)
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
        rail = ex(:RAIL.up, f);
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
  
        cont = make_rest_continuation(first_bang, rail, env, cont)
        ipp_args = [rail.rest]
        ipp_proc = :"NORMALISE-RAIL"
  		
      when :"REST-CONTINUATION"			# state rest! first! rail env cont
        rest_bang = ipp_args[0]
        f = ipp_args[1]
        first_bang = ex(:"FIRST!".up, f)
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
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
        c1 = ex(:C1.up, f)
        c2 = ex(:C2.up, f)
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
        
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
        clauses = ex(:CLAUSES.up, f)
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
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
        clauses = ex(:CLAUSES.up, f)
        env = ex(:ENV.up, f)
        cont = ex(:CONT.up, f)
        if first_condition_bang.down
          ipp_args = [clauses.first.second]
        else
          ipp_args = [Pair.pcons(:COND.up, clauses.rest)]
        end
        ipp_proc = :"NORMALISE"
  
  		
      when :"CALL"						# state f a
        f = ipp_args[0]
        a = ipp_args[1..-1]
        
        ipp_proc = ppc_type(f)  
        if ipp_proc != :"UNKNOWN"
          ipp_args = [a.first, f]
          next
        end
  		
        ipp_proc = ppp_type(f)
        if ipp_proc != :"UNKNOWN"
          ipp_args = a
          next
        end
          
        ipp_args = [f.body.up]      
        env = f.environment.bind_pattern(f.pattern.up, Rail.new(*a).up)
        cont = state.shift_up {|new_level| make_reply_continuation(new_level, $global_env)} 
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

end # module ThreeLispIPP
