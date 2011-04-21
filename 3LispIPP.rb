# encoding: UTF-8

require 'rubygems'
#require 'polyglot'
#require 'treetop'
require './3LispInternaliser.rb'
#require './3LispParser_node_modules.rb'
require './3LispReader.rb'
require './3LispClasses.rb'

$STRINGS_used_by_ACONS = {}

$parser = ThreeLispInternaliser.new
$reader = ExpReader.new

primitive_bindings = {}

PRIMITIVES.map { |primitive| 
  # these are circular closures: quoted atoms used as the body
  primitive_bindings[primitive[0].up] =
    Closure.new(primitive[1], nil, primitive[2], primitive[0]).up # defining env is empty
}

$global_env = Environment.new(primitive_bindings, {}) # tail env is empty!

PRIMITIVE_CLOSURES = PRIMITIVE_PROC_NAMES.map {|var| $global_env.binding(var) }
PRIMITIVE_PROCS = PRIMITIVE_CLOSURES.map {|c| c.down }


def primitive?(closure)
  PRIMITIVE_PROCS.include?(closure)
end  

$global_env.bind_one(:"PRIMITIVE-CLOSURES".up, Rail.new(*PRIMITIVE_CLOSURES).up)

def initial_tower(level)
  [level]
end

def shift_down(continuation, state)
#  print ("shifting down one level\n")
#  state.prep(continuation)
  [continuation] + state
end

def reify_continuation(state)
  if state.length == 1
    make_reply_continuation(state.first, $global_env) # would be at this level
  else
    state.first
  end
end
  
def shift_up(state)
#  print ("shifting up")
  if state.length == 1
#    print (" to level "); print state[0]; print ("\n")
    state[0] += 1
    return state
  else
#    print (" one level\n")
    return state[1..-1] # state.rest
  end
end

def prompt_and_read(level)
  code = nil
  while code.nil?
	  print level
    print "> "
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
    print "= "
    print result.down.to_s + "\n"
  end
end

KERNEL_UTILITY_PARTS = [
  [:"1ST", :SIMPLE, Rail.new(:VEC), "(nth 1 vec)"],
  
  [:"2ND", :SIMPLE, Rail.new(:VEC), "(nth 2 vec)"],
  
  [:"ATOM", :SIMPLE, Rail.new(:EXP), "(= (type exp) 'atom)"],
  
  [:"DE-REFLECT", :SIMPLE, Rail.new(:CLOSURE), "
    (ccons 'simple (environment-designator closure) (pattern closure) (body closure))
  "],
  
#  [:"EMPTY", :SIMPLE, Rail.new(:VEC), "(= 0 (length vec))"], # primitive now
  
  [:"MEMBER", :SIMPLE, Rail.new(:ELEMENT, :VECTOR), "
    (cond [(empty vector) $F]
          [(= element (1st vector)) $T]
          [$T (member element (rest vector))])
  "],
  
  [:"NORMAL", :SIMPLE, Rail.new(:EXP), "
    ((lambda simple [t]
      (cond
        [(= t 'numeral) $T]
        [(= t 'boolean) $T]
        [(= t 'handle) $T]
        [(= t 'string) $T]
        [(= t 'atom) $F]
        [(= t 'rail) (normal-rail exp)]
        [(= t 'closure) $T]
        [(= t 'environment) $T]
        [(= t 'pair) $F]))
     (type exp))
  "],

  [:"NORMAL-RAIL", :SIMPLE, Rail.new(:RAIL), "
    (cond
      [(empty rail) $T]
      [(normal (1st rail)) (normal-rail (rest rail))]
      [$T $F])  
  "],

  [:"PAIR", :SIMPLE, Rail.new(:EXP), "(= (type exp) 'pair)"],

  [:"PRIMITIVE", :SIMPLE, Rail.new(:CLOSURE), "(member closure primitive-closures)"],

  [:"PROMPT&READ", :SIMPLE, Rail.new(:LEVEL), "
    (block
      (print ↑level)
      (read '>))
  "],
  
  [:"PROMPT&REPLY", :SIMPLE, Rail.new(:"RESULT!", :LEVEL), "
    (block
  	  (print ↑level)
      (print '=)
      (print result!)
      (terpri))  
  "],

  [:"RAIL", :SIMPLE, Rail.new(:EXP), "(= (type exp) 'rail)"],

  [:"REFLECTIVE", :SIMPLE, Rail.new(:CLOSURE), "(= (procedure-type closure) 'reflect)"],

  [:"REST", :SIMPLE, Rail.new(:VEC), "(tail 1 vec)"],

  [:"UNIT", :SIMPLE, Rail.new(:VEC), "(= 1 (length vec))"],

  [:"ENVIRONMENT-OF", :SIMPLE, Rail.new(:CLOSURE), "↓(environment-designator closure)"],

  [:"SIMPLE", :SIMPLE, Rail.new(:"DEF-ENV", :PATTERN, :BODY), "↓(ccons 'simple def-env pattern body)"],

  [:"REFLECT", :SIMPLE, Rail.new(:"DEF-ENV", :PATTERN, :BODY), "↓(ccons 'reflect def-env pattern body)"]

# new simple version being explored    
#  [:"SIMPLE", :SIMPLE, [:"DEF-ENV", :PATTERN, :BODY], "(ccons 'simple def-env pattern body)"],
#  [:"REFLECT", :SIMPLE, [:"DEF-ENV", :PATTERN, :BODY], "(ccons 'reflect def-env pattern body)"]
]

KERNEL_UTILITY_PARTS.each {|e|
  $global_env.bind_one(e[0].up, Closure.new(e[1], $global_env, e[2], $parser.parse(e[3]).first).up)
}


#EXTENDED_UTILITY_PARTS = [  
#  [:"DEFINE", :REFLECT, [Rail.new([:VAR, :DEF]), :ENV, :CONT], "
#    (normalise def env 
#      (lambda simple [def!] 
#        (block 
#          (rebind var def! global)
#          (cont ↑var))))
#  "]
#]

#EXTENDED_UTILITY_PARTS.each {|e|
#  $global_env.bind_one(e[0].up, Closure.new(e[1].up, $global_env, Rail.new(e[2]).up, $parser.parse(e[3]).first.up).up)
#}

RPP_PROC_PARTS = 
{
  :"&&READ-NORMALISE-PRINT" => [
    :SIMPLE, Rail.new(:LEVEL, :ENV),
    $parser.parse("
      '(normalise (prompt&read level) env
         (lambda simple [result]                   ; REPLY continuation
           (block (prompt&reply result level)
             (read-normalise-print level env))))
    ").first.down
  ],

  :"&&NORMALISE" => [
    :SIMPLE, Rail.new(:EXP, :ENV, :CONT),
    $parser.parse("
      '(cond [(normal exp) (cont exp)]
             [(atom exp) (cont (binding exp env))]
             [(rail exp) (normalise-rail exp env cont)]
             [(pair exp) (reduce (car exp) (cdr exp) env cont)])
    ").first.down
  ],

  :"&&REDUCE" => [
    :SIMPLE, Rail.new(:PROC, :ARGS, :ENV, :CONT),
    $parser.parse("
      '(normalise proc env
         (lambda simple [proc!]                    ; PROC continuation
           (if (reflective proc!)
            	 (↓(de-reflect proc!) args env cont)
            	 (normalise args env
                          (lambda simple [args!]            ; ARGS continuation
                            (if (primitive proc!)
                                (cont ↑(↓proc! . ↓args!))
                                (normalise (body proc!)
                                           (bind (pattern proc!) args! (environment-of proc!))
                                           cont)))))))
    ").first.down
  ],

  :"&&NORMALISE-RAIL" => [
    :SIMPLE, Rail.new(:RAIL, :ENV, :CONT),
    $parser.parse("
      '(if (empty rail)
           (cont (rcons))
           (normalise (1st rail) env
                      (lambda simple [first!]            ; FIRST continuation
                        (normalise-rail (rest rail) env
                                        (lambda simple [rest!]         ; REST continuation
                                          (cont (prep first! rest!)))))))
    ").first.down
  ],

# implementation paper version
#  :"&&LAMBDA" => [
#    QUOTE_REFLECT, Rail.new([Rail.new([:KIND, :PATTERN, :BODY]), :ENV, :CONT]).up,
#    $parser.parse("
#      '(cont (ccons kind env pattern body))
#    ").first
#  ],

# new version being explored
#  :"&&LAMBDA" => [
#    QUOTE_REFLECT, Rail.new([Rail.new([:KIND, :PATTERN, :BODY]), :ENV, :CONT]).up,
#    $parser.parse("
#      '(cont (↓kind env pattern body))
#    ").first
#  ],


# manual version
  :"&&LAMBDA" => [
    :REFLECT, Rail.new(Rail.new(:KIND, :PATTERN, :BODY), :ENV, :CONT),
    $parser.parse("
      '(reduce kind ↑[↑env pattern body] env cont)
    ").first.down
  ],

  :"&&IF" => [
    :REFLECT, Rail.new(Rail.new(:PREMISE, :C1, :C2), :ENV, :CONT),
    $parser.parse("
      '(normalise premise env
                  (lambda simple [premise!]
                    (normalise (ef ↓premise! c1 c2) env cont)))
    ").first.down
  ],

=begin
  :"&&BLOCK" => [
    :REFLECT, Rail.new(:CLAUSES, :ENV, :CONT),
    $parser.parse("
      '(if (unit clauses)
           (normalise (1st clauses) env cont)
		       (normalise (1st clauses) env
					   (lambda simple arg
					     (normalise (pcons 'block (rest clauses)) env cont))))
    ").first.down
  ],
=end
  :"&&BLOCK" => [
    :REFLECT, Rail.new(:CLAUSES, :ENV, :CONT),
    $parser.parse("
      '(if (unit clauses)
           (normalise (1st clauses) env cont)
		       (normalise (1st clauses) env
					   (lambda simple arg
					     (normalise (pcons 'block (rest clauses)) env cont))))
    ").first.down
  ],



  :"&&COND" => [
    :REFLECT, Rail.new(:CLAUSES, :ENV, :CONT),
    $parser.parse("
      '(if (empty clauses)
           (cont 'error)
           (normalise (1st (1st clauses)) env
				              (lambda simple [1st-condition!]                 ; COND continuation
                        (if ↓1st-condition! 
                            (normalise (2nd (1st clauses)) env cont)
                            (normalise (pcons 'cond (rest clauses)) env cont)))))
    ").first.down
  ]
}
  
def make_rpp_proc(proc_name)
  parts = RPP_PROC_PARTS[proc_name]
  Closure.new(parts[0], $global_env, parts[1], parts[2])
end

RPP_READ_NORMALISE_PRINT_CLOSURE = make_rpp_proc(:"&&READ-NORMALISE-PRINT")
RPP_NORMALISE_CLOSURE = make_rpp_proc(:"&&NORMALISE")
RPP_REDUCE_CLOSURE = make_rpp_proc(:"&&REDUCE")
RPP_NORMALISE_RAIL_CLOSURE = make_rpp_proc(:"&&NORMALISE-RAIL")
RPP_LAMBDA_CLOSURE = make_rpp_proc(:"&&LAMBDA")
RPP_IF_CLOSURE = make_rpp_proc(:"&&IF")
RPP_BLOCK_CLOSURE = make_rpp_proc(:"&&BLOCK")
RPP_COND_CLOSURE = make_rpp_proc(:"&&COND")
  
$global_env.bind_one(:"READ-NORMALISE-PRINT".up, RPP_READ_NORMALISE_PRINT_CLOSURE.up)
$global_env.bind_one(:"NORMALISE".up, RPP_NORMALISE_CLOSURE.up)
$global_env.bind_one(:"REDUCE".up, RPP_REDUCE_CLOSURE.up)
$global_env.bind_one(:"NORMALISE-RAIL".up, RPP_NORMALISE_RAIL_CLOSURE.up)
$global_env.bind_one(:"LAMBDA".up, RPP_LAMBDA_CLOSURE.up)
$global_env.bind_one(:"IF".up, RPP_IF_CLOSURE.up)
$global_env.bind_one(:"BLOCK".up, RPP_BLOCK_CLOSURE.up)
$global_env.bind_one(:"COND".up, RPP_COND_CLOSURE.up)

$global_env.bind_one(:"GLOBAL".up, $global_env.up)

RPP_CONT_PARTS =
{
  :"&&REPLY-CONTINUATION"=> [
    Rail.new(:LEVEL, :ENV, :"READ-NORMALISE-PRINT"), 
    Rail.new(:"RESULT"),
    $parser.parse("
      '(block (prompt&reply result level)
         (read-normalise-print level env))
    ").first.down
  ],

  :"&&PROC-CONTINUATION" => [
    Rail.new(:PROC, :ARGS, :ENV, :CONT, :REDUCE),
    Rail.new(:"PROC!"),
    $parser.parse("
      '(if (reflective proc!)
           (↓(de-reflect proc!) args env cont)
           (normalise args env
             (lambda [args!]
               (if (primitive proc!)
                   (cont ↑(↓proc! . ↓args!))
                   (normalise (body proc!)
                              (bind (pattern proc!)
                                    args!
                                    (environment-of proc!))
                              cont)))))
    ").first.down
  ],
    
  :"&&ARGS-CONTINUATION" => [
    Rail.new(:"PROC!", :PROC, :ARGS, :ENV, :CONT, :REDUCE),
    Rail.new(:"ARGS!"),
    $parser.parse("
      '(if (primitive proc!)  ; HUP new draft misses the quote
           (cont ↑(↓proc! . ↓args!))
           (normalise (body proc!)
                      (bind (pattern proc!)
                            args!
                            (environment-of proc!))
                      cont))        
    ").first.down
  ],
    
  :"&&FIRST-CONTINUATION" => [
    Rail.new(:RAIL, :ENV, :CONT, :"NORMALISE-RAIL"),
    Rail.new(:"FIRST!"),
    $parser.parse("
      '(normalise-rail (rest rail) env
                       (lambda [rest!]
                         (cont (prep first! rest!))))
   ").first.down
  ],
    
  :"&&REST-CONTINUATION" => [
    Rail.new(:"FIRST!", :RAIL, :ENV, :CONT, :"NORMALISE-RAIL"),
    Rail.new(:"REST!"),
    $parser.parse("
      '(cont (prep first! rest!))
    ").first.down
  ],
    
  :"&&IF-CONTINUATION" => [
    Rail.new(:PREMISE, :C1, :C2, :ENV, :CONT, :IF),
    Rail.new(:"PREMISE!"),
    $parser.parse("
      '(normalise (ef ↓premise! c1 c2) env cont)      
    ").first.down
  ],
    
  :"&&BLOCK-CONTINUATION" => [
    Rail.new(:CLAUSES, :ENV, :CONT, :BLOCK),
    :"\?", # no arguments
    $parser.parse("
      '(normalise (pcons 'block (rest clauses)) env cont)
    ").first.down
  ],
    
  :"&&COND-CONTINUATION" => [
    Rail.new(:CLAUSES, :ENV, :CONT, :COND),
    Rail.new(:"1st-condition!"),
    $parser.parse("
      '(if ↓1st-condition!
           (normalise (2nd (1st clauses)) env cont)
           (normalise (pcons 'cond (rest clauses)) env cont)) 
    ").first.down
  ]
}

def make_rpp_continuation(cont_name, args)
  parts = RPP_CONT_PARTS[cont_name]
  Closure.new(:SIMPLE, $global_env.bind_pattern(parts[0].up, args.up), parts[1], parts[2])
end  
  
def make_reply_continuation(level, env)
  local_args = Rail.new(level, env, RPP_READ_NORMALISE_PRINT_CLOSURE)
  make_rpp_continuation(:"&&REPLY-CONTINUATION", local_args)
end
  
def make_proc_continuation(proc, args, env, cont)
  local_args = Rail.new(proc, args, env, cont, RPP_REDUCE_CLOSURE)
  make_rpp_continuation(:"&&PROC-CONTINUATION", local_args)
end

def make_args_continuation(proc_bang, proc, args, env, cont)
  local_args = Rail.new(proc_bang, proc, args, env, cont, RPP_REDUCE_CLOSURE)
  make_rpp_continuation(:"&&ARGS-CONTINUATION", local_args)
end
  
def make_first_continuation(rail, env, cont)
  local_args = Rail.new(rail, env, cont, RPP_NORMALISE_RAIL_CLOSURE)
  make_rpp_continuation(:"&&FIRST-CONTINUATION", local_args)
end
  
def make_rest_continuation(first_bang, rail, env, cont)
  local_args = Rail.new(first_bang, rail, env, cont, RPP_NORMALISE_RAIL_CLOSURE)
  make_rpp_continuation(:"&&REST-CONTINUATION", local_args)
end
  
def make_if_continuation(premise, c1, c2, env, cont)
  local_args = Rail.new(premise, c1, c2, env, cont, RPP_IF_CLOSURE)
  make_rpp_continuation(:"&&IF-CONTINUATION", local_args)
end
  
def make_block_continuation(clauses, env, cont)
  local_args = Rail.new(clauses, env, cont, RPP_BLOCK_CLOSURE)
  make_rpp_continuation(:"&&BLOCK-CONTINUATION", local_args)
end
  
def make_cond_continuation(clauses, env, cont)
  local_args = Rail.new(clauses, env, cont, RPP_COND_CLOSURE)
  make_rpp_continuation(:"&&COND-CONTINUATION", local_args)
end

def ex(variable, closure)
  closure.environment.binding(variable).down
end

def identify_closure(closure, table)
  table.each {|c| return c[0] if closure.similar?(c[1]) }
	
	return :UNKNOWN
end
  
PPP_TABLE = [ 
	[:"&&READ-NORMALISE-PRINT", RPP_READ_NORMALISE_PRINT_CLOSURE],
  [:"&&NORMALISE", RPP_NORMALISE_CLOSURE],
	[:"&&REDUCE", RPP_REDUCE_CLOSURE],
	[:"&&NORMALISE-RAIL", RPP_NORMALISE_RAIL_CLOSURE],
	[:"&&LAMBDA", RPP_LAMBDA_CLOSURE.de_reflect],
	[:"&&IF", RPP_IF_CLOSURE.de_reflect],
	[:"&&BLOCK", RPP_BLOCK_CLOSURE.de_reflect],
	[:"&&COND", RPP_COND_CLOSURE.de_reflect]
]

def ppp_type(closure)
  identify_closure(closure, PPP_TABLE)
end
  
PPC_TABLE = [
  [:"&&PROC-CONTINUATION", make_proc_continuation(:"\?".up, :"\?".up, :"\?".up, :"\?".up)],
  [:"&&ARGS-CONTINUATION", make_args_continuation(:"\?".up, :"\?".up, :"\?".up, :"\?".up, :"\?".up)],
  [:"&&FIRST-CONTINUATION", make_first_continuation(:"\?".up, :"\?".up, :"\?".up)],
  [:"&&REST-CONTINUATION", make_rest_continuation(:"\?".up, :"\?".up, :"\?".up, :"\?".up)],
  [:"&&REPLY-CONTINUATION", make_reply_continuation(:"\?".up, :"\?".up)],
  [:"&&IF-CONTINUATION", make_if_continuation(:"\?".up, :"\?".up, :"\?".up, :"\?".up, :"\?".up)],
  [:"&&BLOCK-CONTINUATION", make_block_continuation(:"\?".up, :"\?".up, :"\?".up)],
  [:"&&COND-CONTINUATION", make_cond_continuation(:"\?".up, :"\?".up, :"\?".up)],
]
    
def ppc_type(closure)
  identify_closure(closure, PPC_TABLE)
end

def plausible_arguments_to_a_continuation?(args_bang)
  return args_bang.rail_d? && args_bang.length == 1 && args_bang.first.handle_d?
end

def plausible_arguments_to_normalise?(args_bang)
  return args_bang.rail_d? && 
    args_bang.length == 3 && 
		args_bang.first.handle_d? && 
		(args_bang.second.environment_d?) && 
		plausible_continuation_designator(args_bang.third)
end
  
def plausible_continuation_designator(c_bang)
  return c_bang.closure_d? && !c_bang.down.reflective? && 
         (c_bang.down.pattern.atom? || (c_bang.down.pattern.rail? && c_bang.down.pattern.length == 1)) 
end

def threeLisp
  # global to threeLisp: state, level, env, cont
  state = initial_tower(1)  # rather than initial_tower(2) as in Implementation paper
  level = 0                 # rather than 1 as in Implementation paper
  initial_defs = $parser.parse(IO.read("init-manual.3lisp"))
 
  library_just_loaded = false

#  initial_defs.each{|e| p e}
  $stdout = File.open("/dev/null", "w")
  
oldtime = Time.now

begin	
	ipp_proc = :"&&READ-NORMALISE-PRINT"
	ipp_args = [] 	  # "arguments" passed among the && procs as an array; none to READ-NORMALISE-PRINT  	  	  
  env = $global_env 
  cont = nil
	
	until false do

#    print "level: "; p level
#if ipp_proc == :"&&NORMALISE"
#    print "ipp_proc: "; p ipp_proc; print "ipp_args: ["; 
#    ipp_args.each {|e| print "\n            "; print e; }; print "\n          ]\n\n" 
#end	  
      # dispatches according to $proc_token,
    case ipp_proc

    when :"&&READ-NORMALISE-PRINT"		# state level env
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
#        p elapsed
                
  	    ipp_args = [prompt_and_read(level)] # initialize here!
      end
      cont = make_reply_continuation(level, env)
      ipp_proc = :"&&NORMALISE"
      oldtime = Time.now
		
	  when :"&&REPLY-CONTINUATION"			# state result level env
      result = ipp_args[0]
      f = ipp_args[1]
      level = ex(:LEVEL.up, f)
      env = ex(:ENV.up, f)
      prompt_and_reply(result, level)
      ipp_proc = :"&&READ-NORMALISE-PRINT"


	  when :"&&NORMALISE"               # state exp env cont
      exp = ipp_args[0]
      if exp.normal? then ipp_args = [cont, exp]; ipp_proc = :"&&CALL"
      elsif exp.atom_d? then ipp_args = [cont, env.binding(exp)]; ipp_proc = :"&&CALL"
      elsif exp.rail_d? then ipp_proc = :"&&NORMALISE-RAIL";
      elsif exp.pair_d? then ipp_args = [exp.car, exp.cdr]; ipp_proc = :"&&REDUCE"
      else raise_error(self, "don't know how to noramlise #{exp}")
      end

	  when :"&&REDUCE"                  # state proc args env cont
      proc = ipp_args[0]; args = ipp_args[1]
      cont = make_proc_continuation(proc, args, env, cont)
      ipp_args = [proc]
      ipp_proc = :"&&NORMALISE"
		
	  when :"&&PROC-CONTINUATION"       # state proc! proc args env cont
      proc_bang = ipp_args[0]
      f = ipp_args[1]
      proc = ex(:PROC.up, f); args = ex(:ARGS.up, f)
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)
      
      if !proc_bang.closure_d?
        raise_error(self, "function expected but was given #{proc_bang.down.to_s}!")
      elsif proc_bang.down.reflective?
        ipp_args = [proc_bang.down.de_reflect, args, env, cont]
        ipp_proc = :"&&CALL"
      else
        cont = make_args_continuation(proc_bang, proc, args, env, cont)
        ipp_args = [args]
        ipp_proc = :"&&NORMALISE"
      end
		
    when :"&&ARGS-CONTINUATION"			# state args! proc! proc args env cont
      args_bang = ipp_args[0]
      f = ipp_args[1]
      proc_bang = ex(:"PROC!".up, f); # proc = ex(:PROC.up, f); args = ex(:ARGS.up, f)
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)
      if primitive?(proc_bang.down)
        ipp_args = [cont, ruby_lambda_for_primitive(proc_bang.down).call(args_bang.down).up]
        ipp_proc = :"&&CALL"
		  else
        ipp_args = [proc_bang, args_bang]
        ipp_proc = :"&&EXPAND-CLOSURE"
      end


    when :"&&EXPAND-CLOSURE"				# state proc! args! cont
      proc_bang = ipp_args[0]; args_bang = ipp_args[1]
      if ppp_type(proc_bang.down) == :"&&NORMALISE" && plausible_arguments_to_normalise?(args_bang)
        state = shift_down(cont, state)
        ipp_args = [args_bang.first.down]
        env = args_bang.second.down
        cont = args_bang.third.down
        ipp_proc = :"&&NORMALISE"
        next
      end
		
      ipp_proc = ppc_type(proc_bang.down)
      if ipp_proc != :"UNKNOWN" && plausible_arguments_to_a_continuation?(args_bang)
        state = shift_down(cont, state)
        ipp_args = [args_bang.first.down, proc_bang.down]
		    next
		  end
		   
      ipp_args = [proc_bang.down.body.up]
      env = proc_bang.down.environment.bind_pattern(proc_bang.down.pattern.up, args_bang)
      ipp_proc = :"&&NORMALISE"		


    when :"&&NORMALISE-RAIL"				# state rail env cont
      rail = ipp_args[0]
      if rail.empty? then 
        ipp_args = [cont, rail]
        ipp_proc = :"&&CALL"
      else 
        ipp_args = [rail.first]
        cont = make_first_continuation(rail, env, cont)
        ipp_proc = :"&&NORMALISE"
      end
		
    when :"&&FIRST-CONTINUATION"			# state first! rail env cont
      first_bang = ipp_args[0]
      f = ipp_args[1]
      rail = ex(:RAIL.up, f);
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)

      cont = make_rest_continuation(first_bang, rail, env, cont)
      ipp_args = [rail.rest]
      ipp_proc = :"&&NORMALISE-RAIL"
		
    when :"&&REST-CONTINUATION"			# state rest! first! rail env cont
      rest_bang = ipp_args[0]
      f = ipp_args[1]
      first_bang = ex(:"FIRST!".up, f)
#      rail = ex(:"RAIL".up, f)
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)
      ipp_args = [cont, rest_bang.prep(first_bang)]
      ipp_proc = :"&&CALL"
		
		
    when :"&&LAMBDA"						# state [kind pattern body] env cont
      kind = ipp_args[0].first; pattern = ipp_args[0].second; body = ipp_args[0].third;

# simple version: implementation paper
#      ipp_args = [cont, Closure.new(kind, env, pattern, body).up]
#      ipp_proc = :"&&CALL"

# Manual version
      ipp_args = [kind, Rail.new(env.up, pattern, body).up]
      ipp_proc = :"&&REDUCE"

    when :"&&IF"							# state [premise c1 c2] env cont
      premise = ipp_args[0].first; c1 = ipp_args[0].second; c2 = ipp_args[0].third
      cont = make_if_continuation(premise, c1, c2, env, cont)
      ipp_args = [premise]
      ipp_proc = :"&&NORMALISE"

    when :"&&IF-CONTINUATION"				# state premise! premise c1 c2 env cont
      premise_bang = ipp_args[0]; 
      f = ipp_args[1]
#      premise = ex(:PREMISE.up, f)
      c1 = ex(:C1.up, f)
      c2 = ex(:C2.up, f)
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)
      
      raise_error(self, "IF expects a truth value but was give #{premise_bang.down}") if !premise_bang.down.boolean?
      ipp_args = [premise_bang.down ? c1 : c2]
      ipp_proc = :"&&NORMALISE"

    when :"&&BLOCK"						# state clauses env cont
      clauses = ipp_args[0]
      if clauses.length != 1
        cont = make_block_continuation(clauses, env, cont)
      end
      ipp_args = [clauses.first]
      ipp_proc = :"&&NORMALISE"

    when :"&&BLOCK-CONTINUATION"			# state 1st-clause! clauses env cont
      f = ipp_args[1]
      clauses = ex(:CLAUSES.up, f)
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)
      ipp_args = [pcons(:BLOCK.up, clauses.rest)]
      ipp_proc = :"&&NORMALISE"

    when :"&&COND"						# state clauses env cont
      clauses = ipp_args[0]
      if clauses.empty?
        raise_error(self, "COND expects at least one clause");
      else
        ipp_args = [clauses.first.first]
        cont = make_cond_continuation(clauses, env, cont)
        ipp_proc = :"&&NORMALISE"
      end

    when :"&&COND-CONTINUATION"			# state 1st-condition! clauses env cont
      first_condition_bang = ipp_args[0]
      f = ipp_args[1]
      clauses = ex(:CLAUSES.up, f)
      env = ex(:ENV.up, f)
      cont = ex(:CONT.up, f)
      if first_condition_bang.down
        ipp_args = [clauses.first.second]
      else
        ipp_args = [pcons(:COND.up, clauses.rest)]
      end
      ipp_proc = :"&&NORMALISE"

		
    when :"&&CALL"						# state f a
      f = ipp_args[0]
      a = ipp_args[1..-1]
      
      ipp_proc = ppp_type(f)
      if ipp_proc != :"UNKNOWN"
        ipp_args = a
        next 
      end

      ipp_proc = ppc_type(f)  
      if ipp_proc != :"UNKNOWN"
        ipp_args = [a.first, f]
        next
      end
		
      if primitive?(f)
        ipp_args = [reify_continuation(state), primitive_lambda(f).call(Rail.new(*a)).up] 
        state = shift_up(state)
        ipp_proc = :"&&CALL"
        next
      end
        
      ipp_args = [f.body.up]
      
      env = f.environment.bind_pattern(f.pattern.up, Rail.new(*a).up)
      cont = reify_continuation(state)
      state = shift_up(state)

      ipp_proc = :"&&NORMALISE" # this does what the 3rd clause of the cond of &&EXPAND-CLOSURE does
		
    else
      raise_error(self, "Implementation error: control has left the IPP");
    end
  end
rescue RuntimeError, ZeroDivisionError => detail
  print "3-Lisp run-time error: " + detail.message + "\n" 
  retry
end
end

threeLisp

