# encoding: UTF-8

# error reporting
module ThreeLispError
  def raise_error(obj, msg)
    caller[0]=~/`(.*?)'/  # note the first quote is a backquote: ` not a normal '
#    raise "from " + obj.class.name + "." + $1 + ": " + msg
    raise msg
  end
end
