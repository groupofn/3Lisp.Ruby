# encoding: UTF-8

require 'rubygems'
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

$global_env.rebind_one(:"PRIMITIVE-CLOSURES".up, Rail.new(*PRIMITIVE_CLOSURES).up)
$reserved_names << :"PRIMITIVE-CLOSURES"

$reserved_names += initialize_kernel($global_env, $parser)

$global_env.rebind_one(:"GLOBAL".up, $global_env.up)
$reserved_names = $reserved_names << :"GLOBAL"

three_lisp
