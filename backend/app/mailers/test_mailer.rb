class TestMailer < ActionMailer::Base
  def test_email(to_email, from_email, body)
    @body = body
    mail(to: to_email, from: from_email, subject: 'This is a Test Email Sent from the Badge List Server')
  end
end
