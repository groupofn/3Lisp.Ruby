# encoding: UTF-8

class IPPState

  attr_accessor :state

  def initialize(level) # initial_tower(level)
    self.state = [level]
  end

  def shift_down(continuation)
    state.push(continuation)
  end

  def shift_up(&cont_maker)
    if state.length == 1
      state[0] += 1
      cont_maker.call(state[0])
    else
      state.pop
    end
  end
  
end


