require 'eventmachine'
require 'em-http'
require 'tk'
require 'tkextlib/tkimg'

class StreamingJPEG 
  attr_accessor :separator

  def initialize
    @root = TkRoot.new do
      title "Streaming JPEG Display"
      minsize(640, 480); maxsize(640, 480)
      resizable(false, false)
    end
    @buffer = ''; @first = true; @last_n_characters = []
  end

  def append(chunk)
    StringIO.new(chunk).each_byte do |character|
      append_character(character)
      joined = @last_n_characters.join

      if !@first and joined == @separator
        draw
        @buffer = ''
      elsif @first and joined == @separator
        @buffer = ''; @first = false
      end
    end
  end

  private

  def draw
    raw = @buffer[53, @buffer.length - @separator.length - 2 - 53]
    TclTkLib.do_one_event(TclTkLib::EventFlag::ALL | TclTkLib::EventFlag::DONT_WAIT)

    @image.delete if defined?(@image)
    @image = TkPhotoImage.new(:format => 'jpeg', :data => raw)
    @label ||= TkLabel.new(@root) 
    @label.image = @image
    @label.place('width' => 640, 'height' => 480, 'x' => 0, 'y' => 0)
  end

  def append_character(character)
    character = character.chr
    @last_n_characters.shift if @last_n_characters.length == separator.length
    @last_n_characters.push(character)
    @buffer << character
  end
end

gui = StreamingJPEG.new
Thread.new { Tk.mainloop }

EM.run do
  http = EM::HttpRequest.new('http://streaming_jpeg_source.com/videostream.cgi').get :head => {'authorization' => ['username', 'password']}

  http.stream do |chunk|
    gui.separator ||= http.response_header['CONTENT_TYPE'].match(/boundary=(.*?)$/i)[1]
    gui.append(chunk)
    EM.stop if gui.frames == 10
  end
end
