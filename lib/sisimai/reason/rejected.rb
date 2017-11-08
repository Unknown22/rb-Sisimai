module Sisimai
  module Reason
    # Sisimai::Reason::Rejected checks the bounce reason is "rejected" or not.
    # This class is called only Sisimai::Reason class.
    #
    # This is the error that a connection to destination server was rejected by
    # a sender's email address (envelope from). Sisimai set "rejected" to the
    # reason of email bounce if the value of Status: field in a bounce email is
    # "5.1.8" or the connection has been rejected due to the argument of SMTP
    # MAIL command.
    #
    #   <kijitora@example.org>:
    #   Connected to 192.0.2.225 but sender was rejected.
    #   Remote host said: 550 5.7.1 <root@nijo.example.jp>... Access denied
    module Rejected
      # Imported from p5-Sisimail/lib/Sisimai/Reason/Rejected.pm
      class << self
        def text; return 'rejected'; end
        def description
          return "Email rejected due to a sender's email address (envelope from)"
        end

        # Try to match that the given text and regular expressions
        # @param    [String] argv1  String to be matched with regular expressions
        # @return   [True,False]    false: Did not match
        #                           true: Matched
        def match(argv1)
          return nil unless argv1
          isnot = %r/recipient[ ]address[ ]rejected/xi
          regex = %r{(?>
             [<][>][ ]invalid[ ]sender
            |address[ ]rejected
            |batv[ ](?:
               failed[ ]to[ ]verify   # SoniWall
              |validation[ ]failure   # SoniWall
              )
            |backscatter[ ]protection[ ]detected[ ]an[ ]invalid[ ]or[ ]expired[ ]email[ ]address    # MDaemon
            |bogus[ ]mail[ ]from        # IMail - block empty sender
            |closed[ ]mailing[ ]list    # Exim test mail
            |denied[ ]\[bouncedeny\]    # McAfee
            |domain[ ]of[ ]sender[ ]address[ ].+[ ]does[ ]not[ ]exist
            |Emetteur[ ]invalide.+[A-Z]{3}.+(?:403|405|415)
            |empty[ ]envelope[ ]senders[ ]not[ ]allowed
            |error:[ ]no[ ]third-party[ ]dsns               # SpamWall - block empty sender
            |fully[ ]qualified[ ]email[ ]address[ ]required # McAfee
            |invalid[ ]domain,[ ]see[ ][<]url:.+[>]
            |Mail[ ]from[ ]not[ ]owned[ ]by[ ]user.+[A-Z]{3}.+421
            |Message[ ]rejected:[ ]Email[ ]address[ ]is[ ]not[ ]verified
            |mx[ ]records[ ]for[ ].+[ ]violate[ ]section[ ].+
            |name[ ]service[ ]error[ ]for[ ]    # Malformed MX RR or host not found
            |Null[ ]Sender[ ]is[ ]not[ ]allowed
            |recipient[ ]not[ ]accepted[.][ ][(]batv:[ ]no[ ]tag
            |returned[ ]mail[ ]not[ ]accepted[ ]here
            |rfc[ ]1035[ ]violation:[ ]recursive[ ]cname[ ]records[ ]for
            |rule[ ]imposed[ ]mailbox[ ]access[ ]for        # MailMarshal
            |sender[ ](?:
               verify[ ]failed        # Exim callout
              |not[ ]pre[-]approved
              |rejected
              |domain[ ]is[ ]empty
              )
            |syntax[ ]error:[ ]empty[ ]email[ ]address
            |the[ ]message[ ]has[ ]been[ ]rejected[ ]by[ ]batv[ ]defense
            |transaction[ ]failed[ ]unsigned[ ]dsn[ ]for
            )
          }ix

          return false if argv1 =~ isnot
          return true  if argv1 =~ regex
          return false
        end

        # Rejected by the envelope sender address or not
        # @param    [Sisimai::Data] argvs   Object to be detected the reason
        # @return   [True,False]            true: is rejected
        #                                   false: is not rejected by the sender
        # @see http://www.ietf.org/rfc/rfc2822.txt
        def true(argvs)
          return nil unless argvs
          return nil unless argvs.is_a? Sisimai::Data
          return nil unless argvs.deliverystatus.size > 0
          return true if argvs.reason == Sisimai::Reason::Rejected.text

          require 'sisimai/smtp/status'
          statuscode = argvs.deliverystatus || ''
          diagnostic = argvs.diagnosticcode || ''
          reasontext = Sisimai::Reason::Rejected.text
          v = false

          if Sisimai::SMTP::Status.name(statuscode) == reasontext
            # Delivery status code points C<rejected>.
            v = true
          else
            # Check the value of Diagnosic-Code: header with patterns
            if argvs.smtpcommand == 'MAIL'
              # Matched with a pattern in this class
              v = true if Sisimai::Reason::Rejected.match(diagnostic)
            end
          end

          return v
        end

      end
    end
  end
end



