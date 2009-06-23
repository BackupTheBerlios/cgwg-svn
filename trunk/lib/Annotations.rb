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


class Annotation
  attr_accessor :qt, :price, :text
  def initialize(qt, price, text)
    @qt=qt
    @price=price
    @text=text
  end
  def to_file_line
    retval = "#{@qt}\t#{@price}\t#{@text}"
  end
  def to_s
    retval = "QT: #{@qt}, P: #{@price}: #{@text}"
  end
end

#todo
class FileAnnotationFactory
  def initialize(filepath)
    @filepath=filepath
  end
  def getAnnotationCollection
  end
end

class AnnotationCollection
  def initialize(filepath)
    @filepath=filepath
    @annotations=Array.new()
    parseFile()
  end
  def parseFile()
    File.open(@filepath){|file|
      while (line=file.gets)
        if line =~ /^#/
          puts "skipping comment #{line}" if $verbose
        else
          puts "adding annotation #{line}" if $verbose
          items=line.split();
          qt=items[0].to_f;
          price=items[1].to_f;
          text=""
          items[2..-1].each{|t|
            text += "#{t} "
          }
          a=Annotation.new(qt, price, text);
          @annotations << a
        end
      end
    }
  end
  def size
    return @annotations.size();
  end
  def each
    @annotations.each{|a|
      yield a
    }
  end
  def getMinQT
    minQTAnnotation = @annotations.min{|a,b|
      a.qt <=> b.qt
    }
    return minQTAnnotation.qt
  end
  def getMinPrice
    minPriceAnnotation = @annotations.min{|a,b|
      a.price <=> b.price
    }
    return minPriceAnnotation.price
  end
  def getMaxQT
    maxQTAnnotation = @annotations.max{|a,b|
      a.qt <=> b.qt
    }
    return maxQTAnnotation.qt
  end
  def getMaxPrice
    maxPriceAnnotation = @annotations.max{|a,b|
      a.price <=> b.price
    }
    return maxPriceAnnotation.price
  end
  def to_s
    retval=""
    @annotations.each{|a|
      retval += " - #{a.to_s}\n"
    }
    retval
  end
end


