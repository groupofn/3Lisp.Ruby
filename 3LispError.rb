# encoding: UTF-8

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
