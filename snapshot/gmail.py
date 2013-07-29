#!/usr/bin/python
#
# Thank you, http://kutuma.blogspot.com/2007/08/sending-emails-via-gmail-with-python.html
#

import smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
import os

def send(to, subject, text, attach, user, pwd):

  msg = MIMEMultipart()

  msg['From']    = user
  msg['To']      = to
  msg['Subject'] = subject

  msg.attach(MIMEText(text))

  if attach is not None:
    part = MIMEBase('application', 'octet-stream')
    part.set_payload(open(attach, 'rb').read())
    Encoders.encode_base64(part)
    part.add_header('Content-Disposition',
      'attachment; filename="%s"' % os.path.basename(attach))
    msg.attach(part)

  mailServer = smtplib.SMTP("smtp.gmail.com", 587)
  #mailServer.set_debuglevel(1)
  mailServer.ehlo()
  mailServer.starttls()
  mailServer.ehlo()
  mailServer.login(user, pwd)
  mailServer.sendmail(user, to, msg.as_string())
  mailServer.close()
  