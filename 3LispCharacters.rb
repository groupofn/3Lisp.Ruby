# encoding: UTF-8

####################################
#                                  #
#   Ruby Implementation of 3Lisp   #
#                                  #
#          Version 1.00            #
#                                  #
#           2011-05-20             #
#           Group of N             #
#                                  #
####################################

require 'set'

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
