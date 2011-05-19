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

require './3LispHandle.rb'

class Pair
  attr_accessor :car, :cdr

  def initialize(car, cdr)
    self.car, self.cdr = car, cdr
  end

  def self.pcons(h, t)
    Handle.new(Pair.new(h.quoted, t.quoted))
  end

  def rplaca(new_car)
    self.car = new_car
  end
  
  def rplacd(new_cdr)
    self.cdr = new_cdr
  end

  def to_s
    # the "[1..-2]" serves to strip off brackets when cdr is rail
    case car
    when :UP then "↑" << (cdr.rail? ? cdr.to_s[1..-2] : cdr.to_s)     
    when :DOWN then "↓" << (cdr.rail? ? cdr.to_s[1..-2] : cdr.to_s)
    else
      "(" << car.to_s << 
        (cdr.rail? ? (cdr.empty? ? "" : " " << cdr.to_s[1..-2]) : " . " << cdr.to_s) <<
      ")"
    end
  end
end
