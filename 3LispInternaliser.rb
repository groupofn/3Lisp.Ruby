# encoding: UTF-8

require 'set'
require './3LispClasses.rb'
require './3LispError.rb'

### Ruby constants for reserved characters ###

# Spaces

SPACE = " "
TAB = "\t"
NEWLINE = "\n"
CARRIAGE_RETURN = "\r"
SPACES = Set.new [SPACE, NEWLINE, CARRIAGE_RETURN, TAB]

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

SPECIAL = Set.new [PAIR_START, PAIR_END, RAIL_START, RAIL_END, PAIR_BREAK, NAME_START, UP, DOWN, QUOTE, BACKQUOTE, COMMA, 
           STRING_START, STRING_END]

# Numeral

PLUS = "+"
MINUS = "-"

SIGNS = Set.new [PLUS, MINUS]
DIGITS = Set.new ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

class ThreeLispInternaliser
  include ThreeLispError
  
  attr_accessor :source, :line, :column
  
  def initialize
    self.source, self.line, self.column = nil, 0, 0, 0
  end

  class CommaExpression
    attr_accessor :exp

    def initialize(exp)
      @exp = exp
    end
  end

  def skip_to_eol
    while !source.empty? && source[0] != NEWLINE
      source.slice!(0)
      self.column += 1
    end
  end
  
  def separator?(ch)
    ch == SPACE || ch == NEWLINE || ch == COMMENT_START || ch == CARRIAGE_RETURN || ch == TAB
  end
  
  def special?(ch)
    ch == PAIR_START || ch == PAIR_END || ch == RAIL_START || ch == RAIL_END || ch = PAIR_BREAK || ch == NAME_START ||
    ch == UP || ch == DOWN || ch == QUOTE || ch == BACKQUOTE || ch == COMMA || ch == STRING_START || ch == STRING_END
  end
  
  def sign?(ch)
    ch == MINUS || ch == PLUS
  end
  
  def digit?(ch)
    ch == "0" || ch == "1" || ch == "2" || ch == "3" || ch == "4" ||
    ch == "5" || ch == "6" || ch == "7" || ch == "8" || ch == "9"
  end

  def skip_separators
#    while !source.empty? && separator?(source[0]) 
    while !source.empty? && SEPARATORS.include?(source[0])
      @ch = source.slice!(0)
      if @ch == NEWLINE
        self.line += 1; 
        self.column = 1
      elsif @ch == COMMENT_START
        self.column += 1;
        skip_to_eol
      else
        self.column += 1
      end
    end
  end

  def internalise_string
    s = ""
    while !source.empty? && source[0] != STRING_END
      s << @ch = source.slice!(0)
      if @ch == NEWLINE # there is a potential problem here in "\n"
        self.line += 1; 
        self.column = 1
      else
        self.column += 1
      end
    end
    raise_error(self, "Line #{line} Column #{column}: " << STRING_END << " expected.", ThreeLispSyntaxError) if source.empty?
    source.slice!(0); self.column += 1 # absorb STRING_END
    return s
  end

  def internalise_pair(bqlevel)
    skip_separators
    raise_error(self, "Line #{line} Column #{column}: expression expected", ThreeLispSyntaxError) if source.empty?
 
    car = internalise_exp(bqlevel)
    skip_separators
    raise_error(self, "Line #{line} Column #{column}: expression expected", ThreeLispSyntaxError) if source.empty?
 
    if source[0] == PAIR_BREAK
      source.slice!(0)
      self.column += 1
      skip_separators
      cdr = internalise_exp(bqlevel)
      skip_separators
      if source.empty? || source[0] != PAIR_END
        raise_error(self, "Line #{line} Column #{column}: " << PAIR_END << " expected.", ThreeLispSyntaxError) 
      end
    elsif source[0] == PAIR_END
      cdr = Rail.new
    else
      cdr = internalise_rail(bqlevel, PAIR_END)
    end
    source.slice!(0); self.column += 1  # absorb PAIR_END
    Pair.new(car, cdr)
  end

  def internalise_rail(bqlevel, ending="")
    exps = Rail.new
    while !source.empty?
      skip_separators
      if source.empty?
        if ending.length > 0        
          raise_error(self, "End of input reached while expecting '" << ending << "'.", ThreeLispSyntaxError)
        else
          return exps
        end
      elsif ending.length > 0 && source[0] == ending
        if ending == RAIL_END
          source.slice!(0); self.column += 1
        end
        break
      else
        exps.append!(internalise_exp(bqlevel))
      end
    end
    exps 
  end
  
  def internalise_exp(bqlevel)
    @ch = source.slice!(0); self.column += 1
    case @ch
    when PAIR_START
      result = internalise_pair(bqlevel)
    when RAIL_START
      result = internalise_rail(bqlevel, RAIL_END)
    when QUOTE
      result = Handle.new(internalise_exp(bqlevel))
    when UP
      result = Pair.new(:UP, Rail.new(internalise_exp(bqlevel)))
    when DOWN
      result = Pair.new(:DOWN, Rail.new(internalise_exp(bqlevel)))    
    when NAME_START
      n = "" << @ch
      
      while !source.empty? && !SEPARATORS.include?(source[0]) && !SPECIAL.include?(source[0])        
#      while !source.empty? && !separator?(source[0]) && !special?(source[0])        
        n << source.slice!(0); self.column += 1 
      end

      if n.upcase == TRUE_NAME
        result = true
      elsif n.upcase == FALSE_NAME 
        result = false 
      else
        # this will be where other names are handled
      end
    when STRING_START
      result = internalise_string
    when COMMA
      raise_error(self, "Line #{line} Column #{column}: ',' has no matching '`'.", ThreeLispSyntaxError) if bqlevel < 1
      result = CommaExpression.new(internalise_exp(bqlevel-1)) # no space between comma and what's comma-ed
    when BACKQUOTE # no space between backquote and what's quoted
      exp = internalise_exp(bqlevel+1)
      result = process_bq(exp)
    else # atom or numeral
      init_char = @ch
      s = "" << @ch
      
      digits_only = true
      while !source.empty? && !SEPARATORS.include?(source[0]) && !SPECIAL.include?(source[0])
#      while !source.empty? && !separator?(source[0]) && !special?(source[0])
         s << @ch = source.slice!(0); self.column += 1 
        digits_only = false if !DIGITS.include?(@ch)
#        digits_only = false if !digit?(@ch)
      end

      if digits_only && (DIGITS.include?(init_char) || (SIGNS.include?(init_char) && s.length > 1))
#      if digits_only && (digit?(init_char) || (sign?(init_char) && s.length > 1))
        result = s.to_i
      else 
        result = s.upcase.to_sym
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
  (lambda simple [read-prompt reply-prompt env]
    (normalise (prompt&read read-prompt) env
      (lambda simple [result]                         ; REPLY continuation
         (block (prompt&reply result reply-prompt)
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
                                        (bind (pattern proc!) args! (environment-of proc!))
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
    (reduce kind ↑[↑env pattern body] env cont)))    ; env is normal form

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
          (lambda simple arg                           ; BLOCK continuation
            (normalise (pcons 'block (rest clauses)) env cont)))))) 

(define COND
  (lambda reflect [clauses env cont]
    (if (empty clauses)
        (cont 'error)
        (normalise (1st (1st clauses)) env
          (lambda simple [1st-condition!]             ; COND continuation
            (if ↓1st-condition!                       
                (normalise (2nd (1st clauses)) env cont)
                (normalise (pcons 'cond (rest clauses)) env cont)))))))
 
;;;;;; End of the RPP ;;;;;;
")

=end

# 



