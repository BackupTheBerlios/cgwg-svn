#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2006 Mathias Dalheimer, md@gonium.net
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
require 'Annotations'
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
      opts.on("-i", "--directory directory","the directory for input files") do |indir|
        options.indir=indir
      end
      opts.on("-l", "--load-level FLOAT","the load level to use") do |loadlevel|
        options.loadlevel=loadlevel
      end
      
      opts.on("-a", "--annotations file","the annotations to be added to the graph") do |annotations|
        options.annotations=annotations
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
options = Optparser.parse(ARGV)
indir = options.indir    
loadlevel = options.loadlevel.to_f
annotations = options.annotations
$verbose = options.verbose

puts "# Calana Scheduler - PAES annotation generator"
if indir == nil
  puts "please read usage note - directory must be given."
  exit
end
if loadlevel == nil
  puts "please read usage note - loadlevel must be given."
  exit
end
if annotations != nil
  annotationsFullPath = File.expand_path(annotations)
  puts "# Using annotations file #{annotationsFullPath}"
end 

indirFullPath = File.expand_path(indir)
puts "# Using data file directory #{indirFullPath}"

puts "# Generating annotations from logfile for load level #{loadlevel}."

# read QT and price values for different preferences
qt_avg=qt_low=qt_high=0.0
qtfile=File.join(indirFullPath, "load-QT.txt");
File.open(qtfile, "r") {|file|
  while (line=file.gets)
    if line =~ /^#/
      puts "skipping comment #{line}" if $verbose
    else
      puts "examining line #{line}" if $verbose
      items=line.split();
      currentlevel=items[0];
      if loadlevel.to_f == currentlevel.to_f
        puts "found loadlevel information!" if $verbose
        qt_avg=items[1];
        qt_low=items[2];
        qt_high=items[3];
      end
    end
  end
}
puts "Found QT: #{qt_avg}, QT_LOW_PERFPREF: #{qt_low}, QT_HIGH_PERFPREF: #{qt_high}"

price_avg=price_low=price_high=0.0
pricefile=File.join(indirFullPath, "load-avgprice.txt");
File.open(pricefile, "r") {|file|
  while (line=file.gets)
    if line =~ /^#/
      puts "skipping comment #{line}" if $verbose
    else
      puts "examining line #{line}" if $verbose
      items=line.split();
      currentlevel=items[0];
      if loadlevel.to_f == currentlevel.to_f
        puts "found loadlevel information!" if $verbose
        price_avg=items[1];
        price_low=items[2];
        price_high=items[3];
      end
    end
  end
}
puts "Found PRICE: #{price_avg}, P_LOW_PRICEPREF: #{price_low}, P_HIGH_PRICEPREF: #{price_high}"

# use QT as first, price as second coordinate, preference as text.
avgAnnotation=Annotation.new(qt_avg, price_avg, "Average")
lowAnnotation=Annotation.new(qt_low, price_high, "Low Performance Preference")
highAnnotation=Annotation.new(qt_high, price_low, "High Performance Preference")

File.open(annotationsFullPath, "w") {|file|
  file << "# QT\tPrice\tText\n"
  file << avgAnnotation.to_file_line + "\n"
  file << lowAnnotation.to_file_line + "\n"
  file << highAnnotation.to_file_line + "\n"
}
