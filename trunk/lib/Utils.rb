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

###
## Mixin for a real clone of a class instance.
#
module DeepClone
  def deep_clone
    return Marshal::load(Marshal.dump(self))
  end
end


###
## Add loglines to the reporter, then dump them later on.
#
class LogReporter
  def initialize
    @lines=Array.new
    @header=""
  end
  def setHeader(header)
    @header=header.to_s
  end
  def addLine(line)
    @lines << (line.to_s)
  end
  def dumpToFile(filename)
    File.open(filename, "w") { |file|
      file.write(@header + "\n")
      @lines.each{|line|
        file.write(line + "\n")
      }
    }
  end
  def dumpToString()
    retval = @header
    @lines.each{|line|
      retval += line + "\n"
    }
  end
end


def mda(width, height)
  mda = Array.new(width)
  mda.map! { Array.new(height) }
end
