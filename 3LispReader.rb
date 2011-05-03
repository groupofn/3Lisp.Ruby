# encoding: UTF-8

# TO DO: 
# [x] do not perform highlighting when caret is after a ';', i.e., in comment
# [x] ignore parens/brackets in comments during highlighting
# [x] do not perform matching when caret is after a ';' on the same line
# [x] ignore parens/brackets in comments during matching

# [x] history
# [x] page-up; page-down; home; end

# [ ] Fix up the "- >" hack; needs to be coordinated with a re-design of prompt-and-read ...
# [ ] Deal with deletion of invisible characters <= Is this a problem? Which characters?
# [ ] Change direct reference to instance variables to accessors. Probably unnecessary ...

class ExpReader

  def initialize
    @history = [] # an Array of lines, each of which corresponds to an activated command

    reinitialize  
  end

  def reinitialize
    @lines = [""] # an Array of strings, each of which corresponds to a line; initialized to one empty line
    @row_pos = 0  # row position of the caret in the current text-editing area of the terminal 
    @col_pos = 0  # column position of the caret, starting from 0, which means inserting to the leftmost column 

    @comment_starts = [1] # col_pos of semicolon on a line; for a line without a semicolon, it's set to length_of_line;    
    @indent_unit = "  " # 2 space characters
    
    @ix_lines_being_edited = @history.length # what's being edited is the next command in history ;-)
    @temp_lines = nil # used to save the newly inputted lines when browsing history
  end
  
  def read_char 
    c = STDIN.getc.chr 
    # gather next two characters of special or "escape" keys 
    if (c=="\e") 
      extra_thread = Thread.new { 
        c = c + STDIN.getc.chr 
        c = c + STDIN.getc.chr 
        c = c + STDIN.getc.chr 
      } 
      # wait just long enough for special keys to get swallowed 
      extra_thread.join(0.0001)
      # kill thread so not-so-long special keys don't wait on getc 
      extra_thread.kill
    end
    
    return c
  end

  def pair_highlight #  highlight the one before @col_pos
    if @col_pos > 0 && @col_pos-1 < @comment_starts[@row_pos]
      ch = @lines[@row_pos][@col_pos-1..@col_pos-1]
      if close_paren?(ch)  # close_paren
        rights = [ch]
        row = @row_pos
        col = @col_pos-1
        while row >= 0
          while col > 0
            ch = @lines[row][col-1..col-1]
            if close_paren?(ch)
              rights.push(ch)
            elsif open_paren?(ch)
              return false if !pair_match?(rights[-1], ch)
              rights.pop
              
              if rights.empty?
                print "\e7" # save caret position

                # move caret to the left of open paren
                print "\e[#{@row_pos - row}A" if row < @row_pos
                print "\e[#{col - @col_pos - 1}C" if col > @col_pos                
                print "\e[#{@col_pos - col + 1}D" if col < @col_pos 
              
                print "\e[7m" # reverse character foreground and background
                print @lines[row][col-1..col-1]
                print "\e[D"  # move caret one space to the left
                sleep(0.2)
                print "\e[m"
                print @lines[row][col-1..col-1]
                
                print "\e8" # restore caret position
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
      code << @lines[i][0..@comment_starts[i]-1]
    end
    
    code.each_char{|ch|
      if open_paren?(ch)
        lefts.push(ch)
      elsif close_paren?(ch)
        return false if !pair_match?(lefts[-1], ch)
        lefts.pop
      end      
    }
    return lefts.length == 0
  end
  
  def open_paren?(c)
    c == "(" || c == "["
  end

  def close_paren?(c)
    c == "]" || c == ")"
  end

  def pair_match?(c1, c2)
    c1 == paren_flip(c2)
  end

  def paren_flip(c)
    case c
    when "(" then ")"
    when ")" then "("
    when "[" then "]"
    when "]" then "["
    end
  end

  def update_comment_start_of_line(row) 
    new_pos = @lines[row] =~ /;/
    if new_pos.nil?
      @comment_starts[row] = @lines[row].length
    else
      @comment_starts[row] = new_pos
    end
  end

  def insert_char(ch)
    @lines[@row_pos].insert(@col_pos, ch)
    update_comment_start_of_line(@row_pos)    
    print @lines[@row_pos][@col_pos..-1] +
          "\b" * (@lines[@row_pos].length - @col_pos - 1)
    @col_pos += ch.length
  end
  
  def delete_char(pos)
    ch = @lines[@row_pos].slice!(pos)
    update_comment_start_of_line(@row_pos)
    print @lines[@row_pos][pos..-1] + 
          " " + "\b" * (@lines[@row_pos].length - pos + 1)
  end

# needs to be fixed up!
  def merge_lines  
    print "\e7" # save cursor position
    print "\e[J" # clear the "residue" lines
    print @lines[@row_pos+1]
    @lines[@row_pos] << @lines[@row_pos + 1]
    update_comment_start_of_line(@row_pos)
    @lines.delete_at(@row_pos+1)
    @comment_starts.delete_at(@row_pos+1)
    @lines[@row_pos+1..-1].each { |line|
      print "\r\n- > " + line
    }
    print "\e8" # restore cursor position
  end
  
  def clear_current
    if @row_pos > 0 # 0 must be avoided because "\e[0A" does move the cursor one line up!
      print "\e[#{@row_pos}A" # move cursor up @row_pos-1 many lines; 
    end
    print "\b" * @col_pos # move cursor left @col_pos many characters
    print "\e[J" # clear below cursor
  end
  
  def display_lines
    @comment_starts = Array.new(@lines.length)
    if @lines.length > 1
      for i in 0..@lines.length-2
        print @lines[i] + "\r\n- > "   # because of leading "- >"
        update_comment_start_of_line(i)
      end
    end
    print @lines[-1]
    update_comment_start_of_line(-1)
    @row_pos = @lines.length - 1
    @col_pos = @lines[-1].length
  end

  def read
    begin
      # save previous state of stty 
      old_state = `stty -g` 
      # disable echoing and enable raw mode, under which characters are read in before pressing ENTER 
      system "stty raw -echo"
      
      # do not buffer on the OUTPUT side
      old_sync = STDOUT.sync
      STDOUT.sync = true

      exp_incomplete = true
      reinitialize

      while exp_incomplete do
        char = read_char # note that char is a Fixnum

        case char
        when "\e"
          print "\r\n... abandoning edits ...\r\n"
          return ""
        when "\n", "\r"
#          p @col_pos; p parens_match?
          if @row_pos == @lines.length - 1 && @col_pos == @lines[-1].length && parens_match?
            exp_incomplete = false
            print "\r\n"
          else
            newline_slice = @lines[@row_pos].slice!(@col_pos..-1)
            @row_pos += 1
            leading_space = @indent_unit * @row_pos
            @col_pos = leading_space.length
            print "\e[J" # clear below cursor
            print "\r\n- > " + leading_space # "- >" is more or less a hack!
            print "\e7" # save cursor position
            print newline_slice
            @lines.insert(@row_pos, leading_space + newline_slice)
            update_comment_start_of_line(@row_pos)
            for i in @row_pos+1..@lines.length-1
              print "\r\n- > " + @lines[i]
              update_comment_start_of_line(i)
            end
            print "\e8" # restore cursor position
#            print "\e[A" if @row_pos < @lines.length - 1 # correct for scrolling
          end
        when "\e[H" # "shift-Home": move to either first non-space character on the line or beginning of line
          if (@col_pos > 0)
            preceding = @lines[@row_pos][0..@col_pos-1] # characters before @col_pos
            match_data = preceding.match(/^[ \t]+/) # match for leading space
            if match_data.nil? || match_data[0].length == @col_pos # no preceding space or already at leading space
              print "\b" * @col_pos # move to leftmost
              @col_pos = 0              
            else
              distance_to_first_none_space = @col_pos - match_data[0].length
              print "\b" * distance_to_first_none_space
              @col_pos = @col_pos - distance_to_first_none_space
            end
          else
            print "\a"
          end
        when "\e[F" # "shift-End"
          if @col_pos < @lines[@row_pos].length
            print "\e[#{@lines[@row_pos].length - @col_pos}C"
            @col_pos = @lines[@row_pos].length
            sleep(0.2) # allow cursor to be displayed first
            pair_highlight
          else
            print "\a"
          end
        when "\e[6~" # "shift-PageDn"
          if @ix_lines_being_edited < @history.length
            clear_current
            @ix_lines_being_edited += 1
            if @ix_lines_being_edited == @history.length
              @lines = @buffer
            else
              @lines = @history[@ix_lines_being_edited]
            end
            display_lines
          else
            print "\a"
          end
        when "\e[5~" # "shift-PageUp"
          if @ix_lines_being_edited > 0
            clear_current
            if @ix_lines_being_edited == @history.length
              @buffer = @lines
            end
            @ix_lines_being_edited -= 1
            @lines = @history[@ix_lines_being_edited].map {|l| l.clone} # this is a bit wasteful of memory, but ...
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
            print "\a"
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
            print "\a"
          end
        when "\e[C" # "RIGHT ARROW"
          if @col_pos < @lines[@row_pos].length
            @col_pos += 1
            print "\e[1C"
            pair_highlight
          elsif @row_pos < @lines.length - 1
            @row_pos += 1
            @col_pos = 0 
            print "\r\n\e[4C" # because of the leading "- > "
          else
            print "\a"
          end
        when "\e[D" # "LEFT ARROW"
          if @col_pos > 0
            @col_pos -= 1
            print "\b"
          elsif @row_pos > 0
            @row_pos -= 1
            @col_pos = @lines[@row_pos].length
            print "\e[1A"
            print "\e[#{@lines[@row_pos].length}C"
          else
            print "\a"
          end
        when "\177" # backspace
          if @col_pos > 0
            print "\b" # move into position
            delete_char(@col_pos-1)
            @col_pos -= 1
          elsif @row_pos > 0 # @col_pos == 0
            # join two lines
            @row_pos -= 1
            @col_pos = @lines[@row_pos].length
            print "\e[A"
            print "\e[#{@col_pos}C"
            merge_lines
          else
            print "\a"
          end
        when "\004" # delete ... CTRL+d
          if @col_pos < @lines[@row_pos].length
            delete_char(@col_pos)
          elsif @row_pos < @lines.length - 1
            merge_lines
          else
            print "\a"
          end
        when "\003" # CTRL+c quits the whole thing!
          print "\r\n"
          Process.exit
        when /^.$/ # "SINGLE CHAR", i.e. other escape sequences are ignored
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
    @history << @lines.map {|l| l.clone} if result.strip != "" # i.e. conatining non-space characters
    # could prevent returning of all-space result too ...
    result
  end
end

### Sample use of ExpReader ###
#
# r = ExpReader.new
# res = r.read 
# puts "\nRead: \n" +  res

