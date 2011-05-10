
[ ] Study prompt-and-read ... make a better API

[ ] There is a question about REBIND: maybe I should block rebinding of all kernel stuff, on top of blocking replacing ...?

[ ] Review treatment of String and Editing ...
[ ] Align RPP with implementation ;-)

Thoughts on primitives related to editing, reading and parsing of files:

[1] (system "..." "..." ...) => returns STDOUT as a string.

[1.1] SOURCE ... PRIMITIVE

[2] (parse "...") => a rail of expressions/structures
         
[3] EDIT

(define edit
  (lambda simple args
    (let [[file (if (> (length args) 0) (1st args) "temp.3lisp")]
          [editor (if (> (length args) 1) (2nd args) "vi")]]
      (system editor file))))

(define editsource
  (lambda simple args
    (let [[file (if (> (length args) 0) (1st args) "temp.3lisp")]
          [editor (if (> (length args) 1) (2nd args) "vi")]]
      (block 
        (system editor file) 
        (source file)))))
  
[4] EDEX

(define edex
  (lambda reflect [args env cont]
    (cont (normalise-rail (parse (editsource . ↓args)) env id))))

(define edex
- >     (lambda reflect [args env cont]
- >         (cont (normalise-rail (edre . ↓args) env id))))


[5] EDITDEF

generate formatted to_s from closure or other structure ... i.e. pretty print.
use editor to edit it ...; change definition ...


                     3Lisp - Ruby Implementation

                           2011-03-12
                           
The package includes a preliminary version of a Ruby implementation of 
3Lisp. The implementation follows that described in des Riviers 
& Smith (1984) and replicates the basic parts of 3Lisp as described
in the Interim 3-Lisp Reference Manual.

For convenience, we'll call this 3Lisp Ruby implementation "3LispR", 
prounced "three-lisper". Please beware that 3LispR is far from ready 
for public consumption. It is here made available for the purpose of 
within-collective play.

Some quick notes:

1. Install Ruby 1.9

3LispR requries Ruby 1.9.1 and above. The preinstalled version of Ruby 
that comes with Snow Leopard is 1.8.7. We thus need to download and
set up Ruby 1.9.x. Assuming you have Xcode installed and has 
"/usr/local/bin" as part of your PATH that preceds "/usr/bin", here's 
how you can set up Ruby 1.9. At the shell prompt, do the following
sequence:

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


2. Starting 3LispR

To run 3LispR, use "3lispr" from the Terminal application of MacOS. 
You might need to do "./3lispr", if your path does not include the 
current directory.

3. '↑' (up-arrow character) and '↓' (down-arrow character)

3LispR uses the following characters for the up-arrow and down-arrow 
of 3Lisp: 

      '↑': unicode 0x2191
      '↓': unicode 0x2193

In MacOS's Terminal application, you can add your faviorite keybindgs 
under Preference => Settings => Keyboard for inputting these characters 
as text. However, this may not work over an SSH connection.

For Cocoa based editors, you can add keybindings through including in 
the file:

      ~/Library/KeyBindings/DefaultKeyBinding.dict

something like the following lines:

      {
      "^~[" = ("insertText:", "\U2191");
      "^~]" = ("insertText:", "\U2193");
      }

which maps CTRL-OPTION-[ to '↑' and CTRL-OPTION-] to '↓'.

4. Exiting 3LispR

To exit from 3LispR, use (exit) at the pormpt:

      0> (exit)

5. Editing in 3LispR

3LispR comes with a simple command prompt editor in which you can use 
the following keys:

- Esc:    abandon inputs & edits and return to the command prompt
- Arrows: move the caret
- Return: if (i) caret is on the currently last line and parenstheses 
          and brackets inputted so far match respectively, then what 
          is currently in the editor buffer is processed as 3Lisp 
          expression.

6. init.3lisp

This is a file that's automatically loaded when 3LispR is launched. 
You can put definitions of your own freuently used procedure in it. 
Note, however, you won't get any error message if your definition 
fails to be successfully processed. Thus, it's best if you have 
tested your definitions first before including them in init.3lisp.

7. tests.3lisp

This file includes a fair number of test cases, which also serve to 
illustarte both basic and unique features of 3Lisp. A good to gain a
sense of how 3Lisp works is to try these cases and their variations.


8. Finally ...

This version of 3LispR -- including its editor, parser and 
processor -- was mostly tested only through Jun's idiosyncratic use. 
There may be many lurking surprises for you!




