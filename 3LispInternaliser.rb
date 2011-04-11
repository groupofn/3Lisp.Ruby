# encoding: UTF-8

require './3LispClasses.rb'

SPACE = " "
TAB = "\t"
NEWLINE = "\n"
CARRIAGE_RETURN = "\r"
SPACES = [SPACE, TAB, NEWLINE, CARRIAGE_RETURN]

COMMENT_START = ";"
SEPARATORS = SPACES + [COMMENT_START]

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

PLUS = "+"
MINUS = "-"

SPECIAL = [PAIR_START, PAIR_BREAK, PAIR_END, RAIL_START, RAIL_END, QUOTE, BACKQUOTE, COMMA, 
           STRING_START, STRING_END, NAME_START, UP, DOWN]
SIGNS = [PLUS, MINUS]
DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

TRUE_NAME = "$T"
FALSE_NAME = "$F"

class CommaExpression
  attr_accessor :exp

  def initialize(exp)
    @exp = exp
  end
end

class ThreeLispInternaliser

  def skip_to_eol
    while $index < $source.length && $source[$index] != NEWLINE
      $index += 1
      $column += 1
    end
  end

  def skip_separators
    while $index < $source.length && SEPARATORS.include?($source[$index])
      if $source[$index] == NEWLINE
        $index += 1; 
        $line += 1; 
        $column = 1
      elsif $source[$index] == COMMENT_START
        $index += 1;
        $column += 1;
        skip_to_eol
      else
        $index += 1; 
        $column += 1
      end
    end
  end

  def internalise_string
    start = $index
    while $index < $source.length && $source[$index] != STRING_END
      if $source[$index] == NEWLINE
        $line += 1; 
        $column = 1
      else
        $column += 1
      end
      $index += 1
    end
    raise("Line #{$line} Column #{$column}: " + STRING_END + " expected.") if $index == $source.length
    $index += 1; $column += 1 # skip over STRING_END
    $source[start..$index-2]
  end

  def internalise_pair(bqlevel)
    skip_separators
    raise("Line #{$line} Column #{$column}: expression expected") if $index == $source.length
 
    car = internalise_exp(bqlevel)
#    print "car: "; p car
    skip_separators
    raise("Line #{$line} Column #{$column}: expression expected") if $index == $source.length
 
    if $source[$index] == PAIR_BREAK
      $index += 1; $column += 1
      skip_separators
      cdr = internalise_exp(bqlevel)
      skip_separators
      if $index == $source.length || $source[$index] != PAIR_END
        raise("Line #{$line} Column #{$column}: " + PAIR_END + " expected.") 
      end
      $index += 1; $column += 1  # absorb PAIR_END
    elsif $source[$index] == PAIR_END
      cdr = Rail.new
      $index += 1; $column += 1  # absorb PAIR_END
    else
      cdr = internalise_rail(bqlevel, PAIR_END)
      $index += 1; $column += 1  # absorb PAIR_END
    end
    Pair.new(car, cdr)
  end

  def internalise_rail(bqlevel, ending="")
    exps = Rail.new
    while $index < $source.length
      skip_separators
      if $index == $source.length
        if ending.length > 0        
          raise("End of input reached while expecting '" + ending + "'.")
        else
          return exps
        end
      elsif ending.length > 0 && $source[$index] == ending
        if ending == RAIL_END
          $index += 1; $column += 1
        end
        break
      else
        exps.append!(internalise_exp(bqlevel))
      end
    end
    exps 
  end
  
  def internalise_exp(bqlevel)
#  print "$source[$index]: "; p $source[$index]
    case $source[$index]
    when PAIR_START
      $index += 1; $column += 1
      result = internalise_pair(bqlevel)
    when RAIL_START
      $index += 1; $column += 1
      result = internalise_rail(bqlevel, RAIL_END)
    when QUOTE
      $index += 1; $column += 1 
      result = Handle.new(internalise_exp(bqlevel))
    when UP
      $index += 1; $column += 1 
      result = Pair.new(:UP, Rail.new(internalise_exp(bqlevel)))
    when DOWN
      $index += 1; $column += 1 
      result = Pair.new(:DOWN, Rail.new(internalise_exp(bqlevel)))    
    when NAME_START
      $index += 1; $column += 1 
      start = $index - 1
      
      while $index < $source.length && !SEPARATORS.include?($source[$index]) && !SPECIAL.include?($source[$index])        
        $index += 1; $column += 1 
      end

      if $source[start..$index-1].upcase == TRUE_NAME
        result = true
      elsif $source[start..$index-1].upcase == FALSE_NAME 
        result = false 
      else
        # this will be where other constants are handled
      end
    when STRING_START
      $index += 1; $column += 1 
      result = internalise_string
    when COMMA
      $index += 1; $column += 1
      raise("Line #{$line} Column #{$column}: ',' has no matching '`'.") if bqlevel < 1
      result = CommaExpression.new(internalise_exp(bqlevel-1)) # no space between comma and what's comma-ed
    when BACKQUOTE
      $index += 1; $column += 1   # no space between backquote and what's quoted
      exp = internalise_exp(bqlevel+1)
      result = process_bq(exp)
    else # atom or numeral 
      start = $index
#      print "a or n"; p $index; p $source[$index]
      
      if SIGNS.include?($source[$index])
        $index += 1; $column += 1 
      end
      
      is_numeral = true;
      while $index < $source.length && !SEPARATORS.include?($source[$index]) && !SPECIAL.include?($source[$index])        
        is_numeral = false if !DIGITS.include?($source[$index])
        $index += 1; $column += 1 
      end
      
      raise("Line #{$line} Column #{$column}: expression expected.") if $index == start

      if is_numeral && !SIGNS.include?($source[start..$index-1])
        result = $source[start..$index-1].to_i
      else 
        result = $source[start..$index-1].upcase.to_sym
      end
    end
    
#    print "exp: "; p result
    result
  end

  def parse(source)
    $index = 0
    $line = 1
    $column = 1
    $source = source
    
    internalise_rail(0)
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
end




