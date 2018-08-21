module Sisimai
  # Sisimai::String provide utilities for dealing string
  module String
    # Imported from p5-Sisimail/lib/Sisimai/String.pm
    class << self
      # End of email message as a sentinel for parsing bounce messages
      # @private
      # @return   [String] Fixed length string like a constant
      def EOM; return '__END_OF_EMAIL_MESSAGE__'; end

      # Create message token from addresser and recipient
      # @param  [String]  addr1 Sender address
      # @param  [String]  addr2 Recipient address
      # @param  [Integer] epoch Machine time of the email bounce
      # @return [String]        Message token(MD5 hex digest)
      # @return [String]        Blank/failed to create token
      # @see    http://en.wikipedia.org/wiki/ASCII
      def token(addr1, addr2, epoch)
        return '' unless addr1.is_a?(::String)
        return '' unless addr1.size > 0
        return '' unless addr2.is_a?(::String)
        return '' unless addr2.size > 0
        return '' unless epoch.is_a?(Integer)

        # Format: STX(0x02) Sender-Address RS(0x1e) Recipient-Address ETX(0x03)
        require 'digest/sha1'
        return Digest::SHA1.hexdigest(
          sprintf("\x02%s\x1e%s\x1e%d\x03", addr1.downcase, addr2.downcase, epoch)
        )
      end

      # The argument is 8-bit text or not
      # @param    [String] argvs  Any string to be checked
      # @return   [True,False]    false: ASCII Characters only
      #                           true:  Including 8-bit character
      def is_8bit(argvs)
        v = argvs.to_s
        return nil   if v.empty?
        return true  unless v =~ /\A[\x00-\x7f]*\z/
        return false
      end

      # Clean the string out
      # @param    [String] argv1  String to be cleaned
      # @return   [String]        Cleaned out string
      # @example  Clean up text
      #   sweep('  neko ') #=> 'neko'
      def sweep(argv1)
        return argv1 unless argv1.is_a?(::String)

        argv1 = argv1.chomp
        argv1 = argv1.squeeze(' ')
        argv1 = argv1.delete("\t")
        argv1 = argv1.strip
        argv1 = argv1.sub(/ [-]{2,}[^ \t].+\z/, '')

        return argv1
      end

      # Convert given HTML text to plain text
      # @param    [String]  argv1 HTML text
      # @param    [Boolean] loose Loose check flag
      # @return   [String]  Plain text
      def to_plain(argv1 = '', loose = false)
        return '' if argv1.empty?

        plain = argv1
        match = {
          html: %r|<html[ >].+?</html>|sim,
          body: %r|<head>.+</head>.*<body[ >].+</body>|sim,
        }

        if loose || plain =~ match[:html] || plain =~ match[:body]
          # <html> ... </html>
          # Rewrite <a> elements
          # 1. <a href = 'http://...'>...</a> to " http://... "
          # 2. <a href = 'mailto:...'>...</a> to " Value <mailto:...> "
          plain = plain.scrub('?')
          plain = plain.gsub(%r|<a\s+href\s*=\s*['"](https?://.+?)['"].*?>(.*?)</a>|i, '[\2](\1)')
          plain = plain.gsub(%r|<a\s+href\s*=\s*["']mailto:([^\s]+?)["']>(.*?)</a>|i, '[\2](mailto:\1)')

          plain = plain.gsub(/<[^<@>]+?>\s*/, ' ')  # Delete HTML tags except <neko@example.jp>
          plain = plain.gsub(/&lt;/, '<')           # Convert to left angle brackets
          plain = plain.gsub(/&gt;/, '>')           # Convert to right angle brackets
          plain = plain.gsub(/&amp;/, '&')          # Convert to "&"
          plain = plain.gsub(/&quot;/, '"')         # Convert to '"'
          plain = plain.gsub(/&apos;/, "'")         # Convert to "'"
          plain = plain.gsub(/&nbsp;/, ' ')         # Convert to ' '

          if argv1.size > plain.size
            plain  = plain.squeeze(' ')
            plain << "\n"
          end
        end

        return plain
      end

      # Convert given string to UTF-8
      # @param    [String] argv1  String to be converted
      # @param    [String] argv2  Encoding name before converting
      # @return   [String]        UTF-8 Encoded string
      def to_utf8(argv1 = '', argv2 = nil)
        return '' unless argv1.size > 0

        encodefrom = argv2 || false
        getencoded = ''

        begin
          # Try to convert the string to UTF-8
          getencoded = if encodefrom
                         # String#encode('UTF-8', <FROM>)
                         argv1.encode('UTF-8', encodefrom)
                       else
                         # Force encoding to UTF-8
                         argv1.force_encoding('UTF-8')
                       end
        rescue
          # Unknown encoding name or failed to encode
          getencoded = argv1.force_encoding('UTF-8')
        end
        getencoded = getencoded.scrub('?')

        return getencoded
      end

    end
  end
end
