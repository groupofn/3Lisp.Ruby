# Design and Implementation
###### Notes on 3LispR Design and Implementation

In the following discussion, I will use "3LispM" to name 3Lisp as defined in the Interim 3-Lisp Reference Manual and use "3LispR" to name 3Lisp as implemented here in Ruby. The deviations of 3LispR from 3LispM are overall minor and of only limited architectural implications. They are not big enough to constitute 3LispR as a new dialect of 3Lisp. It is nevertheless important to document them, especially if further experimentation and development towards 3.nLisp or 4Lisp is to use 3LispR as a tool.

Following the "implementation paper" (des Riviers and Smith 1984), I will use these abbreviations: IPP (Implementation Processor Program) and RPP (Reflective Processor Program).

## Relativization of Level Numbering

3LispM takes the level of initial interaction with the user to be level 1. Thus, when 3LispM starts, the user will encounter this prompt:

    1> 
    
at which they could enter 3Lisp expressions. The "1> " prompt is an invitation, as it were, issued by the level-2 processor to the user to talk to it. I will call it the "read prompt". Assuming no reflection is involved, the expression entered by the user at the prompt will then run at level 1, i.e., it will be run by the level-2 processor, and the result will be given back at the prompt:

    1> (+ 1 1)
    1= 2

I will call "1= " the "reply prompt". 

Under the conception of the infinite tower, what supposedly sets up for this interaction at level 1 is an infinite sequence of invocations (by whom?) of READ-NORMALISE-PRINT, in the following fashion (p.18 of Manual):
        
    god> (READ-NORMALISE-PRINT ∞ global) 
    ∞> (READ-NORMALISE-PRINT ∞-1 global)
    ∞-1> (READ-NORMALISE-PRINT ∞-2 global)
            .
            .
            .
    3> (READ-NORMALISE-PRINT 2 global)
    2> (READ-NORMALISE-PRINT 1 global)
    1> 
        
This is all pretty good, except that if the tower extends infinitely upwards, it does not seem to make sense to say that the READ-NORMALISE-PRINT iteration has a beginning at level ∞. Being at ∞ -- if it makes sense to say that -- is a way of not being at any definite level. After all, if ∞-1 and ∞ are (transfinite?) numbers, they are equal to each other. Therefore, that the last call to READ-NORMALISE-PRINT has 1 as its level argument is not because it is one more level further down from the "top" than the second-last call to READ-NORMALISE-PRINT with 2. 

What really matters about "1> " is not that it is exactly ∞ levels away from God, but rather that it is the level atwhich interaction is going to take place, that it is the last one and the one above it is the second-last one. What matters about this level 1 is its definiteness that is required for actual interaction. I.e. it is where *the* level at which actual interaction is going to take place. This is so especially if the tower could also be extended downwards indefinitely, if not also infinitely as with the upward direction. In such an upwoardly infinite tower, "distance from God" is not available for differentiating the levels.

It seems to me that the "origin myth" of the tower, where God figures at the top of some sort, fails to address the origin of the definiteness of the level at which initial interaction takes place.

In contrast to 3LispM, 3LispR numbers the levels not absolutely, but relatively. It uses 0 for the level at which initial interaction takes place, i.e. the level at which user programs will run initially. The levels above or below level 0 are numbered respectively with positive or negative numbers, the absolute value of which corresponds to how many levels apart they are, relatively, from level 0. In accordance to this relativized level numbering, level number no longer needs to be explicitly given when calling READ-NORMALISE-PRINT, so long as the IPP keeps track of how many levels off from the initial and in which direction the current level is, the relativized number could be used in the prompt. (See next section for more detail about how 3LispR treats the prompt).

Compatible with relative numbering of levels, we could tell an alternative origin myth about the tower:

*Since time immemorial, a demiurge has been tirelessly creating levels of the 3Lisp tower in its programming workshop. We do not know where, how, and when the demiurge started this tower. We just konw that it is still adding levels to it. Whenever we want to tap into that tower, we just run a special program  (e.g. "ruby 3Lisp.rb"). This program functions as a portal into the demiurge's programming workshop. Running it allows us to effectively take control of extension of the tower, suspend it, send the demiurge to rest, and then do what we want at this current level which the demiurge just finished creating when its work is suspended.*
 
Under this alternative myth, we could say that it is the user's "being there at" or "deictic reach into" the demiurge's workshop through runnning the special program that brings the definiteness into the picture: level 0 is just the level at which the tower construction of the demiurge is magically "intercepted" by our request to interact with the tower; it is the level at which we are going to start interacting with the tower. 

## Prompt

In 3LispM, the interactive prompt usually looks like the following:

    1> (+ 1 1)
    1= 2 

The read prompt "1> " and reply prompt "1= " are respectively produced by PROMPT&READ and PROMPT&REPLY. Each prompt consists of 2 parts, a numeral for the level at which interaction is taking place, '1' in this case, and a short string, either "> " or "= ", indicating respectively reading or replying.

READ-NORMALISE-PRINT, in turn, has a "level" argument, which is used when calling PROMPT&READ and PROMPT&REPLY:

    (define READ-NORMALISE-PRINT ; 3LispM version
      (lambda simple [level env]
        (normalise (prompt&read level) env
          (lambda simple [result]
            (block
              (prompt&reply result level)
              (read-normalise-print level env))))))
              
This design allows an arbitrary number be used as the "level" argument in a call to READ-NORMALISE-PRINT:

    1> (read-normalise-print 2001 global) ; 3LispM version
    2001> 

The treatment of prompt in 3LispR differs in a couple of ways. First, level number is differentiated from prompt text. Rather than supplying READ-NORMALISE-PRINT with a level number, the relativized level number (see Section 1) is now part of the IPP state. And this level number could be used in the prompt through an appropriate call to READ and PRINT, which are discussed in the next section.

Second, rather than taking level number as an argument, READ-NORMALISE-PRINT takes two arguments of the string type, which supplies short descriptive texts that are used in respectively the read prompt and the reply prompt. Such descriptive text could be simple signs such as the familiar " > " and " = " or much more loquacious:

    0 > (read-normalise-print " > "  " = " global) ; 3LispR version
    -1 > (+ 1 1)
    -1 = 2
    -1 > (define quit (lambda reflect [args cont env] 'done))
    -1 = 'QUIT
    -1 > (quit)
    0 = 'DONE
    0 > (quit)
    +1 = 'DONE
    +1 > (quit)
    +2 = 'DONE
    +2 > (read-normalise-print " your question please: "  " here is my answer: " global) 
    +1 your question please: (primitive ↑quit)
    +1 here is my answer: $F
    +1 your question please: (quit)
    +2 = 'DONE
    +2 >
        
Accordingly, READ-NORMALISE-PRINT is defined as follows

    (define READ-NORMALISE-PRINT ; 3LispR version
      (lambda simple [read-prompt reply-prompt env]
        (normalise (prompt&read read-prompt) env
          (lambda simple [result]
            (block
              (prompt&reply result reply-prompt)
              (read-normalise-print read-prompt reply-prompt env))))))
                  
Third, in 3LispR the (relativized) level number is explicitly tracked as part of the IPP state at any moment (and differentiated from the stack of continuations), rather than being embedded in the REPLY-CONTINUATION closures as how level number is handled in 3LispM. In 3LispR, what gets embedded in the REPLY-CONTINUATION closures are the descriptive texts for the read and reply prompts, which could be level specific, as illustrated above.
                  
Finally, it is probably worth noting that to ensure that the level numbers are correctly displayed as part of the READ PROMPT, not only are calls to READ-NORMALISE-PRINT now trapped, a shift-down is also performed upon such a call, just as in the case of a call to NORMALISE.

## READ and PRINT

Coordinated with the above treatment of Prompt, the primitives READ and PRINT now could take some extra arguments that control the Prompt. By default, READ and PRINT are used in the following way:

    (READ) 

and 

    (PRINT structure)

The first extra argument is a boolean flag. It turns on or off the display of the relative level number as part of the prompt. The default is off. The second extra argument is a (descriptive) string that is used in the prompt. If display of level number is on, this string follows the level number. 

Thus,

    (READ $F " DEBUG > ")
        
would suppress the level number and displays " DEBUG > " as the prompt. In contrast, 

    (PRINT $T " DEBUG > ")

would display the level number before " DEBUG > ". Their use are illustrated below:

    0 > (block (print (read $F " EXAMPLE > ") $T " EXAMPLE = ") (newline))
     EXAMPLE > (+ 1 2)
    0 EXAMPLE = (+ 1 2)
    0 = 'OK

PROMPT&READ and PROMPT&REPLY could be easily defined using this version of READ and PRINT. 

## Environment

### Enivronment as normal form

Rather than using rails, environment is now a normal form in 3LispR. Accordingly, besides the traditional BINDING, REBIND, and BIND, which have the same interface as in 3LispM but are now primitives, we have the following new primitives: ECONS, BOUND, and BOUND-ATOMS.

ECONS takes no arguments and constructs a so far inaccessible environment structure:

    0 > (econs)
    0 = #<Environment:8856540>

This structure may be then manipulated with REBIND and BIND. BOUND tests whether a given atom is bound in a given environment:

    0 > (set env (econs))
    0 = 'OK
    0 > (bound 'a env)     
    0 = $F
    0 > (rebind 'a '10 env)
    0 = '10
    0 > (bound 'a env)
    0 = $T

BOUND-ATOMS lists all atoms bound in the given environment. To continue the above example:

    0 > (bound-atoms env)
    0 = ['A]
    0 > (rebind 'b '20 env)
    0 = '20
    0 > (bound-atoms env)
    0 = ['A 'B]

Moreover, ENVIRONMENT now names the characteristic function for environment structures rather than an accessor of the environment structure enclosued in a closure. For that we have ENVIRONMENT-OF instead:

    0 > (environment ↑env)
    0 = $T
    0 > (environment-of ↑select)
    0 = #<Environment:4259878>

Finally, we use "environment" to name the 3LispR environment structure and take an environment structure to designate the "bindings", i.e. the association relations between atoms and entities:

    0 > (type (econs))
    0 = 'BINDINGS
    0 > (type ↑(econs))
    0 = 'ENVIRONMENT

### Literal environment construction? 

One issue concerning this change of the implementation of environment is whether we still want to have a literal way of constructing environments in 3Lisp programs. In 3LispM, one could simply write

    [['a '1] ['b '2] ['c '3]]
        
which is a literal way of constructing a rail of rails and what is constructed could be used as an environment structure. To get the same thing in 3LispR one will have to write something that is much less conspicuous:

    (bind 'a '1 (bind 'b '2 (bind 'c '3 (econs))))

If a literal way of environment construction is truly desirable, the following might be a way of doing it:

    <<'a '1> <'b '2> <'c '3>>

This would overload '<' and '>' in their role of reserved characters, forcing the parser to look ahead by at least one more non-space characters, but that should be fine.

## Closure

The biggest meaningful divergence of 3LispR from the implementation paper is probably that of closure implementation. The motivation is to both streamline closure identification and protect the kernel closures from being smashed. 

### Identification

All closures in 3LispR has a special "system-type" tag that is inaccessible from 3Lisp. This tag marks up a closure as a PPP (Primary Processor Procedure), PPC (Primary Processor Continuation), a primitive, a kernel utility, or an ordinary one. Moreover, for the closures of the first four kinds, its system-name is stored in the closure Ruby structure, again inaccessible from 3Lisp. Under the assumption that kernel procedures (including PPP, PPC, and kernel utility) and primitives cannot be smashed from within 3Lisp programs (see caveat below), the identification of any particular PPP or PPC during the running of the IPP is a matter of checking their system-type and their system-name.
 
This design eleminates the need of recursively comparing elements of a closure in an attempt to identify it as a certain PPP or PPC.

### Protection of kernel and primitives

Two kinds of protection are necessary. One against smashing of a kernel or primitive closure structure through REPLACE and another against the rebinding of the name of a kernel function in the global environment through REBIND. Accordingly, the implementation of the REPLACE and REBND primitives check to make sure that the closure being altered is not a kernel or a primitive.

The name "GLOBAL" is similarly protected in the global environment. "PRIMITIVE-CLOSURES" is no longer bound to the set of primitive closures after the initialization of the IPP. The predicate PRIMITIVE is now instead a primitive, which directly tests the system-type tag of a closure, rather than looking it up in the set of primitive closures.

It must be noted that the protection of kernel and primitive closures against REPLACE is incomplete. It only works at the top level of closure construction. Thus, for example, a 3Lisp program could retrieve the body of a closure, and then REPLACE the CAR or CDR of that body, and thereby indirectly alters the closure by altering its elements.

### Towards proper names

It seems to me that the 3LispR closure implementation could provide some of the needed support if we decide to introduce proper names into 3.nLisp and treat the names of kernels and primitives as proper.

## Rail

The implementation of rails in 3LispR changed many times. It started out as a direct extension of Ruby's Array type. It then came to use Ruby's Array type as a delegate. The "problem" with these implementation choices is that they do not (easily or naturally) support shared tails of rails, which is a feature of 3LispM. (Actually, I am not convinced this is a problem because I am still not sure about the general merit or utility of shared tails beyond making environment implementation in rails easy.) After these, rails came to be implemented as containers of linked list in another version of 3LispR, which supported all rail operations in 3LispM, before finally being implemented on the basis of the Ruby class implementing 3Lisp pairs. 

In the currently final implemention, shared tails are still allowed as well as mutation of an element and concatenating one rail to the *end* of another. Mutation of tails is in general forbidden, however.

The motivation for this decision is efficiency. By banning mutation of tails, it is possible to keep track of the length of a rail as well as its last element as rails are created, combined, or recombined, which in turn means LENGTH and a few other operations requires no traversing of the whole rail but could happen in constant time. 

There are some curiosities with this design. For example shared tails and circular structures could still be formed, leading to situations potentially very confusing:

    0 > (set r [1 2 3])
    0 = 'OK
    0 > (concatenate ↑r ↑r)
    0 = '[1 2 3 1 2 3]
    0 > (rplacn 2 ↑r '20)
    0 = 'OK
    0 > r
    0 = [1 20 3 1 20 3]
    0 > (length r)
    0 = 6
 
## REPLACE and Structural Identity

The implementation of REPLACE in 3LispR is at best half-hearted in contrast that in 3LispM. First, as mentioned above, REPLACE does not support the mutation of tails of rails. (CONCATENATE, however, does mutate the tail of a rail, but only the very last tail -- or the "foot" -- of a rail).

Second, REPLACE of atoms, which is supported in 3LispM, is not supported in 3LispR. The immediate reason for this is because atoms are implemented using Ruby's Symbol, which cannot be changed without changing the identity of the Ruby Symbol instance. One could of course implement atoms less directly on top of Ruby's Symbol, but then one also wonders "why bother?"

Third, while environment is a normal form in 3LispR, REPLACE does not work with environment. This is probably OK, because mutation of environment structure is done through the standard utilties such as BIND and REBIND. But these are still limited because it does not allow destructive operations such as deleting individual atom-structure pairings from an environment.

In sum, REPLACE only fully work for closures and pairs. The individual elements of rails (via RPLACN, which is provided primitively) and environment structures may be changed with other special primitives.

I am actually not too sure whether such a situation with REPLACE is happy or unhappy. This is because I am not too sure about the general status of REPLACE in the first place.

What I feel might be going on is that REPLACE is occasionally useful beyond what a reflective version of SET could offer. REPLACE, for example, allows the Y-OPERATOR to be defined:

    (define Y-OPERATOR ; 3LispM & 3LispR
      (lambda simple [fun]
        (let [[temp (lambda simple ? ?)]]
          (block (replace ↑temp ↑(fun temp)) temp))))
      
and similarly with PUSH and POP:

    (define PUSH ; 3LispM only
      (lambda simple [element stack]
        (replace ↑stack
                 ↑(prep element
                        (if (empty stack)
                            (scons)
                            (prep (1st stack) (rest stack)))))))
                    
    (define POP ; 3LispM only
      (lambda simple [stack]
       (let [[top (1st stack)]]
          (block
            (replace ↑stack ↑(rest stack))
            top))))

These are good. 

But I also wonder what is the general rationale for the inclusion of REPLACE in 3Lisp. Is it a way of messing with 3Lisp structures in which their structural identity, as versus their referential equality (or co-referentiality, what '=' tests), actually matters in the effects or even semantics of the procedures involved? In other words, if SET alters reference and establishes co-reference of atoms, then REPLACE treats a structure as persistent while altering. I.e. SET and REPLACE represent two different kinds of side-effects. That REPLACE is provided as a primitive, along with REBIND, seems to suggest that something like this is what is going on. But then it also raises some questions:

* Why isn't REPLACE similar to SET, which can be defined through a combination of REBIND and reflection?
* Does this mean REPLCE is designed to cover a dark corner not under the scope of the 3Lisp model or theory on which the RPP is based? How are we to reflection into the REPLACE business? Does that mean reflection into the implementation?         
        
## Streams

There is a stream type in 3LispM. This is not supported in 3LispR. This is because no constructor of streams is actually defined for 3LispM. And there is no account given as to which streams are provided to user programs by the 3Lisp environment besides what is called the PRIMARY-STREAM. It may be the case that some sort of mapping between the UNIX standard streams (stdin, stdout, and stderr) to some named streams in 3Lisp is assumed. But I did not find any information about this. Thus, for now I opted to keep things simple by leaving out all stream arguments from the primitives and procedures and absorb Ruby's STDIN, STDOUT and STDERR into the context of 3Lisp calls to READ, PRINT, or Error respectively.

## Strings and Characters

In 3LispM, instances of a basic structural type called "Charat" designate individual characters; rails of Charats in turn designate strings, which are taken to be sequences of characters. Under this scheme, string manipulations could be implemented on the basis of rail operations. This is for sure elegant.

3LispR could have followed this route. However, things are kept simple for now by leaving out the Charat type and implementing the string type as atomic structural elements. Thus, one can use a string literal such as "abc" and "Beatrice Potter", or even "there

are three newlines in this string". Atoms may also be bound to strings. No operations such as string concatenation, string matching etc that treats strings non-atomically are supported. Down the road, if it turns out to be desireable, we could easily expose a set of Ruby's string operations as 3LispR's string primitives.

This approach of directly basing the string type on Ruby's corresponding type, rather than basing string structures on top of Charat and Rail, certainly makes string implementation exceedingly simple. This is also the natural thing to do because Ruby does not have a character or Charat type, but has only strings. Nothing prevent us from building a Charat type on top of Ruby's string and then treat strings as sequences of characters. But that would be a truly round-about way of getting something unwieldy, especially because Ruby's string operations seem already slow. 

Here, we do not really have much of a rationale other than efficiency and implementation simplicity to determine which design decision is the more sensible. Further development of 3Lisp into 3.nLisp might help supply this. For now, we are keeping things simple.

Finally, I should note that rather than implementing a separate PRINT-STRING utility as in 3LIspM, I have opted to allow PRINT to accept string arguments and perform a "disquotation" operation on the structure supplied:

    0 > (block (print "Hello!") (newline))
    Hello!
    0 = 'OK

My understanding is that this is in agreement with the general dereference design of PRINT:

    0 > (block (print 1) (newline))
    3-Lisp run-time error: PRINT expects a structure but was given 1
    0 > (block (print '1) (newline))
    1
    0 = 'OK

## Author
Jun Luo of The Group of N
