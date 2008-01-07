# This file is part of the calana grid workload generator.
# (c) 2008 Mathias Dalheimer, md@gonium.net
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

require "open3"

DATAPLOT_CMD = "dataplot"
VARIABLE_LIST = "JID PRPREF PRICE PRICERT PEPREF RT QT RESPT"

class Dataplot
  def initialize(path, datafile)
    puts "Using datafile #{path+"/"+datafile}" if $verbose
    @path=path
    @datafile=datafile
    @dp_in, @dp_out, @dp_err = Open3.popen3(DATAPLOT_CMD)
    puts "dataplot in/out is #{@dp_in}/#{@dp_out}" if $verbose
    writePrefix()
  end

  def writePrefix()
    cmd= <<-END_OF_CMD
      ECHO OFF
      DIMENSION 20 VARIABLES
      ORIENTATION LANDSCAPE
      CD #{@path}
      READ #{@datafile} #{VARIABLE_LIST}
    END_OF_CMD
    executeCmd(cmd)
  end

  def plotSingleRun_Queuetime()
    drawcmd=<<-END_OF_CMD
      TITLE Job Queuetime Plot
      Y1LABEL Queuetime (s)
      X1LABEL Job ID
      PLOT QT
    END_OF_CMD
    executeToFile("qtplot") {
      executeCmd(drawcmd)
    }
  end

  def plotSingleRun_Price()
    drawcmd=<<-END_OF_CMD
      TITLE Job Price Plot
      Y1LABEL Price
      X1LABEL Job ID
      PLOT PRICE
    END_OF_CMD
    executeToFile("priplot") {
      executeCmd(drawcmd)
    }
  end
  
  def plotSingleRun_PricePrefVsPrice()
    drawcmd=<<-END_OF_CMD
      TITLE Price Preference vs. Price
      Y1LABEL Price
      X1LABEL Price Preference
      PLOT PRICE VERSUS PRPREF
    END_OF_CMD
    executeToFile("PvPPplot") {
      executeCmd(drawcmd)
    }
  end

  def plotSingleRun_PerfPrefVsQueueTime()
    drawcmd=<<-END_OF_CMD
      TITLE Performance Preference vs. Queuetime
      Y1LABEL Queuetime (s)
      X1LABEL Performance Preference
      PLOT QT VERSUS PEPREF
    END_OF_CMD
    executeToFile("QTvPPplot") {
      executeCmd(drawcmd)
    }
  end

  def executeToFile(outputfile)
    open=<<-END_OF_CMD
      DEVICE 2 CLOSE
      SET IPL1NA #{outputfile}.ps
      DEVICE 2 POSTSCRIPT
    END_OF_CMD
    executeCmd(open)
    yield
    close=<<-END_OF_CMD
      DEVICE 2 CLOSE
    END_OF_CMD
    executeCmd(close)
  end

  def executeCmd(cmd)
    puts "Executing:\n#{cmd}" if $verbose
    @dp_in.write(cmd)
    @dp_in.flush()
  end

  def plotSingleRun
    methods.grep(/^plotSingleRun_/){|m|
      self.send(m)
    }
    sleep(1)
  end

  def ps2pdf
    puts "Converting files PS -> PDF" if $verbose
    psfiles=Dir.glob("#{@path}/*.ps");
    psfiles.each {|psfile|
      pdffile=psfile.gsub(/.ps/, ".pdf")
      puts "Converting: #{psfile}->#{pdffile}" if $verbose
      out=`ps2pdf #{psfile} #{pdffile}`
      #out=system("ps2pdf #{psfile} #{pdffile}")
      puts "ps2pdf said: #{out}" if $verbose
    }
  end

  def finalize
    sleep(1)
    @dp_in.close();
    @dp_out.close();
    @dp_err.close();

  end
end

# Test routines below - execute this file directly...

#$verbose=true;
#dp=Dataplot.new("/scratch/md/single-synthetic/run04/load-0.902927433628319", "DP0.90.DAT");
#dp.plotSingleRun()
#dp.ps2pdf()
#dp.finalize()
