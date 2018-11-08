#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_CleanUp/vendor/error-handler/error_reporter'

module TT::Plugins::CleanUp

  # Sketchup.write_default("TT_CleanUp", "ErrorServer", "sketchup.thomthom.local")
  # Sketchup.write_default("TT_CleanUp", "ErrorServer", "sketchup.thomthom.net")
  server = Sketchup.read_default(PLUGIN_ID, "ErrorServer",
    "sketchup.thomthom.net")

  unless defined?(DEBUG)
    # Sketchup.write_default("TT_CleanUp", "Debug", true)
    DEBUG = Sketchup.read_default(PLUGIN_ID, "Debug", false)
  end

  config = {
    :extension_id => PLUGIN_ID,
    :extension    => @ex,
    :server       => "http://#{server}/api/v1/extension/report_error",
    :support_url  => "#{PLUGIN_URL}/support",
    :debug        => DEBUG
  }
  ERROR_REPORTER = ErrorReporter.new(config)

end # module


begin
  require "TT_CleanUp/core"
rescue Exception => exception
  TT::Plugins::CleanUp::ERROR_REPORTER.handle(exception)
end
