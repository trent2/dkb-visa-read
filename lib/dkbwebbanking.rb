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
    @agent.follow_meta_refresh = false
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
    form = @agent.page.forms.first

    form.field_with(name: name_for_label(/Anmeldename/)).value = account
    form.field_with(name: name_for_label(/PIN/)).value = password

    button = form.button_with(value: /Anmelden/)

    @agent.submit(form, button)
    log_current_page('logon')
  end

  def logoff
    @agent.page.link_with(:id => /logout/).click
    unless @agent.page.meta_refresh.empty?
        @agent.page.meta_refresh.first.click
    end
    log_current_page('logoff')
  end

  def read_visa_turnovers(fromDate, toDate)
    @agent.page.link_with(:text => /Kreditkartenums.*tze/).click
    unless @agent.page.meta_refresh.empty?
        @agent.page.meta_refresh.first.click
    end
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

  def name_for_label(label_text)
    @agent.page.labels.select { |l| l.text =~ /#{label_text}/ }
    .first.node.attribute('for').value
  end

  def log_current_page(filename)
    File.new("#{filename}.html", 'w') << @agent.page.body if @enableLogging
  end

  def format_number(number)
    return number.tr('.', '')
  end
end
