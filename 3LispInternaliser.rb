# encoding: UTF-8

require './3LispClasses.rb'
require './3LispError.rb'

### Ruby constants for reserved characters ###

# Spaces

SPACE = " "
TAB = "\t"
NEWLINE = "\n"
CARRIAGE_RETURN = "\r"
SPACES = [SPACE, TAB, NEWLINE, CARRIAGE_RETURN]

COMMENT_START = ";"
SEPARATORS = SPACES + [COMMENT_START]

# Special

PAIR_START = "("
PAIR_BREAK = "."
PAIR_END = ")"
RAIL_START = "["
RAIL_END = "]"
QUOTE = "'"
BACKQUOTE = "`"
COMMA = ","

STRING_START = "\""
STRING_END = "\""
NAME_START = "$"

UP = "↑"   # unicode 0x2191
DOWN = "↓" # unicode 0x2193

TRUE_NAME = "$T"
FALSE_NAME = "$F"

SPECIAL = [PAIR_START, PAIR_BREAK, PAIR_END, RAIL_START, RAIL_END, QUOTE, BACKQUOTE, COMMA, 
           STRING_START, STRING_END, NAME_START, UP, DOWN]

# Numeral

PLUS = "+"
MINUS = "-"

SIGNS = [PLUS, MINUS]
DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

class ThreeLispInternaliser
  include ThreeLispError
  
  attr_accessor :source, :index, :line, :column
  
  def initialize
    self.source, self.index, self.line, self.column = nil, 0, 0, 0
  end

  class CommaExpression
    attr_accessor :exp

    def initialize(exp)
      @exp = exp
    end
  end

  def skip_to_eol
    while index < source.length && source[index] != NEWLINE
      self.index += 1
      self.column += 1
    end
  end

  def skip_separators
    while index < source.length && SEPARATORS.include?(source[index])
      if source[index] == NEWLINE
        self.index += 1; 
        self.line += 1; 
        self.column = 1
      elsif source[index] == COMMENT_START
        self.index += 1;
        self.column += 1;
        skip_to_eol
      else
        self.index += 1; 
        self.column += 1
      end
    end
  end

  def internalise_string
    start = index
    while index < source.length && source[index] != STRING_END
      if source[index] == NEWLINE
        self.line += 1; 
        self.column = 1
      else
        self.column += 1
      end
      self.index += 1
    end
    raise_error(self, "Line #{line} Column #{column}: " + STRING_END + " expected.", ThreeLispSyntaxError) if index == source.length
    self.index += 1; self.column += 1 # absorb STRING_END
    source[start..index-2]
  end

  def internalise_pair(bqlevel)
    skip_separators
    raise_error(self, "Line #{line} Column #{column}: expression expected", ThreeLispSyntaxError) if index == source.length
 
    car = internalise_exp(bqlevel)
    skip_separators
    raise_error(self, "Line #{line} Column #{column}: expression expected", ThreeLispSyntaxError) if index == source.length
 
    if source[index] == PAIR_BREAK
      self.index += 1; self.column += 1
      skip_separators
      cdr = internalise_exp(bqlevel)
      skip_separators
      if index == source.length || source[index] != PAIR_END
        raise_error(self, "Line #{line} Column #{column}: " + PAIR_END + " expected.", ThreeLispSyntaxError) 
      end
      self.index += 1; self.column += 1  # absorb PAIR_END
    elsif source[index] == PAIR_END
      cdr = Rail.new
      self.index += 1; self.column += 1  # absorb PAIR_END
    else
      cdr = internalise_rail(bqlevel, PAIR_END)
      self.index += 1; self.column += 1  # absorb PAIR_END
    end
    Pair.new(car, cdr)
  end

  def internalise_rail(bqlevel, ending="")
    exps = Rail.new
    while index < source.length
      skip_separators
      if index == source.length
        if ending.length > 0        
          raise_error(self, "End of input reached while expecting '" + ending + "'.", ThreeLispSyntaxError)
        else
          return exps
        end
      elsif ending.length > 0 && source[index] == ending
        if ending == RAIL_END
          self.index += 1; self.column += 1
        end
        break
      else
        exps.append!(internalise_exp(bqlevel))
      end
    end
    exps 
  end
  
  def internalise_exp(bqlevel)
    case source[index]
    when PAIR_START
      self.index += 1; self.column += 1
      result = internalise_pair(bqlevel)
    when RAIL_START
      self.index += 1; self.column += 1
      result = internalise_rail(bqlevel, RAIL_END)
    when QUOTE
      self.index += 1; self.column += 1 
      result = Handle.new(internalise_exp(bqlevel))
    when UP
      self.index += 1; self.column += 1 
      result = Pair.new(:UP, Rail.new(internalise_exp(bqlevel)))
    when DOWN
      self.index += 1; self.column += 1 
      result = Pair.new(:DOWN, Rail.new(internalise_exp(bqlevel)))    
    when NAME_START
      self.index += 1; self.column += 1 
      start = index - 1
      
      while index < source.length && !SEPARATORS.include?(source[index]) && !SPECIAL.include?(source[index])        
        self.index += 1; self.column += 1 
      end

      if source[start..index-1].upcase == TRUE_NAME
        result = true
      elsif source[start..index-1].upcase == FALSE_NAME 
        result = false 
      else
        # this will be where other names are handled
      end
    when STRING_START
      self.index += 1; self.column += 1 
      result = internalise_string
    when COMMA
      self.index += 1; self.column += 1
      raise_error(self, "Line #{line} Column #{column}: ',' has no matching '`'.", ThreeLispSyntaxError) if bqlevel < 1
      result = CommaExpression.new(internalise_exp(bqlevel-1)) # no space between comma and what's comma-ed
    when BACKQUOTE
      self.index += 1; self.column += 1   # no space between backquote and what's quoted
      exp = internalise_exp(bqlevel+1)
      result = process_bq(exp)
    else # atom or numeral 
      start = index
      
      if SIGNS.include?(source[index])
        self.index += 1; self.column += 1 
      end
      
      is_numeral = true;
      while index < source.length && !SEPARATORS.include?(source[index]) && !SPECIAL.include?(source[index])        
        is_numeral = false if !DIGITS.include?(source[index])
        self.index += 1; self.column += 1 
      end
      
      raise_error(self, "Line #{line} Column #{column}: expression expected.", ThreeLispSyntaxError) if index == start

      if is_numeral && !SIGNS.include?(source[start..index-1])
        result = source[start..index-1].to_i
      else 
        result = source[start..index-1].upcase.to_sym
      end
    end
    
    result
  end

  def process_bq(exp)
    if exp.class == CommaExpression
      exp.exp
    elsif exp.class == Pair
      Pair.new(:PCONS, Rail.new(process_bq(exp.car), process_bq(exp.cdr)))
    elsif exp.class == Rail
      Pair.new(:RCONS, exp.map{|e| process_bq(e)})
    else
      Handle.new(exp)
    end
  end

  def parse(source)
    self.index = 0
    self.line = 1
    self.column = 1
    self.source = source
    
    internalise_rail(0)
  end
end

### Sample Use ###
#

=begin

parser = ThreeLispInternaliser.new
parser.parse(IO.read("RPP.3lisp").to_s

# or 

parser.parse("
;;;;;; the 3-Lisp Reflective Processor Program  ;;;;;;

(define READ-NORMALISE-PRINT
  (lambda simple [level env]
    (normalise (prompt&read level) env
      (lambda simple [result]                         ; REPLY continuation
         (block (prompt&reply result level)
                (read-normalise-print level env))))))

(define NORMALISE
  (lambda simple [exp env cont]
    (cond [(normal exp) (cont exp)]
          [(atom exp) (cont (binding exp env))]
          [(rail exp) (normalise-rail exp env cont)]
          [(pair exp) (reduce (car exp) (cdr exp) env cont)])))

(define REDUCE
  (lambda simple [proc args env cont]
    (normalise proc env
      (lambda simple [proc!]                          ; PROC continuation
        (if (reflective proc!)
            (↓(de-reflect proc!) args env cont)
            (normalise args env
                       (lambda simple [args!]         ; ARGS continuation
                         (if (primitive proc!)
                             (cont ↑(↓proc! . ↓args!))
                             (normalise (body proc!)
                                        (bind (pattern proc!) args! (environment proc!))
                                        cont)))))))))

(define NORMALISE-RAIL
  (lambda simple [rail env cont]
    (if (empty rail)
        (cont (rcons))
        (normalise (1st rail) env
                   (lambda simple [first!]            ; FIRST continuation
                     (normalise-rail (rest rail) env
                       (lambda simple [rest!]         ; REST continuation
                         (cont (prep first! rest!)))))))))

(define LAMBDA
  (lambda reflect [[kind pattern body] env cont]
    (cont (ccons kind env pattern body))))            ; env is normal form

(define IF
  (lambda reflect [[premise c1 c2] env cont]
    (normalise premise env
      (lambda simple [premise!]                       ; IF continuation
        (normalise (ef ↓premise! c1 c2) env cont)))))        

(define BLOCK
  (lambda reflect [clauses env cont]
    (if (unit clauses)
        (normalise (1st clauses) env cont)
        (normalise (1st clauses) env
          (lambda simple []                           ; BLOCK continuation
            (normalise (pcons 'block (rest clauses)) env cont)))))) 

(define COND
  (lambda reflect [clauses env cont]
    (if (empty clauses)
        (cont 'error)
        (normalise (1st (1st clauses)) env
          (lambda simple [1st-condition!]             ; COND continuation
            (if ↓1st-condition!                       ; would ef work here? ... no! 
                (normalise (2nd (1st clauses)) env cont)
                (normalise (pcons 'cond (rest clauses)) env cont)))))))
 
;;;;;; End of the RPP ;;;;;;
")

=end

# 



