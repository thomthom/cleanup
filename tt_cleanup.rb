#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module CleanUp
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  PLUGIN_ID       = 'TT_CleanUp'.freeze
  PLUGIN_NAME     = 'CleanUp³'.freeze
  PLUGIN_VERSION  = '3.4.0'.freeze
  PLUGIN_URL      = 'http://extensions.sketchup.com/content/cleanup%C2%B3'.freeze
  
  # Resource paths
  FILENAMESPACE = File.basename( __FILE__, '.*' )
  PATH_ROOT     = File.dirname( __FILE__ ).freeze
  PATH          = File.join( PATH_ROOT, FILENAMESPACE ).freeze
  
  
  ### EXTENSION ### ------------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    loader = File.join( PATH, 'bootstrap' )
    @ex = SketchupExtension.new( PLUGIN_NAME, loader )
    @ex.description = 'Cleanup and optimization operations for the model.'
    @ex.version     = PLUGIN_VERSION
    @ex.copyright   = 'Thomas Thomassen © 2009-2016'
    @ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension( @ex, true )
  end
  
  end # module CleanUp
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
