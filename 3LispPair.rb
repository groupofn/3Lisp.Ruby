# encoding: UTF-8

require './3LispHandle.rb'

class Pair
  attr_accessor :car, :cdr

  def initialize(car, cdr)
    @car, @cdr = car, cdr
  end

  def self.pcons(h, t)
    Handle.new(Pair.new(h.down, t.down))
  end

  def to_s
    # the "[1..-2]" serves to strip off brackets when cdr is rail
    case car
    when :UP then "↑" + (cdr.rail? ? cdr.to_s[1..-2] : cdr.to_s)     
    when :DOWN then "↓" + (cdr.rail? ? cdr.to_s[1..-2] : cdr.to_s)
    else
      "(" + car.to_s + 
        (cdr.rail? ? (cdr.empty? ? "" : " " + cdr.to_s[1..-2]) : " . " + cdr.to_s) +
      ")"
    end
  end
end
