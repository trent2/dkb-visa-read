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
#    puts @agent.page.forms.first.fields[1].inspect
#    puts @agent.page.forms.first.fields[2].inspect
#    exit
    @agent.page.forms.first.fields[1].value = account
    @agent.page.forms.first.fields[2].value = password

    @mainPage = @agent.page.forms.first.submit
    log_current_page('logon')

#    raise DkbWebBankingError, 'Login fehlgeschlagen' if not @mainPage.form_with(:name => 'logoutform')
  end

  def logoff
    logoutLink = @agent.page.link_with(:text => 'Abmelden')
    unless logoutLink.nil?
      logoutLink.click
      log_current_page('logoff')
    end
  end

  def read_visa_turnovers(fromDate, toDate)
    # Umsätze / Kreditkartenumsätze
#    @agent.page.link_with(:text => /Ums.*tze/).click
    @agent.page.link_with(:text => /Kreditkartenums.*tze/).click
    log_current_page('creditCardPage')

    creditCardForms = @agent.page.forms_with(:name => /form-[0-9]+_1/)
    creditCardForm = nil
    for creditCardForm in creditCardForms
      unless creditCardForm.field_with(:name => 'slCreditCard').nil?
        break
      end
    end

    transactions = {}

    for card in creditCardForm.field_with(:name => 'slCreditCard').options
      creditCardForm.radiobuttons[1].check
      creditCardForm.postingDate = fromDate
      creditCardForm.toPostingDate = toDate
      card.select

      card.text =~ /([^ ]*) /
      card_number = $1.chomp.strip.tr('*','x')

      transactions[card_number] = []
      resultPage = creditCardForm.submit

      # click on link to first page of result list
      l = resultPage.link_with(:text => "1")
      unless l.nil?
        l.click
      end

      pageNumber = 1
      log_current_page("resultPage_#{card_number}_#{pageNumber}")
      transactions[card_number] += parse_visa_transactions(resultPage)

      for nextLink in resultPage.links_with(:text => /^[0-9]+$/) do
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
    for row in @agent.page.search('tbody tr') do
      columns = row.search('td')
      
      posting_date, receipt_date = columns[1].text.split

      transaction = CreditCardTransaction.new
      transaction.Date = posting_date
      transaction.ReceiptDate = receipt_date
      transaction.Payee = columns[2].text.strip
      columns[3].text.strip =~ /([-0-9.]+,[0-9]+)/m

      if columns[3].text.strip =~ /([-0-9.]+,[0-9]+)/m
        transaction.Amount = format_number($1)
        transactions << transaction
      end
    end
    return transactions
  end

  def log_current_page(filename)
    File.new("#{filename}.html", 'w') << @agent.page.body if @enableLogging
  end

  def format_number(number)
    # return number.tr('.', '').tr(',','.')
    return number.tr('.', '')
  end
end
