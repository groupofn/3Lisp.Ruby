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

class Stopwatch

  attr_accessor :muted, :start_time, :lap_start, :laptimes, :stop_message, :lap_message

  def initialize(muted = false, stop_message = nil, lap_message = nil)
    self.muted = muted
    self.stop_message = stop_message
    self.lap_message = lap_message
  end
  
  def mute
    self.muted = true
  end  
  
  def unmute
    self.muted = false
  end
  
  def toggle_mute
    self.muted = !muted
  end

  def lap(msg = nil)
    new_lap_start = Time.now
    elapsed = new_lap_start - lap_start
    lap_start = new_lap_start
    
    laptimes << elapsed
    if !muted
      print (msg.nil? ? (lap_message.nil? ? "Lap time: " : lap_message) : msg) 
      p elapsed
    end
    elapsed
  end
  
  def start
    self.laptimes = []
    self.start_time = self.lap_start = Time.now
  end
  
  def stop(msg = nil)
    elapsed = Time.now - start_time
    if !muted
      print (msg.nil? ? (stop_message.nil? ? "Total time: " : lap_message) : msg) 
      p elapsed
    end
    
    elapsed
  end
end