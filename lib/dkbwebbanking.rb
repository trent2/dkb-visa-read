#
# dkb-visa-read - reads the creditcard turnovers from the DKB web banking
#
# Copyright (C) 2006 - 2010 Tobias Grimm <tg:AT:e-tobi.net>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the 
# Free Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 
# 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

require 'rubygems'
require 'mechanize'
require 'logger'
require 'lib/creditcardtransaction'

class DkbWebBankingError < RuntimeError
end

class DkbWebBanking
  def initialize(enableLogging)
    @webBankingUrl = 'https://banking.dkb.de/dkb/-?$javascript=disabled'
    @enableLogging = enableLogging
    @agent = Mechanize.new
    @agent.follow_meta_refresh = true
    @agent.keep_alive = false
    if File.exists?('cacert.pem')
      @agent.ca_file = 'cacert.pem'
    else
      STDERR.puts('Warnung: Zertifikat-Datei cacert.pem nicht gefunden!')
    end
    @agent.log = Logger.new('dkb-visa-read.log') if @enableLogging
  end

  def logon(account, password)
    @agent.get(@webBankingUrl)
    @agent.page.forms.first.j_username  = account
    @agent.page.forms.first.j_password = password

    @mainPage = @agent.page.forms.first.submit
    log_current_page('logon')

    raise DkbWebBankingError, 'Login fehlgeschlagen' if not @mainPage.form_with(:name => 'logoutform')
  end

  def logoff
    logoutForm = @mainPage.form_with(:name => 'logoutform')
    if logoutForm
      logoutForm.click_button
      log_current_page('logoff')
    end
  end

  def read_visa_turnovers(fromDate, toDate)
    # Umsätze / Kreditkartenumsätze
    @agent.page.link_with(:text => /Kreditkartenums.*tze/).click
    log_current_page('creditCardPage')

    creditCardForm = @agent.page.form_with(:name => /form-.*/, :class => 'form validate')

    transactions = {}

    for card in creditCardForm.field_with('slCreditCard').options
      creditCardForm.radiobuttons[1].check
      creditCardForm.postingDate = fromDate
      creditCardForm.toPostingDate = toDate
      card.select

      card.text =~ /([^ ]*) /
      card_number = $1.chomp.strip.tr('*','x')

      transactions[card_number] = []

      pageNumber = 1
      resultPage = creditCardForm.submit

      #
      # The request for the second credit card might not start with the first
      # page, so we need to jump explicitly to the first page
      #
      firstPageLinkText = '|<'
      firstPageLinkText = '|&lt;' if !resultPage.link_with(:text => firstPageLinkText)

      if resultPage.link_with(:text => firstPageLinkText)
        resultPage = resultPage.link_with(:text => firstPageLinkText).click
      end
      log_current_page("resultPage_#{card_number}_#{pageNumber}")

      transactions[card_number] += parse_visa_transactions(resultPage)

      #
      # Workaround - on some systems, the &gt; entity is not translated to >
      #
      nextText = '>>'
      nextText = '&gt;&gt;' if !resultPage.link_with(:text => nextText)

      while nextLink = resultPage.link_with(:text => nextText) do
        pageNumber += 1
        resultPage = nextLink.click
        log_current_page("resultPage_#{card_number}_#{pageNumber}")
        transactions[card_number] += parse_visa_transactions(resultPage)
      end
    end

    return transactions
  end

  def parse_visa_transactions(doc)
    transactions = []
    for row in @agent.page.search('tr')
      columns = row.search('td')
      if columns.count > 1
        posting_date, receipt_date = columns[1].text.split

        transaction = CreditCardTransaction.new
        transaction.Date = posting_date
        transaction.ReceiptDate = receipt_date
        transaction.Payee = columns[2].text.strip

        if columns[3].text.strip =~ /(.[0-9.]+,[0-9]+)/m
          transaction.Amount = format_number($1)
          transactions << transaction
        end
      end
    end
    return transactions
  end

  def format_number(number)
    #    return number.tr('.', '').tr(',','.')
    return number.tr('.', '')
  end

  def log_current_page(filename)
    File.new("#{filename}.html", 'w') << @agent.page.body if @enableLogging
  end
end

