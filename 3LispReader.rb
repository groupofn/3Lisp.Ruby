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

require './3LispCharacters.rb'
require './3LispError.rb'

class ExpReader
  
  def initialize
    @history = [] # an Array of lines, each of which corresponds to a processed expression
    @line_prefix = "- > "    
    reinitialize
  end

  def reinitialize
    @lines = [""] # an Array of strings, each of which corresponds to a line w/o the ending '\r' or '\n'
    @row_pos = 0  # row position of the terminal caret w.r.t. @lines  
    @col_pos = 0  # column position of the terminal caret w.r.t. @lines
                  # @lines[@row_pos][@col_pos] is where the next char will be inserted into @lines 

    @comment_starts = [1] # col_pos of semicolon on a line, or length_of_line if no semicolon    
    @indent_unit = "  "   # 2 space characters
    
    @history_index = @history.length  # index in @history of the expression currently displayed and edited
    @temp_lines = nil                 # used to save the newly inputted lines when browsing @history
  end
  
  def read_char 
    c = STDIN.getc.chr 
    if (c=="\e")  # gather up to 3 characters of a special key or "escape" squences 
      extra_thread = Thread.new { 
        c = c + STDIN.getc.chr 
        c = c + STDIN.getc.chr 
        c = c + STDIN.getc.chr 
      } 
      # wait just long enough for the escape sequence to get swallowed 
      extra_thread.join(0.002)
      # kill thread so not-so-long escape sequences don't wait on getc 
      extra_thread.kill
    end
    
    return c
  end

  def pair_highlight #  highlight the one before @col_pos
    if @col_pos > 0 && @col_pos-1 < @comment_starts[@row_pos]
      ch = @lines[@row_pos][@col_pos-1]
      if close_paren?(ch)
        rights = [ch]
        row = @row_pos
        col = @col_pos-1
        while row >= 0
          while col > 0
            ch = @lines[row][col-1]
            if close_paren?(ch)
              rights.push(ch)
            elsif open_paren?(ch)
              return false if !pair_match?(rights.pop, ch)
              
              if rights.empty?
                print "\e7"   # save caret position

                # move caret to the left of open paren
                print "\e[#{@row_pos - row}A"     if row < @row_pos
                print "\e[#{col - @col_pos - 1}C" if col > @col_pos                
                print "\e[#{@col_pos - col + 1}D" if col < @col_pos 
              
                print "\e[7m" # reverse character foreground and background
                print @lines[row][col-1]
                print "\e[D"  # move caret one space to the left
                sleep(0.2)    # wait for user to notice
                print "\e[m"  # restore character foreground and background
                print @lines[row][col-1]
                
                print "\e8"   # restore caret position
                return            
              end
            end
            col -= 1
          end
          row -= 1
          col = @comment_starts[row] if row >= 0
        end
      end
    end
  end
  
  def parens_match?
    lefts = []
    
    code = ""
    for i in 0..@lines.length-1
      if @comment_starts[i] == @lines[i].length
        code << @lines[i]
      else
        code << @lines[i][0..@comment_starts[i]] # drop comments
      end
    end

    code.each_char { |ch|
      if open_paren?(ch)
        lefts.push(ch)
      elsif close_paren?(ch)
        return false if !pair_match?(lefts.pop, ch)
      end      
    }
    return lefts.length == 0
  end
  
  def open_paren?(c)
    c == PAIR_START || c == RAIL_START
  end

  def close_paren?(c)
    c == PAIR_END || c == RAIL_END
  end

  def pair_match?(c1, c2)
    c1 == paren_flip(c2)
  end

  def paren_flip(c)
    case c
    when PAIR_START then PAIR_END
    when PAIR_END then PAIR_START
    when RAIL_START then RAIL_END
    when RAIL_END then RAIL_START
    end
  end

  def update_comment_position(row) 
    new_pos = @lines[row] =~ /;/
    if new_pos.nil? # no SEMICOLON found
      @comment_starts[row] = @lines[row].length
    else
      @comment_starts[row] = new_pos
    end
  end

  def clone_history_for_editing
    if @history_index < @history.length && @lines.equal?(@history[@history_index]) 
      @lines = @history[@history_index].map(&:clone) # clone history for editing
    end
  end

  def insert_char(ch)
    clone_history_for_editing
    @lines[@row_pos].insert(@col_pos, ch)
    print @lines[@row_pos][@col_pos..-1] +
          "\b" * (@lines[@row_pos].length - @col_pos - 1)
    @col_pos += ch.length
    update_comment_position(@row_pos)    
  end
  
  def delete_char
    clone_history_for_editing
    @lines[@row_pos].slice!(@col_pos)
    print @lines[@row_pos][@col_pos..-1] + 
          " " + "\b" * (@lines[@row_pos].length - @col_pos + 1)
    update_comment_position(@row_pos)
  end

  def merge_lines  
    clone_history_for_editing
    print "\e7"  # save cursor position
    print "\e[J" # clear the rest of current line and all lines below
    print @lines[@row_pos+1] 
    @lines[@row_pos] << @lines[@row_pos + 1]
    @lines.delete_at(@row_pos+1)
    update_comment_position(@row_pos)
    @comment_starts.delete_at(@row_pos+1)
    @lines[@row_pos+1..-1].each { |line|
      print "\r\n" << @line_prefix << line
    }
    print "\e8"  # restore cursor position
  end
  
  def clear_lines
    if @row_pos > 0           # 0 must be avoided because "\e[0A" does move the cursor one line up!
      print "\e[#{@row_pos}A" # move cursor up @row_pos-1 many lines; 
    end
    print "\b" * @col_pos     # move cursor left @col_pos many characters
    print "\e[J"              # clear below cursor
  end
  
  def display_lines
    @comment_starts = Array.new(@lines.length)
    if @lines.length > 1
      for i in 0..@lines.length-2
        print @lines[i] + "\r\n" << @line_prefix
        update_comment_position(i)
      end
    end
    print @lines[-1]
    update_comment_position(-1)
    @row_pos = @lines.length - 1
    @col_pos = @lines[-1].length # caret is at the very end
  end

  def set_line_prefix(prompt)
    @line_prefix = 
      case prompt.length
      when 0 
        ""
      when 1
        " "
      when 2
        "> "
      when 3
        " > "
      else
        "-" * (prompt.length - 3) << " > "
      end
  end

  def read(prompt = "")
    set_line_prefix(prompt)
    print prompt
         
    begin
      # save previous state of stty 
      old_state = `stty -g` 
      # disable echoing & enable raw mode, under which characters are read in before pressing ENTER 
      system "stty raw -echo"
      
      # do not buffer on the OUTPUT side
      old_sync = STDOUT.sync
      STDOUT.sync = true

      exp_incomplete = true
      reinitialize

      while exp_incomplete do
        char = read_char

        case char
        when "\e"
          print "\r\n... abandoning edits ...\r\n"
          return ""
        when "\n", "\r"
          if @row_pos == @lines.length - 1 && @col_pos == @lines[-1].length && parens_match?
            # expression is completed if ENTER is pressed when caret is at end of last line and parens match
            exp_incomplete = false
            print "\r\n"
          else
            clone_history_for_editing
            newline_slice = @lines[@row_pos].slice!(@col_pos..-1)
            @row_pos += 1
            leading_space = @indent_unit * @row_pos
            @col_pos = leading_space.length
            print "\e[J" # clear below cursor
            print "\r\n" << @line_prefix << leading_space
            print "\e7" # save cursor position
            print newline_slice
            @lines.insert(@row_pos, leading_space + newline_slice)
            update_comment_position(@row_pos)
            for i in @row_pos+1..@lines.length-1
              print "\r\n" << @line_prefix << @lines[i]
              update_comment_position(i)
            end
            print "\e8" # restore cursor position
          end
        when "\e[H" # "shift-Home": move to before first non-space character or to beginning of line
          if (@col_pos > 0)
            preceding = @lines[@row_pos][0..@col_pos-1]            # characters before @col_pos
            match_data = preceding.match(/^[ \t]+/)                # match for leading space
            if match_data.nil? || match_data[0].length == @col_pos # no preceding space or already at leading space
              print "\b" * @col_pos                                # move to beginning of line
              @col_pos = 0              
            else                                                   # move to before first non-space character
              print "\b" * (@col_pos - match_data[0].length)
              @col_pos = match_data[0].length
            end
          else
            print "\a" # warning: already at beginning of line
          end
        when "\e[F" # "shift-End"
          if @col_pos < @lines[@row_pos].length
            print "\e[#{@lines[@row_pos].length - @col_pos}C"
            @col_pos = @lines[@row_pos].length                     # move to end of line
            sleep(0.3)                                             # allow cursor to be noted at new position
            pair_highlight                                         # then highlight matched paren, if there's one
          else
            print "\a" # warning: already at end of line
          end
        when "\e[6~" # "shift-PageDn"
          if @history_index < @history.length
            clear_lines
            @history_index += 1
            if @history_index == @history.length
              @lines = @temp_lines
            else
              @lines = @history[@history_index]
            end
            display_lines
          else
            print "\a"
          end
        when "\e[5~" # "shift-PageUp"
          if @history_index > 0
            clear_lines
            if @history_index == @history.length
              @temp_lines = @lines
            end
            @history_index -= 1
            @lines = @history[@history_index]
            display_lines
          else
            print "\a"
          end
        when "\e[A" # "UP ARROW"
          if @row_pos > 0
            @row_pos -= 1
            print "\e[A"
            if @col_pos > @lines[@row_pos].length
              print "\b" * (@col_pos - @lines[@row_pos].length)
              @col_pos = @lines[@row_pos].length
            end
          else
            print "\a" # warning: already on first line 
          end
        when "\e[B" # "DOWN ARROW" 
          if @row_pos < @lines.length - 1
            @row_pos += 1
            print "\e[B"
            if @col_pos > @lines[@row_pos].length
              print "\b" * (@col_pos - @lines[@row_pos].length)
              @col_pos = @lines[@row_pos].length
            end
          else
            print "\a" # warning: already on last line
          end
        when "\e[C" # "RIGHT ARROW"
          if @col_pos < @lines[@row_pos].length
            @col_pos += 1
            print "\e[C"
            pair_highlight
          elsif @row_pos < @lines.length - 1
            @row_pos += 1
            @col_pos = 0 
            print "\r\n\e[#{@line_prefix.length}C"
          else
            print "\a" # warning: already at end of last line
          end
        when "\e[D" # "LEFT ARROW"
          if @col_pos > 0
            @col_pos -= 1
            print "\b"
          elsif @row_pos > 0
            @row_pos -= 1
            @col_pos = @lines[@row_pos].length
            print "\e[A"
            print "\e[#{@lines[@row_pos].length}C"
          else
            print "\a" # warning: already at beginning of first line
          end
        when "\177" # BACKSPACE
          if @col_pos > 0
            print "\b"               # move into position
            @col_pos -= 1
            delete_char
          elsif @row_pos > 0         # when @col_pos == 0, join two lines
            @row_pos -= 1
            @col_pos = @lines[@row_pos].length
            print "\e[A"
            print "\e[#{@col_pos}C"
            merge_lines
          else
            print "\a" # warning: at beginning of first line
          end
        when "\004" # DELETE or CTRL+d
          if @col_pos < @lines[@row_pos].length
            delete_char
          elsif @row_pos < @lines.length - 1
            merge_lines
          else
            print "\a" # warning: at end of last line
          end
        when "\003" # CTRL+c quits the whole thing!
          print "\r\n"
          Process.exit
        when /^.$/ # "SINGLE CHAR"; other escape sequences are therefore dropped          
          char = @indent_unit if char == "\t"
          
          insert_char(char) if char.length > 0
          pair_highlight
        end
      end
    rescue => ex 
      puts "#{ex.class}: #{ex.message}" 
      puts ex.backtrace 
    ensure 
      STDOUT.sync = old_sync
      
      # restore previous state of stty system 
      system "stty #{old_state}" 
    end
    result = @lines.join("\n") + "\n"
    if result.strip != "" # i.e. conatining non-space characters
      if @history_index == @history.length
        @history << @lines.map(&:clone)
      else
        @history << @lines # because @lines were cloned from a past expression
      end
    end
    result
  end
end

### Sample use of ExpReader ###
#
# r = ExpReader.new
# res = r.read 
# puts "\nRead: \n" +  res

