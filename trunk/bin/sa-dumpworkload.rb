#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2009 Mathias Dalheimer, md@gonium.net
#
# The calana grid workload generator (CGWG) is free software; you can 
# redistribute it and/or modify it under the terms of the GNU General Public 
# License as published by the Free Software Foundation; either version 2 of 
# the License, or any later version.
#
# CGWG is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CGWG; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

# Read the CGWG location from the environment, warn otherwise
if (ENV["CGWG_HOME"] == nil)
  puts "WARNING: Environment does not define $CGWG_HOME!"
else
  libpath= File.join(File.expand_path(ENV["CGWG_HOME"]), "lib")
  $:.unshift << libpath
  #  puts "Using libraty path #{$:.join(":")}" 
end


require 'rubygems'
#gem 'builder' #we need xml builder
#require 'builder/xmlmarkup'
require 'Scheduler'
require 'optparse'
require 'ostruct'

###
## Commandline parser
#
class Optparser
  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }
  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.inplace = false
    options.encoding = "utf8"
    options.verbose = false
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Specific options:"
      # Mandatory argument.
      opts.on("-s", "--store PATH", "path to workload collection store") do |store|
        options.store=store
      end
      opts.on("-l", "--list", "list workloads in collection") do |list|
        options.list=list
      end
      opts.on("-n", "--name-loadlevels", "list the load levels in the collection") do |name|
        options.loadlevels=name
      end
      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do |v|
        options.verbose = v
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    opts.parse!(args)
    options
  end
end

###
## Script startup
#
#@@config = ConfigManager.new # some global constants etc.
options = Optparser.parse(ARGV)
storePath = options.store
if options.list
  doListing=true 
elsif options.loadlevels
  doLoadLevels = true
end


if storePath == nil 
  puts "please read usage note (-h)"
  exit
end

puts "# Workload Collection tool" if $verbose
storeFullPath = File.expand_path(storePath)
puts "# Using workload collection file #{storeFullPath}" if $verbose

workloads = WorkloadCollection.instanceFromFile(storeFullPath)

if doListing
  puts workloads.to_s
end

if doLoadLevels
  retval=""
  levels=workloads.getLoadlevels()
  levels.each{|level|
    retval += "#{level} "
  }
  puts retval
end
