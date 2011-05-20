
                               3LispR - A Ruby Implementation of 3Lisp 

                                           2011-05-20
                                         
                                           Jun Luo
                                            
                                              of
                                        The Group of N
                           
The package includes a BETA version of a Ruby implementation of 3Lisp. The implementation follows the design 
in des Riviers & Smith (1984) and largely conforms to 3Lisp as specified in the Interim 3-Lisp Reference 
Manual. For convenience, we will call this 3Lisp Ruby implementation "3LispR", prounced "three-lisper". 



1. Install Ruby 1.9

3LispR requries Ruby 1.9.1 and above. The preinstalled version of Ruby that comes with Snow Leopard is 1.8.7. 
We thus need to download and set up Ruby 1.9.x. 

Assuming you have Xcode installed and has "/usr/local/bin" as part of your PATH that precedes "/usr/bin", 
you can set up Ruby 1.9.2 through the following sequence at the shell prompt:

      curl -O ftp://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p180.tar.gz
  
      tar xzvf ruby-1.9.2-p180.tar.gz

      cd ruby-1.9.2-p180

      ./configure --enable-shared --enable-pthread CFLAGS=-D_XOPEN_SOURCE=1

      make
  
      sudo make install

After these, you can try:

      which ruby

and you should see

      /usr/local/bin/ruby
  
You could always run "ruby -v" to check the version of ruby you use.

Well, 3LispR was developed using Ruby 1.9.1. After the Ruby environment got updated to Ruby 1.9.2 (just now),
it turned out that 3LispR runs 50-90% slower than under 1.9.1! 



2. Starting, Exiting and Prompt

To run 3LispR, use "3lispr" from the Terminal application of MacOS. You might need to do "./3lispr", if your 
path does not include the current directory. It may take a second or two before you see the prompt:

      0 > 

To exit from 3LispR, use (exit) at the pormpt:

      0 > (exit)

The prompt has two parts in it. The first part is the "relativzed level number" (see Implementation Notes). 
This starts out at 0 and then becomes incremented or decremented as the implementation shifts levels up
or down. However, there may be many more shifts in between two promptings. The following illustrates how level 
number at the prompt may change:

      0 > (define quit (lambda reflect [args env cont] 'DONE))
      0 = 'QUIT
      0 > (quit)
      +1 = 'DONE
      +1 > (quit)
      +2 = 'DONE
      +2 > (read-normalise-print " > " " = " global)
      +1 > (read-normalise-print " > " " = " global)
      0 > (read-normalise-print " > " " = " global)
      -1 > (read-normalise-print " > " " = " global)
      -2 > (read-normalise-print " > " " = " global)
      -3 > 

The second part of the prompt, as illustrated by the use of READ-NORMALISE-PRINT above, contains a bit of 
presumably descriptive or indicative text. This is specified in the called to READ-NORMALISE-PRINT, with two 
strings, respectively as the prompt for reading and the prompt for replying. This second part is concatenated 
with the relativized level number to form the complete prompt:

      -3 > (read-normalise-print " Your Question? " " My Answer: " global)
      -4 Your Question? (= 1 2)    
      -4 My Answer: $F
      -4 Your Question? (quit)
      -3 = 'DONE
      -3 >

In the abvoe example, the prompt for reading was changed to " Your Question? " and that for replying to
" My Answer: " for level -4. After quitting from level -4, however, the descriptive/indicative texts (which
are stored in the REPLY-CONTINUATION) of level -3 are restored.



3. '↑' (up-arrow character) and '↓' (down-arrow character)

3LispR uses the following characters for the up-arrow and down-arrow of 3Lisp: 

      '↑': unicode 0x2191
      '↓': unicode 0x2193

In MacOS's Terminal application, you can add your faviorite keybindgs under Preference => Settings => Keyboard 
for inputting these characters as text. However, this may not work over an SSH connection.

For Cocoa based editors, you can add keybindings through including in the file:

      ~/Library/KeyBindings/DefaultKeyBinding.dict

something like the following lines:

      {
      "^~[" = ("insertText:", "\U2191");
      "^~]" = ("insertText:", "\U2193");
      }

which maps CTRL-OPTION-[ to '↑' and CTRL-OPTION-] to '↓'.



4. Editing at Command Prompt and Command History

3LispR comes with a simple command prompt editor in which the following keys have special roles:

(1) Esc:     abandons inputs & edits

(2) Return:  when caret is on the last line and pairs of parenstheses and brackets inputted so far 
             respectively match, then the text currently being edited is processed as 3Lisp 
             expression

(3) Arrows:  move the caret up, down, left, and right respectively

(4) Shift-HOME & Shift-END:         move the caret to the beginning or end of liine

(5) Shift-PAGEUP & Shift-PAGEDOWN:  navigates the command history.
             
(6) CTRL-C:  quits 3LispR if pressed at the prompt, but terminates the current processng if a 3Lisp expression
             is being processed. 



5. System Command, External Editors and Executing Files

3LispR provides a set of utilities for invoking OS commands without exiting and for invoking external editors
and executing external files. These utilities are meant to support experimentation with 3LispR that invovles
a large number of definitions, i.e., the sort of playing with 3LispR that's more like serious programming.

(1) SYS takes one or more strings, which are joined with separating spaces into one shell commmand, which is 
in turned executed. If the execution is successful, 'OK is returned; otherwise, an exception is raised. Thus, 
one can do:

      0 > (sys "ls")

or

      0 > (sys "ls" "-l")

etc.

(2) EDIT allows editing of a file without leaving 3LispR. The default editor is vi. It is defined using SYS
as follows:

(define edit
  (lambda simple args
    (let [[file (if (> (length args) 0) (1st args) "temp.3lisp")]
          [editor (if (> (length args) 1) (2nd args) "vi")]]
      (sys editor file))))

(3) SOURCE takes a string argument that names a text file, reads, and returns the content of that files as a
string:

      0 > (sys "cat" ">" "add.3lisp") 
      (set a 1)                                    ; This was input from the user to the "cat" interaction
      (set b 1)                                    ; Input continues ...
      (+ a b)                                      ; And continues till its terminated with CTRL-D
      0 = 'OK
      0 > (source "add.3lisp")
      0 = "(set a 1)
      (set b 1)
      (+ a b)
      "

In this example, a file named "add.3lisp" was created using the system command "cat" and then its content was 
read in using SOURCE.

(4) EDITSOURCE is basically a combination of EDIT and SOURCE:

(define editsource
  (lambda simple args
    (let [[file (if (> (length args) 0) (1st args) "temp.3lisp")]
          [editor (if (> (length args) 1) (2nd args) "vi")]]
      (block 
        (sys editor file) 
        (source file)))))

(5) PARSE takes a string, treats it as string representation of 3Lisp structures and returns a rail that contains
the specified 3Lisp structure:

     0 > (parse "(+ 1 2)")
     0 = '[(+ 1 2)]
     0 > (normalise (parse "(set a 1) (set b 1) (+ a b)") global id)
     0 = '['OK 'OK 2]

(6)  EXEC combines SOURCE and PARSE and NORMALISE to run an external 3Lisp source program:

     0 > (exec "add.3lisp")
     0 = ['OK 'OK 2]

It is defined as follows:

(define exec
  (lambda reflect [args env cont]
    (cont (normalise-rail (parse (source . ↓args)) env id))))
  

(7) EDEX allows the user to first edit a file before running it:

(define edex
  (lambda reflect [args env cont]
    (cont (normalise-rail (parse (editsource . ↓args)) env id))))



6. ./init.3lisp

This file is automatically loaded when 3LispR is launched. The file already contains many definitions of frequently
used procedures, providing a basic library.

You can put definitions of your own freuently used procedures in it. Note, however, you won't get any error messages 
if your definition fails to be successfully processed. Thus, it is best if you have tested your definitions first 
before including them in init.3lisp.



7. 3Lisp Primer

The Interim 3-Lisp Reference Manual contains a 3Lisp Primer, which is reproduced and lightly annotated with (of course!)
iAnnotate. This is your best starting point!



8. tests.3lisp

This file includes a fair number of test cases, which also serve to illustarte both basic and unique features of 3Lisp. 
A good way to gain a sense of how 3Lisp works is to try these cases and their variations.



9. Finally ...

This version of 3LispR -- including its editor, parser and processor -- was mostly tested only through Jun's 
idiosyncratic use. There may be many lurking surprises for you! But please feel free to use it, abuse it and above 
all play with it. Do let Jun know if you want any improvemet anywhere and do feel free to created your own version!


