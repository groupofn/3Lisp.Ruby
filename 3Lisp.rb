# encoding: UTF-8

# [ ] initialization could be optimized for speed ...
oldtime = Time.now

#require 'rubygems'
require './3LispReader.rb'
require './3LispClasses.rb'
require './3LispInternaliser.rb'
require './3LispPrimitives.rb'
require './3LispIPPState.rb'
require './3LispKernel.rb'
require './3LispIPP.rb'

include ThreeLispKernel
include ThreeLispPrimitives
include ThreeLispIPP

$STRINGS_used_by_ACONS = {}

$reader = ExpReader.new
$parser = ThreeLispInternaliser.new

$global_env = Environment.new(PRIMITIVE_BINDINGS, {}) # tail env is empty!
$reserved_names = PRIMITIVES.map{|p| p[0] }

$primitive_closures = Rail.new(*PRIMITIVE_CLOSURES) # translating from Array into 3Lisp Rail
$global_env.rebind_one(:"PRIMITIVE-CLOSURES".up, $primitive_closures.up)
$reserved_names << :"PRIMITIVE-CLOSURES"

$reserved_names += initialize_kernel($global_env, $parser)

$global_env.rebind_one(:"GLOBAL".up, $global_env.up)
$reserved_names = $reserved_names << :"GLOBAL"

elapsed = Time.now - oldtime
#print "Time spent on loading Ruby files and initializing data structures: "; p elapsed

three_lisp
