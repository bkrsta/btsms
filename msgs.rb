%w(rubygems serialport time).each {|v|require v}

class GSM
  # SMSC = "+38598"

  def initialize(options = {})
    @port = SerialPort.new(options[:port] || 3, options[:baud] || 38400, options[:bits] || 8, options[:stop] || 1, SerialPort::NONE)
    @debug = options[:debug]
    cmd("AT")
    # cmd("AT+CSCA=\"#{SMSC}\"") # Set SMSC number
  end

  def close()
    @port.close
  end

  def cmd(cmd)
    @port.write(cmd + "\r")
    wait
  end

  def wait
    buffer = ''
    while IO.select([@port], [], [], 0.25)
      chr = @port.getc.chr;
      print chr if @debug == true
      buffer += chr
    end
    buffer
  end

  def send_sms(options)
    cmd("AT+CMGS=\"#{options[:number]}\"")
    cmd("#{options[:message][0..140]}#{26.chr}\r\r")
    sleep 3
    wait
    cmd("AT")
  end

  class SMS
    attr_accessor :id, :sender, :message, :connection
    attr_writer :time

    def initialize(params)
      @id = params[:id]; @sender = params[:sender]; @time = params[:time]; @message = params[:message]; @connection = params[:connection]
    end

    def delete
      @connection.cmd("AT+CMGD=#{@id}")
    end

    def time
      Time.parse(@time.sub(/(\d+)\D+(\d+)\D+(\d+)/, '\2/\3/20\1'))
    end
  end

  def messages
    # sms = cmd("AT+CMGL=4")
    cmd 'AT+CPMS="ME"'
    sms = cmd("AT+CMGL=1")
    # msgs = sms.scan(/\+CMGL\:\s*?(\d+)\,.*?\,\"(.+?)\"\,.*?\,\"(.+?)\".*?\n(.*)/)
    msgs = sms.scan /\+CMGL: (\d+),(\d+),,(\d+)\r\n(.+)\r/
    return nil unless msgs
    # msgs.collect!{ |m| GSM::SMS.new(:connection => self, :id => m[0], :status => m[1], :message => m[3].chomp) } rescue nil
    msgs.collect!{ |m| {:connection => self, :id => m[0], :status => m[1], :message => m[3].chomp} } rescue nil
  end
end

def parse msg, id
  out = `v8 pdu.js -e "getPDUMetaInfo('#{msg}')"`

  {
    :id => id,
    :smsc => begin out.scan(/SMSC#(.+)/)[0][0] rescue nil end,
    :from => begin out.scan(/Sender:(.+)/)[0][0] rescue nil end,
    :date => begin out.scan(/TimeStamp:(.+)/)[0][0] rescue nil end,
    :msg => begin out.split("\n\n")[1].scan(/(.+)\nLength/)[0][0] rescue nil end,
    :length => begin out.split("\n\n")[1].scan(/\nLength:(\d+)/)[0][0] rescue nil end
  }
end

x = GSM.new(:port => "/dev/tty.BKrsta-SerialPort", :baud => 115200, :debug => false)
# x.cmd 'AT+CPMS="ME"'
x.messages.each { |v|
  m = parse v[:message], v[:id]
  puts [m, v[:message]].inspect
}
