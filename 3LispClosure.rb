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

class Closure
  include ThreeLispError
  
  attr_accessor :kind, :environment, :pattern, :body, :system_type, :name, :ruby_lambda

  def initialize(kind, environment, pattern, body, system_type = :Ordinary, name = nil, ruby_lambda = nil)
    self.kind, self.environment, self.pattern, self.body, self.system_type, self.name, self.ruby_lambda = kind, environment, pattern, body, system_type, name, ruby_lambda
  end
  
  def replace(other) # system_type, name, and ruby_lambda are not mutable
    self.kind, self.environment, self.pattern, self.body = other.kind, other.environment, other.pattern, other.body
  end
   
  def to_s
    "{" << (kernel? ? "Kernel" : system_type.to_s) << ": " <<
      kind.to_s << " " << (environment.nil? ? "#<>" : environment.to_s) << " " << pattern.to_s << " " << body.to_s << 
    "}"
  end

  def kernel?
    system_type == :KernelUtility || system_type == :PPP || system_type == :PPC
  end

  def primitive?
    system_type == :Primitive  
  end

  def ordinary?
    system_type == :Ordinary
  end
  
  def ppp_type
    return name if system_type == :PPP
    return :UNKNOWN
  end
    
  def ppc_type
    return name if system_type == :PPC
    return :UNKNOWN
  end
  
  def simple?
    kind == :SIMPLE
  end
  
  def reflective?
    kind == :REFLECT
  end
  
  def de_reflect
    Closure.new(:SIMPLE, environment, pattern, body, system_type, name, ruby_lambda)
  end

  def extract(variable)
    environment.binding(variable)
  end
end


