# encoding: UTF-8

require './3LispInternaliser.rb'

module ThreeLispKernel
  $ppc_t_a = Handle.new(:"\?")  # ppc template argument
  PPP_TABLE = []
  PPC_TEMPLATES = {}
  PPC_TABLE = []
    
  KERNEL_UTILITY_PARTS = [
    [:"1ST", :SIMPLE, Rail.new(:VEC), "(nth 1 vec)"],
  
    [:"2ND", :SIMPLE, Rail.new(:VEC), "(nth 2 vec)"],
  
    [:"ATOM", :SIMPLE, Rail.new(:EXP), "(= (type exp) 'atom)"],
  
    [:"DE-REFLECT", :SIMPLE, Rail.new(:CLOSURE), "
      (ccons 'simple (environment-designator closure) (pattern closure) (body closure))
    "],
    
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
  ]

  def initialize_kernel_utilities(env, parser)
    KERNEL_UTILITY_PARTS.each {|e|
      env.rebind_one(e[0].up, Closure.new(e[1], env, e[2], parser.parse(e[3]).first).up)
    }
  end

  RPP_PROC_PARTS = 
  {
    :"READ-NORMALISE-PRINT" => [
      :SIMPLE, Rail.new(:LEVEL, :ENV),
      "
        (normalise (prompt&read level) env
          (lambda simple [result]                   ; REPLY continuation
            (block (prompt&reply result level)
              (read-normalise-print level env))))
      "
    ],
  
    :"NORMALISE" => [
      :SIMPLE, Rail.new(:EXP, :ENV, :CONT),
      "
         (cond [(normal exp) (cont exp)]
               [(atom exp) (cont (binding exp env))]
               [(rail exp) (normalise-rail exp env cont)]
               [(pair exp) (reduce (car exp) (cdr exp) env cont)])
      "
    ],
  
    :"REDUCE" => [
      :SIMPLE, Rail.new(:PROC, :ARGS, :ENV, :CONT),
      "
        (normalise proc env
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
      "
    ],
  
    :"NORMALISE-RAIL" => [
      :SIMPLE, Rail.new(:RAIL, :ENV, :CONT),
      "
        (if (empty rail)
             (cont (rcons))
             (normalise (1st rail) env
                        (lambda simple [first!]            ; FIRST continuation
                          (normalise-rail (rest rail) env
                                          (lambda simple [rest!]         ; REST continuation
                                            (cont (prep first! rest!)))))))
      "
    ],
  
    :"LAMBDA" => [
      :REFLECT, Rail.new(Rail.new(:KIND, :PATTERN, :BODY), :ENV, :CONT),
      "
        (reduce kind ↑[↑env pattern body] env cont)
      "
    ],
  
    :"IF" => [
      :REFLECT, Rail.new(Rail.new(:PREMISE, :C1, :C2), :ENV, :CONT),
      "
        (normalise premise env
                    (lambda simple [premise!]
                      (normalise (ef ↓premise! c1 c2) env cont)))
      "
    ],
  
    :"BLOCK" => [
      :REFLECT, Rail.new(:CLAUSES, :ENV, :CONT),
      "
        (if (unit clauses)
            (normalise (1st clauses) env cont)
  		      (normalise (1st clauses) env
  					   (lambda simple arg
  					     (normalise (pcons 'block (rest clauses)) env cont))))
      "
    ],
  
    :"COND" => [
      :REFLECT, Rail.new(:CLAUSES, :ENV, :CONT),
      "
        (if (empty clauses)
            (cont 'error)
            (normalise (1st (1st clauses)) env
  			               (lambda simple [1st-condition!]                 ; COND continuation
                          (if ↓1st-condition! 
                              (normalise (2nd (1st clauses)) env cont)
                              (normalise (pcons 'cond (rest clauses)) env cont)))))
      "
    ]
  }
  
  def initialize_ppp_table(env, parser)
    RPP_PROC_PARTS.keys.each {|name|
      parts = RPP_PROC_PARTS[name]
      closure = Closure.new(parts[0], env, parts[1], parser.parse(parts[2]).first)
      env.rebind_one(name.up, closure.up)
      PPP_TABLE.push([("&&" + name.to_s).to_sym, closure.reflective? ? closure.de_reflect : closure])
    }
  end 
      
  RAW_PPC_TEMPLATES =
  {
    :"&&REPLY-CONTINUATION"=> [
      Rail.new(:LEVEL, :ENV), 
      Rail.new(:"RESULT"),
      "
        (block (prompt&reply result level)
          (read-normalise-print level env))
      "
    ],
  
    :"&&PROC-CONTINUATION" => [
      Rail.new(:PROC, :ARGS, :ENV, :CONT),
      Rail.new(:"PROC!"),
      "
        (if (reflective proc!)
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
      "
    ],
      
    :"&&ARGS-CONTINUATION" => [
      Rail.new(:"PROC!", :PROC, :ARGS, :ENV, :CONT),
      Rail.new(:"ARGS!"),
      "
        (if (primitive proc!)  ; HUP new draft misses the quote
            (cont ↑(↓proc! . ↓args!))
            (normalise (body proc!)
                       (bind (pattern proc!)
                             args!
                             (environment-of proc!))
                       cont))        
      "
    ],
      
    :"&&FIRST-CONTINUATION" => [
      Rail.new(:RAIL, :ENV, :CONT),
      Rail.new(:"FIRST!"),
      "
        (normalise-rail (rest rail) env
                        (lambda [rest!]
                          (cont (prep first! rest!))))
     "
    ],
      
    :"&&REST-CONTINUATION" => [
      Rail.new(:"FIRST!", :RAIL, :ENV, :CONT),
      Rail.new(:"REST!"),
      "
        (cont (prep first! rest!))
      "
    ],
      
    :"&&IF-CONTINUATION" => [
      Rail.new(:PREMISE, :C1, :C2, :ENV, :CONT),
      Rail.new(:"PREMISE!"),
      "
        (normalise (ef ↓premise! c1 c2) env cont)      
      "
    ],
      
    :"&&BLOCK-CONTINUATION" => [
      Rail.new(:CLAUSES, :ENV, :CONT),
      :"\?", # no arguments
      "
        (normalise (pcons 'block (rest clauses)) env cont)
      "
    ],
      
    :"&&COND-CONTINUATION" => [
      Rail.new(:CLAUSES, :ENV, :CONT),
      Rail.new(:"1st-condition!"),
      "
        (if ↓1st-condition!
            (normalise (2nd (1st clauses)) env cont)
            (normalise (pcons 'cond (rest clauses)) env cont)) 
      "
    ]
  }
  
  def initialize_ppc_templates_and_table(env, parser)
    RAW_PPC_TEMPLATES.keys.each {|name|
      parts = RAW_PPC_TEMPLATES[name]
      PPC_TEMPLATES[name] = [parts[0], Closure.new(:SIMPLE, env, parts[1], parser.parse(parts[2]).first)]
    }

    [
      [:"&&PROC-CONTINUATION", make_proc_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a, $ppc_t_a)],
      [:"&&ARGS-CONTINUATION", make_args_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a, $ppc_t_a, $ppc_t_a)],
      [:"&&FIRST-CONTINUATION", make_first_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a)],
      [:"&&REST-CONTINUATION", make_rest_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a, $ppc_t_a)],
      [:"&&REPLY-CONTINUATION", make_reply_continuation($ppc_t_a, $ppc_t_a)],
      [:"&&IF-CONTINUATION", make_if_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a, $ppc_t_a, $ppc_t_a)],
      [:"&&BLOCK-CONTINUATION", make_block_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a)],
      [:"&&COND-CONTINUATION", make_cond_continuation($ppc_t_a, $ppc_t_a, $ppc_t_a)],
    ].each {|e|
      PPC_TABLE.push(e)
    }
    
  end
  
  def make_rpp_continuation(cont_name, args)
    template = PPC_TEMPLATES[cont_name]
    Closure.new(template[1].kind, 
                template[1].environment.bind_pattern(template[0].up, args.up), 
                template[1].pattern,
                template[1].body)
  end  
    
  def make_reply_continuation(level, env)
    local_args = Rail.new(level, env)
    make_rpp_continuation(:"&&REPLY-CONTINUATION", local_args)
  end
    
  def make_proc_continuation(proc, args, env, cont)
    local_args = Rail.new(proc, args, env, cont)
    make_rpp_continuation(:"&&PROC-CONTINUATION", local_args)
  end
  
  def make_args_continuation(proc_bang, proc, args, env, cont)
    local_args = Rail.new(proc_bang, proc, args, env, cont)
    make_rpp_continuation(:"&&ARGS-CONTINUATION", local_args)
  end
    
  def make_first_continuation(rail, env, cont)
    local_args = Rail.new(rail, env, cont)
    make_rpp_continuation(:"&&FIRST-CONTINUATION", local_args)
  end
    
  def make_rest_continuation(first_bang, rail, env, cont)
    local_args = Rail.new(first_bang, rail, env, cont)
    make_rpp_continuation(:"&&REST-CONTINUATION", local_args)
  end
    
  def make_if_continuation(premise, c1, c2, env, cont)
    local_args = Rail.new(premise, c1, c2, env, cont)
    make_rpp_continuation(:"&&IF-CONTINUATION", local_args)
  end
    
  def make_block_continuation(clauses, env, cont)
    local_args = Rail.new(clauses, env, cont)
    make_rpp_continuation(:"&&BLOCK-CONTINUATION", local_args)
  end
    
  def make_cond_continuation(clauses, env, cont)
    local_args = Rail.new(clauses, env, cont)
    make_rpp_continuation(:"&&COND-CONTINUATION", local_args)
  end
  
  def ex(variable, closure)
    closure.environment.binding(variable).down
  end
  
  def identify_closure(closure, table)
    table.each {|c| 
      return c[0] if closure.similar?(c[1]) 
    }
  	
  	return :UNKNOWN
  end
    
  def ppp_type(closure)
    identify_closure(closure, PPP_TABLE)
  end
    
  def ppc_type(closure)
=begin
    PPC_TABLE.each {|c| 

    if closure.similar?(c[1])
      print "object_id: " + closure.object_id.to_s + " vs. " + c[1].object_id.to_s
      puts
      print "kind: " + closure.kind.object_id.to_s + " vs. " + c[1].kind.object_id.to_s
      puts
      print "environment: " + closure.environment.object_id.to_s + " vs. " + c[1].environment.object_id.to_s
      puts
      print "pattern: " + closure.pattern.object_id.to_s + " vs. " + c[1].pattern.object_id.to_s
      puts
      print "body: " + closure.body.object_id.to_s + " vs. " + c[1].body.object_id.to_s
      puts
      print closure.to_s + "\n"
      print c[1].to_s + "\n"
      puts
      
      return c[0]
    end
    }
  	return :UNKNOWN
=end
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

  def initialize_kernel(env, parser)
    initialize_kernel_utilities(env, parser)
    initialize_ppp_table(env, parser)
    initialize_ppc_templates_and_table(env, parser)
  end
end # module ThreeLispKernel

