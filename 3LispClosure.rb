# encoding: UTF-8

class Closure
  include ThreeLispError
  
  attr_accessor :kind, :environment, :pattern, :body, :system_type, :name

  def initialize(kind, environment, pattern, body, system_type = :Ordinary, name = nil)
    self.kind, self.environment, self.pattern, self.body, self.system_type, self.name = kind, environment, pattern, body, system_type, name
  end
  
  def replace(other) # kernel and name are not mutable
    self.kind, self.environment, self.pattern, self.body = other.kind, other.environment, other.pattern, other.body
  end
   
  def to_s
    "{" + (kernel? ? "Kernel" : system_type.to_s) + " closure: " +
      kind.to_s + " " + (environment.nil? ? "#<>" : environment.to_s) + " " + pattern.to_s + " " + body.to_s + 
    "}"
  end

  def kernel?
    system_type == :Kernel_Utility || system_type == :PPP || system_type == :PPC
  end

  def primitive?
    system_type == :Primitive  
  end
  
  def ordinary?
    system_type == :Ordinary
  end

  def simple?
    kind == :SIMPLE
  end
  
  def reflective?
    kind == :REFLECT
  end
  
  def de_reflect
    Closure.new(:SIMPLE, environment, pattern, body, system_type, name)
  end
end
