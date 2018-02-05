module Sisimai
  module Reason
    # Sisimai::Reason::MailboxFull checks the bounce reason is "mailboxfull" or
    # not. This class is called only Sisimai::Reason class.
    #
    # This is the error that a recipient's mailbox is full. Sisimai will set
    # "mailboxfull" to the reason of email bounce if the value of Status: field
    # in a bounce email is "4.2.2" or "5.2.2".
    module MailboxFull
      # Imported from p5-Sisimail/lib/Sisimai/Reason/MailboxFull.pm
      class << self
        def text; return 'mailboxfull'; end
        def description; return "Email rejected due to a recipient's mailbox is full"; end

        # Try to match that the given text and regular expressions
        # @param    [String] argv1  String to be matched with regular expressions
        # @return   [True,False]    false: Did not match
        #                           true: Matched
        def match(argv1)
          return nil unless argv1
          regex = %r{(?>
             account[ ]disabled[ ]temporarly[ ]for[ ]exceeding[ ]receiving[ ]limits
            |account[ ]is[ ](?:
               exceeding[ ]their[ ]quota
              |over[ ]quota
              |temporarily[ ]over[ ]quota
              )
            |boite[ ]du[ ]destinataire[ ]pleine.+[a-z]{3}.+417
            |delivery[ ]failed:[ ]over[ ]quota
            |disc[ ]quota[ ]exceeded
            |does[ ]not[ ]have[ ]enough[ ]space
            |exceeded[ ]storage[ ]allocation
            |exceeding[ ]its[ ]mailbox[ ]quota
            |full[ ]mailbox
            |is[ ]over[ ](?:
               disk[ ]quota
              |quota[ ]temporarily
              )
            |mail[ ](?:
               file[ ]size[ ]exceeds[ ]the[ ]maximum[ ]size[ ]allowed[ ]for[ ]mail[ ]delivery
              |quota[ ]exceeded
              )
            |mailbox[ ](?:
              exceeded[ ]the[ ]local[ ]limit
              |full
              |has[ ]exceeded[ ]its[ ]disk[ ]space[ ]limit
              |is[ ]full
              |over[ ]quota
              |quota[ ]usage[ ]exceeded
              |size[ ]limit[ ]exceeded
              )
            |maildir[ ](?:
               delivery[ ]failed:[ ](?:user|domain)disk[ ]quota[ ]?.*[ ]exceeded
              |over[ ]quota
              )
            |mailfolder[ ]is[ ]full
            |not[ ]enough[ ]storage[ ]space[ ]in
            |over[ ]the[ ]allowed[ ]quota
            |quota[ ](?:
               exceeded
              |violation[ ]for
              )
            |recipient[ ](?:
               reached[ ]disk[ ]quota
              |rejected:[ ]mailbox[ ]would[ ]exceed[ ]maximum[ ]allowed[ ]storage
              )
            |the[ ](?:
               recipient[ ]mailbox[ ]has[ ]exceeded[ ]its[ ]disk[ ]space[ ]limit
              |user[']s[ ]space[ ]has[ ]been[ ]used[ ]up
              |user[ ]you[ ]are[ ]trying[ ]to[ ]reach[ ]is[ ]over[ ]quota
              )
            |too[ ]much[ ]mail[ ]data   # @docomo.ne.jp
            |user[ ](?:
               has[ ](?:
                 exceeded[ ]quota,[ ]bouncing[ ]mail
                |too[ ]many[ ]messages[ ]on[ ]the[ ]server
                )
              |is[ ]over[ ](?:the[ ])?quota
              |over[ ]quota
              |over[ ]quota[.][ ][(][#]5[.]1[.]1[)]   # qmail-toaster
              )
            |was[ ]automatically[ ]rejected:[ ]quota[ ]exceeded
            |would[ ]be[ ]over[ ]the[ ]allowed[ ]quota
            )
          }x

          return true if argv1 =~ regex
          return false
        end

        # The envelope recipient's mailbox is full or not
        # @param    [Sisimai::Data] argvs   Object to be detected the reason
        # @return   [True,False]            true: is mailbox full
        #                                   false: is not mailbox full
        # @see http://www.ietf.org/rfc/rfc2822.txt
        def true(argvs)
          return nil unless argvs
          return nil unless argvs.is_a? Sisimai::Data
          return nil unless argvs.deliverystatus.size > 0
          return true if argvs.reason == 'mailboxfull'

          # Delivery status code points "mailboxfull".
          # Status: 4.2.2
          # Diagnostic-Code: SMTP; 450 4.2.2 <***@example.jp>... Mailbox Full
          require 'sisimai/smtp/status'
          return true if Sisimai::SMTP::Status.name(argvs.deliverystatus) == 'mailboxfull'

          # Check the value of Diagnosic-Code: header with patterns
          return true if match(argvs.diagnosticcode.downcase)
          return false
        end

      end
    end
  end
end



