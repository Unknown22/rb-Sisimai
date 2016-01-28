module Sisimai
  module MSP::US
    # Sisimai::MSP::US::Verizon parses a bounce email which created by Verizon
    # Wireless. Methods in the module are called from only Sisimai::Message.
    module Verizon
      # Imported from p5-Sisimail/lib/Sisimai/MSP/US/Verizon.pm
      class << self
        require 'sisimai/msp'
        require 'sisimai/rfc5322'

        Re0 = {
          :'received'  => %r/by .+[.]vtext[.]com /,
          :'vtext.com' => {
              :'from' => %r/\Apost_master[@]vtext[.]com\z/,
          },
          :'vzwpix.com' => {
              :'from'    => %r/[<]?sysadmin[@].+[.]vzwpix[.]com[>]?\z/,
              :'subject' => %r/Undeliverable Message/,
          },
        }
        Indicators = Sisimai::MSP.INDICATORS
        LongFields = Sisimai::RFC5322.LONGFIELDS
        RFC822Head = Sisimai::RFC5322.HEADERFIELDS

        def description; return 'Verizon Wireless: http://www.verizonwireless.com'; end
        def smtpagent;   return 'US::Verizon'; end
        def headerlist;  return []; end
        def pattern
          return {
            :from => %r/(?:\Apost_master[@]vtext[.]com|[<]?sysadmin[@].+[.]vzwpix[.]com[>]?)\z/,
            :subject => Re0[:'vzwpix.com'][:subject],
          }
        end

        # Parse bounce messages from Verizon
        # @param         [Hash] mhead       Message header of a bounce email
        # @options mhead [String] from      From header
        # @options mhead [String] date      Date header
        # @options mhead [String] subject   Subject header
        # @options mhead [Array]  received  Received headers
        # @options mhead [String] others    Other required headers
        # @param         [String] mbody     Message body of a bounce email
        # @return        [Hash, Nil]        Bounce data list and message/rfc822
        #                                   part or nil if it failed to parse or
        #                                   the arguments are missing
        def scan(mhead, mbody)
          return nil unless mhead
          return nil unless mbody

          match = -1
          loop do
            # Check the value of "From" header
            break unless mhead['received'].find { |a| a =~ Re0[:received] }
            match = 1 if mhead['from'] =~ Re0[:'vtext.com'][:from]
            match = 0 if mhead['from'] =~ Re0[:'vzwpix.com'][:from]
            break
          end
          return nil if match < 0

          require 'sisimai/mime'
          require 'sisimai/address'
          dscontents = []; dscontents << Sisimai::MSP.DELIVERYSTATUS
          hasdivided = mbody.split("\n")
          rfc822next = { 'from' => false, 'to' => false, 'subject' => false }
          rfc822part = ''     # (String) message/rfc822-headers part
          previousfn = ''     # (String) Previous field name
          readcursor = 0      # (Integer) Points the current cursor position
          recipients = 0      # (Integer) The number of 'Final-Recipient' header
          senderaddr = ''     # (String) Sender address in the message body
          subjecttxt = ''     # (String) Subject of the original message

          re1        = {}     # (Ref->Hash) Delimiter patterns
          reFailure  = {}     # (Ref->Hash) Error message patterns
          boundary00 = ''     # (String) Boundary string
          v = nil

          if match == 1
            # vtext.com
            re1 = {
              :begin  => %r/\AError:[ \t]/,
              :rfc822 => %r/\A__BOUNDARY_STRING_HERE__\z/,
              :endof  => %r/\A__END_OF_EMAIL_MESSAGE__\z/,
            }
            reFailure = {
              # The attempted recipient address does not exist.
              'userunknown' => %r{
                550[ ][-][ ]Requested[ ]action[ ]not[ ]taken:[ ]no[ ]such[ ]user[ ]here
              }x,
            }
            rfc822next = { 'from' => 0, 'to' => 0, 'subject' => 0 }
            boundary00 = Sisimai::MIME.boundary(mhead['content-type']) || ''

            if boundary00.size > 0
              # Convert to regular expression
              re1['rfc822'] = Regexp.new('\A' + Regexp.escape('--' + boundary00 + '--') + '\z')
            end

            hasdivided.each do |e|
              if readcursor == 0
                # Beginning of the bounce message or delivery status part
                if e =~ re1[:begin]
                  readcursor |= Indicators[:'deliverystatus']
                  next
                end
              end

              if readcursor & Indicators[:'message-rfc822'] == 0
                # Beginning of the original message part
                if e =~ re1[:rfc822]
                  readcursor |= Indicators[:'message-rfc822']
                  next
                end
              end

              if readcursor & Indicators[:'message-rfc822'] > 0
                # After "message/rfc822"
                if cv = e.match(/\A([-0-9A-Za-z]+?)[:][ ]*.+\z/)
                  # Get required headers only
                  lhs = cv[1].downcase
                  previousfn = '';
                  next unless RFC822Head.key?(lhs)

                  previousfn  = lhs
                  rfc822part += e + "\n"

                elsif e =~ /\A[ \t]+/
                  # Continued line from the previous line
                  next if rfc822next[previousfn]
                  rfc822part += e + "\n" if LongFields.key?(previousfn)

                else
                  # Check the end of headers in rfc822 part
                  next unless LongFields.key?(previousfn)
                  next unless e.empty?
                  rfc822next[previousfn] = true
                end

              else
                # Before "message/rfc822"
                next if readcursor & Indicators[:'deliverystatus'] == 0
                next if e.empty?

                # Message details:
                #   Subject: Test message
                #   Sent date: Wed Jun 12 02:21:53 GMT 2013
                #   MAIL FROM: *******@hg.example.com
                #   RCPT TO: *****@vtext.com
                v = dscontents[-1]
                if cv = e.match(/\A[ \t]+RCPT TO: (.*)\z/)
                  if v['recipient']
                    # There are multiple recipient addresses in the message body.
                    dscontents << Sisimai::MSP.DELIVERYSTATUS
                    v = dscontents[-1]
                  end

                  v['recipient'] = cv[1]
                  recipients += 1
                  next

                elsif cv = e.match(/\A[ \t]+MAIL FROM:[ \t](.+)\z/)
                  #   MAIL FROM: *******@hg.example.com
                  senderaddr = cv[1] if senderaddr.empty?

                elsif cv = e.match(/\A[ \t]+Subject:[ \t](.+)\z/)
                  #   Subject:
                  subjecttxt = cv[1] if subjecttxt.empty?

                else
                  # 550 - Requested action not taken: no such user here
                  v['diagnosis'] = e if e =~ /\A(\d{3})[ \t][-][ \t](.*)\z/
                end
              end
            end

          else
            # vzwpix.com
            re1 = {
              :begin  => %r/\AMessage could not be delivered to mobile/,
              :rfc822 => %r/\A__BOUNDARY_STRING_HERE__\z/,
              :endof  => %r/\A__END_OF_EMAIL_MESSAGE__\z/,
            }
            reFailure = {
                'userunknown' => %r{
                    No[ ]valid[ ]recipients[ ]for[ ]this[ ]MM
                }x,
            }
            rfc822next = { 'from' => 0, 'to' => 0, 'subject' => 0 }
            boundary00 = Sisimai::MIME.boundary(mhead['content-type'])
            if boundary00.size > 0
              # Convert to regular expression
              re1['rfc822'] = Regexp.new('\A' + Regexp.escape('--' + boundary00 + '--') + '\z')
            end

            hasdivided.each do |e|
              if readcursor == 0
                # Beginning of the bounce message or delivery status part
                if e =~ re1[:begin]
                  readcursor |= Indicators[:'deliverystatus']
                  next
                end
              end

              if readcursor & Indicators[:'message-rfc822'] == 0
                # Beginning of the original message part
                if e =~ re1[:rfc822]
                  readcursor |= Indicators[:'message-rfc822']
                  next
                end
              end

              if readcursor & Indicators[:'message-rfc822'] > 0
                # After "message/rfc822"
                if cv = e.match(/\A([-0-9A-Za-z]+?)[:][ ]*.+\z/)
                  # Get required headers only
                  lhs = cv[1].downcase
                  previousfn = '';
                  next unless RFC822Head.key?(lhs)

                  previousfn  = lhs
                  rfc822part += e + "\n"

                elsif e =~ /\A[ \t]+/
                  # Continued line from the previous line
                  next if rfc822next[previousfn]
                  rfc822part += e + "\n" if LongFields.key?(previousfn)

                else
                  # Check the end of headers in rfc822 part
                  next unless LongFields.key?(previousfn)
                  next unless e.empty?
                  rfc822next[previousfn] = true
                end

              else
                # Before "message/rfc822"
                next if readcursor & Indicators[:'deliverystatus'] == 0
                next if e.empty?

                # Original Message:
                # From: kijitora <kijitora@example.jp>
                # To: 0000000000@vzwpix.com
                # Subject: test for bounce
                # Date:  Wed, 20 Jun 2013 10:29:52 +0000
                v = dscontents[-1]
                if cv = e.match(/\ATo:[ \t]+(.*)\z/)
                  if v['recipient']
                    # There are multiple recipient addresses in the message body.
                    dscontents << Sisimai::MSP.DELIVERYSTATUS
                    v = dscontents[-1]
                  end
                  v['recipient'] = Sisimai::Address.s3s4(cv[1])
                  recipients += 1
                  next

                elsif cv = e.match(/\AFrom:[ \t](.+)\z/)
                  # From: kijitora <kijitora@example.jp>
                  senderaddr = Sisimai::Address.s3s4(cv[1]) if senderaddr.empty?

                elsif cv = e.match(/\ASubject:[ \t](.+)\z/)
                  #   Subject:
                  subjecttxt = cv[1] if subjecttxt.empty?

                else
                  # Message could not be delivered to mobile.
                  # Error: No valid recipients for this MM
                  v['diagnosis'] = e if e =~ /\AError:[ \t]+(.+)\z/
                end
              end
            end
          end

          return nil if recipients == 0

          # Set the value of "MAIL FROM:" or "From:", and "Subject"
          rfc822part += sprintf("From: %s\n", senderaddr) unless rfc822part =~ /\bFrom: /
          rfc822part += sprintf("Subject: %s\n", subjecttxt) unless rfc822part =~ /\bSubject: /

          require 'sisimai/string'
          require 'sisimai/smtp/status'

          dscontents.map do |e|
            if mhead['received'].size > 0
              # Get localhost and remote host name from Received header.
              r0 = mhead['received']
              ['lhost', 'rhost'].each { |a| e[a] ||= '' }
              e['lhost'] = Sisimai::RFC5322.received(r0[0]).shift if e['lhost'].empty?
              e['rhost'] = Sisimai::RFC5322.received(r0[-1]).pop  if e['rhost'].empty?
            end
            e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'])

            reFailure.each_key do |r|
              # Verify each regular expression of session errors
              next unless e['diagnosis'] =~ reFailure[r]
              e['reason'] = r
              break
            end

            e['status'] = Sisimai::SMTP::Status.find(e['diagnosis'])
            e['spec']   = e['reason'] == 'mailererror' ? 'X-UNIX' : 'SMTP'
            e['action'] = 'failed' if e['status'] =~ /\A[45]/
            e['agent']   = Sisimai::MSP::US::Verizon.smtpagent
          end

          return { 'ds' => dscontents, 'rfc822' => rfc822part }
        end

      end
    end
  end
end
