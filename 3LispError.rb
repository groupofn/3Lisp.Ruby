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

# error reporting
module ThreeLispError
  class ThreeLispSyntaxError < StandardError
  end
  
  def raise_error(obj, msg, type = RuntimeError)
    caller[0]=~/`(.*?)'/  # note the first quote is a backquote: ` not a normal '
#    raise "from " + obj.class.name + "." + $1 + ": " + msg
    raise type, msg
  end
end
