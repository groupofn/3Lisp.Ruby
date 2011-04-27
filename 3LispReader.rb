# encoding: UTF-8


# TO DO: 
# [ ] do not perform highlighting when caret is after a ';', i.e., in comment
# [ ] ignore parens/brackets in comments during highlighting
# [ ] do not perform matching when caret is after a ';' on the same line
# [ ] ignore parens/brackets in comments during matching

# [ ] Fix up the "->" hack
# [ ] Deal with deletion of invisible characters
# [ ] Change direct reference to instance variables to accessors

class ExpReader

  def initialize
    @lines = [""] # an Array of strings, each of which corresponds to a line; initialized to one empty line
    @row_pos = 0  # row position of the caret in the current text-editing area of the terminal 
    @col_pos = 0  # column position of the caret, starting from 0, which means inserting to the leftmost column 
    @indent_unit = "  " # 2 space characters
  end

  def read_char 
    c = STDIN.getc.chr 
    # gather next two characters of special or "escape" keys 
    if (c=="\e") 
      extra_thread = Thread.new{ 
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
    if @col_pos > 0
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
          col = @lines[row].length if row >= 0
        end
      end
    end
  end
  
  def parens_match?
    lefts = []
    
    @lines.join.each_char{|ch|
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

  def insert_char(pos, ch)
    @lines[@row_pos].insert(@col_pos, ch)
    print @lines[@row_pos][@col_pos..-1] +
          "\b" * (@lines[@row_pos].length - @col_pos - 1)
    @col_pos += ch.length
  end
  
  def delete_char(pos)
    @lines[@row_pos].slice!(pos)
    print @lines[@row_pos][pos..-1] + 
          " " + "\b" * (@lines[@row_pos].length - pos + 1)
  end

  def merge_lines  
    print "\e7" # save cursor position
    print "\e[J" # clear the "residue" lines
    print @lines[@row_pos+1] + "\r\n"
    @lines[@row_pos] << @lines[@row_pos + 1]
    @lines.delete_at(@row_pos+1)
    @lines[@row_pos+1..-1].each{|line|
      print line + "\r\n"
    }
    print "\e8" # restore cursor position
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
      initialize

      while exp_incomplete do
        char = read_char # note that char is a Fixnum

        case char
        when "\e"
          print "\r\n... abandoning edits ...\r\n"
          return ""
        when "\n", "\r"
          if @row_pos == @lines.length - 1 && parens_match?
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
            @lines[@row_pos+1..-1].each{|line|
              print "\r\n" + line
            }
            print "\e8" # restore cursor position
            print "\e[A" if @row_pos < @lines.length - 1 # correct for scrolling
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
            print "\r\n\e[3C" # because of the leading "-> "
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
        when /^.$/ # "SINGLE CHAR"
          # if paren, then check ... 
          char = @indent_unit if char == "\t"
          
          insert_char(@col_pos, char) if char.length > 0
          pair_highlight
######## other escape sequences are ignored
#        else puts "SOMETHING ELSE: #{c.inspect}" 
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
    @lines.join("\n") + "\n"
  end
end

### Sample use of ExpReader ###
#
# r = ExpReader.new
# res = r.read 
# puts "\nRead: \n" +  res

