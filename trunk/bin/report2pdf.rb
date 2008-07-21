#!/usr/bin/env ruby
# This file is part of the calana grid work$load generator.
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
  #  puts "Using libraty path #{$:.join(":")}" 
end


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
      opts.banner = "Usage: calana2r.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"
      # Mandatory argument.
      opts.on("-i", "--input directory", "the input file in calanasim format") do |indir|
        options.indir=indir
      end
      opts.on("-o", "--output directory","the output directory for the report files") do |outdir|
        options.outdir=outdir
    end
    opts.on("-l", "--load FLOAT", "the load level of the input
            file, e.g. 0.25") do |load|
      options.load=load
            end
    opts.on("-e", "--entity String", "The entity to plot when
            doing load-dependent plots, e.g. bidder-43") do |entity|
      options.entity=entity
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

# ========================================================
# = Runs gnuplot with the given config, then runs ps2pdf =
# ========================================================
def runGnuPlot (gnuplotCmd, inFile, outFile)
  inputFile = $inDir+"/"+inFile
  outputFile = $outDir+"/"+outFile
  outPDF = outFile.sub(/eps/, "pdf")
  outPDFFile = $outDir+"/"+outPDF
  puts "Using gnuplot command: \n#{gnuplotCmd}\n" if $verbose
  puts "running gnuplot to create #{outFile}"
  cmd = `echo -n "#{gnuplotCmd}" | gnuplot`
  print "Gnuplot said: \n#{cmd}\n" if $verbose 
  print "converting to PDF\n" if $verbose
  cmd = `ps2pdf #{outputFile} #{outPDFFile}`
  print "ps2pdf said: #{cmd}\n" if $verbose    
end

# ==================================
# = Prints a 2-dimensional dataset =
# ==================================
def gnuPlot2Data(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn)
  inputFile = $inDir+"/"+inFile
  outputFile = $outDir+"/"+outFile
  gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
plot \\"#{inputFile}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\"
EOC
  runGnuPlot(gnuplotCmd, inFile, outFile)
end

# =============================================================
# = Prints a 2-dimensional dataset , connects data with lines =
# =============================================================
def gnuPlot2Lines(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn)
  inputFile = $inDir+"/"+inFile
  sortedInput = "#{inputFile}.sorted"
  # Hack: Sort the values accending..."
  msg = `cat #{inputFile} | sort -n > #{sortedInput}`
  outputFile = $outDir+"/"+outFile
  gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
plot \\"#{sortedInput}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\" with linespoints
EOC
  runGnuPlot(gnuplotCmd, inFile, outFile)
end


# ==============================================================
# = Prints a 2-dimensional dataset , connects data with points =
# ==============================================================
def gnuPlot2Points(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn)
  inputFile = $inDir+"/"+inFile
  outputFile = $outDir+"/"+outFile
  gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
plot \\"#{inputFile}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\" with points pt 7
EOC
  runGnuPlot(gnuplotCmd, inFile, outFile)
end


# ======================================
# = Prints a multi-dimensional dataset =
# ======================================
def gnuPlotMultiData(inFile, outFile, title, xlabel, ylabel, columns)
  inputFile = $inDir+"/"+inFile
  outputFile = $outDir+"/"+outFile
  gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
EOC
  plotCmd="\nplot "
  maxIndex = columns.length()
  columns.each_index{|index|
    column = index+2
    if (index < maxIndex-1)
      tmp = <<-EOC
\\"#{inputFile}\\" using 1:#{column} title \\"#{columns[index]}\\" with steps, \\
EOC
    else
      tmp = <<-EOC
\\"#{inputFile}\\" using 1:#{column} title \\"#{columns[index]}\\" with steps
EOC
    end
    plotCmd << tmp
  }
  runGnuPlot(gnuplotCmd << plotCmd, inFile, outFile)    
end

# ======================================
# = Prints a multi-dimensional dataset with lines =
# ======================================
def gnuPlotMultiLines(inFile, outFile, title, xlabel, ylabel, columns)
    inputFile = $inDir+"/"+inFile
    sortedInput = "#{inputFile}.sorted"
    # Hack: Sort the values accending..."
    msg = `cat #{inputFile} | sort -n > #{sortedInput}`
    outputFile = $outDir+"/"+outFile
    gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
EOC
    plotCmd="\nplot "
    maxIndex = columns.length()
    columns.each_index{|index|
        column = index+2
        if (index < maxIndex-1)
            tmp = <<-EOC
\\"#{sortedInput}\\" using 1:#{column} title \\"#{columns[index]}\\" with lines, \\
EOC
        else
            tmp = <<-EOC
\\"#{sortedInput}\\" using 1:#{column} title \\"#{columns[index]}\\" with lines
EOC
        end
        plotCmd << tmp
    }
    runGnuPlot(gnuplotCmd << plotCmd, inFile, outFile)    
end


def discoverEntities(inFile)
    file = File.new($inDir+"/"+inFile, "r")
    entityLine = ""
    file.each_line {|line|
        if line =~ /#entities:/
            entityLine = line.sub(/#entities:/, "")
            entityLine.strip!
            break
        end
    }
    file.close()
    entities = entityLine.split(";")
    entities.compact!
    if $verbose
        entities.each{|entity|
            puts "#{entity}\n" 
        }
    end
    return entities
end

def plotNumberUnusedResources()
    values = Hash.new
    File.open("#{$inDir}/utilization-all.txt") { |file|
        # for each loadlevel (line), count the number of used resources.
        file.each_line {|line|
            if line =~ /^#/
                next
            end
            counter = 0
            entities = line.split()
            # The first field contains the load level of the workload
            loadLevel = entities[0].to_f
            # The second contains the aggregated load, ignore it
            for i in 2..entities.length
                if (entities[i].to_f > 0.0)
                    counter += 1
                end
            end
            numAgents = entities.length - 2
            values[loadLevel] = numAgents - counter
            #puts "Discovered loadLevel=#{loadLevel}, counter=#{counter}"
        }
    }
    sortedLoads=values.sort()
    outFile = File.open("#{$inDir}/utilization-unused-resources.txt", "w")
    sortedLoads.each {|loadLevel, value|
        puts "Writing line: LoadLevel=#{loadLevel}; value = #{value}" if $verbose
        outFile.puts "#{loadLevel}\t#{value}"
    }
    outFile.close
    gnuPlot2Lines("utilization-unused-resources.txt",
        "utilization-unused-resources.eps", 
        "Number of unused Resources vs. Load", "Load", "Unused Resources", 1,2)

end

# Runs the load-dependent scripts.
def runLoadDepScripts()
    gnuPlot2Points("time-price-#{$load}.txt", "time-price-#{$load}.eps", 
        "Time vs. Price per Second", "time", "price", 1, 2)
    gnuPlot2Points("queue-time-#{$load}.txt", "queue-time-#{$load}.eps", 
        "Time vs. QueueTime", "Time", "queueTime", 1, 2)
    gnuPlot2Points("turn-over-#{$load}.txt", "turn-over-#{$load}.eps",
        "Agents vs. Turn over", "agents", "turn over", 1, 2)
    gnuPlot2Data("price-pref-#{$load}.txt", "price-pref-#{$load}.eps", 
        "Time vs. PricePreference", "time", "accuracy of user preference", 1, 2)
    gnuPlot2Data("price-rt-preference-#{$load}.txt", "price-rt-pref-#{$load}.eps", 
        "Price vs. PricePreference", "pricePref", "pricePerSecond", 2, 1)
    gnuPlot2Data("price-rt-preference-#{$load}.txt", "perf-pref-#{$load}.eps", 
        "Queuetime vs. PerfPreference", "perfPref", "queuetime", 4, 3)
    names = discoverEntities("utilization-#{$load}.txt")
    gnuPlotMultiData("utilization-#{$load}.txt", "utilization-#{$load}.eps", 
        "Utilization per agent", "time", "utilization", names)
    names = discoverEntities("queuelength-#{$load}.txt")
    gnuPlotMultiData("queuelength-#{$load}.txt", "queuelength-#{$load}.eps", 
        "Queue length per agent", "time", "queue length", names)
end

def runLoadDepScriptsEntity(entity)
    names = discoverEntities("utilization-#{$load}.txt")
    position = names.index(entity)
    if position == nil
        puts "This entity is not defined in utilization-#{$load}.txt"
    else
        gnuPlot2Lines("utilization-#{$load}.txt",
        "utilization-#{$load}-#{entity}.eps", 
            "Utilization for agent #{entity}", "time", "utilization",
            1,position)
    end
    names = discoverEntities("queuelength-#{$load}.txt")
    position = names.index(entity)
    if position == nil
        puts "This entity is not defined in queuelength-#{$load}.txt"
    else
        gnuPlot2Lines("queuelength-#{$load}.txt",
        "queuelength-#{$load}-#{entity}.eps", 
        "Queue length for agent #{entity}", "time", "queue length", 1,
        position)
    end
end


# Runs the load-independent plot scripts.
def runGeneralScripts()
    gnuPlot2Lines("load-ART.txt", "load-ART.eps", 
        "Average Response Time vs. Load", "Load", "ART", 1,2)

    names = Array.new
    names << "ART" << "ART (perfPref <= 0.25)" 
    names << "ART (perfPref >= 0.75)"
    gnuPlotMultiLines("load-ART.txt", "load-ART-all.eps", 
        "Average Response Time vs. Load (with perfPref settings)",
        "Load", "ART", names)

    names = Array.new
    names << "Queuetime" << "Queuetime (perfPref <= 0.25)" 
    names << "Queuetime (perfPref >= 0.75)"
    gnuPlotMultiLines("load-QT.txt", "load-QT-all.eps", 
        "Average Queue Time vs. Load (with perfPref settings)",
        "Load", "Queuetime", names)

    gnuPlot2Lines("load-avgprice.txt", "load-avgprice.eps", 
        "Average Price vs. Load", "Load", "Average Price", 1,2)

    names = Array.new
    names << "Price" << "Price (pricePref <= 0.25)" 
    names << "Price (pricePref >= 0.75)"
    gnuPlotMultiLines("load-avgprice.txt", "load-avgprice-all.eps", 
        "Average Price vs. Load", "Load", "Average Price", names)
    gnuPlot2Lines("preference-correlation.txt", "priceCorrelation.eps", 
        "Price-PricePreference-Correlation vs. Load", "Load",
        "Correlation of Price and PricePreference", 1,2)
    gnuPlot2Lines("preference-correlation.txt", "perfCorrelation.eps", 
        "Queuetime-PerfPreference-Correlation vs. Load", "Load",
        "Correlation of Queuetime and Performance Preference", 1,3)
    gnuPlot2Lines("utilization-all.txt", "utilization-all.eps", 
        "Average Utilization vs. Load", "Load", "Average Utilization",
        1, 2)
    plotNumberUnusedResources()
end

###
## Script begins here
#
print "report to PDF converter\n"

options = Optparser.parse(ARGV)

$inDir = options.indir
$outDir = options.outdir
$load = options.load
$verbose = options.verbose
$entity = options.entity

if $inDir == nil or $outDir == nil 
    print "please read usage note (-h)\n"
    exit
end

if $load == nil
    puts "No load specified, running load-independent scripts"
    runGeneralScripts()
else
    if $entity == nil
        puts "Running load-dependent scripts only, for all entities"
        runLoadDepScripts()
    else
        puts "Running load-dependent scripts only, for entity #{$entity}"
        runLoadDepScriptsEntity($entity)
    end
end


