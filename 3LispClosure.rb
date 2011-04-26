# encoding: UTF-8

class Closure  
  attr_accessor :kind, :environment, :pattern, :body

  def initialize(kind, environment, pattern, body)
    self.kind, self.environment, self.pattern, self.body = kind, environment, pattern, body
  end
  
  def replace(kind, environment, pattern, body)
    self.kind, self.environment, self.pattern, self.body = kind, environment, pattern, body
  end
   
  def to_s
    "{Closure: " + kind.to_s + " " + environment.to_s + " " + pattern.to_s + " " + body.to_s + "}"
  end

  def simple?
    kind == :SIMPLE 
  end
  
  def reflective?
    kind == :REFLECT
  end
  
  def de_reflect
    Closure.new(:SIMPLE, environment, pattern, body)
  end
  
  def similar?(template)
    return true if self.equal?(template)
    return pattern.isomorphic(template.pattern) &&
           body.isomorphic(template.body) &&
           kind == template.kind && 
           environment.similar?(template.environment)
  end
end
