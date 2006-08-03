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


# =============================================================
# = Prints a 2-dimensional dataset , connects data with lines =
# =============================================================
def gnuPlot2Lines(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn, xmaxrange, ymaxrange)
    inputFile = inFile
    outputFile = outFile
    gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
set xrange [0:#{xmaxrange}]
set yrange [0:#{ymaxrange}]
set size 2,2
plot \\"#{inputFile}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\" with linespoints
EOC
    runGnuPlot(gnuplotCmd, inFile, outFile)
end

# ========================================================
# = Runs gnuplot with the given config, then runs ps2pdf =
# ========================================================
def runGnuPlot (gnuplotCmd, inputFile, outputFile)
    outPDFFile = outputFile.sub(/eps/, "pdf")
    outPNGFile = outputFile.sub(/eps/, "png")
    puts "Using gnuplot command: \n#{gnuplotCmd}\n" if $verbose
    puts "running gnuplot to create #{outputFile}"
    cmd = `echo -n "#{gnuplotCmd}" | gnuplot`
    print "Gnuplot said: \n#{cmd}\n" if $verbose
    print "converting to PDF\n" if $verbose
    cmd = `ps2pdf #{outputFile} #{outPDFFile}`
    print "ps2pdf said: #{cmd}\n" if $verbose
    cmd = `convert #{outputFile} -scale 800x600 #{outPNGFile}`
end
 
