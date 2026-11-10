ENV["MT_NO_EXPECTATIONS"] = "true"
require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::ProgressReporter.new]

require "bridgetown/test"
