#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2006 Mathias Dalheimer, md@gonium.net
#
# The calana grid work$load generator (CGWG) is free software; you can 
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
end

require 'optparse'
require 'ostruct'
require 'find'

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
      opts.banner = "Usage: analysis.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"
      # Mandatory argument.
      opts.on("-i", "--input directory", "the top-level directory with the load level logs") do |indir|
        options.indir=indir
      end
      opts.on("-o", "--output directory","the output directory for the PDFs") do |outdir|
        options.outdir=outdir
      end
      opts.on("-v", "--verbose", "Run verbosely") do |v|
        options.verbose = v
      end
      opts.on("-s", "--short", "Run only the report section and ignore the traces -> much faster") do |v|
        options.short = v
      end
      opts.on("-m", "--mode STRING", "Mode can be: sa or calana") do |v|
        options.mode = v
      end
      opts.on("-f", "--force", "Do not check whether the output directory is empty") do |v|
        options.force = v
      end
      opts.on("-d", "--workload-dir DIR", "base path to the workload directories (set if -w option is set)") do |d|
        options.wlDir = d
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

def calanaAnalysis
  # Create a list of load levels, from the subdirectories in the input
  # directory

  logDirs = Hash.new

  Find.find($inDir) { |path|
    if FileTest.directory?(path)
      puts "Found dir: #{path}"
      basename = File.basename(path)
      if basename =~ /^load-/
        loadLevel = basename.sub(/load-/, "")
        logDirs[loadLevel] = path
      end
    end
  }

  if $verbose
    logDirs.each_pair{ | load, path |
      puts "Loadlevel: #{load}, LogDir: #{path}"
    }
  end

  # For each load level, run the calana2report script

  logDirs.each_pair {| load, path |
    puts "###\n## Processing load: #{load}\n#\n"
    report = File.join(File.expand_path(path), "report.log")
    trace = File.join(File.expand_path(path), "trace.log")
    cmd = "ruby #{$basedir}/bin/calana2report.rb -r #{report} -l #{load} -o #{$outDir}"
      cmd += " -d #{$wlDir}" if $wlDir != nil 
    if (not $short)
      cmd << " -t #{trace}" 
    end
    if $verbose
      cmd << " -v"
    end
    output = `#{cmd}`
    #puts "#{cmd}\n"
    puts "#{output}" if $verbose
    #Run the report2pdf script for each load level
    cmd = "ruby #{$basedir}/bin/report2pdf.rb -i #{$outDir} -l #{load} -o #{$outDir}"
    output = `#{cmd}`
    puts "#{output}" if $verbose
  }
end

def saAnalysis
  logDirs = Hash.new
  Find.find($inDir) { |path|
    if FileTest.file?(path)
      if path =~ /\.bin$/
        basename = File.basename(path)
        loadLevel = basename.sub(/sa-schedule-/, "")
        loadLevel = loadLevel.sub(/\.bin$/, "")
        puts "Loadlevel #{loadLevel}, path #{path}"
        logDirs[loadLevel] = path
      end
    end
  }
  if $verbose
    logDirs.each_pair{ | load, path |
      puts "Loadlevel: #{load}, path: #{path}"
    }
  end
  # For each load level, run the calana2report script
  logDirs.each_pair {| load, path |
    puts "###\n## Processing load: #{load}\n#\n"
    #schedulebin = File.join($inDir, path)
    cmd = "ruby #{$basedir}/bin/calana2report.rb -s #{path} -l #{load} -o #{$outDir}"   #TODO maybe add wlDir (see calanaAnalysis)
    if $verbose
      cmd << " -v"
    end
    output = `#{cmd}`
    #puts "#{cmd}\n"
    puts "#{output}" if $verbose
    #Run the report2pdf script for each load level
    cmd = "ruby #{$basedir}/bin/report2pdf.rb -i #{$outDir} -l #{load} -o #{$outDir}"
    output = `#{cmd}`
    puts "#{output}" if $verbose
  }
end

###
## Script begins here
#
print "Calana Analysis Frontend\n"

options = Optparser.parse(ARGV)

$inDir = options.indir
$outDir = options.outdir
$verbose = options.verbose
$short = options.short
$force = options.force
$wlDir = options.wlDir

if $inDir == nil or $outDir == nil
  print "please read usage note (-h)\n"
  exit
end

$basedir=File.expand_path(ENV["CGWG_HOME"])
#$basedir=File.dirname(__FILE__)
#$basedir=Dir.getwd
print "Assuming base directory #{$basedir}\n"

# Purge output directory
empty = true;
Find.find($outDir) {|path|
  puts "Found #{path}" if $verbose
  if (path != $outDir)
    empty = false
  end
}
if (! empty)
  if not $force
    puts "Output directory is not empty - please purge it..."
    exit(10)
  else
    puts "Output directory not empty - forced to ignore..."
  end
end

if (options.mode.upcase == "CALANA")
  calanaAnalysis
elsif (options.mode.upcase == "SA")
  saAnalysis
end

# Run the report2pdf script
cmd = "ruby #{$basedir}/bin/report2pdf.rb -i #{$outDir} -o #{$outDir}"
if $verbose
  cmd << " -v"
end
output = `#{cmd}`
puts "#{output}" if $verbose
nca
